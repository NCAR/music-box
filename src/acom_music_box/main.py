import os
import argparse
from acom_music_box import MusicBox, Examples, __version__ 
import datetime
import sys
import logging
import colorlog
import subprocess
import tempfile


def format_examples_help(examples):
    return '\n'.join(f"{e.short_name}: {e.description}" for e in examples)


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='MusicBox simulation runner.',
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        '-c', '--config',
        type=str,
        help='Path to the configuration file. If --example is provided, this argument is ignored.'
    )
    parser.add_argument(
        '-e', '--example',
        type=str,
        choices=[e.short_name for e in Examples],
        help=f'Name of the example to use. Overrides --config.\nAvailable examples:\n{format_examples_help(Examples)}'
    )
    parser.add_argument(
        '-o', '--output',
        type=str,
        help='Path to save the output file, including the file name. If not provided, result will be printed to the console.'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='count',
        default=0,
        help='Increase logging verbosity. Use -v for info, -vv for debug.'
    )
    parser.add_argument(
        '--version',
        action='version',
        version=__version__,
    )
    parser.add_argument(
        '--color-output',
        action='store_true',
        help='Enable color output for logs.'
    )
    parser.add_argument(
        '--plot',
        type=str,
        help='Plot a comma-separated list of species if gnuplot is available (e.g., CONC.A,CONC.B).'
    )
    return parser.parse_args()


def setup_logging(verbosity, color_output):
    if verbosity >= 2:
        log_level = logging.DEBUG
    elif verbosity == 1:
        log_level = logging.INFO
    else:
        log_level = logging.CRITICAL

    formatter = logging.Formatter(
        '%(asctime)s - %(levelname)s - %(module)s.%(funcName)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S')
    if color_output:
        color_formatter = colorlog.ColoredFormatter(
            '%(log_color)s%(asctime)s - %(levelname)s - %(module)s.%(funcName)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S',
            log_colors={
                'DEBUG': 'green',
                'INFO': 'cyan',
                'WARNING': 'yellow',
                'ERROR': 'red',
                'CRITICAL': 'bold_red'})
        console_handler = logging.StreamHandler()
        console_handler.setLevel(log_level)
        console_handler.setFormatter(color_formatter)
        logging.basicConfig(level=log_level, handlers=[console_handler])
    else:
        console_handler = logging.StreamHandler()
        console_handler.setLevel(log_level)
        console_handler.setFormatter(formatter)
        logging.basicConfig(level=log_level, handlers=[console_handler])


def plot_with_gnuplot(data, species_list):
    # Prepare columns and data for plotting
    columns = ['time'] + species_list
    data_to_plot = data[columns]

    data_csv = data_to_plot.to_csv(index=False)

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.csv') as data_file:
            data_file.write(data_csv.encode())
            data_file_path = data_file.name

        plot_commands = ',\n\t'.join(
            f"'{data_file_path}' using 1:{i+2} with lines title '{species}'" for i,
            species in enumerate(species_list))

        gnuplot_command = f"""
        set datafile separator ",";
        set terminal dumb size 120,25;
        set xlabel 'Time';
        set ylabel 'Value';
        set title 'Time vs Species';
        plot {plot_commands}
        """

        subprocess.run(['gnuplot', '-e', gnuplot_command], check=True)
    except FileNotFoundError:
        logging.critical("gnuplot is not installed. Skipping plotting.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error occurred while plotting: {e}")
    finally:
        # Clean up the temporary file
        if data_file_path:
            os.remove(data_file_path)


def main():
    start = datetime.datetime.now()

    args = parse_arguments()
    setup_logging(args.verbose, args.color_output)

    logger = logging.getLogger(__name__)

    logger.debug(f"{__file__}")
    logger.info(f"Start time: {start}")

    logger.debug(f"Working directory = {os.getcwd()}")

    if args.example:
        example = next(e for e in Examples if e.short_name == args.example)
        musicBoxConfigFile = example.path
        logger.info(f"Using example: {example}")
    else:
        musicBoxConfigFile = args.config

    musicBoxOutputPath = args.output
    plot_species_list = args.plot.split(',') if args.plot else None

    # Create and load a MusicBox object
    myBox = MusicBox()
    logger.debug(f"Configuration file = {musicBoxConfigFile}")
    myBox.readConditionsFromJson(musicBoxConfigFile)

    # Create solver and solve
    config_path = os.path.join(
        os.path.dirname(musicBoxConfigFile),
        myBox.config_file)
    myBox.create_solver(config_path)
    result = myBox.solve(musicBoxOutputPath)

    if musicBoxOutputPath is None:
        print(result.to_csv(index=False))

    if plot_species_list:
        # Prepare data for plotting
        plot_with_gnuplot(result, plot_species_list)

    end = datetime.datetime.now()
    logger.info(f"End time: {end}")
    logger.info(f"Elapsed time: {end - start} seconds")

    sys.exit(0)


if __name__ == "__main__":
    main()
