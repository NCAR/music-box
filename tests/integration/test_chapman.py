from acom_music_box import MusicBox, Examples

import os
import csv
import math


class TestChapman:
    def test_run(self):
        box_model = MusicBox()

        conditions_path = Examples.Chapman.path

        box_model.loadJson(conditions_path)

        # solves and saves output
        df = box_model.solve()
        model_output = [df.columns.values.tolist()] + df.values.tolist()

        current_dir = os.path.dirname(__file__)
        expected_results_path = os.path.join(current_dir, "expected_results/chapman_test.csv")

        # read chapman_test.csv into test_output
        with open(expected_results_path, "r") as file:
            reader = csv.reader(file)
            test_output = list(reader)

        concs_to_test = [
            "CONC.H2O",
            "CONC.Ar",
            "CONC.CO2",
            "CONC.O1D",
            "CONC.O2",
            "CONC.O3",
            "CONC.O",
        ]
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
                    rel_tol=1e-7,
                    abs_tol=1e-15,
                ), f"Arrays differ at index ({i}, {j}) for species {concs_to_test[j]}"


if __name__ == "__main__":
    test = TestChapman()
    test.test_run()
