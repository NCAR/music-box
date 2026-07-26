import json
import os
import tempfile
import unittest

from acom_music_box.config_converter import (
    convert_csv_header, convert_config, _convert_inline_data)


class TestConvertCsvHeader(unittest.TestCase):
    def test_conc_keeps_units_dot_separated(self):
        self.assertEqual(convert_csv_header("CONC.O3 [mol m-3]"), "CONC.O3.mol m-3")
        self.assertEqual(convert_csv_header("CONC.GLYOXAL [mol m-3]"), "CONC.GLYOXAL.mol m-3")

    def test_env_bracket_to_dot(self):
        self.assertEqual(convert_csv_header("ENV.temperature [K]"), "ENV.temperature.K")
        self.assertEqual(convert_csv_header("ENV.pressure [Pa]"), "ENV.pressure.Pa")

    def test_surface_effective_radius(self):
        self.assertEqual(
            convert_csv_header("SURFACE.usr_GLYOXAL_aer.m"),
            "SURF.usr_GLYOXAL_aer.effective radius.m")

    def test_surface_number_concentration(self):
        self.assertEqual(
            convert_csv_header("SURFACE.usr_GLYOXAL_aer.# m-3"),
            "SURF.usr_GLYOXAL_aer.particle number concentration.# m-3")

    def test_passthrough(self):
        for col in ("time.s", "ENV.temperature.K", "PHOTO.jno2.s-1", "EMIS.NO.mol m-3 s-1"):
            self.assertEqual(convert_csv_header(col), col)


class TestConvertInlineData(unittest.TestCase):
    def test_list_of_lists_prepends_time(self):
        block = _convert_inline_data(
            [["ENV.temperature [K]", "CONC.A [mol m-3]"], [298.0, 1e-9]])
        self.assertEqual(block["headers"], ["time.s", "ENV.temperature.K", "CONC.A.mol m-3"])
        self.assertEqual(block["rows"], [[0.0, 298.0, 1e-9]])

    def test_existing_time_column_preserved(self):
        block = _convert_inline_data([["time.s", "PHOTO.j.s-1"], [0, 1e-4]])
        self.assertEqual(block["headers"], ["time.s", "PHOTO.j.s-1"])
        self.assertEqual(block["rows"], [[0, 1e-4]])

    def test_empty(self):
        self.assertIsNone(_convert_inline_data(None))
        self.assertIsNone(_convert_inline_data([]))


class TestConvertConfig(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = self.tmp.name
        camp = os.path.join(root, "camp_data")
        os.makedirs(camp)
        # Minimal v0 CAMP mechanism.
        with open(os.path.join(camp, "config.json"), "w") as f:
            json.dump({"camp-files": ["species.json", "reactions.json"]}, f)
        with open(os.path.join(camp, "species.json"), "w") as f:
            json.dump({"camp-data": [
                {"name": "A", "type": "CHEM_SPEC"},
                {"name": "B", "type": "CHEM_SPEC"},
                {"name": "M", "type": "CHEM_SPEC", "tracer type": "THIRD_BODY"},
            ]}, f)
        with open(os.path.join(camp, "reactions.json"), "w") as f:
            json.dump({"camp-data": [{"type": "MECHANISM", "name": "m", "reactions": [
                {"type": "ARRHENIUS", "A": 1.0, "reactants": {"A": {}}, "products": {"B": {}}},
            ]}]}, f)
        # Old-format initial CSV (no time column, unit-tagged CONC headers).
        with open(os.path.join(root, "ic.csv"), "w") as f:
            f.write("CONC.A [mol m-3],CONC.B [mol m-3]\n1e-9,2e-9\n")
        # Evolving CSV already carries a time.s column (a time series).
        with open(os.path.join(root, "evolving.csv"), "w") as f:
            f.write("time.s,PHOTO.rphoto.s-1\n0,1e-4\n60,2e-4\n")
        # Old-format top-level config.
        self.old_config = os.path.join(root, "my_config.json")
        with open(self.old_config, "w") as f:
            json.dump({
                "box model options": {"grid": "box", "chemistry time step [sec]": 1,
                                      "output time step [sec]": 1, "simulation length [hour]": 1},
                "environmental conditions": {
                    "temperature": {"initial value [K]": 290.0},
                    "pressure": {"initial value [Pa]": 101325.0}},
                "initial conditions": {"filepaths": ["ic.csv"]},
                "evolving conditions": {"filepaths": ["evolving.csv"]},
                "model components": [{
                    "type": "CAMP", "configuration file": "camp_data/config.json",
                    "override species": {"M": {"mixing ratio mol mol-1": 1},
                                         "A": {"mixing ratio mol mol-1": 0.5}},
                    "suppress output": {"M": {}}}],
            }, f)
        self.out_dir = os.path.join(root, "out")

    def tearDown(self):
        self.tmp.cleanup()

    def test_convert_config_structure(self):
        out_config = convert_config(self.old_config, self.out_dir)
        with open(out_config) as f:
            new = json.load(f)

        # New layout: box model options + conditions + inline mechanism.
        self.assertEqual(set(new), {"box model options", "conditions", "mechanism"})
        self.assertEqual(new["box model options"]["grid"], "box")

        cond = new["conditions"]
        self.assertEqual(cond["data"][0]["headers"],
                         ["time.s", "ENV.temperature.K", "ENV.pressure.Pa"])
        self.assertEqual(cond["data"][0]["rows"], [[0.0, 290.0, 101325.0]])
        # Both initial and evolving CSVs are referenced.
        self.assertEqual(cond["filepaths"], ["ic.csv", "evolving.csv"])

        # Mechanism converted to v1 with all species.
        self.assertEqual(new["mechanism"]["version"], "1.0.0")
        names = {s["name"] for s in new["mechanism"]["species"]}
        self.assertEqual(names, {"A", "B", "M"})
        self.assertEqual(len(new["mechanism"]["reactions"]), 1)

    def test_override_species_translation(self):
        out_config = convert_config(self.old_config, self.out_dir)
        with open(out_config) as f:
            species = {s["name"]: s for s in json.load(f)["mechanism"]["species"]}

        # Third-body M is fixed to air density by the mechanism; the override
        # needs no translation and must not add a constant mixing ratio.
        self.assertTrue(species["M"]["is third body"])
        self.assertNotIn("constant mixing ratio [mol mol-1]", species["M"])

        # A non-third-body override becomes a constant mixing ratio on the species.
        self.assertEqual(species["A"]["constant mixing ratio [mol mol-1]"], 0.5)

    def test_convert_config_rewrites_csv(self):
        convert_config(self.old_config, self.out_dir)
        with open(os.path.join(self.out_dir, "ic.csv")) as f:
            lines = [line.strip() for line in f if line.strip()]
        self.assertEqual(lines[0], "time.s,CONC.A.mol m-3,CONC.B.mol m-3")
        self.assertEqual(lines[1], "0.0,1e-9,2e-9")

    def test_evolving_conditions_converted(self):
        convert_config(self.old_config, self.out_dir)
        # The evolving CSV is copied over, keeping its existing time.s column
        # (no extra time column prepended).
        with open(os.path.join(self.out_dir, "evolving.csv")) as f:
            lines = [line.strip() for line in f if line.strip()]
        self.assertEqual(lines[0], "time.s,PHOTO.rphoto.s-1")
        self.assertEqual(lines[1:], ["0,1e-4", "60,2e-4"])

    def test_inline_initial_conditions_data(self):
        # An old config that uses an inline 'data' table instead of a CSV filepath.
        with open(self.old_config) as f:
            cfg = json.load(f)
        cfg["initial conditions"] = {
            "data": [["CONC.A [mol m-3]", "CONC.B [mol m-3]"], [1e-9, 2e-9]]}
        cfg.pop("evolving conditions", None)
        with open(self.old_config, "w") as f:
            json.dump(cfg, f)

        out_config = convert_config(self.old_config, self.out_dir)
        with open(out_config) as f:
            cond = json.load(f)["conditions"]
        # The inline table becomes a converted data block (with a time.s column).
        inline = [b for b in cond["data"] if "CONC.A.mol m-3" in b["headers"]]
        self.assertEqual(len(inline), 1)
        self.assertEqual(inline[0]["headers"], ["time.s", "CONC.A.mol m-3", "CONC.B.mol m-3"])
        self.assertEqual(inline[0]["rows"], [[0.0, 1e-9, 2e-9]])
        self.assertNotIn("filepaths", cond)


if __name__ == "__main__":
    unittest.main()
