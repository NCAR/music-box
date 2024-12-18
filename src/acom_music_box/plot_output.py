import logging
import matplotlib.pyplot as plt
import mplcursors
import subprocess
import os
import tempfile

logger = logging.getLogger(__name__)


class PlotOutput:
    """
    A class to handle plotting operations for a DataFrame, including plotting species
    concentrations over time using gnuplot or matplotlib.

    This class manages the plotting tool, species list, and data output formats based on
    the provided arguments, ensuring valid paths and creating necessary directories.

    Attributes
    ----------
    df : pandas.DataFrame
        The DataFrame to be plotted.
    args : argparse.Namespace
        Command-line arguments or configurations specifying plot options.
    species_list : list of lists
        A list of lists, where each sublist contains species to be plotted in a separate window.

    Examples
    --------
    >>> import pandas as pd
    >>> from argparse import Namespace
    >>> df = pd.DataFrame({
    ...     'time': [0, 1, 2],
    ...     'CONC.A.mol m-3': [1, 2, 3],
    ...     'CONC.B.mol m-3': [4, 5, 6],
    ...     'CONC.C.mol m-3': [7, 8, 9]
    ... })
    >>> args = Namespace(plot=['CONC.A,CONC.B'], plot_tool='matplotlib')
    >>> plot_output = PlotOutput(df, args)
    >>> plot_output.plot()
    """

    def __init__(self, df, args):
        """
        Initialize the PlotOutput class with a DataFrame and configuration arguments.

        Parameters
        ----------
        df : pandas.DataFrame
            The DataFrame containing the data to be output.
        args : argparse.Namespace
            Arguments specifying the plot configuration, such as plot tool and species list.
        """

        self.df = df.copy(deep=True)
        self.args = args
        self.species_list = [self._format_species_list(group.split(',')) for group in self.args.plot]

    def _format_species_list(self, species_list):
        """
        Format the species list for plotting.

        This method formats the species list for plotting by adding the 'CONC.' prefix
        to each species name if it is not already present.

        Parameters
        ----------
        species_list : list
            A list of species to plot.

        Returns
        -------
        list
            A formatted list of species for plotting.
        """

        plot_list = None
        if species_list is not None:
            plot_list = []
            for species in species_list:
                species = species.strip()
                if 'CONC.' not in species:
                    species = f'CONC.{species}'
                plot_list.append(species)

        return plot_list

    def _plot_with_gnuplot(self):
        """
        Plot the specified species using gnuplot.
        """
        # Prepare columns and data for plotting
        for species_group in self.species_list:
            columns = ['time'] + species_group
            data_to_plot = self.df[columns]

            data_csv = data_to_plot.to_csv(index=False)

            try:
                with tempfile.NamedTemporaryFile(suffix='.csv', mode='w+', delete=True) as data_file:
                    data_file.write(data_csv)
                    data_file.flush()
                    data_file_path = data_file.name

                    plot_commands = ',\n\t'.join(
                        f"'{data_file_path}' using 1:{i+2} with lines title '{species}'" for i,
                        species in enumerate(species_group))

                    gnuplot_command = f"""
                set datafile separator ",";
                set terminal dumb size 120,25;
                set xlabel 'Time';
                set ylabel 'Value';
                set title 'Time vs Species';
                plot {plot_commands}
                """

                    subprocess.run(['gnuplot', '-e', gnuplot_command], check=True)
            except FileNotFoundError as e:
                logging.critical("gnuplot is not installed. Skipping plotting.")
                raise e
            except subprocess.CalledProcessError as e:
                logging.error(f"Error occurred while plotting: {e}")
                raise e

    def _plot_with_matplotlib(self):
        """
        Plot the specified species using matplotlib.
        """
        for species_group in self.species_list:
            indexed = self.df.set_index('time')
            fig, ax = plt.subplots()
            indexed[species_group].plot(ax=ax)

            ax.set(xlabel='Time [s]', ylabel='Concentration [mol m-3]', title='Time vs Species')

            ax.spines[:].set_visible(False)
            ax.spines['left'].set_visible(True)
            ax.spines['bottom'].set_visible(True)

            ax.grid(alpha=0.5)
            ax.legend()

            # Enable interactive data cursors with hover functionality
            cursor = mplcursors.cursor(hover=True)

            # Customize the annotation format
            @cursor.connect("add")
            def on_add(sel):
                sel.annotation.set_text(f'Time: {sel.target[0]:.2f}\nConcentration: {sel.target[1]:1.2e}')

        plt.show()

    def plot(self):
        """
        Plot the specified species using the selected plotting tool.
        """

        if self.species_list is None:
            logger.debug("No species provided for plotting.")
            return

        if self.args.plot_tool == 'gnuplot':
            self._plot_with_gnuplot()
        else:
            self._plot_with_matplotlib()
