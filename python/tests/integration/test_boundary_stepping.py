"""
A 10 second simulation with a 5 second chemistry time step and a 3 second
output time step -- the output step does not evenly divide the chemistry
step. Output must still land on every output-step multiple (0, 3, 6, 9)
plus the final simulation time (10).
"""

from pathlib import Path

from acom_music_box import MusicBox

CONFIG_PATH = Path(__file__).resolve().parent / "configs" / "boundary_stepping" / "my_config.json"


class TestBoundaryStepping:

    def test_output_times(self):
        box_model = MusicBox()
        box_model.loadJson(str(CONFIG_PATH))
        df = box_model.solve()

        assert df["time.s"].tolist() == [0.0, 3.0, 6.0, 9.0, 10.0]
