
from box_model import BoxModel

import math


def __main__():
    box_model = BoxModel()

    #configures box model
    conditions_path = "configs/test_config_2/my_config.json"
    camp_path = "configs/test_config_2/camp_data"
    
    box_model.readConditionsFromJson(conditions_path)
    box_model.create_solver(camp_path)

    # solves and saves output
    output = box_model.solve(path_to_output = "test_2_output.csv")

    #print(output)

   


if __name__ == "__main__":
    __main__()