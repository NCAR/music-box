from acom_music_box import MusicBox, Examples, DataOutput
import os

import pandas as pd
import math


class TestCarbonBond5:
    def test_run(self):
        box_model = MusicBox()

        conditions_path = Examples.CarbonBond5.path

        box_model.loadJson(conditions_path)

        # solves and saves output
        df = box_model.solve()
        dataOutput = DataOutput(df, None)
        model_output = [dataOutput.df.columns.values.tolist()] + \
            dataOutput.df.values.tolist()

        current_dir = os.path.dirname(__file__)
        expected_results_path = os.path.join(
            current_dir, "expected_results/full_gas_phase_mechanism.csv")

        # read full_gas_phase_mechanism.csv into a DataFrame
        expected = pd.read_csv(expected_results_path)
        test_output = [expected.columns.values.tolist()] + \
            expected.values.tolist()

        concs_to_test = [
            "CONC.PAN",
            "CONC.SO2",
            "CONC.H2",
            "CONC.BENZRO2",
            "CONC.CH4",
            "CONC.TOL",
            "CONC.FACD",
            "CONC.PANX",
            "CONC.PNA",
            "CONC.HONO",
            "CONC.PACD",
            "CONC.XYLRO2",
            "CONC.TOLRO2",
            "CONC.ETHA",
            "CONC.AACD",
            "CONC.N2O5",
            "CONC.SESQ",
            "CONC.ETOH",
            "CONC.O2",
            "CONC.XYL",
            "CONC.TO2",
            "CONC.FMCL",
            "CONC.MEPX",
            "CONC.ROOH",
            "CONC.H2O2",
            "CONC.HCL",
            "CONC.CLO",
            "CONC.MEOH",
            "CONC.CRO",
            "CONC.MGLY",
            "CONC.HCO3",
            "CONC.O1D",
            "CONC.ROR",
            "CONC.HNO3",
            "CONC.OPEN",
            "CONC.TERP",
            "CONC.CO",
            "CONC.ETH",
            "CONC.CRES",
            "CONC.XO2N",
            "CONC.IOLE",
            "CONC.H2O",
            "CONC.ISPD",
            "CONC.NTR",
            "CONC.OLE",
            "CONC.MEO2",
            "CONC.PAR",
            "CONC.ISOP",
            "CONC.ALDX",
            "CONC.C2O3",
            "CONC.CXO3",
            "CONC.ALD2",
            "CONC.FORM",
            "CONC.XO2",
            "CONC.CL",
            "CONC.O",
            "CONC.O3",
            "CONC.NO2",
            "CONC.NO3",
            "CONC.HO2",
            "CONC.NO",
            "CONC.SULF",
            "CONC.HOCL",
            "CONC.OH",
        ]

        # append units to those chemicals for CSV comparison
        concUnits = ".mol m-3"
        concs_to_test = [conc + concUnits for conc in concs_to_test]

        model_output_header = model_output[0]
        test_output_header = test_output[0]

        output_indices = [model_output_header.index(
            conc) for conc in concs_to_test]
        test_output_indices = [
            test_output_header.index(conc) for conc in concs_to_test]

        model_output_concs = [
            [row[i] for i in output_indices] for row in model_output[1:]
        ]
        test_output_concs = [
            [row[i] for i in test_output_indices] for row in test_output[1:]
        ]

        # asserts concentrations
        for i in range(len(model_output_concs)):
            for j in range(len(model_output_concs[i])):
                assert math.isclose(
                    float(model_output_concs[i][j]),
                    float(test_output_concs[i][j]),
                    rel_tol=1e-4,
                    abs_tol=1e-4,
                ), f"Arrays differ at index ({i}, {j}, species {concs_to_test[j]})"


if __name__ == "__main__":
    test = TestCarbonBond5()
    test.test_run()
