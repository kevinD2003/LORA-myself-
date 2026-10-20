"""Generate all 50 normalized-K10 ideal physical points, SER only."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

import numpy as np

import search_normalized_pdp as screening
import validate_normalized_pdp as native


ROOT = Path(__file__).resolve().parents[1]
TIMES = (-366.0, -274.5, -183.0, -91.5, 0.0)


def points() -> list[dict]:
    rows: list[dict] = []
    index = 0
    for sf in (7, 12):
        grid = range(-15, -5) if sf == 7 else range(-30, -20)
        for case_index, start in ((1, -366.0), (2, 0.0)):
            for snr in grid:
                index += 1
                rows.append({
                    "pointId": f"p{index:03d}_sf{sf}_rician_case{case_index}_snr_m{abs(snr)}",
                    "index": index,
                    "sf": sf,
                    "channel": "Rician",
                    "family": "case",
                    "caseIndex": case_index,
                    "orbitStartSec": start,
                    "snrDb": float(snr),
                    "esN0Db": float(snr + 10 * math.log10(2**sf)),
                    "paperIdealSer": screening.PAPER[(sf, "case")],
                })
        for start in TIMES:
            index += 1
            rows.append({
                "pointId": f"p{index:03d}_sf{sf}_rician_half_t_{str(start).replace('-', 'm').replace('.', 'p')}",
                "index": index,
                "sf": sf,
                "channel": "Rician",
                "family": "half",
                "caseIndex": 0,
                "orbitStartSec": start,
                "snrDb": float(15 - 10 * math.log10(2**sf)),
                "esN0Db": 15.0,
                "paperIdealSer": screening.PAPER[(sf, "half")],
            })
    if index != 50:
        raise AssertionError("full Rician plan must contain 50 physical points")
    return rows


def write_csv(path: Path, rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--packets", type=int, default=1000)
    parser.add_argument("--seed-root", type=int, default=4090000000)
    parser.add_argument("--output", type=Path, default=ROOT / "results" / "full1000" / "analysis")
    args = parser.parse_args()
    if args.packets <= 0:
        raise ValueError("packets must be positive")
    args.output.mkdir(parents=True, exist_ok=True)
    profile = native.load_profile()
    relative = np.asarray(profile["diffuseRelativePowers"], dtype=float)
    results = []
    for point in points():
        seed = args.seed_root + point["index"] * 100000
        value = native.simulate(point, profile, args.packets, seed)
        value["cyclicTheorySer"] = screening.cyclic_ser(
            point["sf"], point["snrDb"], relative, 512
        )
        value["cyclicRatioToPaper"] = value["cyclicTheorySer"] / point["paperIdealSer"]
        value["displayFloor"] = 0.5 / (args.packets * 112)
        results.append(value)
        print(
            f"{point['pointId']} {point['index']}/50 "
            f"causal=[{value['lowerSer']:.7g},{value['upperSer']:.7g}] "
            f"cyclic={value['cyclicTheorySer']:.7g}",
            flush=True,
        )

    csv_path = args.output / "NORMALIZED_K10_FULL1000_SER.csv"
    json_path = args.output / "NORMALIZED_K10_FULL1000_SER.json"
    status_path = args.output / "STATUS.json"
    write_csv(csv_path, results)
    json_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    endpoint_rows = [
        row for row in results
        if (row["family"] == "case" and row["snrDb"] == (-6 if row["sf"] == 7 else -21))
        or (row["family"] == "half" and row["orbitStartSec"] == 0)
    ]
    status = {
        "status": "COMPLETE",
        "model": profile["profileId"],
        "kDb": 10,
        "ensembleTotalPower": 1,
        "linkMarginDb": 0,
        "packetsPerPoint": args.packets,
        "completePoints": len(results),
        "totalPackets": len(results) * args.packets,
        "metric": "pre-FEC FFT hard-chirp SER bounds; no BER",
        "endpointRows": len(endpoint_rows),
        "endpointUpperPointAtOrBelowPaper": all(row["upperRatioToPaper"] <= 1 for row in endpoint_rows),
        "endpointUpper95AtOrBelowPaper": all(row["upper95RatioToPaper"] <= 1 for row in endpoint_rows),
        "sourceFiles": {
            "profile": str((ROOT / "CHANNEL_PROFILE.json").resolve()),
            "profileSha256": sha256(ROOT / "CHANNEL_PROFILE.json"),
            "generator": str(Path(__file__).resolve()),
            "generatorSha256": sha256(Path(__file__)),
            "validatorSha256": sha256(Path(native.__file__)),
            "screeningSha256": sha256(Path(screening.__file__)),
        },
        "outputs": {
            "csv": str(csv_path.resolve()),
            "csvSha256": sha256(csv_path),
            "json": str(json_path.resolve()),
            "jsonSha256": sha256(json_path),
        },
    }
    status_path.write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(status, indent=2))


if __name__ == "__main__":
    main()

