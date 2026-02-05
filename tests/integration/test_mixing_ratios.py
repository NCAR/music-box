from acom_music_box import MusicBox, Examples
import os

import math
import logging
logger = logging.getLogger(__name__)


class TestAnalyticalWithMixingRatios:
    def run_example(self, example):
        logger.info(f"example = {example}")

        box_model = MusicBox()
        box_model.loadJson(example)

        # solves and saves output
        df = box_model.solve()
        output = [df.columns.values.tolist()] + df.values.tolist()

        conc_a_index = output[0].index("CONC.A.mol m-3")
        conc_b_index = output[0].index("CONC.B.mol m-3")
        conc_c_index = output[0].index("CONC.C.mol m-3")

        # extracts model concentrations from data output
        model_concentrations = [
            [row[conc_a_index], row[conc_b_index], row[conc_c_index]]
            for row in output[1:]
        ]

        # initializes the species concentrations from concentration_events
        analytical_concentrations = []
        raw_conds = box_model.conditions_raw
        time_zero_row = raw_conds[raw_conds["time.s"] == 0].iloc[0]

        # Get species concentrations from concentration_events
        conc_events = box_model.concentration_events
        initial_concs = conc_events.get(0, conc_events.get(0.0, {}))
        initial_A = initial_concs.get("A", 0.0)
        initial_B = initial_concs.get("B", 0.0)
        initial_C = initial_concs.get("C", 0.0)

        analytical_concentrations.append([initial_A, initial_B, initial_C])
        logger.info(f"analytical_concentrations = {analytical_concentrations}")

        chem_time_step = box_model.box_model_options.chem_step_time
        out_time_step = box_model.box_model_options.output_step_time
        logger.debug(f"chem_time_step = {chem_time_step}   out_time_step = {out_time_step}")
        sim_length = box_model.box_model_options.simulation_length

        temperature = time_zero_row.get("ENV.temperature.K", 283.6)
        pressure = time_zero_row.get("ENV.pressure.Pa", 102364.4)

        k1 = 4.0e-3 * math.exp(50 / temperature)
        k2 = (
            1.2e-4
            * math.exp(75 / temperature)
            * (temperature / 50) ** 7
            * (1.0 + 0.5 * pressure)
        )

        curr_time = chem_time_step
        last_out_time = 0

        idx_A = 0
        idx_B = 1
        idx_C = 2

        # gets analytical concentrations
        # For this loop to approximately the model solver accurately,
        # out_time_step should be an even multiple of chem_time_step.
        while curr_time <= sim_length:

            C_conc = analytical_concentrations[0][idx_C]
            A_conc = initial_A * math.exp(-(k1) * curr_time)
            B_conc = (
                initial_A
                * (k1 / (k2 - k1))
                * (math.exp(-k1 * curr_time) - math.exp(-k2 * curr_time))
            )
            C_conc += initial_A * (
                1.0
                + (k1 * math.exp(-k2 * curr_time) - k2 * math.exp(-k1 * curr_time))
                / (k2 - k1)
            ) + initial_B

            if (curr_time >= last_out_time + out_time_step):
                analytical_concentrations.append([A_conc, B_conc, C_conc])
                last_out_time += out_time_step

            curr_time += chem_time_step

        logger.debug(f"len model_concentrations = {len(model_concentrations)}")
        logger.debug(f"len analytical_concentrations = {len(analytical_concentrations)}")

        # asserts concentrations
        for i in range(len(model_concentrations)):
            assert math.isclose(
                model_concentrations[i][idx_A],
                analytical_concentrations[i][idx_A],
                rel_tol=1e-8,
            ), f"Arrays differ at index ({i}, 0)"
            assert math.isclose(
                model_concentrations[i][idx_B],
                analytical_concentrations[i][idx_B],
                rel_tol=1e-8,
            ), f"Arrays differ at index ({i}, 1)"
            assert math.isclose(
                model_concentrations[i][idx_C],
                analytical_concentrations[i][idx_C],
                rel_tol=1e-8,
            ), f"Arrays differ at index ({i}, 2)"

    def test_mol_mol_1(self):
        current_dir = os.path.dirname(__file__)
        example = os.path.join(current_dir, "configs", "mixing_ratio", "mol mol-1", "my_config.json")
        self.run_example(example)

    def test_ppth(self):
        current_dir = os.path.dirname(__file__)
        example = os.path.join(current_dir, "configs", "mixing_ratio", "ppth", "my_config.json")
        self.run_example(example)

    def test_ppm(self):
        current_dir = os.path.dirname(__file__)
        example = os.path.join(current_dir, "configs", "mixing_ratio", "ppm", "my_config.json")
        self.run_example(example)

    def test_ppb(self):
        current_dir = os.path.dirname(__file__)
        example = os.path.join(current_dir, "configs", "mixing_ratio", "ppb", "my_config.json")
        self.run_example(example)

    def test_ppt(self):
        current_dir = os.path.dirname(__file__)
        example = os.path.join(current_dir, "configs", "mixing_ratio", "ppt", "my_config.json")
        self.run_example(example)


if __name__ == "__main__":
    test = TestAnalyticalWithMixingRatios()
    test.test_mol_mol_1()
