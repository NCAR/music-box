
from box_model import BoxModel


def __main__():
    box_model = BoxModel()

    #configures box model
    conditions_path = "configs/test_config_1/my_config.json"
    camp_path = "configs/test_config_1/camp_data"
    
    box_model.readConditionsFromJson(conditions_path)
    box_model.create_solver(camp_path)

    #solves and outputs to file
    output_path = "test_config_1_out.csv"
    box_model.solve(path_to_output=output_path)

if __name__ == "__main__":
    __main__()