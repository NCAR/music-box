import os
import datetime
import logging

logger = logging.getLogger(__name__)


class DataOutput:
    """
    A class to handle data output operations for a DataFrame, including converting to CSV
    or NetCDF formats with appended units for columns. Designed for environmental data
    with specific units and formats.

    This class manages file paths, unit mappings, and data output formats based on
    the provided arguments, ensuring valid paths and creating necessary directories.

    Attributes
    ----------
    df : pandas.DataFrame
        The DataFrame to be output.
    args : argparse.Namespace
        Command-line arguments or configurations specifying output options.
    unit_mapping : dict
        A dictionary mapping specific columns to their respective units.

    Examples
    --------
    >>> import pandas as pd
    >>> from argparse import Namespace
    >>> df = pd.DataFrame({
    ...     'ENV.temperature': [290, 295, 300],
    ...     'ENV.pressure': [101325, 100000, 98500],
    ...     'ENV.number_density_air': [102, 5096, 850960],
    ...     'time': [0, 1, 2]
    ... })
    >>> args = Namespace(output='output.nc', output_format='netcdf')
    >>> data_output = DataOutput(df, args)
    >>> data_output.output()
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
        self.df = df.copy(deep=True)
        self.args = args
        self.unit_mapping = {
            'ENV.temperature': 'K',
            'ENV.pressure': 'Pa',
            'ENV.number_density_air': 'kg m-3',
            'time': 's'
        }

    def _get_default_filename(self):
        """Generate a default filename based on the current datetime and output format."""
        now = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        extension = 'csv' if self.args.output_format == 'csv' else 'nc'
        return f"music_box_{now}.{extension}"

    def _ensure_output_path(self):
        """Ensure the output path is valid and create directories if needed."""
        if not self.args.output:
            self.args.output = self._get_default_filename()

        if os.path.isdir(self.args.output):
            self.args.output = os.path.join(
                self.args.output, self._get_default_filename())

        dir_path = os.path.dirname(self.args.output)
        if dir_path and not os.path.exists(dir_path):
            os.makedirs(dir_path, exist_ok=True)
            logger.info(f"Created directory: {dir_path}")

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
        ds['ENV.number_density_air'].attrs = {'units': 'kg m-3'}
        ds['time'].attrs = {'units': 's'}

        ds.to_netcdf(self.args.output)

    def _output_csv(self):
        """Handles CSV output."""
        self._append_units_to_columns()
        if self.args.output:
            self._ensure_output_path()
            self.df.to_csv(self.args.output, index=False)
            logger.info(f"CSV output written to: {self.args.output}")
        else:
            print(self.df.to_csv(index=False))

    def _output_netcdf(self):
        """Handles NetCDF output."""
        if self.args.output:
            self._ensure_output_path()
        self._convert_to_netcdf()
        logger.info(f"NetCDF output written to: {self.args.output}")

    def _output_terminal(self):
        """Handles output to terminal."""
        self._append_units_to_columns()
        print(self.df.to_csv(index=False))

    def output(self):
        """Main method to handle output based on the provided arguments."""
        # Default output paths based on format
        if self.args.output is None:
            self.args.output = self._get_default_filename()

        # Determine output type and call the respective method
        if self.args.output_format is None or self.args.output_format == 'terminal':
            self._output_terminal()

        # Even if we are printing to the terminal, we still allow output to be written to csv if an output path is provided
        if (self.args.output_format == 'csv') or (self.args.output is not None and self.args.output_format == 'terminal'):
            self._output_csv()
        
        if self.args.output_format == 'netcdf':
            self._output_netcdf()