
from box_model import BoxModel

import math


def __main__():
    box_model = BoxModel()

    #configures box model
    conditions_path = "configs/test_config_1/my_config.json"
    camp_path = "configs/test_config_1/camp_data"
    
    box_model.readConditionsFromJson(conditions_path)
    box_model.create_solver(camp_path)

    #solves and saves output
    output = box_model.solve()

    conc_a_index = output[0].index('CONC.A')
    conc_b_index = output[0].index('CONC.B')
    conc_c_index = output[0].index('CONC.C')

    #extracts model concentratins from data output
    model_concentrations = [[row[conc_a_index], row[conc_b_index], row[conc_c_index]] for row in output[1:]]


    

    #initalizes concentrations 
    analytical_concentrations = []
    analytical_concentrations.append([1,0,0])

    time_step = box_model.box_model_options.chem_step_time
    sim_length = box_model.box_model_options.simulation_length

    temperature = box_model.initial_conditions.temperature
    pressure = box_model.initial_conditions.pressure

    k1 = 4.0e-3 * math.exp(50 / temperature)
    k2 = 1.2e-4 * math.exp(75 / temperature) * (temperature / 50)**7* (1.0 + 0.5 * pressure)


    
    curr_time = time_step

    idx_A = 0
    idx_B = 1
    idx_C = 2

    #gets analytical concentrations 
    while curr_time <= sim_length:

        initial_A = analytical_concentrations[0][idx_A]
        A_conc = initial_A * math.exp(-(k1)* curr_time)
        B_conc = initial_A * (k1 / (k2 - k1)) * (math.exp(-k1 * curr_time) - math.exp(-k2 * curr_time))
        C_conc =  initial_A * (1.0 + (k1 * math.exp(-k2 * curr_time) - k2 * math.exp(-k1 * curr_time)) / (k2 - k1))

        analytical_concentrations.append([A_conc, B_conc, C_conc])
        curr_time += time_step

    #asserts concentrations
    for i in range(len(model_concentrations)):
        assert math.isclose(model_concentrations[i][idx_A], analytical_concentrations[i][idx_A], rel_tol=1e-8), f"Arrays differ at index ({i}, 0)"
        assert math.isclose(model_concentrations[i][idx_B], analytical_concentrations[i][idx_B], rel_tol=1e-8), f"Arrays differ at index ({i}, 1)"
        assert math.isclose(model_concentrations[i][idx_C], analytical_concentrations[i][idx_C], rel_tol=1e-8), f"Arrays differ at index ({i}, 2)"



if __name__ == "__main__":
    __main__()