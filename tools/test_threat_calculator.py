import unittest
from threat_calculator import (
    MeasuredAction, raw_ability_threat, rage_gain_threat, apply_threat_multiplier
)


class ThreatCalculatorTests(unittest.TestCase):
    def test_measured_rank_formulas(self):
        self.assertEqual(raw_ability_threat(MeasuredAction("Sunder Armor", 1, ap=1000)), 85)
        self.assertEqual(raw_ability_threat(MeasuredAction("Sunder Armor", 2, ap=1000)), 126)
        self.assertEqual(raw_ability_threat(MeasuredAction("Revenge", 2, damage=400)), 900)
        self.assertEqual(raw_ability_threat(MeasuredAction("Heroic Strike", 4, damage=240)), 301)
        self.assertEqual(raw_ability_threat(MeasuredAction("Cleave", 2, damage=100, targets_hit=2)), 123)
        self.assertEqual(raw_ability_threat(MeasuredAction("Demoralizing Shout")), 37)

    def test_rage_distribution_and_prepull(self):
        self.assertEqual(rage_gain_threat(10), 50)
        self.assertEqual(rage_gain_threat(10, targets_in_combat=2), 25)
        self.assertEqual(rage_gain_threat(75, in_combat=False), 0)

    def test_multiplier_is_explicit(self):
        self.assertAlmostEqual(apply_threat_multiplier(126, 1.495), 188.37)

    def test_unknown_rank_rejected(self):
        for action in (MeasuredAction("Shield Slam", 4, damage=700),
                       MeasuredAction("Sunder Armor", 5, ap=1500)):
            with self.assertRaises(ValueError):
                raw_ability_threat(action)


if __name__ == "__main__":
    unittest.main()
