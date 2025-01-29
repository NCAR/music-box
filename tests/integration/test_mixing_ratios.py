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

        conc_a_index = output[0].index("CONC.A")
        conc_b_index = output[0].index("CONC.B")
        conc_c_index = output[0].index("CONC.C")

        # extracts model concentrations from data output
        model_concentrations = [
            [row[conc_a_index], row[conc_b_index], row[conc_c_index]]
            for row in output[1:]
        ]

        # initalizes the species concentrations
        analytical_concentrations = []
        box_spec_conc = box_model.initial_conditions.species_concentrations
        analytical_concentrations.append([
            box_spec_conc["A"],
            box_spec_conc["B"],
            box_spec_conc["C"]
        ])
        logger.info(f"analytical_concentrations = {analytical_concentrations}")

        chem_time_step = box_model.box_model_options.chem_step_time
        out_time_step = box_model.box_model_options.output_step_time
        logger.debug(f"chem_time_step = {chem_time_step}   out_time_step = {out_time_step}")
        sim_length = box_model.box_model_options.simulation_length

        temperature = box_model.initial_conditions.temperature
        pressure = box_model.initial_conditions.pressure

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

            initial_A = analytical_concentrations[0][idx_A]
            initial_B = analytical_concentrations[0][idx_B]
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
    test = TestAnalytical()
    test.test_run()

