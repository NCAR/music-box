from acom_music_box import MusicBox, Examples
import os

import math
import logging
logger = logging.getLogger(__name__)


class TestAnalytical:
    def test_run(self):
        box_model = MusicBox()

        conditions_path = Examples.Analytical.path
        logger.info(f"conditions_path = {conditions_path}")

        box_model.loadJson(conditions_path)

        # The analytical solution below will match the model solution
        # only when initial B=0 and C=0. A=n from the JSON config is okay.
        box_model.initial_conditions.species_concentrations["B"] = 0.0
        box_model.initial_conditions.species_concentrations["C"] = 0.0

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
        logger.info(f"Initial analytical_concentrations = {analytical_concentrations}")

        # set up the time steps
        chem_time_step = box_model.box_model_options.chem_step_time
        out_time_step = box_model.box_model_options.output_step_time
        logger.debug(f"chem_time_step = {chem_time_step}   out_time_step = {out_time_step}")
        sim_length = box_model.box_model_options.simulation_length

        # set up the initial environment
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
        # For this loop to replicate the model solver accurately,
        # out_time_step should be an even multiple of chem_time_step.
        initial_A = analytical_concentrations[0][idx_A]
        while curr_time <= sim_length:
            A_conc = initial_A * math.exp(-(k1) * curr_time)
            B_conc = (
                initial_A
                * (k1 / (k2 - k1))
                * (math.exp(-k1 * curr_time) - math.exp(-k2 * curr_time))
            )
            C_conc = initial_A * (
                1.0
                + (k1 * math.exp(-k2 * curr_time) - k2 * math.exp(-k1 * curr_time))
                / (k2 - k1)
            )

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
                rel_tol=1e-6,
            ), f"Arrays differ at index ({i}, 0)"
            assert math.isclose(
                model_concentrations[i][idx_B],
                analytical_concentrations[i][idx_B],
                rel_tol=1e-6,
            ), f"Arrays differ at index ({i}, 1)"
            assert math.isclose(
                model_concentrations[i][idx_C],
                analytical_concentrations[i][idx_C],
                rel_tol=1e-6,
            ), f"Arrays differ at index ({i}, 2)"


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    test = TestAnalytical()
    test.test_run()

