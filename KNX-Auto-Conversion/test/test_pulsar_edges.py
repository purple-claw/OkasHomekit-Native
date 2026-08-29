"""
Edge-case tests for pulsar.py. Catches known bugs the integration test misses.
"""
import importlib.util, pathlib, sys, unittest, json, shutil
import xml.etree.ElementTree as ET

PROJECT_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_DIR))
spec = importlib.util.spec_from_file_location("pulsar", PROJECT_DIR / "pulsar.py")
k = importlib.util.module_from_spec(spec)
sys.modules["pulsar"] = k
spec.loader.exec_module(k)


def gaRaw(addr):
    p = [int(x) for x in str(addr).split("/")]
    if len(p) == 3: return (p[0] << 11) + (p[1] << 8) + p[2]
    if len(p) == 2: return (p[0] << 11) + p[1]
    return p[0]


class DimmerLayout(unittest.TestCase):
    """3.007 (Dim) GA cluster: the canonical ETS layout has Bri at raw-2, Bvi at raw-1."""

    def test_bri_before_dim(self):
        # Synthesise a small GA set: Bri(raw-2), Bvi(raw-1), Dim(raw 0).
        # Build gas with raw 2048..2050, all DPT-bearing.
        class G:
            def __init__(self, key, raw, dpt, name=""):
                self.key = key
                self.raw = raw
                self.dpt = dpt
                self.addr = k.fGa(raw, "ThreeLevel")
                self.name = name
                self.rPath = ["Room"]
        gas = {
            "GA-1": G("GA-1", 2046, "DPST-5-1", "Bri"),
            "GA-2": G("GA-2", 2047, "DPST-5-1", "Bvi"),
            "GA-3": G("GA-3", 2048, "DPST-3-7", "Dim"),
        }
        # The cluster should pair Dim with Bri at raw-2 and Bvi at raw-1.
        loads, skips, _ = k.clstrGAs(gas, set(), {}, {})
        self.assertEqual(len(loads), 1, f"expected 1 dimmer load, got {len(loads)}: {[l['gAdd'] for l in loads]}")
        self.assertEqual(loads[0]["ldTyp"], "Dimmer")
        gA = loads[0]["GA"]
        self.assertEqual(gA.get("Dim"), "1/0/0", f"got {gA}")
        self.assertEqual(gA.get("Bri"), "0/7/254", f"got {gA}")
        self.assertEqual(gA.get("Bvi"), "0/7/255", f"got {gA}")

    def test_screen_switch_not_curtain(self):
        # A 1.007 (step/stop) beside 1.001 pairs must NOT fabricate a Curtain —
        # regression: "Big HT Screen Lights ON/OFF" came out Curtain.
        class G:
            def __init__(self, key, r, d, n=""):
                self.key = key; self.raw = r; self.dpt = d
                self.addr = k.fGa(r, "ThreeLevel"); self.name = n; self.rPath = ["Room"]
        gas = {
            "GA-1": G("GA-1", 1, "DPST-1-7", "Screen ON/OFF"),
            "GA-2": G("GA-2", 2, "DPST-1-1", "Screen Status"),
            "GA-3": G("GA-3", 3, "DPST-1-1", "Back DL ON/OFF"),
            "GA-4": G("GA-4", 4, "DPST-1-1", "Back DL Status"),
        }
        loads, _, _ = k.clstrGAs(gas, set(), {}, {})
        types = [(l["ldTyp"], l["gAdd"]) for l in loads]
        self.assertTrue(all(t != "Curtain" for t, _ in types), f"curtain leaked: {types}")
        self.assertEqual(types[0][0], "Switch")

    def test_real_curtain_with_generic_status(self):
        # [1.008 up/down, 1.001 status] IS a curtain: Mvi is Movement Value.
        class G:
            def __init__(self, key, r, d, n=""):
                self.key = key; self.raw = r; self.dpt = d
                self.addr = k.fGa(r, "ThreeLevel"); self.name = n; self.rPath = ["Room"]
        gas = {
            "GA-1": G("GA-1", 100, "DPST-1-8", "Curtain Up/Down"),
            "GA-2": G("GA-2", 101, "DPST-1-1", "Curtain Status"),
        }
        loads, _, _ = k.clstrGAs(gas, set(), {}, {})
        self.assertEqual(len(loads), 1)
        self.assertEqual(loads[0]["ldTyp"], "Curtain")
        self.assertEqual(loads[0]["GA"].get("Mov"), "0/0/100")
        self.assertEqual(loads[0]["GA"].get("Mvi"), "0/0/101")

    def test_humidity_sensor_not_a_load(self):
        # 9.007 humidity is a measurement — audits out, never becomes a load.
        class G:
            def __init__(self, key, r, d, n=""):
                self.key = key; self.raw = r; self.dpt = d
                self.addr = k.fGa(r, "ThreeLevel"); self.name = n; self.rPath = ["Room"]
        gas = {"GA-1": G("GA-1", 500, "DPST-9-7", "Humidity"),
               "GA-2": G("GA-2", 501, "DPST-5-1", "Humidity Value")}
        loads, skips, _ = k.clstrGAs(gas, set(), {}, {})
        self.assertEqual(loads, [], f"sensor became a load: {loads}")
        self.assertEqual(len(skips), 2)


class AppRefLookup(unittest.TestCase):
    """fDef disambiguates multiple defs ending with the same tail."""

    def test_ambiguous_refid_picks_closest(self):
        defs = {
            "M-X_A_O-1_R-7": k.cDef(id="M-X_A_O-1_R-7", isRef=True, refId="M-X_A_O-1", dpts=["1.001"]),
            "M-X_A_O-1_R-9": k.cDef(id="M-X_A_O-1_R-9", isRef=True, refId="M-X_A_O-1", dpts=["1.001"]),
        }
        # The module-instance prefix is "MD-x_M-x_MI-x_" — strip that, leaving
        # "O-1_R-7", which is the canonical refId tail both defs share. Disambiguate
        # by the very last chunk ("R-7" vs "R-9"). Expect the R-7 match.
        result = k.fDef(defs, "MD-1_M-1_MI-1_O-1_R-7")
        self.assertIsNotNone(result, "fDef must not return None for a unique-shape refId")
        self.assertEqual(result.id, "M-X_A_O-1_R-7")


class DptNormalisation(unittest.TestCase):
    def test_every_documented_dpt_form(self):
        cases = [
            ("DPST-1-1", "1.001"),
            ("DPST-1-2", "1.002"),
            ("DPST-1-7", "1.007"),
            ("DPST-1-8", "1.008"),
            ("DPST-1-9", "1.009"),
            ("DPST-1-10", "1.010"),
            ("DPST-1-11", "1.011"),
            ("DPST-1-100", "1.100"),
            ("DPST-3-7", "3.007"),
            ("DPST-3-8", "3.008"),
            ("DPST-5-1", "5.001"),
            ("DPST-5-3", "5.003"),
            ("DPST-5-4", "5.004"),
            ("DPST-5-10", "5.010"),
            ("DPST-5-100", "5.100"),
            ("DPST-7-1", "7.001"),
            ("DPST-7-13", "7.013"),
            ("DPST-7-600", "7.600"),
            ("DPST-9-1", "9.001"),
            ("DPST-9-24", "9.024"),
            ("DPST-14-19", "14.019"),
            ("DPST-14-56", "14.056"),
            ("DPST-17-1", "17.001"),
            ("DPST-18-1", "18.001"),
            ("DPST-20-102", "20.102"),
            ("DPST-20-105", "20.105"),
            ("DPST-232-600", "232.600"),
            ("DPST-234-600", "234.600"),
            ("DPST-237-600", "237.600"),
            ("DPST-238-600", "238.600"),
            ("DPST-251-600", "251.600"),
            ("DPT-1", "1"),
            ("DPT-5", "5"),
            ("DPT-7", "7"),
            ("DPT-9", "9"),
            ("9.001", "9.001"),
            ("", ""),
        ]
        for inp, want in cases:
            got = k.nDpt(inp)
            self.assertEqual(got, want, f"nDpt({inp!r}) = {got!r}, want {want!r}")


class SlotAssignment(unittest.TestCase):
    """Every documented DPT must map to its expected Okas key."""

    def test_every_slot(self):
        cases = [
            # (DPT, role, expected okas key)
            ("DPST-1-1", "ctl", "Swt"), ("DPST-1-1", "sta", "Sta"),
            ("DPST-1-2", "ctl", "Swt"), ("DPST-1-2", "sta", "Sta"),
            ("DPST-1-7", "ctl", "Stp"),
            ("DPST-1-8", "ctl", "Mov"), ("DPST-1-8", "sta", "Mvi"),
            ("DPST-1-9", "ctl", "Mov"), ("DPST-1-9", "sta", "Mvi"),
            ("DPST-1-100", "ctl", "Thc"),
            ("DPST-3-7", "ctl", "Dim"),
            ("DPST-5-1", "ctl", "Bri"), ("DPST-5-1", "sta", "Bvi"),
            ("DPST-5-100", "ctl", "Fsc"), ("DPST-5-100", "sta", "Fsv"),
            ("DPST-7-13", "ctl", "Bri"), ("DPST-7-13", "sta", "Bvi"),
            ("DPST-7-600", "ctl", "Tuc"), ("DPST-7-600", "sta", "Tuv"),
            ("DPST-9-1", "ctl", "Tsp"), ("DPST-9-1", "sta", "Trm"),
            ("DPST-17-1", "ctl", "Scn"),
            ("DPST-20-102", "ctl", "Tmc"), ("DPST-20-102", "sta", "Tmv"),
            ("DPST-232-600", "ctl", "Clc"),
            ("DPST-9", "ctl", "Tsp"),
            ("DPST-5", "ctl", "Bri"),
        ]
        for d, role, want in cases:
            got = k.sFor(d, role)
            self.assertEqual(got, want, f"sFor({d!r}, {role!r}) = {got!r}, want {want!r}")


class ConvertEdgeCases(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path("/tmp/pulsar_edge")
        if self.tmp.exists(): shutil.rmtree(self.tmp)
        self.tmp.mkdir(parents=True)

    def test_missing_knxproj(self):
        r = k.convert(pathlib.Path("/nope.knxproj"), self.tmp)
        self.assertFalse(r["ok"])

    def test_empty_knxproj(self):
        # Create a valid but empty knxproj ZIP.
        z = self.tmp / "empty.knxproj"
        with __import__("zipfile").ZipFile(z, "w"):
            pass
        r = k.convert(z, self.tmp / "out")
        self.assertFalse(r["ok"])

    def test_minimal_knxproj_no_gas(self):
        # knx_master only, no P-*/0.xml
        z = self.tmp / "min.knxproj"
        with __import__("zipfile").ZipFile(z, "w") as zf:
            zf.writestr("knx_master.xml", b"<KNX/>")
        r = k.convert(z, self.tmp / "out")
        self.assertFalse(r["ok"])


if __name__ == "__main__":
    unittest.main()
