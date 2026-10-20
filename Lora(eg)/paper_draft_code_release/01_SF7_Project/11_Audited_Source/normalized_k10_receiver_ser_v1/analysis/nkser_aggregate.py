"""Validate and aggregate frozen AWGN with normalized-K10 Rician SER evidence.

This program never simulates packets and never writes inside the frozen AWGN
directory.  Cohorts are validated independently and joined only in summary
tables.
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
FROZEN = ROOT.parent / "all_curves_symbolvp_k10"
PROFILE = ROOT.parent / "normalized_k10_pdp_v1" / "CHANNEL_PROFILE.json"
REFERENCE = ROOT.parent / "results" / "conditions.json"
METHODS = ("prec", "vp", "paper", "idealNative", "idealPaper")
METHOD_PAIRS = tuple((METHODS[i], METHODS[j]) for i in range(5) for j in range(i + 1, 5))
GATE_INDICES = (10, 20, 25, 35, 45, 50)
PROFILE_SHA256 = "1f596a8252e946cb64307d55fcc546e2b69dbc0f0106fb6737d137f5f639d350"
SEED_ROOTS = {"gate100": 3_000_000_000, "formal1000": 3_100_000_000}
CHIRPS = 112


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def text_sha256(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def dump(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def read_csv(path):
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def write_csv(path, rows, fieldnames=None):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if fieldnames is None:
        require(rows, f"Cannot infer columns for empty CSV {path}")
        fieldnames = list(rows[0])
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(path)


def integer(row, field):
    value = float(row[field])
    require(math.isfinite(value) and value == int(value), f"Invalid integer {field}")
    return int(value)


def close(actual, expected, label):
    require(math.isclose(float(actual), float(expected), rel_tol=2e-11, abs_tol=2e-12), label)


def family(point):
    value = str(point["family"]).lower()
    if value == "case":
        value += str(int(point["caseIndex"]))
    require(value in ("case1", "case2", "half"), f"Invalid family {value}")
    return value


def bootstrap_means(values, denominator, replicates, seed):
    values = np.asarray(values, dtype=np.float64)
    require(values.ndim == 1 and len(values), "Empty bootstrap sample")
    unique, counts = np.unique(values, return_counts=True)
    rng = np.random.default_rng(seed)
    output = np.empty(replicates)
    for start in range(0, replicates, 1000):
        size = min(1000, replicates - start)
        draws = rng.multinomial(len(values), counts / len(values), size=size)
        output[start:start + size] = (draws @ unique) / (len(values) * denominator)
    return output


def interval(counts, denominator, seed, replicates=10_000):
    counts = np.asarray(counts, dtype=np.int64)
    require(np.all((counts >= 0) & (counts <= denominator)), "Error count outside denominator")
    errors = int(counts.sum())
    rate = errors / (len(counts) * denominator)
    if errors == 0:
        upper = float(-np.expm1(np.log(.05) / len(counts)))
        return {"errors": 0, "rate": 0.0, "ciLow": 0.0, "ciHigh": upper,
                "upperOneSided95": upper, "zeroEvents": True,
                "ciMethod": "conservative exact packet zero-event one-sided95", "bootstrapReplicates": 0}
    boot = bootstrap_means(counts, denominator, replicates, seed)
    return {"errors": errors, "rate": rate, "ciLow": float(np.quantile(boot, .025)),
            "ciHigh": float(np.quantile(boot, .975)), "upperOneSided95": float(np.quantile(boot, .95)),
            "zeroEvents": False, "ciMethod": "paired-packet bootstrap percentile",
            "bootstrapReplicates": replicates}


def paired_interval(first, second, seed, replicates=10_000):
    difference = np.asarray(first, dtype=np.int64) - np.asarray(second, dtype=np.int64)
    boot = bootstrap_means(difference, CHIRPS, replicates, seed)
    return {"rateDifference": float(difference.mean() / CHIRPS),
            "ciLow": float(np.quantile(boot, .025)), "ciHigh": float(np.quantile(boot, .975)),
            "upperOneSided95": float(np.quantile(boot, .95)),
            "bootstrapReplicates": replicates, "ciMethod": "paired-packet bootstrap percentile"}


def verify_profile():
    require(sha256(PROFILE) == PROFILE_SHA256, "Registered profile bytes changed")
    value = load(PROFILE)
    require(value["id"] == "normalized-k10-zero038-exp13-d1-4-v1", "Wrong profile id")
    require(value["ricianKDb"] == 10 and value["ensembleTotalPower"] == 1, "Wrong K/power")
    require(value["linkMarginDb"] == 0 and not value["perPacketPowerNormalization"], "Margin/normalization changed")
    require(value["delaysSamples"] == [0, 1, 2, 3, 4], "Delay grid changed")
    expected = [.38, .4535322280719623, .12360195131516263, .033685461414424, .009180359198451017]
    require(all(math.isclose(a, b, abs_tol=1e-15) for a, b in zip(value["diffuseRelativePowers"], expected)),
            "Diffuse relative powers changed")
    return value


def verify_new_plan():
    plan_path = ROOT / "POINTS.json"
    plan = load(plan_path)
    points = plan["points"]
    require(len(points) == 50 and [int(p["localIndex"]) for p in points] == list(range(1, 51)), "Wrong Rician plan size/order")
    require([int(p["originalIndex"]) for p in points] == list(range(51, 101)), "Wrong original indices")
    require(plan["gateLocalIndices"] == list(GATE_INDICES), "Gate endpoints changed")
    require(plan["seedRoots"] == {"gate100": 3_000_000_000, "formal1000": 3_100_000_000,
                                  "pairedHalf100": 3_200_000_000}, "Seed roots changed")
    seen = set()
    for point in points:
        require(point["channel"] == "Rician" and int(point["sf"]) in (7, 12), "Non-Rician point in new plan")
        expected_grid = range(-15, -5) if int(point["sf"]) == 7 else range(-30, -20)
        coordinate = float(point["orbitStartSec"])
        if family(point).startswith("case"):
            require(float(point["snrDb"]) in expected_grid, "Wrong case SNR")
            close(coordinate, -366 if family(point) == "case1" else 0, "Wrong case time")
        else:
            require(coordinate in (-366, -274.5, -183, -91.5, 0), "Wrong half-orbit time")
            close(point["esN0Db"], 15, "Wrong Rician half-orbit Es/N0")
        close(point["esN0Db"], float(point["snrDb"]) + 10 * math.log10(2 ** int(point["sf"])), "Es/N0 mismatch")
        key = (int(point["sf"]), family(point), float(point["snrDb"]), coordinate)
        require(key not in seen, "Duplicate new physical point")
        seen.add(key)
    return plan_path, plan, points


def verify_sources(entries):
    require(entries and isinstance(entries, list), "Missing source provenance")
    for item in entries:
        path = Path(item["path"])
        require(path.is_file() and sha256(path) == item["sha256"], f"Frozen source changed: {path}")
    return text_sha256(json.dumps(entries, separators=(",", ":"), ensure_ascii=False))


def validate_new_point(point, cohort, evidence):
    budget = 100 if cohort == "gate100" else 1000
    directory = ROOT / "results" / cohort / point["id"]
    summary_path, manifest_path = directory / "SUMMARY.json", directory / "MANIFEST.json"
    raw_path, checkpoint_path = directory / "RAW_PACKETS.csv", directory / "CHECKPOINT.mat"
    require(all(path.is_file() for path in (summary_path, manifest_path, raw_path, checkpoint_path)),
            f"Missing new point evidence {point['id']}")
    summary, manifest, raw = load(summary_path), load(manifest_path), read_csv(raw_path)
    require(summary["pointId"] == point["id"] == manifest["pointId"], "New point identity mismatch")
    require(summary["cohort"] == cohort == manifest["cohort"], "New cohort mismatch")
    require(summary["signature"] == sha256(manifest_path), "New manifest signature mismatch")
    require(summary["complete"] and summary["packets"] == budget == len(raw), "New packet budget incomplete")
    require(summary["plannedPackets"] == budget == manifest["plannedPackets"], "New planned budget mismatch")
    require(summary["profileSha256"] == manifest["profileSha256"] == PROFILE_SHA256, "New profile hash mismatch")
    require(summary["profileId"] == manifest["profileId"] == "normalized-k10-zero038-exp13-d1-4-v1", "Wrong new profile")
    require(summary["kDb"] == 10 and summary["ensembleTotalPower"] == 1 and summary["linkMarginDb"] == 0,
            "Wrong new channel normalization")
    require(not summary["perPacketPowerNormalization"] and not summary["idealRemovesFading"], "Wrong normalization/ideal")
    require(summary["metric"] == manifest["metric"] == "pre-FEC-FFT-hard-chirp-SER-only", "Wrong new metric")
    require(not summary["berGenerated"] and not any("Bit" in key or "Ber" in key for key in summary), "BER leaked into summary")
    require(not any("Bit" in name or "Ber" in name for name in raw[0]), "BER leaked into raw packet table")
    require(summary["methodIds"] == list(METHODS) == manifest["methodIds"], "New method set changed")
    require(summary["cr"] == 3 and summary["dataChirps"] == CHIRPS and summary["noLdro"], "New PHY changed")
    require(summary["nativePhysicalRows"] == 120 and summary["paperPhysicalRows"] == (129 if int(point["sf"]) == 7 else 157),
            "New frame geometry changed")
    for key in ("localIndex", "originalIndex", "sf", "snrDb", "esN0Db", "orbitStartSec"):
        close(summary[key], point[key], f"New point metadata mismatch {key}")
    require(family(summary) == family(point), "New family mismatch")
    source_digest = verify_sources(manifest["codeProvenance"])
    require([integer(row, "packetId") for row in raw] == list(range(1, budget + 1)), "New packet ids are not continuous")
    expected_base = SEED_ROOTS[cohort] + int(point["originalIndex"]) * 100_000
    require(manifest["packetSeedBase"] == expected_base and manifest["packetSeedStride"] == 8, "New seed base changed")
    counts, failures = {}, {}
    for row in raw:
        base = expected_base + integer(row, "packetId") * 8
        for name, offset in (("payloadSeed", 0), ("noiseSeed", 1), ("channelSeed", 2), ("paperExtraNoiseSeed", 3)):
            require(integer(row, name) == base + offset, f"New seed mismatch {name}")
        close(row["noiseVariance"], 10 ** (-float(point["snrDb"]) / 10), "New noise variance changed")
        energy = float(row["realizedTapEnergy"])
        require(math.isfinite(energy) and energy >= 0, "Invalid realized tap energy")
    for method in METHODS:
        method_counts = np.array([integer(row, method + "Errors") for row in raw], dtype=np.int64)
        method_failures = np.array([integer(row, method + "Failure") for row in raw], dtype=np.int64)
        require(np.all((method_counts >= 0) & (method_counts <= CHIRPS)), f"Invalid {method} errors")
        require(np.all((method_failures == 0) | (method_failures == 1)), f"Invalid {method} failure")
        require(np.all((method_failures == 0) | (method_counts == CHIRPS)), f"Dropped {method} failure")
        require(int(method_counts.sum()) == int(summary[method + "Errors"]), f"New {method} total mismatch")
        close(summary[method + "Ser"], method_counts.sum() / (budget * CHIRPS), f"New {method} SER mismatch")
        require(int(method_failures.sum()) == int(summary[method + "Failures"]), f"New {method} failure total mismatch")
        counts[method], failures[method] = method_counts, int(method_failures.sum())
    for path in (summary_path, manifest_path, raw_path, checkpoint_path):
        evidence[str(path.resolve())] = {"path": str(path.resolve()), "sha256": sha256(path)}
    return summary, manifest, raw, counts, failures, source_digest


def frozen_points():
    plan = load(FROZEN / "POINTS.json")
    points = [point for point in plan["points"] if point["channel"] == "AWGN"]
    require(len(points) == 50 and [int(p["index"]) for p in points] == list(range(1, 51)), "Frozen AWGN grid changed")
    return points


def validate_frozen_awgn(point, evidence):
    directory = FROZEN / "results" / "formal1000" / point["id"]
    summary_path, manifest_path = directory / "SUMMARY.json", directory / "MANIFEST.json"
    raw_path, checkpoint_path = directory / "RAW_PACKETS.csv", directory / "CHECKPOINT.mat"
    require(all(path.is_file() for path in (summary_path, manifest_path, raw_path, checkpoint_path)),
            f"Missing frozen AWGN evidence {point['id']}")
    summary, manifest, raw = load(summary_path), load(manifest_path), read_csv(raw_path)
    require(summary["pointId"] == point["id"] == manifest["pointId"], "Frozen point mismatch")
    require(summary["channel"] == point["channel"] == "AWGN", "Non-AWGN frozen point selected")
    require(summary["cohort"] == manifest["cohort"] == "formal1000", "Frozen cohort changed")
    require(summary["signature"] == sha256(manifest_path), "Frozen manifest signature mismatch")
    require(summary["complete"] and summary["packets"] == 1000 == len(raw), "Frozen AWGN budget incomplete")
    require(len(manifest["codeProvenance"]) == 79, "Frozen AWGN must retain exactly 79 source identities")
    source_digest = verify_sources(manifest["codeProvenance"])
    require(summary["symbolSource"] == manifest["symbolSource"] == "native-FFT-hard-chirp-before-FEC", "Frozen AWGN metric changed")
    require(summary["methodIds"] == list(METHODS), "Frozen AWGN method set changed")
    require(summary["cr"] == 3 and summary["dataChirps"] == CHIRPS and summary["noLdro"], "Frozen AWGN PHY changed")
    require(summary["nativePhysicalRows"] == 120 and summary["paperPhysicalRows"] == (129 if int(point["sf"]) == 7 else 157),
            "Frozen AWGN frame geometry changed")
    for key in ("sf", "snrDb", "esN0Db", "orbitStartSec"):
        close(summary[key], point[key], f"Frozen point metadata mismatch {key}")
    require(family(summary) == family(point), "Frozen AWGN family mismatch")
    require([integer(row, "packetId") for row in raw] == list(range(1, 1001)), "Frozen packet ids changed")
    expected_base = 2_800_000_000 + int(point["index"]) * 100_000
    require(manifest["packetSeedBase"] == expected_base and manifest["packetSeedStride"] == 8, "Frozen seed policy changed")
    counts, failures = {}, {}
    for row in raw:
        base = expected_base + integer(row, "packetId") * 8
        for name, offset in (("payloadSeed", 0), ("noiseSeed", 1), ("channelSeed", 2), ("paperExtraNoiseSeed", 3)):
            require(integer(row, name) == base + offset, f"Frozen seed mismatch {name}")
        close(row["noiseVariance"], 10 ** (-float(point["snrDb"]) / 10), "Frozen noise variance changed")
    for method in METHODS:
        method_counts = np.array([integer(row, method + "Errors") for row in raw], dtype=np.int64)
        method_failures = np.array([integer(row, method + "Failure") for row in raw], dtype=np.int64)
        require(np.all((method_counts >= 0) & (method_counts <= CHIRPS)), f"Invalid frozen {method} errors")
        require(np.all((method_failures == 0) | (method_counts == CHIRPS)), f"Dropped frozen {method} failure")
        require(int(method_counts.sum()) == int(summary[method + "Errors"]), f"Frozen {method} total mismatch")
        close(summary[method + "Ser"], method_counts.sum() / (1000 * CHIRPS), f"Frozen {method} SER mismatch")
        counts[method], failures[method] = method_counts, int(method_failures.sum())
    for path in (summary_path, manifest_path, raw_path, checkpoint_path):
        evidence[str(path.resolve())] = {"path": str(path.resolve()), "sha256": sha256(path)}
    return summary, manifest, raw, counts, failures, source_digest


def common_row(point, source):
    index = int(point.get("originalIndex", point.get("index")))
    return {"pointId": point["id"], "index": index, "sf": int(point["sf"]), "channel": point["channel"],
            "family": family(point), "snrDb": float(point["snrDb"]), "esN0Db": float(point["esN0Db"]),
            "orbitStartSec": float(point["orbitStartSec"]), "packets": 1000, "dataChirps": CHIRPS,
            "pointSource": source}


def aggregate_gate():
    verify_profile();plan_path, plan, points = verify_new_plan()
    evidence = {str(plan_path.resolve()): {"path": str(plan_path.resolve()), "sha256": sha256(plan_path)},
                str(PROFILE.resolve()): {"path": str(PROFILE.resolve()), "sha256": sha256(PROFILE)}}
    rows, source_digests = [], set();total_failures = 0
    for index in GATE_INDICES:
        point = points[index - 1]
        summary, manifest, raw, counts, failures, digest = validate_new_point(point, "gate100", evidence)
        source_digests.add(digest);total_failures += sum(failures.values())
        row = {**common_row(point, "normalized-k10-gate100"), "packets": 100,
               "seedRoot": manifest["seedRoot"], "packetSeedBase": manifest["packetSeedBase"]}
        for method in METHODS:
            row[method + "Errors"] = int(counts[method].sum())
            row[method + "Ser"] = float(counts[method].sum() / (100 * CHIRPS))
            row[method + "Failures"] = failures[method]
        rows.append(row)
    require(len(source_digests) == 1, "Gate mixed numerical sources")
    ideal_range_passed = all(0 <= row[method + "Ser"] <= 1
                             for row in rows for method in ("idealNative", "idealPaper"))
    require(ideal_range_passed, "Gate ideal SER is outside the defined [0,1] range")
    output = ROOT / "results" / "gate100" / "analysis"
    write_csv(output / "GATE_ENDPOINTS.csv", rows)
    numerical_digest = text_sha256(json.dumps(rows and load(ROOT / "results" / "gate100" / points[GATE_INDICES[0]-1]["id"] / "MANIFEST.json")["codeProvenance"],
                                                separators=(",", ":"), ensure_ascii=False))
    gate = {"passed": total_failures == 0, "status": "PASS" if total_failures == 0 else "FAIL",
            "plannedPackets": 100, "completePoints": 6, "totalPackets": 600,
            "receiverFailures": total_failures, "invalidOutputs": 0,
            "seedContinuity": True, "denominatorPerPoint": 11_200,
            "identityMatched": True, "idealSerRangeDefinition": "0 <= measured SER <= 1",
            "idealSerRangePassed": ideal_range_passed,
            "profileSha256": PROFILE_SHA256, "numericalProvenanceSha256": numerical_digest,
            "gatePolicy": "Structural only: identity, consecutive seeds, fixed denominator, valid outputs, and zero failures; no SER threshold.",
            "evidenceFiles": list(evidence.values()), "endpointCsv": str((output / "GATE_ENDPOINTS.csv").resolve()),
            "endpointCsvSha256": sha256(output / "GATE_ENDPOINTS.csv")}
    dump(output / "GATE.json", gate)
    return gate


def append_metrics(point, source, raw_path, counts, failures, metrics, paired):
    base = common_row(point, source);index = base["index"]
    by_method = {}
    for method_index, method in enumerate(METHODS):
        stats = interval(counts[method], CHIRPS, 3_300_000_000 + index * 100 + method_index)
        row = {**base, "method": method,
               "frame": "paper-midamble" if method in ("paper", "idealPaper") else "native",
               "denominatorTotal": 1000 * CHIRPS, "failures": failures[method],
               "rawPath": str(raw_path.resolve()), "rawSha256": sha256(raw_path), **stats}
        metrics.append(row);by_method[method] = row
    for pair_index, (first, second) in enumerate(METHOD_PAIRS):
        paired.append({**base, "firstMethod": first, "secondMethod": second,
                       **paired_interval(counts[first], counts[second],
                                         3_400_000_000 + index * 20 + pair_index)})
    return by_method


def endpoint_rows(metric_lookup, combined_points):
    reference = load(REFERENCE)
    references = {item["id"]: item for item in reference["reference"]}
    output = []
    for target_point in reference["points"]:
        target_family = family(target_point)
        matches = [point for point in combined_points if int(point["sf"]) == int(target_point["sf"])
                   and point["channel"] == target_point["channel"] and family(point) == target_family
                   and math.isclose(float(point["snrDb"]), float(target_point["snrDb"]), abs_tol=1e-11)
                   and math.isclose(float(point["orbitStartSec"]), float(target_point["orbitStartSec"]), abs_tol=1e-11)]
        require(len(matches) == 1, f"Endpoint physical match failed: {target_point['id']}")
        point = matches[0];reference_row = references[target_point["id"]]
        for method, field in (("paper", "methodTargetSer"), ("idealPaper", "baselineTargetSer")):
            observed = metric_lookup[(point["id"], method)];target = float(reference_row[field])
            output.append({"referenceId": target_point["id"], "pointId": point["id"],
                           "sf": int(point["sf"]), "channel": point["channel"], "family": target_family,
                           "snrDb": float(point["snrDb"]), "esN0Db": float(point["esN0Db"]),
                           "orbitStartSec": float(point["orbitStartSec"]), "method": method,
                           "paperTargetSer": target, "packets": 1000, "errors": observed["errors"],
                           "ser": observed["rate"], "ciLow": observed["ciLow"], "ciHigh": observed["ciHigh"],
                           "upperOneSided95": observed["upperOneSided95"],
                           "nominalAtOrBelowFixedRead": observed["rate"] <= target,
                           "pointwise95AtOrBelowFixedRead": observed["upperOneSided95"] <= target,
                           "paperReadSource": reference_row["source"],
                           "paperReadErrorStatus": reference_row["readingIntervalStatus"],
                           "strictOriginalPaperConditionsMatched": reference_row["strictPaperConditionsMatched"],
                           "statisticalScope": "pointwise one-sided 95%; not simultaneous across 24 rows"})
    require(len(output) == 24, "Expected 24 endpoint rows")
    return output


def wide_rows(points, metric_lookup):
    output = []
    for point in sorted(points, key=lambda p: int(p.get("originalIndex", p.get("index")))):
        base = common_row(point, metric_lookup[(point["id"], "prec")]["pointSource"])
        for method in METHODS:
            metric = metric_lookup[(point["id"], method)]
            for field in ("errors", "rate", "ciLow", "ciHigh", "upperOneSided95", "failures"):
                base[method + field[0].upper() + field[1:]] = metric[field]
        output.append(base)
    require(len(output) == 100, "Expected 100 physical-point rows")
    return output


def validate_paired_half(output):
    rows_out, evidence, failures = [], {}, 0
    for sf_index, sf in enumerate((7, 12)):
        directory = ROOT / "results" / "pairedHalf100" / f"sf{sf}"
        summary_path, manifest_path = directory / "SUMMARY.json", directory / "MANIFEST.json"
        raw_path, checkpoint_path = directory / "RAW_PAIRED.csv", directory / "CHECKPOINT.mat"
        require(all(path.is_file() for path in (summary_path, manifest_path, raw_path, checkpoint_path)), f"Missing paired SF{sf}")
        summary, manifest, raw = load(summary_path), load(manifest_path), read_csv(raw_path)
        require(summary["complete"] and summary["packetsPerTime"] == 100 and len(raw) == 500, "Paired diagnostic incomplete")
        require(summary["signature"] == sha256(manifest_path) and manifest["commonRandomNumbers"], "Paired identity mismatch")
        require(manifest["pairedRunnerSha256"] == sha256(ROOT / "nkserRunPairedHalf.m"),
                "Paired runner changed after evidence generation")
        current_provenance_digest = verify_sources(manifest["numericalProvenance"])
        require(current_provenance_digest == text_sha256(json.dumps(manifest["numericalProvenance"],
                separators=(",", ":"), ensure_ascii=False)), "Paired numerical provenance mismatch")
        require(manifest["seedRoot"] == 3_200_000_000 and manifest["packetSeedStride"] == 8, "Paired seeds changed")
        require(manifest["profileSha256"] == PROFILE_SHA256 and not summary["berGenerated"], "Paired profile/metric changed")
        for packet in range(1, 101):
            group = [row for row in raw if integer(row, "packetId") == packet]
            require(len(group) == 5 and [integer(row, "timeIndex") for row in group] == [1, 2, 3, 4, 5], "Paired time group broken")
            for field in ("payloadSeed", "noiseSeed", "channelSeed", "paperExtraNoiseSeed", "realizedTapEnergy", "noiseVariance"):
                values = [float(row[field]) for row in group]
                require(all(value == values[0] for value in values), f"Paired field changed across time: {field}")
        for method_index, method in enumerate(METHODS):
            base = np.array([integer(row, method + "Errors") for row in raw if integer(row, "timeIndex") == 1])
            failures += sum(integer(row, method + "Failure") for row in raw)
            for time_index in range(2, 6):
                selected = [row for row in raw if integer(row, "timeIndex") == time_index]
                current = np.array([integer(row, method + "Errors") for row in selected])
                item = {"sf": sf, "method": method, "referenceTimeSec": -366,
                        "comparisonTimeSec": (-366, -274.5, -183, -91.5, 0)[time_index - 1],
                        "packets": 100, **paired_interval(current, base,
                            3_500_000_000 + sf_index * 100 + method_index * 10 + time_index, replicates=10_000)}
                if method_index < 3:
                    base_rows = [row for row in raw if integer(row, "timeIndex") == 1]
                    item["meanCfoDifferenceBins"] = float(np.mean([float(row[method + "MeanCfoBins"]) for row in selected])
                                                               - np.mean([float(row[method + "MeanCfoBins"]) for row in base_rows]))
                    item["meanRateDifferenceBinsPerSec"] = float(np.mean([float(row[method + "MeanRateBinsPerSec"]) for row in selected])
                                                                      - np.mean([float(row[method + "MeanRateBinsPerSec"]) for row in base_rows]))
                else:
                    item["meanCfoDifferenceBins"] = ""
                    item["meanRateDifferenceBinsPerSec"] = ""
                rows_out.append(item)
        for path in (summary_path, manifest_path, raw_path, checkpoint_path):
            evidence[str(path.resolve())] = {"path": str(path.resolve()), "sha256": sha256(path)}
    write_csv(output / "PAIRED_HALF_TIME_DIFFERENCES.csv", rows_out)
    status = {"status": "PASS" if failures == 0 else "FAIL", "complete": True,
              "sfCount": 2, "timesPerSf": 5, "packetsPerTime": 100,
              "comparisonRows": len(rows_out), "receiverFailures": failures,
              "pairingChecks": "same payload/noise/channel/Paper-extra seeds, realized tap energy, and noise variance across five times",
              "onlyChanged": "trajectory time and deterministic V4 orbital Doppler",
              "notPooledWithFormal": True, "files": list(evidence.values())}
    dump(output / "PAIRED_HALF_STATUS.json", status)
    return status


def aggregate_formal(include_paired=True):
    profile = verify_profile();plan_path, plan, new_points = verify_new_plan();old_points = frozen_points()
    evidence = {str(plan_path.resolve()): {"path": str(plan_path.resolve()), "sha256": sha256(plan_path)},
                str(PROFILE.resolve()): {"path": str(PROFILE.resolve()), "sha256": sha256(PROFILE)},
                str((FROZEN / "POINTS.json").resolve()): {"path": str((FROZEN / "POINTS.json").resolve()),
                                                          "sha256": sha256(FROZEN / "POINTS.json")}}
    metrics, paired, seed_rows, failure_rows = [], [], [], []
    metric_lookup, awgn_source_digests, rician_source_digests = {}, set(), set()
    combined = old_points + new_points
    for point in old_points:
        summary, manifest, raw, counts, failures, digest = validate_frozen_awgn(point, evidence)
        awgn_source_digests.add(digest);source = "frozen-AWGN-formal1000"
        lookup = append_metrics(point, source, FROZEN / "results" / "formal1000" / point["id"] / "RAW_PACKETS.csv",
                                counts, failures, metrics, paired)
        metric_lookup.update({(point["id"], method): row for method, row in lookup.items()})
        seed_rows.append({"pointId": point["id"], "channel": "AWGN", "sourceCohort": source,
                          "seedRoot": manifest["seedRoot"], "packetSeedBase": manifest["packetSeedBase"],
                          "packetSeedStride": manifest["packetSeedStride"], "packets": 1000,
                          "rawSha256": sha256(FROZEN / "results" / "formal1000" / point["id"] / "RAW_PACKETS.csv")})
        for method, count in failures.items():
            if count: failure_rows.append({"pointId": point["id"], "method": method, "failures": count, "channel": "AWGN"})
    for point in new_points:
        summary, manifest, raw, counts, failures, digest = validate_new_point(point, "formal1000", evidence)
        rician_source_digests.add(digest);source = "normalized-K10-Rician-formal1000"
        raw_path = ROOT / "results" / "formal1000" / point["id"] / "RAW_PACKETS.csv"
        lookup = append_metrics(point, source, raw_path, counts, failures, metrics, paired)
        metric_lookup.update({(point["id"], method): row for method, row in lookup.items()})
        seed_rows.append({"pointId": point["id"], "channel": "Rician", "sourceCohort": source,
                          "seedRoot": manifest["seedRoot"], "packetSeedBase": manifest["packetSeedBase"],
                          "packetSeedStride": manifest["packetSeedStride"], "packets": 1000,
                          "rawSha256": sha256(raw_path)})
        for method, count in failures.items():
            if count: failure_rows.append({"pointId": point["id"], "method": method, "failures": count, "channel": "Rician"})
    require(len(awgn_source_digests) == 1 and len(rician_source_digests) == 1, "Mixed source identities")
    require(len(metrics) == 500 and len(paired) == 1000, "Wrong combined metric/pair row count")
    output = ROOT / "results" / "formal1000" / "analysis";output.mkdir(parents=True, exist_ok=True)
    write_csv(output / "SER_500_METHOD_ROWS.csv", metrics)
    write_csv(output / "SER_100_POINTS.csv", wide_rows(combined, metric_lookup))
    write_csv(output / "PAIRED_METHOD_DIFFERENCES.csv", paired)
    endpoints = endpoint_rows(metric_lookup, combined);write_csv(output / "ENDPOINT_24_ACCEPTANCE.csv", endpoints)
    write_csv(output / "SEED_POINT_MANIFEST.csv", seed_rows)
    write_csv(output / "FAILURES.csv", failure_rows, fieldnames=["pointId", "method", "failures", "channel"])
    paired_status = validate_paired_half(output) if include_paired else {"status": "NOT_REQUESTED_IN_THIS_RUN"}
    source_seed = {"experimentId": "normalized-k10-receiver-ser-v1", "status": "COMPLETE",
                   "frozenAwgn": {"points": 50, "packetsPerPoint": 1000, "rawPackets": 50_000,
                                  "sourceItemCount": 79, "sourceDigest": next(iter(awgn_source_digests)),
                                  "directory": str((FROZEN / "results" / "formal1000").resolve()),
                                  "reusePolicy": "read-only summary-layer reuse; no rerun, overwrite, or packet pooling"},
                   "normalizedK10Rician": {"points": 50, "packetsPerPoint": 1000, "rawPackets": 50_000,
                                           "sourceDigest": next(iter(rician_source_digests)),
                                           "profileId": profile["id"], "profileSha256": PROFILE_SHA256,
                                           "kDb": 10, "ensembleTotalPower": 1, "linkMarginDb": 0,
                                           "perPacketNormalization": False, "seedRoot": 3_100_000_000},
                   "metric": "pre-FEC FFT hard decisions, 112 data chirps/packet; BER not generated for new cohort",
                   "sourceAndSeedChecks": True, "seedManifest": str((output / "SEED_POINT_MANIFEST.csv").resolve()),
                   "failureRows": len(failure_rows), "evidenceFiles": list(evidence.values())}
    dump(output / "FAILURE_IDENTITY_SOURCE_SEED_MANIFEST.json", source_seed)
    nominal = sum(bool(row["nominalAtOrBelowFixedRead"]) for row in endpoints)
    pointwise = sum(bool(row["pointwise95AtOrBelowFixedRead"]) for row in endpoints)
    status = {"status": "COMPLETE", "complete": True, "physicalPoints": 100, "methodRows": 500,
              "frozenAwgnPoints": 50, "newRicianPoints": 50, "packetsPerPoint": 1000,
              "newRicianReceiverFailures": sum(row["failures"] for row in failure_rows if row["channel"] == "Rician"),
              "allReceiverFailures": sum(row["failures"] for row in failure_rows),
              "endpointRows": 24, "endpointNominalAtOrBelowFixedRead": nominal,
              "endpointPointwise95AtOrBelowFixedRead": pointwise,
              "simultaneous95Claim": False,
              "paperReadError": "Unquantified: fixed values are PDF vector reads; no frozen paper-reading interval exists.",
              "pairedDiagnostic": paired_status,
              "tables": {name: {"path": str((output / name).resolve()), "sha256": sha256(output / name)} for name in
                         ("SER_500_METHOD_ROWS.csv", "SER_100_POINTS.csv", "PAIRED_METHOD_DIFFERENCES.csv",
                          "ENDPOINT_24_ACCEPTANCE.csv", "SEED_POINT_MANIFEST.csv", "FAILURES.csv")}}
    dump(output / "STATUS.json", status)
    report = ["# Normalized K=10 SER result", "", "- Frozen AWGN: 50 points x 1000 packets, reused read-only after all 79 live source hashes and frame/SNR/SER identities matched.",
              "- New Rician: 50 points x 1000 packets, profile normalized-k10-zero038-exp13-d1-4-v1, K=10 dB, ensemble power 1, margin 0 dB, no packet normalization.",
              "- Metric: pre-FEC FFT hard-chirp SER over 112 data chirps. The new cohort contains no BER output.",
              f"- Paper endpoint nominal comparisons at or below fixed reads: {nominal}/24.",
              f"- Pointwise one-sided 95% upper bounds at or below fixed reads: {pointwise}/24.",
              "- These are 24 separate pointwise results, not a simultaneous 95% non-inferiority claim.",
              "- Paper values are digitized PDF reads with no frozen reading-error interval; that uncertainty is separate from packet sampling uncertainty.",
              f"- Receiver failures retained in denominators: {status['allReceiverFailures']}.", ""]
    (output / "RESULT_SUMMARY.md").write_text("\n".join(report), encoding="utf-8")
    return status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("gate100", "formal1000", "formal1000-no-paired"))
    args = parser.parse_args()
    result = aggregate_gate() if args.mode == "gate100" else aggregate_formal(args.mode == "formal1000")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
