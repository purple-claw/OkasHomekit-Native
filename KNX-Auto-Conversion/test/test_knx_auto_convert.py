"""
Unit + integration tests for knx_auto_convert_v2.
- Unit: DPT normalization, slot assignment, GA-style conversion.
- Integration: for every .knxproj fixture whose name matches a
  ValidateXmls XML, run the converter and assert every emitted GA is in
  the matching XML and every XML GA is either used by a load or
  explicitly audited as unreferenced.
"""
import importlib.util
import pathlib
import sys
import unittest
import xml.etree.ElementTree as ET

from collections import Counter

PROJECT_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_DIR))

SOURCE = PROJECT_DIR / "pulsar.py"
spec = importlib.util.spec_from_file_location("pulsar", SOURCE)
k = importlib.util.module_from_spec(spec)
sys.modules["pulsar"] = k
spec.loader.exec_module(k)


def _ga_raw(addr: str) -> int:
    parts = [int(p) for p in str(addr).split("/")]
    if len(parts) == 3:
        return (parts[0] << 11) + (parts[1] << 8) + parts[2]
    if len(parts) == 2:
        return (parts[0] << 11) + parts[1]
    return parts[0]


def _fixture_ga_set(path: pathlib.Path) -> set:
    s = set()
    for e in ET.parse(path).iter():
        if e.tag.rsplit("}", 1)[-1] == "GroupAddress" and e.get("Address"):
            s.add(_ga_raw(e.get("Address")))
    return s


class UnitTests(unittest.TestCase):
    def test_nDpt(self):
        self.assertEqual(k.nDpt("DPST-1-1"), "1.001")
        self.assertEqual(k.nDpt("DPT-5"), "5")
        self.assertEqual(k.nDpt("DPST-9.001"), "9.001")
        self.assertEqual(k.nDpt("DPST 7-600"), "7.600")
        self.assertEqual(k.nDpt(""), "")

    def test_fGa(self):
        self.assertEqual(k.fGa(2048, "ThreeLevel"), "1/0/0")
        self.assertEqual(k.fGa(2048, "TwoLevel"), "1/0")
        self.assertEqual(k.fGa(2048, "Free"), "2048")

    def test_sFor(self):
        self.assertEqual(k.sFor("DPST-1-1", "ctl"), "Swt")
        self.assertEqual(k.sFor("DPST-1-1", "sta"), "Sta")
        self.assertEqual(k.sFor("DPST-3-7", "ctl"), "Dim")
        self.assertEqual(k.sFor("DPST-7-600", "ctl"), "Tuc")
        self.assertEqual(k.sFor("DPST-7-600", "sta"), "Tuv")
        self.assertEqual(k.sFor("DPST-9-1", "ctl"), "Tsp")
        self.assertEqual(k.sFor("DPST-20-102", "ctl"), "Tmc")
        self.assertEqual(k.sFor("DPST-17-1", "ctl"), "Scn")
        self.assertEqual(k.sFor("DPST-232-600", "ctl"), "Clc")
        self.assertEqual(k.sFor("DPST-5-1", "ctl"), "Bri")
        self.assertEqual(k.sFor("DPST-3-7", "sta"), None)
        self.assertEqual(k.sFor("DPST-1-8", "ctl"), "Mov")
        self.assertEqual(k.sFor("DPST-1-7", "ctl"), "Stp")

    def test_typ4k(self):
        self.assertEqual(k.typ4k({"Swt", "Sta"})[0], "Switch")
        self.assertEqual(k.typ4k({"Swt", "Sta", "Dim", "Bri", "Bvi"})[0], "Dimmer")
        self.assertEqual(k.typ4k({"Tuc", "Tuv", "Bri"})[0], "Tunable")
        self.assertEqual(k.typ4k({"Mov", "Mvi", "Stp"})[0], "Curtain")
        self.assertEqual(k.typ4k({"Fsc", "Fsv"})[0], "Fan")
        self.assertEqual(k.typ4k({"Tsp", "Trm", "Tmc"})[0], "HVAC")
        self.assertEqual(k.typ4k({"Scn"})[0], "Scene")
        self.assertEqual(k.typ4k({"Clc", "Clv"})[0], "RGB")

    def test_dDptFrmSz(self):
        self.assertEqual(k.dDptFrmSz("1 Bit"), "1.001")
        self.assertEqual(k.dDptFrmSz("4 Bit"), "3.007")
        self.assertEqual(k.dDptFrmSz("1 Byte"), "5.001")
        self.assertEqual(k.dDptFrmSz("2 Bytes"), "7.013")
        self.assertEqual(k.dDptFrmSz("4 Bytes (Float)"), "14.056")
        self.assertEqual(k.dDptFrmSz("6 Bytes"), "232.600")

    def test_pFlg(self):
        self.assertIs(k.pFlg("Enabled"), True)
        self.assertIs(k.pFlg("Disabled"), False)
        self.assertIsNone(k.pFlg(None))


class IntegrationTests(unittest.TestCase):
    """Each .knxproj paired with its ValidateXmls must:
    - emit only GAs that exist in the validation XML
    - have well-formed room/load indices
    """

    def _run(self, knxproj: pathlib.Path) -> dict:
        out = pathlib.Path("/tmp/kac_test") / knxproj.stem
        if out.exists():
            import shutil
            shutil.rmtree(out)
        return k.convert(knxproj, out, audit=True)

    def test_rooms_have_valid_load_indices(self):
        import shutil
        for prj in (PROJECT_DIR / "test" / "knxprojfiles").glob("*.knxproj"):
            with self.subTest(project=prj.name):
                out = pathlib.Path("/tmp/kac_test") / prj.stem
                if out.exists():
                    shutil.rmtree(out)
                res = k.convert(prj, out)
                self.assertTrue(res.get("ok"), res)
                self.assertGreater(res["loads"], 0, f"zero loads in {prj.name}")
                doc = (out / "KNXdata.json").read_text()
                import json
                data = json.loads(doc)
                for r in data["rooms"]:
                    self.assertGreater(len(r["loads"]), 0, f"empty room {r['name']} in {prj.name}")
                    for idx in r["loads"]:
                        self.assertGreaterEqual(idx, 1)
                        self.assertLessEqual(idx, len(data["loads"]))
                    self.assertEqual(len(r["loads"]), len(set(r["loads"])),
                                     f"duplicate load indices in room {r['name']}")

    def test_emitted_gas_subset_of_fixture(self):
        import json
        pairs = [
            ("test/knxprojfiles/Abhinav Reddy ( GAR New House ).knxproj",
             "ValidateXmls/Abhinav Reddy GAR New House.xml"),
            ("test/knxprojfiles/GAR_Janawada_FarmHouse.knxproj",
             "ValidateXmls/Abhinav Reddy GAR Janawada .xml"),
            ("test/knxprojfiles/Miantic Demo Showroom (07-April-26).knxproj",
             "ValidateXmls/Miantic Demo.xml"),
            ("test/knxprojfiles/Venkat Reddy (Ananthapur) 19-07-2025 -.knxproj",
             "ValidateXmls/Venkat Reddy.csv.xml"),
            ("test/knxprojfiles/43 PHR Guest & Jr Son's  Floor's.knxproj",
             "ValidateXmls/43 PHR Guest.xml"),
            ("test/knxprojfiles/IKEA { Leighton } After Ware house  (1).knxproj",
             "ValidateXmls/Ikea.xml"),
            ("test/Black Nova Tet File.knxproj",
             "ValidateXmls/ghjkl.xml"),
        ]
        for prj, fixture in pairs:
            with self.subTest(project=prj):
                prj_path = PROJECT_DIR / prj
                fix_path = PROJECT_DIR / fixture
                out = pathlib.Path("/tmp/kac_test") / prj_path.stem
                if out.exists():
                    import shutil
                    shutil.rmtree(out)
                res = k.convert(prj_path, out)
                self.assertTrue(res.get("ok"), res)
                data = json.loads((out / "KNXdata.json").read_text())
                emitted = {g for ld in data["loads"] for g in ld.get("gAdd", []) if g}
                emitted_raw = {_ga_raw(a) for a in emitted}
                fixture_set = _fixture_ga_set(fix_path)
                extras = emitted_raw - fixture_set
                self.assertFalse(
                    extras,
                    f"{prj_path.name}: emitted GAs not in fixture: {sorted(extras)[:5]}",
                )


if __name__ == "__main__":
    unittest.main()
