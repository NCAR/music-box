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
    >>> args = Namespace(output='output.nc')
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
                Format of the output file, either 'csv' or 'netcdf'. Defaults to 'csv'.
        """
        self.df = df.copy(deep=True)
        self.args = args
        self.unit_mapping = {
            'ENV.temperature': 'K',
            'ENV.pressure': 'Pa',
            'ENV.number_density_air': 'mol m-3',
            'time': 's'
        }
        self.default_output_format = 'csv'

    def _get_default_filename(self):
        """Generate a default filename based on the current datetime and output format."""
        now = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        extension = 'csv' if self.default_output_format == 'csv' else 'nc'
        return f"music_box_{now}.{extension}"

    def _ensure_output_path(self, outPath):
        """Ensure the output path is valid and create directories if needed."""
        myFile = outPath
        if not myFile:
            myFile = self._get_default_filename()

        outDir, outFile = os.path.split(myFile)
        if not outFile:
            # no filename, just a directory like results/
            myFile = os.path.join(
                myFile, self._get_default_filename())

        dir_path = os.path.dirname(myFile)
        if dir_path and not os.path.exists(dir_path):
            os.makedirs(dir_path, exist_ok=True)
            logger.info(f"Created directory: {dir_path}")

        return (myFile)

    def _append_units_to_columns(self):
        """Append units to DataFrame column names based on unit mapping."""
        self.df.columns = [
            f"{col}.{self.unit_mapping[col]}" if col in self.unit_mapping else
            f"{col}.mol m-3" if col.startswith('CONC.') else col
            for col in self.df.columns
        ]

    def _convert_to_netcdf(self, toFile):
        """Convert DataFrame to xarray Dataset and save as NetCDF with attributes."""
        ds = self.df.set_index(['time.s']).to_xarray()
        for var in ds.data_vars:
            if var.startswith('CONC.'):
                ds[var].attrs = {'units': 'mol m-3'}
                new_var_name = '.'.join(var.split('.')[:2])
                ds = ds.rename({var: new_var_name})

        ds = ds.rename({'ENV.temperature.K': 'ENV.temperature'})
        ds = ds.rename({'ENV.pressure.Pa': 'ENV.pressure'})
        ds = ds.rename({'ENV.air number density.mol m-3': 'ENV.number_density_air'})
        ds = ds.rename({'time.s': 'time'})
        ds['ENV.temperature'].attrs = {'units': 'K'}
        ds['ENV.pressure'].attrs = {'units': 'Pa'}
        ds['ENV.number_density_air'].attrs = {'units': 'mol m-3'}
        ds['time'].attrs = {'units': 's'}

        ds.to_netcdf(toFile)

    def _output_csv(self, toFile):
        """Handles CSV output."""
        myFile = toFile
        if myFile:
            myFile = self._ensure_output_path(myFile)
            self.df.to_csv(myFile, index=False)
            logger.info(f"CSV output written to: {myFile}")
        else:
            print(self.df.to_csv(index=False))

    def _output_netcdf(self, toFile):
        """Handles NetCDF output."""
        myFile = toFile
        if myFile:
            myFile = self._ensure_output_path(myFile)
        self._convert_to_netcdf(myFile)
        logger.info(f"NetCDF output written to: {myFile}")

    def _output_terminal(self):
        """Handles output to terminal."""
        print(self.df.to_csv(index=False))

    def _get_output_format(self, out_filename):
        # Determine output type to call the respective method
        nameonly, extension = os.path.splitext(out_filename)
        if extension.lower() in {'.csv', '.txt'}:
            return ('csv')
        if extension.lower() in {'.nc', '.nc4'}:
            return ('netcdf')
        return (self.default_output_format)

    def output(self):
        """Main method to handle output based on the provided arguments."""
        # display solved results only on console if no --output specified
        if self.args.output is None:
            self._output_terminal()
            return

        # loop through all the mixed-format output files
        save_columns = self.df.columns.copy()   # for restoring after CSV output
        for myOutput in self.args.output:
            # Determine output type and call the respective method
            myFormat = self._get_output_format(myOutput)

            if myFormat == 'csv':
                self._append_units_to_columns()
                self._output_csv(myOutput)
                self.df.columns = save_columns.copy()

            if myFormat == 'netcdf':
                self._output_netcdf(myOutput)
