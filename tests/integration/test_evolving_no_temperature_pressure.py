from acom_music_box import MusicBox

import os
import pandas as pd
import math

class TestEvolvingNoTemperaturePressureConfig:
  def test_run(self):
    music_box = MusicBox()

    current_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(current_dir, "configs", "evolving_no_temperature_pressure", "my_config.json")
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
        assert math.isclose(temp, 300.0, rel_tol=1e-9)
        assert math.isclose(press, 101300.0, rel_tol=1e-9)


if __name__ == "__main__":
  test = TestEvolvingNoTemperaturePressureConfig()
  test.test_run()