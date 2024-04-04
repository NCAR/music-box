from box_model import BoxModel
import csv
import math

def __main__():
    box_model = BoxModel()

    #configures box model
    conditions_path = "configs/chapman_config/my_config.json"
    camp_path = "configs/chapman_config/camp_data"

    box_model.readConditionsFromJson(conditions_path)
    box_model.create_solver(camp_path)

    #solves and saves output
    model_output = box_model.solve()

    #read chapman_test.csv into test_output
    with open('chapman_test.csv', 'r') as file:
        reader = csv.reader(file)
        test_output = list(reader)


    concs_to_test = ['CONC.H2O', 'CONC.Ar', 'CONC.CO2', 'CONC.O1D', 'CONC.O2', 'CONC.O3', 'CONC.O']
    model_output_header = model_output[0]
    test_output_header = test_output[0]

    output_indices = [model_output_header.index(conc) for conc in concs_to_test]
    test_output_indices = [test_output_header.index(conc) for conc in concs_to_test]

    model_output_concs = [[row[i] for i in output_indices] for row in model_output[1:]]
    test_output_concs = [[row[i] for i in test_output_indices] for row in test_output[1:]]

    #asserts concentrations
    for i in range(len(model_output_concs)):
        for j in range(len(model_output_concs[i])):
            assert math.isclose(float(model_output_concs[i][j]), float(test_output_concs[i][j]), rel_tol=1e-8), f"Arrays differ at index ({i}, {j}) for "    
      

    


if __name__ == "__main__":
    __main__()