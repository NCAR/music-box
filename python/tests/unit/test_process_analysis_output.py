import os
import tempfile
import unittest

import numpy as np
import pandas as pd
import xarray as xr
import yaml

from acom_music_box import ProcessAnalysisOutput


class _Comp:
    def __init__(self, name, coefficient=1.0):
        self.name = name
        self.coefficient = coefficient


# Reaction stand-ins. The writer dispatches on the class name (``Photolysis``)
# and on the presence of ``reactants``/``gas_phase_species`` attributes, so these
# lightweight duck-typed objects exercise the same code paths as musica's classes.
class Arrhenius:
    def __init__(self, reactants, products, name=""):
        self.reactants = reactants
        self.products = products
        self.name = name


class Photolysis:
    def __init__(self, reactants, products, name=""):
        self.reactants = reactants
        self.products = products
        self.name = name


class Surface:
    def __init__(self, gas_phase_species, gas_phase_products, name=""):
        self.gas_phase_species = gas_phase_species
        self.gas_phase_products = gas_phase_products
        self.name = name


class _Species:
    def __init__(self, name):
        self.name = name


class _Mechanism:
    def __init__(self, reactions, species, name="test-mech"):
        self.reactions = reactions
        self.species = species
        self.name = name


class TestProcessAnalysisOutput(unittest.TestCase):
    def setUp(self):
        self.reactions = [
            Arrhenius([_Comp("NO3"), _Comp("CH3COCHO")],
                      [_Comp("HNO3"), _Comp("CO"), _Comp("irr__aaa")]),
            Photolysis([_Comp("CCL4")], [_Comp("CL", 4.0), _Comp("irr__bbb")]),
            Surface(_Comp("GLYOXAL"), [_Comp("SOAG0"), _Comp("irr__ccc")]),
            # Same reactants as the first reaction -> exercises name disambiguation.
            Arrhenius([_Comp("NO3"), _Comp("CH3COCHO")],
                      [_Comp("HNO3", 0.5), _Comp("irr__ddd")]),
        ]
        self.species = [_Species(n) for n in (
            "NO3", "CH3COCHO", "HNO3", "CO", "CCL4", "CL", "GLYOXAL", "SOAG0",
            "irr__aaa", "irr__bbb", "irr__ccc", "irr__ddd")]
        self.mech = _Mechanism(self.reactions, self.species)

        # Three output steps; irr tracers accumulate (cumulative IRR).
        cols = {"time.s": [0.0, 60.0, 120.0]}
        for s in self.species:
            base = {"irr__aaa": 1e-12, "irr__bbb": 2e-12, "irr__ccc": 3e-12, "irr__ddd": 4e-12}.get(s.name, 0.0)
            cols[f"CONC.{s.name}.mol m-3"] = [base, base * 2, base * 3]
        self.df = pd.DataFrame(cols)

        self.temp_dir = tempfile.TemporaryDirectory()
        self.prefix = os.path.join(self.temp_dir.name, "sub", "run")

    def tearDown(self):
        self.temp_dir.cleanup()

    def _write(self):
        ProcessAnalysisOutput(self.df, self.mech, self.prefix + ".nc").write()
        return self.prefix + ".yaml", self.prefix + ".nc"

    def test_yaml_structure_and_grammar(self):
        yaml_path, _ = self._write()
        self.assertTrue(os.path.exists(yaml_path))
        with open(yaml_path) as handle:
            doc = yaml.safe_load(handle)

        # Real species only; tracers excluded.
        self.assertNotIn("irr__aaa", doc["species_list"])
        self.assertIn("GLYOXAL", doc["species_list"])
        self.assertEqual(len(doc["species_list"]), 8)

        rl = doc["reaction_list"]
        self.assertEqual(len(rl), 4)
        # Names, disambiguation, and grammar.
        self.assertEqual(rl["NO3_CH3COCHO_IRR"], "NO3 + CH3COCHO ->[k] HNO3 + CO")
        self.assertEqual(rl["CCL4_HV_IRR"], "CCL4 ->[j] 4*CL")
        self.assertEqual(rl["GLYOXAL_IRR"], "GLYOXAL ->[k] SOAG0")
        self.assertEqual(rl["NO3_CH3COCHO_a_IRR"], "NO3 + CH3COCHO ->[k] 0.5*HNO3")
        # No irr__ tracer leaks into any equation.
        self.assertFalse(any("irr__" in eq for eq in rl.values()))

    def test_netcdf_variables_match_reactions(self):
        yaml_path, nc_path = self._write()
        self.assertTrue(os.path.exists(nc_path))
        ds = xr.open_dataset(nc_path)
        try:
            with open(yaml_path) as handle:
                rl = yaml.safe_load(handle)["reaction_list"]
            # Every reaction key has a matching NetCDF variable with the tracer series.
            for key in rl:
                self.assertIn(key, ds.data_vars)
                self.assertEqual(ds[key].dims, ("TSTEP",))
            np.testing.assert_allclose(ds["GLYOXAL_IRR"].values, [3e-12, 6e-12, 9e-12])
            self.assertEqual(ds["GLYOXAL_IRR"].attrs.get("units"), "mol m-3")
            # IOAPI-style time flag present.
            self.assertIn("TFLAG", ds.data_vars)
            self.assertEqual(ds["TFLAG"].dims, ("TSTEP", "VAR", "DATE-TIME"))
        finally:
            ds.close()


if __name__ == "__main__":
    unittest.main()
