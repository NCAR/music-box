import os
import pandas as pd
import xarray as xr

class DataOutput:
    """
    A class to handle data output operations for a DataFrame, including converting to CSV
    or NetCDF formats with appended units for columns. Designed for environmental data
    with specific units and formats.

    This class manages file paths, unit mappings, and data output formats based on
    the provided arguments, ensuring valid paths and creating necessary directories.

    Parameters
    ----------
    df : pandas.DataFrame
        The DataFrame containing the data to output.
    args : argparse.Namespace
        Arguments specifying output path, format, and additional options.

    Attributes
    ----------
    df : pandas.DataFrame
        The DataFrame to be output.
    args : argparse.Namespace
        Command-line arguments or configurations specifying output options.
    unit_mapping : dict
        A dictionary mapping specific columns to their respective units.    
    """

    def __init__(self, df, args):
        """
        Initialize the DataOutput class with a DataFrame and configuration arguments.

        Parameters
        ----------
        df : pandas.DataFrame
            The DataFrame containing the data to be output.
        args : argparse.Namespace
            Arguments specifying the output configuration, such as file path and format.

        Notes
        -----
        The `args` argument should have the following attributes:
            - output : str
                The path to save the output file.
            - output_format : str, optional
                Format of the output file, either 'csv' or 'netcdf'. Defaults to 'csv'.
        """
        self.df = df
        self.args = args
        self.unit_mapping = {
            'ENV.temperature': 'K',
            'ENV.pressure': 'Pa',
            'ENV.number_density_air': 'kg -m3',
            'time': 's'
        }

    def _ensure_output_path(self):
        """Ensure the output path is valid and create directories if needed."""
        if os.path.dirname(self.args.output) == '':
            self.args.output = os.path.join(os.getcwd(), self.args.output)
        elif not os.path.basename(self.args.output):
            raise ValueError(f"Invalid output path: '{self.args.output}' does not contain a filename.")
        
        dir_path = os.path.dirname(self.args.output)
        if dir_path and not os.path.exists(dir_path):
            os.makedirs(dir_path, exist_ok=True)

    def _append_units_to_columns(self):
        """Append units to DataFrame column names based on unit mapping."""
        self.df.columns = [
            f"{col}.{self.unit_mapping[col]}" if col in self.unit_mapping else 
            f"{col}.mol m-3" if col.startswith('CONC.') else col
            for col in self.df.columns
        ]

    def _convert_to_netcdf(self):
        """Convert DataFrame to xarray Dataset and save as NetCDF with attributes."""
        ds = self.df.set_index(['time']).to_xarray()
        for var in ds.data_vars:
            if var.startswith('CONC.'):
                ds[var].attrs = {'units': 'mol m-3'}
        
        ds['ENV.temperature'].attrs = {'units': 'K'}
        ds['ENV.pressure'].attrs = {'units': 'Pa'}
        ds['ENV.number_density_air'].attrs = {'units': 'kg -m3'}
        ds['time'].attrs = {'units': 's'}

        ds.to_netcdf(self.args.output)

    def output(self):
        """Main method to handle output based on the provided arguments."""
        if self.args.output is None:
            # Output to terminal
            self._append_units_to_columns()
            print(self.df.to_csv(index=False))
        else:
            # Ensure the output path is valid
            self._ensure_output_path()
            
            if self.args.output_format is None or self.args.output_format == 'csv':
                # CSV output
                self._append_units_to_columns()
                self.df.to_csv(self.args.output, index=False)
            elif self.args.output_format == 'netcdf':
                # NetCDF output
                self._convert_to_netcdf()
