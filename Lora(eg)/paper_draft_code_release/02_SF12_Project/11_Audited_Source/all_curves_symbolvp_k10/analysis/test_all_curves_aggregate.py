"""Calculation and grid checks; these tests create no experiment observations."""
import math
import unittest

import numpy as np

from all_curves_aggregate import bootstrap_means, interval, paired_interval, verify_grid


def metadata_grid():
    points = []
    for sf in (7, 12):
        for channel in ("AWGN", "Rician"):
            for family, start in (("case1", -366), ("case2", 0)):
                for snr in range(-15 if sf == 7 else -30, -5 if sf == 7 else -20):
                    points.append({"id": str(len(points) + 1), "index": len(points) + 1, "sf": sf,
                                   "channel": channel, "family": family, "orbitStartSec": start,
                                   "snrDb": snr, "esN0Db": snr + 10 * math.log10(2 ** sf)})
            esn0 = 14 if channel == "AWGN" else 15
            for start in (-366, -274.5, -183, -91.5, 0):
                points.append({"id": str(len(points) + 1), "index": len(points) + 1, "sf": sf,
                               "channel": channel, "family": "half", "orbitStartSec": start,
                               "snrDb": esn0 - 10 * math.log10(2 ** sf), "esN0Db": esn0})
    return points


class StatisticsChecks(unittest.TestCase):
    def test_zero_events_remain_zero_with_packet_upper_bound(self):
        result = interval(np.zeros(100, dtype=int), 112, 4000, 11)
        self.assertEqual(result["rate"], 0)
        self.assertEqual(result["errors"], 0)
        self.assertEqual(result["ciLow"], 0)
        self.assertAlmostEqual(result["ciHigh"], 1 - .05 ** (1 / 100))
        self.assertEqual(result["bootstrapReplicates"], 0)
        self.assertGreater(result["ciHigh"], 1 - .05 ** (1 / 11200))

    def test_packet_denominator_and_reproducibility(self):
        counts = np.array([0] * 99 + [112])
        result = interval(counts, 112, 4000, 11)
        self.assertEqual(result["rate"], .01)
        self.assertEqual(result["errors"], 112)
        self.assertGreaterEqual(result["ciHigh"], .02)
        self.assertEqual(result, interval(counts, 112, 4000, 11))

    def test_identical_packet_methods_have_exact_zero_difference(self):
        counts = np.array([0, 1, 4, 112] * 25)
        result = paired_interval(counts, counts, 112, 4000, 11)
        self.assertEqual(result["rateDifference"], 0)
        self.assertEqual(result["ciLow"], 0)
        self.assertEqual(result["ciHigh"], 0)

    def test_constant_packet_difference_preserves_pairing(self):
        first = np.arange(100)
        result = paired_interval(first, first + 2, 112, 4000, 11)
        self.assertAlmostEqual(result["rateDifference"], -2 / 112)
        self.assertAlmostEqual(result["ciLow"], -2 / 112)
        self.assertAlmostEqual(result["ciHigh"], -2 / 112)

    def test_invalid_counts_are_rejected(self):
        with self.assertRaises(ValueError):
            interval(np.array([113]), 112, 4000, 11)
        with self.assertRaises(ValueError):
            bootstrap_means(np.array([]), 112, 4000, 11)


class GridChecks(unittest.TestCase):
    def test_full_grid(self):
        verify_grid(metadata_grid())

    def test_missing_point_rejected(self):
        with self.assertRaisesRegex(ValueError, "100 physical"):
            verify_grid(metadata_grid()[:-1])

    def test_repeated_physical_point_rejected(self):
        points = metadata_grid()
        points[1]["snrDb"] = points[0]["snrDb"]
        points[1]["esN0Db"] = points[0]["esN0Db"]
        with self.assertRaisesRegex(ValueError, "Duplicate physical"):
            verify_grid(points)


if __name__ == "__main__":
    unittest.main()
