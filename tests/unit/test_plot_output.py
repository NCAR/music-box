from acom_music_box.plot_output import PlotOutput
import unittest
import pandas as pd
from argparse import Namespace
import matplotlib

matplotlib.use('Agg')  # Use a non-interactive backend


class TestPlotOutput(unittest.TestCase):

    def setUp(self):
        # Set up a sample DataFrame and arguments for testing
        self.df = pd.DataFrame({
            'time.s': [0, 1, 2],
            'CONC.A.mol m-3': [1, 2, 3],
            'CONC.B.mol m-3': [4, 5, 6],
            'CONC.C.mol m-3': [7, 8, 9],
            'ENV.temperature.K': [298.15, 298.15, 298.15],
            'ENV.pressure.Pa': [101325, 101325, 101325]
        })

    def test_format_species_list(self):
        args = Namespace(plot=['A', 'B'], plot_output_unit='mol m-3')
        plot_output = PlotOutput(self.df, args)
        expected_list = [['CONC.A.mol m-3'], ['CONC.B.mol m-3']]
        self.assertEqual(plot_output.species_list, expected_list)

        args = Namespace(plot=['CONC.A', 'CONC.B'], plot_output_unit='mol m-3')
        plot_output = PlotOutput(self.df, args)
        self.assertEqual(plot_output.species_list, expected_list)

    def test_plot_with_matplotlib(self):
        args = Namespace(plot=['A', 'B'], plot_output_unit='mol m-3')
        plot_output = PlotOutput(self.df, args)
        plot_output.plot()

    def test_multiple_groups_with_matplotlib(self):
        args = Namespace(plot=['A,B', 'C'], plot_output_unit='mol m-3')
        plot_output = PlotOutput(self.df, args)
        plot_output.plot()


if __name__ == '__main__':
    unittest.main()
