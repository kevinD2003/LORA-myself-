"""Validate and aggregate paired full-curve evidence without pooling cohorts.

Uses NumPy; creates no simulations or surrogate observations.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
METHODS = ("prec", "vp", "paper", "idealNative", "idealPaper")
ACTUAL_METHODS = METHODS[:3]
BUDGETS = {"validation100": 100, "formal1000": 1000}
BOOTSTRAPS = {"validation100": 4000, "formal1000": 10000}
SEED_ROOTS = {"validation100": 2700000000, "formal1000": 2800000000}
CHIRPS = 112
REFERENCE = ROOT.parent / "results" / "conditions.json"
OLD_ENDPOINT_METADATA = ROOT.parent / "k10_multipath_revision" / "results" / "analysis" / "MP_K10_CONFIRM1000_24.csv"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def write_csv(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def integer(row, field):
    value = float(row[field])
    require(math.isfinite(value) and value == int(value), f"Invalid integer {field}")
    return int(value)


def close(actual, expected, label):
    require(math.isclose(float(actual), float(expected), rel_tol=2e-11, abs_tol=2e-12), label)


def bootstrap_means(counts, denominator, replicates, seed):
    """Histogram resampling is exactly packet bootstrap, including ties."""
    counts = np.asarray(counts, dtype=np.int64)
    require(counts.ndim == 1 and len(counts) > 0, "Empty/nonvector packet sample")
    require(denominator > 0 and replicates > 0, "Invalid bootstrap denominator/budget")
    values, frequencies = np.unique(counts, return_counts=True)
    rng = np.random.default_rng(seed)
    out = np.empty(replicates)
    for start in range(0, replicates, 1000):
        size = min(1000, replicates - start)
        draws = rng.multinomial(len(counts), frequencies / len(counts), size=size)
        out[start:start + size] = (draws @ values) / (len(counts) * denominator)
    return out


def interval(counts, denominator, replicates, seed):
    counts = np.asarray(counts, dtype=np.int64)
    require(counts.ndim == 1 and len(counts) > 0, "No packet errors")
    require(np.all((counts >= 0) & (counts <= denominator)), "Packet errors outside denominator")
    errors = int(counts.sum())
    rate = errors / (len(counts) * denominator)
    if errors == 0:
        # A packet error indicator dominates its fractional symbol/bit loss.
        # This upper bound allows arbitrary within-packet error dependence.
        upper = float(-np.expm1(np.log(.05) / len(counts)))
        return {"errors": errors, "rate": rate, "ciLow": 0., "ciHigh": upper,
                "upperOneSided95": upper, "zeroEvents": True,
                "ciMethod": "zero-event exact packet one-sided95 conservative rate upper",
                "bootstrapReplicates": 0}
    boot = bootstrap_means(counts, denominator, replicates, seed)
    return {"errors": errors, "rate": rate, "ciLow": float(np.quantile(boot, .025)),
            "ciHigh": float(np.quantile(boot, .975)), "upperOneSided95": float(np.quantile(boot, .95)),
            "zeroEvents": False, "ciMethod": "packet histogram bootstrap percentile two-sided95",
            "bootstrapReplicates": replicates}


def paired_interval(first, second, denominator, replicates, seed):
    require(len(first) == len(second), "Unpaired packet samples")
    difference = np.asarray(first, dtype=np.int64) - np.asarray(second, dtype=np.int64)
    boot = bootstrap_means(difference, denominator, replicates, seed)
    return {"rateDifference": float(difference.mean() / denominator),
            "ciLow": float(np.quantile(boot, .025)), "ciHigh": float(np.quantile(boot, .975)),
            "bootstrapReplicates": replicates, "ciMethod": "paired packet bootstrap percentile two-sided95"}


def normalized_family(point):
    family = str(point["family"]).lower()
    if family == "case":
        family += str(int(point["caseIndex"]))
    require(family in ("case1", "case2", "half"), f"Unrecognized family {family}")
    return family


def verify_grid(points):
    require(len(points) == 100, "Plan must contain all 100 physical points")
    require(len({p["id"] for p in points}) == 100, "Duplicate point id in plan")
    require(sorted(int(p["index"]) for p in points) == list(range(1, 101)), "Point indices must be 1:100")
    seen = set()
    for point in points:
        sf, channel = int(point["sf"]), point["channel"]
        family = normalized_family(point)
        require(sf in (7, 12) and channel in ("AWGN", "Rician"), "Unsupported SF/channel")
        start, snr = float(point["orbitStartSec"]), float(point["snrDb"])
        close(point["esN0Db"], snr + 10 * math.log10(2 ** sf), "Es/N0 does not match sample SNR")
        if family.startswith("case"):
            require(snr in range(-15 if sf == 7 else -30, -5 if sf == 7 else -20), "Wrong full SNR sweep")
            close(start, -366 if family == "case1" else 0, "Wrong case orbit time")
        else:
            require(start in (-366, -274.5, -183, -91.5, 0), "Wrong half-orbit sample")
            close(point["esN0Db"], 14 if channel == "AWGN" else 15, "Wrong half-orbit Es/N0")
        key = (sf, channel, family, snr if family.startswith("case") else start)
        require(key not in seen, f"Duplicate physical point {key}")
        seen.add(key)
    for sf in (7, 12):
        for channel in ("AWGN", "Rician"):
            for family in ("case1", "case2", "half"):
                require(sum(p[:3] == (sf, channel, family) for p in seen) == (5 if family == "half" else 10), "Incomplete curve in plan")


def provenance_files(manifest, evidence):
    sources = manifest["codeProvenance"]
    if isinstance(sources, dict):
        sources = [sources]
    require(isinstance(sources, list) and len(sources) > 0, "Missing source provenance")
    for source in sources:
        path = Path(source["path"])
        require(path.is_file() and sha256(path) == source["sha256"], f"Frozen source changed: {path}")
        evidence[str(path.resolve())] = {"path": str(path.resolve()), "sha256": source["sha256"]}
    return tuple(sorted((s["path"], s["sha256"]) for s in sources))


def validate_point(directory, point, cohort, evidence):
    summary = load(directory / "SUMMARY.json")
    manifest_path = directory / "MANIFEST.json"
    manifest = load(manifest_path)
    raw_path = directory / "RAW_PACKETS.csv"
    raw = read_csv(raw_path)
    budget = BUDGETS[cohort]
    require(summary["pointId"] == point["id"] and summary["cohort"] == cohort, "Wrong point/cohort")
    require(manifest["cohort"] == cohort and manifest["pointId"] == point["id"], "Wrong manifest point/cohort")
    if "signature" in summary:
        require(summary["signature"] == sha256(manifest_path), "Manifest signature mismatch")
    require(summary["plannedPackets"] == budget and manifest["plannedPackets"] == budget, "Wrong fixed cohort budget")
    require(len(raw) == summary["packets"] and 0 < len(raw) <= budget, "Raw/summary packet budget mismatch")
    require(bool(summary["complete"]) == (len(raw) == budget), "Incorrect completion flag")
    require(summary["channel"] == point["channel"], "Wrong channel")
    for key in ("sf", "snrDb", "esN0Db", "orbitStartSec"):
        close(summary[key], point[key], f"Wrong point metadata: {key}")
    require(summary["globalKDb"] == 10 and summary["profileIndex"] == 5, "K/PDP changed")
    require(summary["profileSha256"] == manifest["profileSha256"], "PDP hash mismatch")
    profile = manifest["config"]["channelProfile"]
    require(profile["id"] == "d1-2-3-4_equal" and profile["delayedSamples"] == [1, 2, 3, 4]
            and profile["powers"] == [.25] * 4, "Registered PDP 5 changed")
    close(profile["losPhaseRad"], 0, "LOS phase changed")
    require(manifest["vpHistoryLength"] == 8, "VP history length changed")
    require(manifest["symbolSource"] == "native-FFT-hard-chirp-before-FEC"
            and summary["symbolSource"] == manifest["symbolSource"], "SER source changed")
    require(manifest["bitErrorStage"] == "hard-FEC-decoded-information-bits"
            and summary["bitErrorStage"] == manifest["bitErrorStage"], "Decoded-BER stage changed")
    require(summary["methodIds"] == list(METHODS), "Receiver method set/order changed")
    require(summary["cr"] == 3 and summary["dataChirps"] == CHIRPS and summary["noLdro"], "PHY/SER denominator changed")
    require(summary["informationBits"] == (448 if point["sf"] == 7 else 768), "Information-bit denominator changed")
    require(summary["nativePhysicalRows"] == 120 and summary["paperPhysicalRows"] == (129 if point["sf"] == 7 else 157), "Frame geometry changed")
    require(not summary["perPacketPowerNormalization"] and not summary["idealRemovesFading"], "Channel/ideal convention changed")
    require([integer(r, "packetId") for r in raw] == list(range(1, len(raw) + 1)), "Missing/duplicate packet ids")
    require(manifest["packetSeedStride"] == 8, "Seed stride changed")
    expected_base = SEED_ROOTS[cohort] + point["index"] * 100000
    require(manifest["packetSeedBase"] == expected_base, "Wrong cohort/point seed base")
    for row in raw:
        base = expected_base + integer(row, "packetId") * 8
        for field, offset in (("payloadSeed", 0), ("noiseSeed", 1), ("channelSeed", 2)):
            require(integer(row, field) == base + offset, f"Seed mismatch: {field}")
        if "paperExtraNoiseSeed" in row:
            require(integer(row, "paperExtraNoiseSeed") == base + 3, "Paper extra-noise seed mismatch")
        close(row["noiseVariance"], 10 ** (-float(point["snrDb"]) / 10), "Noise is not fixed by nominal SNR")
        if "channelPower" in row:
            power = float(row["channelPower"])
            require(math.isfinite(power) and power >= 0, "Invalid channel power")
            if point["channel"] == "AWGN":
                close(power, 1, "AWGN channel power changed")
        for field in ("runtimePrecSec", "runtimeVpSec", "runtimePaperSec"):
            if field in row:
                value = float(row[field])
                require(math.isnan(value) or (math.isfinite(value) and value >= 0), f"Invalid optional {field}")
        if "acceptedVp" in row:
            require(integer(row, "acceptedVp") in (0, 1), "Invalid VP acceptance flag")
        for method in METHODS:
            errors, failure = integer(row, method + "Errors"), integer(row, method + "Failure")
            require(0 <= errors <= CHIRPS and failure in (0, 1), f"Invalid {method} hard-error/failure count")
            require(not failure or errors == CHIRPS, f"{method} failure dropped from SER")
        for method in METHODS:
            errors, failure = integer(row, method + "BitErrors"), integer(row, method + "DecodeFailure")
            require(0 <= errors <= summary["informationBits"] and failure in (0, 1), f"Invalid {method} decoded-bit count")
            require(not failure or errors == summary["informationBits"], f"{method} decode failure dropped from BER")
    for method in METHODS:
        errors = sum(integer(r, method + "Errors") for r in raw)
        require(errors == summary[method + "Errors"], f"{method} raw/summary errors differ")
        close(summary[method + "Ser"], errors / (len(raw) * CHIRPS), f"{method} raw/summary SER differs")
        require(sum(integer(r, method + "Failure") for r in raw) == summary[method + "Failures"], f"{method} failure totals differ")
    for method in METHODS:
        errors = sum(integer(r, method + "BitErrors") for r in raw)
        require(errors == summary[method + "BitErrors"], f"{method} raw/summary bit errors differ")
        close(summary[method + "Ber"], errors / (len(raw) * summary["informationBits"]), f"{method} raw/summary BER differs")
        if method + "DecodeFailures" in summary:
            require(sum(integer(r, method + "DecodeFailure") for r in raw) == summary[method + "DecodeFailures"], f"{method} decode failure totals differ")
    identity = provenance_files(manifest, evidence)
    for path in (directory / "SUMMARY.json", manifest_path, raw_path, directory / "CHECKPOINT.mat"):
        require(path.is_file(), f"Missing evidence: {path}")
        evidence[str(path.resolve())] = {"path": str(path.resolve()), "sha256": sha256(path)}
    return summary, raw, manifest, identity


def endpoint_comparison(rows, points, evidence):
    """Read published reference metadata only; never consume old packet counts."""
    reference = load(REFERENCE)
    refs = {r["id"]: r for r in reference["reference"]}
    evidence[str(REFERENCE.resolve())] = {"path": str(REFERENCE.resolve()), "sha256": sha256(REFERENCE)}
    corrected_targets = {}
    if OLD_ENDPOINT_METADATA.is_file():
        for old in read_csv(OLD_ENDPOINT_METADATA):
            method = "paper" if old["condition"] == "actual_method" else "idealPaper"
            corrected_targets[(old["pointId"], method)] = float(old["paperTargetSer"])
        evidence[str(OLD_ENDPOINT_METADATA.resolve())] = {"path": str(OLD_ENDPOINT_METADATA.resolve()), "sha256": sha256(OLD_ENDPOINT_METADATA)}
    out = []
    for reference_point in reference["points"]:
        family = normalized_family(reference_point)
        candidates = [p for p in points if p["sf"] == reference_point["sf"] and p["channel"] == reference_point["channel"]
                      and normalized_family(p) == family
                      and math.isclose(p["orbitStartSec"], reference_point["orbitStartSec"], abs_tol=1e-10)
                      and math.isclose(p["snrDb"], reference_point["snrDb"], abs_tol=1e-10)]
        require(len(candidates) == 1, f"Published endpoint absent from new grid: {reference_point['id']}")
        point = candidates[0]
        for method, target_field in (("paper", "methodTargetSer"), ("idealPaper", "baselineTargetSer")):
            target = corrected_targets.get((reference_point["id"], method), refs[reference_point["id"]][target_field])
            match = [r for r in rows if r["pointId"] == point["id"] and r["metric"] == "preFecHardSer" and r["method"] == method]
            require(len(match) <= 1, "Duplicated endpoint metric")
            row = {"referenceId": reference_point["id"], "pointId": point["id"], "sf": point["sf"],
                   "channel": point["channel"], "family": family, "snrDb": point["snrDb"],
                   "esN0Db": point["esN0Db"], "orbitStartSec": point["orbitStartSec"], "method": method,
                   "frame": "paper-midamble", "paperTargetSer": target, "packets": "", "errors": "", "ser": "",
                   "ciLow": "", "ciHigh": "", "upperOneSided95": "", "nominalAtOrBelow": "", "pointwise95AtOrBelow": "",
                   "complete": False, "status": "PENDING", "referenceSource": refs[reference_point["id"]]["source"]}
            if match:
                observed = match[0]
                row.update({k: observed[k] for k in ("packets", "errors", "ciLow", "ciHigh", "upperOneSided95", "complete")})
                row.update({"ser": observed["rate"], "nominalAtOrBelow": observed["rate"] <= target,
                            "pointwise95AtOrBelow": observed["upperOneSided95"] <= target})
                if observed["complete"]:
                    row["status"] = "AT_OR_BELOW" if row["nominalAtOrBelow"] else "ABOVE"
            out.append(row)
    require(len(out) == 24, "Expected 24 paper/idealPaper reference comparisons")
    return out


def aggregate(cohort, plan_path, results_root=ROOT / "results"):
    results_root = Path(results_root)
    require(results_root.resolve().is_relative_to(ROOT.resolve()), "Results writes must stay inside this experiment directory")
    plan = load(plan_path)
    points = plan["points"] if isinstance(plan, dict) else plan
    verify_grid(points)
    evidence = {str(plan_path.resolve()): {"path": str(plan_path.resolve()), "sha256": sha256(plan_path)}}
    script_path = Path(__file__).resolve()
    evidence[str(script_path)] = {"path": str(script_path), "sha256": sha256(script_path)}
    rows, pairs, missing, incomplete, invalid = [], [], [], [], []
    profile_hash, source_identity, frozen_manifest = None, None, None
    receiver_failures, decode_failures = 0, 0
    for point in sorted(points, key=lambda p: p["index"]):
        directory = results_root / cohort / point["id"]
        if not (directory / "SUMMARY.json").exists():
            missing.append(point["id"])
            continue
        try:
            summary, raw, manifest, identity = validate_point(directory, point, cohort, evidence)
            if source_identity is None:
                source_identity, profile_hash, frozen_manifest = identity, summary["profileSha256"], manifest
            require(identity == source_identity and profile_hash == summary["profileSha256"], "Mixed source/PDP across points")
        except (KeyError, ValueError, OSError, TypeError) as error:
            invalid.append({"pointId": point["id"], "reason": str(error)})
            continue
        if not summary["complete"]:
            incomplete.append(point["id"])
        receiver_failures += sum(summary[m + "Failures"] for m in METHODS)
        decode_failures += sum(summary[m + "DecodeFailures"] for m in METHODS)
        common = {"pointId": point["id"], "index": point["index"], "cohort": cohort,
                  "sf": point["sf"], "channel": point["channel"], "family": normalized_family(point),
                  "snrDb": point["snrDb"], "esN0Db": point["esN0Db"], "orbitStartSec": point["orbitStartSec"],
                  "packets": len(raw), "plannedPackets": BUDGETS[cohort], "complete": bool(summary["complete"]),
                  "globalKDb": 10, "profileIndex": 5, "profileSha256": profile_hash,
                  "rawPath": str((directory / "RAW_PACKETS.csv").resolve()), "rawSha256": sha256(directory / "RAW_PACKETS.csv")}
        seed = 4190000000 + (100000 if cohort == "formal1000" else 0) + point["index"] * 100
        metrics = (("preFecHardSer", METHODS, "Errors", CHIRPS),
                   ("decodedBer", ACTUAL_METHODS, "BitErrors", summary["informationBits"]))
        for metric_index, (metric, methods, suffix, denominator) in enumerate(metrics):
            counts = {m: np.array([integer(r, m + suffix) for r in raw], dtype=np.int64) for m in methods}
            for number, method in enumerate(methods):
                failure_field = method + ("Failure" if metric == "preFecHardSer" else "DecodeFailure")
                rows.append({**common, "metric": metric, "method": method,
                             "frame": "paper-midamble" if method in ("paper", "idealPaper") else "native-no-midamble",
                             "denominatorPerPacket": denominator, "denominatorTotal": len(raw) * denominator,
                             "failures": sum(integer(r, failure_field) for r in raw),
                             **interval(counts[method], denominator, BOOTSTRAPS[cohort], seed + metric_index * 40 + number)})
            for number, (first, second) in enumerate((("vp", "prec"), ("vp", "paper"), ("prec", "paper"))):
                pairs.append({**common, "metric": metric, "firstMethod": first, "secondMethod": second,
                              **paired_interval(counts[first], counts[second], denominator, BOOTSTRAPS[cohort], seed + metric_index * 40 + 20 + number)})
    endpoints = endpoint_comparison(rows, points, evidence)
    out = results_root / cohort / "analysis"
    metric_path, paired_path = out / "ALL_CURVES_METRICS.csv", out / "ALL_CURVES_PAIRED_DIFFERENCES.csv"
    if rows:
        write_csv(metric_path, rows)
        write_csv(paired_path, pairs)
    else:
        metric_path.unlink(missing_ok=True)
        paired_path.unlink(missing_ok=True)
    endpoint_path = out / "ENDPOINT_24_COMPARISON.csv"
    write_csv(endpoint_path, endpoints)
    complete = not missing and not incomplete and not invalid and len(rows) == 800
    status = {"status": "COMPLETE" if complete else "PENDING", "complete": complete, "cohort": cohort,
              "packetsPerPoint": BUDGETS[cohort], "bootstrapReplicates": BOOTSTRAPS[cohort],
              "expectedPhysicalPoints": 100, "validPhysicalPoints": len({r["pointId"] for r in rows}),
              "completedPhysicalPoints": len({r["pointId"] for r in rows if r["complete"]}),
              "expectedSerRows": 500, "serRows": sum(r["metric"] == "preFecHardSer" for r in rows),
              "expectedDecodedBerRows": 300, "decodedBerRows": sum(r["metric"] == "decodedBer" for r in rows),
              "expectedMainFiguresPerMetric": 12, "missingPointIds": missing, "incompletePointIds": incomplete,
              "receiverFailures": receiver_failures, "decodeFailures": decode_failures,
              "endpointComparisonRows": 24, "completeEndpointRows": sum(r["complete"] for r in endpoints),
              "endpointNominalAtOrBelow": sum(r["complete"] and r["nominalAtOrBelow"] for r in endpoints),
              "endpointPointwise95AtOrBelow": sum(r["complete"] and r["pointwise95AtOrBelow"] for r in endpoints),
              "endpointCsv": str(endpoint_path.resolve()), "endpointCsvSha256": sha256(endpoint_path),
              "invalidPoints": invalid, "profileSha256": profile_hash, "metricCsv": str(metric_path.resolve()),
              "metricCsvSha256": sha256(metric_path) if rows else None,
              "pairedDifferenceCsv": str(paired_path.resolve()), "evidenceFiles": list(evidence.values()),
              "files": list(evidence.values()),
              "pairedDifferenceCsvSha256": sha256(paired_path) if rows else None,
              "ciNote": "Nonzero: packet bootstrap two-sided95. Zero: conservative exact packet one-sided95 upper; measured rate remains zero.",
              "metricNote": "SER is 112 pre-FEC hard FFT chirps per packet for every method. Decoded BER is separate.",
              "idealNote": "IdealNative and IdealPaper retain their own frame timing and frequency-selective fading; they are separate ideals."}
    dump(out / "AGGREGATE_MANIFEST.json", status)
    if cohort == "validation100":
        gate_path = results_root / "validation100" / "analysis" / "VALIDATION_GATE.json"
        if complete and receiver_failures == 0 and decode_failures == 0:
            gate = {"passed": True, "plannedPackets": 100, "completePoints": 100,
                    "receiverFailures": 0, "decodeFailures": 0, "profileSha256": profile_hash,
                    "codeProvenance": frozen_manifest["codeProvenance"],
                    "receiverIdentity": frozen_manifest["receiverIdentity"], "planSha256": sha256(plan_path),
                    "aggregateManifestPath": str((out / "AGGREGATE_MANIFEST.json").resolve()),
                    "aggregateManifestSha256": sha256(out / "AGGREGATE_MANIFEST.json"),
                    "gatePolicy": "Exact 100-packet coverage, raw counts, current source hashes, and zero receiver/decoder failures. No SER threshold or method ranking."}
            dump(gate_path, gate)
        else:
            gate_path.unlink(missing_ok=True)
    return status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cohort", choices=BUDGETS)
    parser.add_argument("--plan", type=Path, default=ROOT / "POINTS.json")
    parser.add_argument("--results-root", type=Path, default=ROOT / "results")
    args = parser.parse_args()
    status = aggregate(args.cohort, args.plan, args.results_root)
    fields = ("status", "cohort", "validPhysicalPoints", "completedPhysicalPoints", "serRows", "decodedBerRows", "missingPointIds", "invalidPoints")
    print(json.dumps({k: status[k] for k in fields}, indent=2))


if __name__ == "__main__":
    main()
