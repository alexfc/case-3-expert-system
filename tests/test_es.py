import re
import unittest

import clips

from es import engine


def top(result):
    accepted = [d for d in result["diagnoses"] if d["accepted"]]
    return accepted[0] if accepted else None


def by_code(result, code):
    return next((d for d in result["diagnoses"] if d["code"] == code), None)


class KnowledgeBaseIntegrity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.env = clips.Environment()
        cls.env.load(str(engine.KB_PATH))
        cls.env.reset()
        cls.symptoms = {str(f["code"]) for f in cls.env.find_template("symptom-info").facts()}
        cls.faults = {str(f["code"]) for f in cls.env.find_template("fault-info").facts()}

    def test_rules_use_known_symptoms(self):
        for rule in self.env.rules():
            for group in re.findall(r"\(symptom \(code ([\w|-]+)\)", str(rule)):
                for code in group.split("|"):
                    self.assertIn(code, self.symptoms, f"{rule.name}: неизвестный симптом {code}")

    def test_rules_conclude_known_faults(self):
        for rule in self.env.rules():
            for code in re.findall(r"\(evidence \(fault ([\w-]+)\)", str(rule)):
                self.assertIn(code, self.faults, f"{rule.name}: неизвестная неисправность {code}")

    def test_every_fault_has_parts(self):
        with_parts = {str(p["fault"]) for p in self.env.find_template("part").facts()}
        self.assertEqual(self.faults, with_parts)

    def test_every_symptom_is_used(self):
        used = set()
        for rule in self.env.rules():
            for group in re.findall(r"\(symptom \(code ([\w|-]+)\)", str(rule)):
                used.update(group.split("|"))
        self.assertEqual(self.symptoms - used, set())


class CombineCF(unittest.TestCase):
    def setUp(self):
        self.env = clips.Environment()
        self.env.load(str(engine.KB_PATH))

    def cf(self, a, b):
        return self.env.eval(f"(combine-cf {a} {b})")

    def test_positive(self):
        self.assertAlmostEqual(self.cf(0.6, 0.4), 0.76)

    def test_mixed(self):
        self.assertAlmostEqual(self.cf(0.3, -0.5), -0.2 / 0.7)

    def test_commutative_and_bounded(self):
        for a, b in [(0.2, 0.9), (-0.4, 0.7), (-0.3, -0.6)]:
            self.assertAlmostEqual(self.cf(a, b), self.cf(b, a))
            self.assertTrue(-1 <= self.cf(a, b) <= 1)


class Scenarios(unittest.TestCase):
    def test_01_battery_cold_old(self):
        r = engine.diagnose("car", ["starter-clicks", "dim-lights", "cold-weather"], 120000, 5)
        d = top(r)
        self.assertEqual(d["code"], "battery")
        self.assertAlmostEqual(d["cf"], 0.892, places=3)
        self.assertIsNone(by_code(r, "starter"))
        self.assertEqual(d["parts"][0]["name"], "Аккумуляторная батарея")

    def test_02_starter_with_new_battery(self):
        r = engine.diagnose("car", ["starter-clicks"], 40000, 1)
        self.assertEqual(top(r)["code"], "starter")
        bat = by_code(r, "battery")
        self.assertFalse(bat["accepted"])
        self.assertLess(bat["cf"], 0)

    def test_03_head_gasket_critical(self):
        r = engine.diagnose("car", ["white-smoke", "coolant-loss", "overheat"], 210000)
        d = top(r)
        self.assertEqual(d["code"], "head-gasket")
        self.assertGreater(d["cf"], 0.9)
        self.assertTrue(any("прокладки ГБЦ" in w or "ГБЦ" in w for w in r["warnings"]))
        rules = [e["rule"] for e in by_code(r, "cooling")["explanation"]]
        self.assertNotIn("cool-leak", rules)

    def test_04_cold_condensate_not_gasket(self):
        r = engine.diagnose("car", ["white-smoke", "cold-weather"])
        self.assertIsNone(top(r))
        self.assertLess(by_code(r, "head-gasket")["cf"], 0)
        self.assertEqual(r["warnings"], [])
        self.assertEqual(len(r["conclusions"]), 1)

    def test_05_moto_brake_hydraulics(self):
        r = engine.diagnose("moto", ["brake-soft", "brake-fluid-low"], 15000)
        d = top(r)
        self.assertEqual(d["code"], "brake-hydraulics")
        self.assertAlmostEqual(d["cf"], 0.85, places=2)
        self.assertEqual(len(r["warnings"]), 1)

    def test_06_moto_chain(self):
        r = engine.diagnose("moto", ["chain-noise"], 25000)
        d = top(r)
        self.assertEqual(d["code"], "chain")
        self.assertAlmostEqual(d["cf"], 0.86, places=2)
        self.assertEqual([p["name"] for p in d["parts"]],
                         ["Приводная цепь", "Комплект звёзд", "Смазка для цепи"])

    def test_07_chain_rule_ignored_for_car(self):
        r = engine.diagnose("car", ["chain-noise"], 25000)
        self.assertIsNone(by_code(r, "chain"))

    def test_08_parts_filtered_by_vehicle(self):
        r = engine.diagnose("moto", ["oil-on-shock"])
        names = [p["name"] for p in top(r)["parts"]]
        self.assertIn("Сальники вилки", names)
        self.assertNotIn("Амортизаторы (пара)", names)

    def test_09_no_symptoms(self):
        r = engine.diagnose("car", [])
        self.assertEqual(r["diagnoses"], [])
        self.assertEqual(len(r["conclusions"]), 1)

    def test_10_pads_not_hydraulics(self):
        r = engine.diagnose("car", ["brake-squeal", "brake-fluid-low"])
        self.assertEqual(top(r)["code"], "brake-pads")
        self.assertAlmostEqual(top(r)["cf"], 0.76, places=2)
        self.assertIsNone(by_code(r, "brake-hydraulics"))

    def test_11_ignition_misfire(self):
        r = engine.diagnose("car", ["rough-idle", "check-engine", "power-loss"], 80000)
        self.assertEqual(top(r)["code"], "ignition")
        self.assertAlmostEqual(top(r)["cf"], 0.832, places=3)
        self.assertIsNone(by_code(r, "fuel"))

    def test_12_duplicate_symptoms(self):
        a = engine.diagnose("car", ["blue-smoke"], 160000)
        b = engine.diagnose("car", ["blue-smoke", "blue-smoke"], 160000)
        self.assertEqual(top(a)["cf"], top(b)["cf"])

    def test_13_several_faults_ranked(self):
        r = engine.diagnose("car", ["brake-vibration", "knock-bumps", "bounce", "belt-squeal"])
        cfs = [d["cf"] for d in r["diagnoses"]]
        self.assertEqual(cfs, sorted(cfs, reverse=True))
        self.assertEqual({d["code"] for d in r["diagnoses"]},
                         {"brake-discs", "suspension-joints", "shocks", "belt"})
        self.assertTrue(r["trace"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
