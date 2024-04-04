from box_model import BoxModel

def __main__():
    box_model = BoxModel()

    #configures box model
    conditions_path = "configs/wall_loss_config/my_config.json"
    camp_path = "configs/wall_loss_config/camp_data"

    box_model.readConditionsFromJson(conditions_path)
    box_model.create_solver(camp_path)

    #solves and saves output
    output = box_model.solve(path_to_output="output.csv")

if __name__ == "__main__":
    __main__()