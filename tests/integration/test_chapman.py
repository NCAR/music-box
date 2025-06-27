from acom_music_box import MusicBox, Examples

import os
import pandas as pd
import math


class TestChapman:
    def test_run(self):
        box_model = MusicBox()

        conditions_path = Examples.Chapman.path

        box_model.loadJson(conditions_path)

        # solves and saves output
        model = box_model.solve()

        current_dir = os.path.dirname(__file__)
        expected_results_path = os.path.join(current_dir, "expected_results/chapman_test.csv")

        # read chapman_test.csv into test_output
        expected = pd.read_csv(expected_results_path)

        concs_to_test = [column for column in expected.columns if 'CONC' in column]

        for (_model_index, _model), (_expected_index, _expected) in zip(model.iterrows(), expected.iterrows()):
            for column in concs_to_test:
                assert math.isclose(
                    _model[column],
                    _expected[column],
                    rel_tol=1.0e-12,
                    abs_tol=1.0e-15,
                ), f"Model results differ from expected for row index {_model_index} for species {column}"


class TestChapmanConfig:
    def test_run(self):
        box_model = MusicBox()

        current_dir = os.path.dirname(__file__)
        config_path = os.path.join(current_dir, "configs", "chapman", "chapman.v1.config.json")
        box_model.loadJson(config_path)

        # solves and saves output
        model = box_model.solve()

        current_dir = os.path.dirname(__file__)
        expected_results_path = os.path.join(current_dir, "expected_results/chapman_test.csv")

        # read chapman_test.csv into test_output
        expected = pd.read_csv(expected_results_path)

        concs_to_test = [column for column in expected.columns if 'CONC' in column]

        for (_model_index, _model), (_expected_index, _expected) in zip(model.iterrows(), expected.iterrows()):
            for column in concs_to_test:
                assert math.isclose(
                    _model[column],
                    _expected[column],
                    rel_tol=1e-10,
                    abs_tol=1e-16,
                ), f"Model results differ from expected for row index {_model_index} for species {column}"


if __name__ == "__main__":
    test = TestChapman()
    test.test_run()
    test_config = TestChapmanConfig()
    test_config.test_run()
