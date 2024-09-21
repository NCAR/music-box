from acom_music_box import MusicBox, Examples
import os


def callback(df, current_time, current_conditions, total_simulation_time):
    print(f"Current time: {current_time} s, total simulation time: {total_simulation_time} s, percentage complete: {current_time / total_simulation_time * 100:.2f}%")


class TestCallbackFunction:
    def test_run(self, mocker):
        box_model = MusicBox()

        conditions_path = Examples.Analytical.path

        box_model.loadJson(conditions_path)

        # Mock the callback function
        callback_mock = mocker.Mock(side_effect=callback)

        # Run the solver with the mocked callback
        box_model.solve(callback=callback_mock)

        # Assert that the callback was called at least once
        callback_mock.assert_called()


if __name__ == "__main__":
    test = TestCallbackFunction()
    test.test_run()
