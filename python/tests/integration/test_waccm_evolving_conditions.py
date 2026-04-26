from acom_music_box import MusicBox

import os
import pandas as pd
import math


class TestWaccmEvolvingConditions:
    def test_run(self):

        # Create a required CSV by converting WACCM data.
        repo_root = get_repo_root()
        sample_data_dir = os.path.join(repo_root, "sample_waccm_data")

        # set up the output files
        csvOutPath = os.path.join(repo_root, "python", "tests", "integration",
            "configs", "waccm_evolving_conditions", "evolving_conditions.csv")

        # Set up arguments for the WACCM conversion
        args = [
            "--waccmDir", f"{sample_data_dir}",
            "--date", "20260208,20260208",
            "--time", "00:00,23:00",
            "--latitude", "2.7,13.8",
            "--longitude", "101.7,123.8",
            "--altitude", "567.8,4567.8",
            "--output", csvOutPath,
            "--verbose"
        ]

        # Run the waccmToMusicBox script with the arguments
        run_waccm_to_music_box_with_args(args, temp_dir)

        # Now run MusicBox with that CSV file containing WACCM data.
        # This portion of the test will fail if waccmToMusicBox did not run correctly.
        music_box = MusicBox()

        current_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(current_dir, "configs", "waccm_evolving_conditions", "my_config.json")
        music_box.loadJson(config_path)

        results = music_box.solve()
        assert results is not None

        # Get values from DataFrame columns
        temperatures = results["ENV.temperature.K"]
        pressures = results["ENV.pressure.Pa"]
        assert len(temperatures) == len(pressures)

        for temp, press in zip(temperatures, pressures):
            assert temp is not None
            assert press is not None
            assert math.isclose(temp, 287.0, rel_tol=0.004)
            assert math.isclose(press, 78750.0, rel_tol=0.002)


if __name__ == "__main__":
    test = TestWaccmEvolvingConditions()
    test.test_run()
