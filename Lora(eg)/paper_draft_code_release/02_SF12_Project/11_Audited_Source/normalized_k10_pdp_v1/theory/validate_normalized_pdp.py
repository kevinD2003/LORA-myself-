"""Native causal ideal-SER bounds for the registered normalized K10 PDP."""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
from pathlib import Path
import sys

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
PROFILE_FILE = ROOT / "CHANNEL_PROFILE.json"
BASE_FILE = ROOT.parent / "k10_multipath_revision" / "theory" / "mp_native_ideal.py"
spec = importlib.util.spec_from_file_location("frozen_mp_native_ideal", BASE_FILE)
base = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = base
spec.loader.exec_module(base)


def load_profile() -> dict:
    registered = json.loads(PROFILE_FILE.read_text(encoding="utf-8"))
    powers = np.asarray(registered["diffuseRelativePowers"], dtype=float)
    delays = np.asarray(registered["delaysSamples"], dtype=int)
    if not np.isclose(powers.sum(), 1.0, atol=2e-15, rtol=0.0):
        raise ValueError("registered diffuse powers do not sum to one")
    if registered["ricianKLinear"] != 10 or registered["ensembleTotalPower"] != 1:
        raise ValueError("profile must preserve normalized K10")
    return {
        "profileId": registered["id"],
        "delaysSamples": delays.tolist(),
        "diffuseRelativePowers": powers.tolist(),
        "kDb": 10,
        "ensembleTotalPower": 1.0,
    }


def boundary_means_with_zero_delay(
    sf: int,
    symbols: np.ndarray,
    previous: np.ndarray,
    delayed_taps: np.ndarray,
    delayed_samples: np.ndarray,
    zero_tap: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    means, epsilon, _ = base.boundary_means(
        sf, symbols, previous, delayed_taps, delayed_samples
    )
    means[..., 0] += np.sqrt(2**sf) * zero_tap[:, None]
    return means, epsilon


def simulate(source: dict, profile: dict, packets: int, seed: int) -> dict:
    sf = int(source["sf"])
    m = 2**sf
    variance = 10 ** (-float(source["snrDb"]) / 10.0)
    all_delays = np.asarray(profile["delaysSamples"], dtype=int)
    all_powers = np.asarray(profile["diffuseRelativePowers"], dtype=float)
    if all_delays[0] != 0 or np.any(all_delays[1:] <= 0):
        raise ValueError("profile needs one zero-delay and positive delayed taps")
    payload_rng = np.random.default_rng(seed + 1)
    channel_rng = np.random.default_rng(seed + 2)
    noise_rng = np.random.default_rng(seed + 3)
    max_rng = np.random.default_rng(seed + 4)
    lower_counts: list[int] = []
    upper_counts: list[int] = []
    conditional_lower: list[float] = []
    conditional_upper: list[float] = []
    epsilon_sum = 0.0

    for start in range(0, packets, 128):
        n = min(128, packets - start)
        symbols = base.coded_bins(sf, payload_rng, n)
        previous = base.preceding_bins(sf, symbols)
        normal = channel_rng.standard_normal((n, len(all_delays))) + 1j * channel_rng.standard_normal((n, len(all_delays)))
        diffuse = normal * np.sqrt(all_powers / (2 * 11.0))
        zero_tap = diffuse[:, 0]
        delayed_taps = diffuse[:, 1:]
        means, epsilon = boundary_means_with_zero_delay(
            sf, symbols, previous, delayed_taps, all_delays[1:], zero_tap
        )
        noisy = means + np.sqrt(variance / 2) * (
            noise_rng.standard_normal(means.shape) + 1j * noise_rng.standard_normal(means.shape)
        )
        true_amplitude = np.abs(noisy[..., 0])
        special_error = np.max(np.abs(noisy[..., 1:]), axis=-1) > true_amplitude
        ordinary_bins = m - len(all_delays)
        maximum = np.sqrt(
            -variance
            * np.log(-np.expm1(np.log(max_rng.random((n, base.CHIRPS))) / ordinary_bins))
        )
        lower = special_error | (np.maximum(0.0, maximum - epsilon) > true_amplitude)
        upper = special_error | (maximum + epsilon > true_amplitude)
        lower_counts.extend(lower.sum(axis=1).tolist())
        upper_counts.extend(upper.sum(axis=1).tolist())

        def exceed(threshold: np.ndarray) -> np.ndarray:
            energy = np.maximum(0.0, threshold) ** 2 / variance
            with np.errstate(divide="ignore", invalid="ignore"):
                return -np.expm1(ordinary_bins * np.log1p(-np.exp(-energy)))

        rb_lower = np.where(special_error, 1.0, exceed(true_amplitude + epsilon))
        rb_upper = np.where(special_error, 1.0, exceed(true_amplitude - epsilon))
        conditional_lower.extend(np.mean(rb_lower, axis=1).tolist())
        conditional_upper.extend(np.mean(rb_upper, axis=1).tolist())
        epsilon_sum += float(epsilon.sum())

    lower_array = np.asarray(lower_counts, dtype=int)
    upper_array = np.asarray(upper_counts, dtype=int)
    lower_ci = base.packet_ci(lower_array, seed + 5)
    upper_ci = base.packet_ci(upper_array, seed + 6)
    paper = float(source["paperIdealSer"])
    return {
        **source,
        **profile,
        "packets": packets,
        "seed": seed,
        "lowerErrors": int(lower_array.sum()),
        "upperErrors": int(upper_array.sum()),
        "lowerSer": lower_ci["ser"],
        "upperSer": upper_ci["ser"],
        "lowerRatioToPaper": lower_ci["ser"] / paper,
        "upperRatioToPaper": upper_ci["ser"] / paper,
        "upperOneSided95": upper_ci["upperOneSided95"],
        "upper95RatioToPaper": upper_ci["upperOneSided95"] / paper,
        "conditionalLowerSer": float(np.mean(conditional_lower)),
        "conditionalUpperSer": float(np.mean(conditional_upper)),
        "conditionalLowerStandardError": float(np.std(conditional_lower, ddof=1) / math.sqrt(packets)),
        "conditionalUpperStandardError": float(np.std(conditional_upper, ddof=1) / math.sqrt(packets)),
        "averageBoundaryAmplitudeBound": epsilon_sum / (packets * base.CHIRPS),
        "allPowerNormalized": True,
        "linkMarginDb": 0,
        "noFec": True,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--packets", type=int, default=1024)
    parser.add_argument("--seed", type=int, default=4070000000)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    profile = load_profile()
    sources = [source for source in base.sources() if source["channel"] == "Rician"]
    results = [
        simulate(source, profile, args.packets, args.seed + index * 100000)
        for index, source in enumerate(sources)
    ]
    report = {
        "constraints": {
            "kDb": 10,
            "ensembleTotalPower": 1,
            "linkMarginDb": 0,
            "sameProfileAcrossSf": True,
        },
        "packetsPerSource": args.packets,
        "allUpperPointEstimatesAtOrBelowPaper": all(row["upperRatioToPaper"] <= 1 for row in results),
        "allUpper95AtOrBelowPaper": all(row["upper95RatioToPaper"] <= 1 for row in results),
        "results": results,
    }
    text = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    print(text, end="")


if __name__ == "__main__":
    main()
