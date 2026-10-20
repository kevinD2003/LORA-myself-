"""Screen normalized K10 partial-flat/exponential PDP candidates.

The calculation is the cyclic LoRa FFT approximation. It retains the exact
noncentral correct-bin distribution for the LOS plus zero-delay diffuse tap
and the exact exponential distributions for every delayed diffuse echo bin.
Native causal packet-boundary effects are deliberately deferred to waveform
validation.
"""
from __future__ import annotations

import argparse
import csv
import functools
import json
import math
from pathlib import Path

import numpy as np


PAPER = {
    (7, "case"): 0.002583154001145438,
    (7, "half"): 0.002239810615533604,
    (12, "case"): 0.01032408321335461,
    (12, "half"): 0.009566141994319557,
}
CASE_SNR_DB = {7: -6.0, 12: -21.0}
DELAYS = np.array([1, 2, 3, 4], dtype=int)


@functools.lru_cache(maxsize=None)
def quadrature(order: int) -> tuple[np.ndarray, np.ndarray]:
    """Cache the deterministic Gauss-Legendre rule across candidates."""
    return np.polynomial.legendre.leggauss(order)


def endpoint_snr_db(sf: int, family: str) -> float:
    if family == "case":
        return CASE_SNR_DB[sf]
    if family == "half":
        return 15.0 - 10.0 * math.log10(2**sf)
    raise ValueError(f"unsupported family {family}")


def diffuse_pdp(alpha: float, beta: float) -> np.ndarray:
    """Return powers relative to total diffuse power for delays 0..4."""
    if not 0.0 < alpha < 1.0:
        raise ValueError("alpha must lie strictly between zero and one")
    if beta < 0.0 or not math.isfinite(beta):
        raise ValueError("beta must be finite and nonnegative")
    delayed = np.exp(-beta * np.arange(len(DELAYS), dtype=float))
    delayed /= delayed.sum()
    powers = np.concatenate(([alpha], (1.0 - alpha) * delayed))
    if not np.isclose(powers.sum(), 1.0, rtol=0.0, atol=2e-15):
        raise AssertionError("diffuse PDP does not sum to one")
    return powers


def cyclic_ser(sf: int, snr_db: float, powers: np.ndarray, order: int) -> float:
    """Cyclic ideal hard-FFT SER for normalized K10 and a diffuse PDP."""
    m = 2**sf
    if len(powers) != 1 + len(DELAYS):
        raise ValueError("one zero-delay plus four delayed powers required")
    lam = m * 10 ** (snr_db / 10.0)
    correct_mean_energy = lam * 10.0 / 11.0
    correct_variance = 1.0 + lam * powers[0] / 11.0
    echo_variances = 1.0 + lam * powers[1:] / 11.0
    ordinary_bins = m - 1 - len(echo_variances)
    if ordinary_bins <= 0:
        raise ValueError("not enough FFT bins")

    upper = max(
        80.0,
        correct_mean_energy
        + 24.0 * math.sqrt(correct_variance * (correct_mean_energy + correct_variance))
        + 60.0,
    )
    nodes, weights = quadrature(order)
    energy = (nodes + 1.0) * upper / 2.0
    density = (
        np.exp(-(energy + correct_mean_energy) / correct_variance)
        * np.i0(2.0 * np.sqrt(correct_mean_energy * energy) / correct_variance)
        / correct_variance
    )
    with np.errstate(divide="ignore", invalid="ignore"):
        log_correct = ordinary_bins * np.log1p(-np.exp(-energy))
        for variance in echo_variances:
            log_correct += np.log1p(-np.exp(-energy / variance))
    integrand = -np.expm1(log_correct) * density
    value = float(np.dot(weights, integrand) * upper / 2.0)
    if not 0.0 <= value <= 1.0 or not math.isfinite(value):
        raise AssertionError("invalid SER integral")
    return value


def rms_delay_samples(powers: np.ndarray) -> float:
    delays = np.concatenate(([0.0], DELAYS.astype(float)))
    mean = float(np.dot(powers, delays))
    return math.sqrt(float(np.dot(powers, (delays - mean) ** 2)))


def evaluate(alpha: float, beta: float, order: int) -> dict:
    powers = diffuse_pdp(alpha, beta)
    ratios = {}
    values = {}
    for sf in (7, 12):
        for family in ("case", "half"):
            value = cyclic_ser(sf, endpoint_snr_db(sf, family), powers, order)
            values[(sf, family)] = value
            ratios[(sf, family)] = value / PAPER[(sf, family)]
    ratio_values = np.array(list(ratios.values()))
    below = np.maximum(0.7 - ratio_values, 0.0)
    above = np.maximum(ratio_values - 0.9, 0.0)
    band_penalty = float(np.dot(below, below) + np.dot(above, above))
    center_penalty = float(np.mean((ratio_values - 0.8) ** 2))
    return {
        "alpha": alpha,
        "beta": beta,
        "delaysSamples": DELAYS.tolist(),
        "diffuseRelativePowers": powers.tolist(),
        "rmsDelaySamples": rms_delay_samples(powers),
        "rmsDelayMicroseconds": rms_delay_samples(powers) * 8.0,
        "sf7CaseSer": values[(7, "case")],
        "sf7CaseRatio": ratios[(7, "case")],
        "sf7HalfSer": values[(7, "half")],
        "sf7HalfRatio": ratios[(7, "half")],
        "sf12CaseSer": values[(12, "case")],
        "sf12CaseRatio": ratios[(12, "case")],
        "sf12HalfSer": values[(12, "half")],
        "sf12HalfRatio": ratios[(12, "half")],
        "allAtOrBelowPaper": bool(np.all(ratio_values <= 1.0)),
        "allInsideTargetBand": bool(np.all((ratio_values >= 0.7) & (ratio_values <= 0.9))),
        "minimumRatio": float(ratio_values.min()),
        "maximumRatio": float(ratio_values.max()),
        "bandPenalty": band_penalty,
        "centerPenalty": center_penalty,
    }


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--alpha-min", type=float, default=0.25)
    parser.add_argument("--alpha-max", type=float, default=0.65)
    parser.add_argument("--alpha-step", type=float, default=0.005)
    parser.add_argument("--beta-min", type=float, default=0.0)
    parser.add_argument("--beta-max", type=float, default=3.0)
    parser.add_argument("--beta-step", type=float, default=0.05)
    parser.add_argument("--order", type=int, default=256)
    parser.add_argument("--top", type=int, default=20)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    alphas = np.arange(args.alpha_min, args.alpha_max + args.alpha_step / 2, args.alpha_step)
    betas = np.arange(args.beta_min, args.beta_max + args.beta_step / 2, args.beta_step)
    rows = [evaluate(float(alpha), float(beta), args.order) for alpha in alphas for beta in betas]
    rows.sort(key=lambda row: (
        not row["allInsideTargetBand"],
        not row["allAtOrBelowPaper"],
        row["bandPenalty"],
        row["centerPenalty"],
        row["rmsDelaySamples"],
    ))
    if args.output:
        write_csv(args.output.with_suffix(".csv"), rows)
        args.output.with_suffix(".json").write_text(
            json.dumps({
                "constraints": {"kDb": 10, "ensemblePower": 1, "linkMarginDb": 0},
                "grid": {"alphas": len(alphas), "betas": len(betas), "order": args.order},
                "insideBandCount": sum(row["allInsideTargetBand"] for row in rows),
                "atOrBelowPaperCount": sum(row["allAtOrBelowPaper"] for row in rows),
                "top": rows[:args.top],
            }, indent=2) + "\n",
            encoding="utf-8",
        )
    print(json.dumps({
        "insideBandCount": sum(row["allInsideTargetBand"] for row in rows),
        "atOrBelowPaperCount": sum(row["allAtOrBelowPaper"] for row in rows),
        "top": rows[:args.top],
    }, indent=2))


if __name__ == "__main__":
    main()
