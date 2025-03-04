from acom_music_box import MusicBox

import csv
import math


class TestWallLoss:
    def test_run(self):
        box_model = MusicBox()

        # configures box model
        conditions_path = "configs/wall_loss_config/my_config.json"
        camp_path = "configs/wall_loss_config/camp_data"

        box_model.readConditionsFromJson(conditions_path)
        box_model.create_solver(camp_path)

        # solves and saves output
        model_output = box_model.solve()

        # read wall_loss_test.csv into test_output
        with open("expected_results/wall_loss_test.csv", "r") as file:
            reader = csv.reader(file)
            test_output = list(reader)

        concs_to_test = ["CONC.SOA1", "CONC.SOA2", "CONC.a-pinene", "CONC.O3"]
        model_output_header = model_output[0]
        test_output_header = test_output[0]

        output_indices = [model_output_header.index(conc) for conc in concs_to_test]
        test_output_indices = [test_output_header.index(conc) for conc in concs_to_test]

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
                    rel_tol=1e-8,
                ), f"Arrays differ at index ({i}, {j}) for "


if __name__ == "__main__":
    test = TestWallLoss()
    test.test_run()
