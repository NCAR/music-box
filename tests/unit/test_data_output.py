import unittest
import pandas as pd
import xarray as xr
import os
import tempfile
from argparse import Namespace
from acom_music_box import DataOutput


class TestDataOutput(unittest.TestCase):

    def setUp(self):
        # Set up a sample DataFrame and arguments for testing
        self.df = pd.DataFrame({
            'ENV.temperature.K': [290, 295, 300],
            'ENV.pressure.Pa': [101325, 100000, 98500],
            'ENV.air number density.mol m-3': [102, 5096, 850960],
            'time.s': [0, 1, 2]
        })
        self.temp_dir = tempfile.TemporaryDirectory()
        self.csv_path = os.path.join(self.temp_dir.name, 'output.csv')
        self.netcdf_path = os.path.join(self.temp_dir.name, 'output.nc')

    def tearDown(self):
        # Clean up temporary directory
        self.temp_dir.cleanup()

    def test_ensure_output_path_creates_directories(self):
        args = Namespace(output=[self.csv_path])
        data_output = DataOutput(self.df, args)
        sure_path = data_output._ensure_output_path(self.csv_path)
        self.assertTrue(os.path.exists(os.path.dirname(sure_path)))

    def test_append_units_to_columns(self):
        args = Namespace(output=None)
        data_output = DataOutput(self.df, args)
        data_output._append_units_to_columns()
        expected_columns = ['ENV.temperature.K', 'ENV.pressure.Pa', 'ENV.air number density.mol m-3', 'time.s']
        self.assertEqual(list(data_output.df.columns), expected_columns)

    def test_convert_to_netcdf(self):
        args = Namespace(output=[self.netcdf_path])
        data_output = DataOutput(self.df, args)
        data_output._convert_to_netcdf(self.netcdf_path)
        self.assertTrue(os.path.exists(self.netcdf_path))

        # Load the NetCDF file to check the attributes
        ds = xr.open_dataset(self.netcdf_path)
        self.assertEqual(ds['ENV.temperature'].attrs['units'], 'K')
        self.assertEqual(ds['ENV.pressure'].attrs['units'], 'Pa')
        self.assertEqual(ds['ENV.number_density_air'].attrs['units'], 'mol m-3')
        self.assertEqual(ds['time'].attrs['units'], 's')
        ds.close()

    def test_output_csv(self):
        args = Namespace(output=[self.csv_path])
        data_output = DataOutput(self.df, args)
        data_output._append_units_to_columns()
        data_output.output()
        self.assertTrue(os.path.exists(self.csv_path))

        # Check the contents of the CSV file
        output_df = pd.read_csv(self.csv_path)
        expected_columns = ['ENV.temperature.K', 'ENV.pressure.Pa', 'ENV.air number density.mol m-3', 'time.s']
        self.assertEqual(list(output_df.columns), expected_columns)

    def test_output_netcdf(self):
        args = Namespace(output=[self.netcdf_path])
        data_output = DataOutput(self.df, args)
        data_output.output()
        self.assertTrue(os.path.exists(self.netcdf_path))

        # Check the contents of the NetCDF file
        ds = xr.open_dataset(self.netcdf_path)
        self.assertEqual(ds['ENV.temperature'].attrs['units'], 'K')
        self.assertEqual(ds['ENV.pressure'].attrs['units'], 'Pa')
        self.assertEqual(ds['ENV.number_density_air'].attrs['units'], 'mol m-3')
        self.assertEqual(ds['time'].attrs['units'], 's')
        ds.close()


if __name__ == '__main__':
    unittest.main()
