from acom_music_box.plot_output import PlotOutput
import unittest
import pandas as pd
import shutil
from argparse import Namespace
import matplotlib
import subprocess

matplotlib.use('Agg')  # Use a non-interactive backend


class TestPlotOutput(unittest.TestCase):

    def setUp(self):
        # Set up a sample DataFrame and arguments for testing
        self.df = pd.DataFrame({
            'time': [0, 1, 2],
            'CONC.A': [1, 2, 3],
            'CONC.B': [4, 5, 6],
            'CONC.C': [7, 8, 9]
        })

    def test_format_species_list(self):
        args = Namespace(plot=['A', 'B'], plot_tool='matplotlib')
        plot_output = PlotOutput(self.df, args)
        expected_list = [['CONC.A'], ['CONC.B']]
        self.assertEqual(plot_output.species_list, expected_list)

        args = Namespace(plot=['CONC.A', 'CONC.B'], plot_tool='matplotlib')
        plot_output = PlotOutput(self.df, args)
        self.assertEqual(plot_output.species_list, expected_list)

    def test_plot_with_gnuplot(self):
        args = Namespace(plot=['A', 'B'], plot_tool='gnuplot')
        plot_output = PlotOutput(self.df, args)
        if shutil.which('gnuplot') is None:
            with self.assertRaises(FileNotFoundError):
                plot_output.plot()
        else:
            plot_output.plot()

    def test_plot_with_matplotlib(self):
        args = Namespace(plot=['A', 'B'], plot_tool='matplotlib')
        plot_output = PlotOutput(self.df, args)
        plot_output.plot()

    def test_multiple_groups_with_gnuplot(self):
        args = Namespace(plot=['A,B', 'C'], plot_tool='gnuplot')
        plot_output = PlotOutput(self.df, args)
        if shutil.which('gnuplot') is None:
            with self.assertRaises(FileNotFoundError):
                plot_output.plot()
        else:
            plot_output.plot()

    def test_multiple_groups_with_matplotlib(self):
        args = Namespace(plot=['A,B', 'C'], plot_tool='matplotlib')
        plot_output = PlotOutput(self.df, args)
        plot_output.plot()


if __name__ == '__main__':
    unittest.main()
