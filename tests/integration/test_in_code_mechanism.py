from acom_music_box import MusicBox, Conditions
import mechanism_configuration as mc

import math
import logging
logger = logging.getLogger(__name__)


class TestInCodeMechanism:

    def define_system(self):
        """
        Define the system for the test case.
        """
        A = mc.Species(name="A")
        B = mc.Species(name="B")
        C = mc.Species(name="C")
        D = mc.Species(name="D")
        E = mc.Species(name="E")
        F = mc.Species(name="F")
        species = { "A": A, "B": B, "C": C, "D": D, "E": E, "F": F }
        gas = mc.Phase(name="gas", species=list(species.values()))

        return gas, species

    def create_box_model(self, mechanism):
        """
        Create a MusicBox instance and load the mechanism.
        """
        box_model = MusicBox()
        box_model.load_mechanism(mechanism)

        # Set the initial conditions
        box_model.initial_conditions = Conditions(
          temperature=298.15,
          pressure=101325.0,
          species_concentrations={
            "A": 1.0,
            "B": 0.0,
            "C": 0.0,
            "D": 10.0,
            "E": 0.0,
            "F": 0.0,
          })

        # Set the evolving conditions
        box_model.add_evolving_condition(
          300.0,
          Conditions(
            temperature=310.0,
            pressure=100100.0,
            species_concentrations={
              "D": 1.0,
              "E": 0.0,
              "F": 0.0,
            }))
        box_model.add_evolving_condition(
          450.0,
          Conditions(
            temperature=280.0,
            pressure=90500.0,
            species_concentrations={
              "A": 100.0,
              "B": 0.0,
              "C": 0.0,
            }))

        # Set the time step and duration
        box_model.box_model_options.simulation_length = 600.0
        box_model.box_model_options.chem_step_time = 2
        box_model.box_model_options.output_step_time = 6

        return box_model

    def solve_and_compare(self, box_model, calc_k1, calc_k2, calc_k3, calc_k4):
        """
        Solve the box model and compare the results with analytical solutions.
        """
        df = box_model.solve()
        model_concentrations = df[["CONC.A.mol m-3", "CONC.B.mol m-3", "CONC.C.mol m-3",
                                   "CONC.D.mol m-3", "CONC.E.mol m-3", "CONC.F.mol m-3"]].values
        temperatures = df["ENV.temperature.K"].values
        pressures = df["ENV.pressure.Pa"].values
        air_densities = df["ENV.air number density.mol m-3"].values
        times = df["time.s"].values

        logging.debug(f"Model output: {df}")

        for i_time, time in enumerate(times):

            # Extract the model concentrations for the current time step
            A_conc_model = model_concentrations[i_time][0]
            B_conc_model = model_concentrations[i_time][1]
            C_conc_model = model_concentrations[i_time][2]
            D_conc_model = model_concentrations[i_time][3]
            E_conc_model = model_concentrations[i_time][4]
            F_conc_model = model_concentrations[i_time][5]

            # Calculate the rate constants for the current time step
            k1 = calc_k1(temperatures[i_time], pressures[i_time], air_densities[i_time])
            k2 = calc_k2(temperatures[i_time], pressures[i_time], air_densities[i_time])
            k3 = calc_k3(temperatures[i_time], pressures[i_time], air_densities[i_time])
            k4 = calc_k4(temperatures[i_time], pressures[i_time], air_densities[i_time])

            logging.debug(f"Rate constants at time {time}: k1={k1}, k2={k2}, k3={k3}, k4={k4}")

            # Calculate the analytical concentrations
            if time <= 300.0:
                curr_time = time
                initial_A = 1.0
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
                initial_D = 10.0
                D_conc = initial_D * math.exp(-(k3) * curr_time)
                E_conc = (
                    initial_D
                    * (k3 / (k4 - k3))
                    * (math.exp(-k3 * curr_time) - math.exp(-k4 * curr_time))
                )
                F_conc = initial_D * (
                    1.0
                    + (k3 * math.exp(-k4 * curr_time) - k4 * math.exp(-k3 * curr_time))
                    / (k4 - k3)
                )

                # Compare the model and analytical concentrations
                assert math.isclose(A_conc, A_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"A concentrations differ at time {time}"
                assert math.isclose(B_conc, B_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"B concentrations differ at time {time}"
                assert math.isclose(C_conc, C_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"C concentrations differ at time {time}"
                assert math.isclose(D_conc, D_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"D concentrations differ at time {time}"
                assert math.isclose(E_conc, E_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"E concentrations differ at time {time}"
                assert math.isclose(F_conc, F_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"F concentrations differ at time {time}"
            elif time <= 450.0:
                curr_time = time - 300.0
                initial_D = 1.0
                D_conc = initial_D * math.exp(-(k3) * curr_time)
                E_conc = (
                    initial_D
                    * (k3 / (k4 - k3))
                    * (math.exp(-k3 * curr_time) - math.exp(-k3 * curr_time))
                )
                F_conc = initial_D * (
                    1.0
                    + (k3 * math.exp(-k4 * curr_time) - k4 * math.exp(-k3 * curr_time))
                    / (k4 - k3)
                )

                # Compare the model and analytical concentrations
                assert math.isclose(D_conc, D_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"D concentrations differ at time {time}"
                assert math.isclose(E_conc, E_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"E concentrations differ at time {time}"
                assert math.isclose(F_conc, F_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"F concentrations differ at time {time}"
            else:
                curr_time = time - 450.0
                initial_A = 100.0
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

                # Compare the model and analytical concentrations
                assert math.isclose(A_conc, A_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"A concentrations differ at time {time}"
                assert math.isclose(B_conc, B_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"B concentrations differ at time {time}"
                assert math.isclose(C_conc, C_conc_model, rel_tol=1e-6, abs_tol=1.0e-3), f"C concentrations differ at time {time}"
        
        
    def test_arrhenius(self):
        """
        Test the Arrhenius reaction mechanism.
        """
        gas, species = self.define_system()
        arr1 = mc.Arrhenius(name="A->B", A=4.0e-3, C=50,
            reactants=[species["A"]], products=[species["B"]], gas_phase=gas)
        arr2 = mc.Arrhenius(name="B->C", A=1.2e-4, B=2.5, C=75, D=50, E=0.5,
            reactants=[species["B"]], products=[species["C"]], gas_phase=gas)
        arr3 = mc.Arrhenius(name="D->E", A=4.0e-3, C=35,
            reactants=[species["D"]], products=[species["E"]], gas_phase=gas)
        arr4 = mc.Arrhenius(name="B->C", A=1.2e-4, B=1.4, C=75, D=50, E=0.1,
            reactants=[species["E"]], products=[species["F"]], gas_phase=gas)
        mechanism = mc.Mechanism(name="test_mechanism", species=list(species.values()),
            phases=[gas], reactions=[arr1, arr2, arr3, arr4])
        
        box_model = self.create_box_model(mechanism)

        # Define the rate constants as functions of temperature, pressure, and air density
        def calc_k1(temperature, pressure, air_density):
            return 4.0e-3 * math.exp(50 / temperature)

        def calc_k2(temperature, pressure, air_density):
            return  (
                1.2e-4
                * math.exp(75 / temperature)
                * (temperature / 50) ** 2.5
                * (1.0 + 0.5 * pressure)
              )
        
        def calc_k3(temperature, pressure, air_density):
            return 4.0e-3 * math.exp(35 / temperature)

        def calc_k4(temperature, pressure, air_density):
            return  (
                1.2e-4
                * math.exp(75 / temperature)
                * (temperature / 50) ** 1.4
                * (1.0 + 0.1 * pressure)
              )

        self.solve_and_compare(box_model, calc_k1, calc_k2, calc_k3, calc_k4)


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    test = TestInCodeMechanism()
    test.test_arrhenius()
        
        


