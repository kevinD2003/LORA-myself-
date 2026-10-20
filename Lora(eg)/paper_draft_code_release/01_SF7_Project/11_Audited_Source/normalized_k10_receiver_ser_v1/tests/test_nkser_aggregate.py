import importlib.util
import pathlib
import unittest

import numpy as np


MODULE_PATH = pathlib.Path(__file__).resolve().parents[1] / "analysis" / "nkser_aggregate.py"
SPEC = importlib.util.spec_from_file_location("nkser_aggregate", MODULE_PATH)
AGGREGATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AGGREGATE)


class AggregateContractTest(unittest.TestCase):
    def test_registered_profile_and_grid(self):
        profile = AGGREGATE.verify_profile()
        _, plan, points = AGGREGATE.verify_new_plan()
        self.assertEqual(profile["ricianKDb"], 10)
        self.assertEqual(len(points), 50)
        self.assertEqual(plan["gateLocalIndices"], [10, 20, 25, 35, 45, 50])

    def test_interval_keeps_zero_measurement_zero(self):
        result = AGGREGATE.interval(np.zeros(100, dtype=int), 112, 1)
        self.assertEqual(result["rate"], 0)
        self.assertGreater(result["upperOneSided95"], 0)
        self.assertTrue(result["zeroEvents"])

    def test_paired_difference_sign(self):
        result = AGGREGATE.paired_interval(np.full(100, 2), np.full(100, 1), 3, replicates=100)
        self.assertAlmostEqual(result["rateDifference"], 1 / 112)

    def test_frozen_awgn_has_fifty_points(self):
        points = AGGREGATE.frozen_points()
        self.assertEqual(len(points), 50)
        self.assertTrue(all(point["channel"] == "AWGN" for point in points))


if __name__ == "__main__":
    unittest.main()
