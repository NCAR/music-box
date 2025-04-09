import argparse
import colorlog
import datetime
import logging
import os
from acom_music_box import MusicBox, Examples, __version__, DataOutput, PlotOutput
from acom_music_box.utils import get_available_units


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
        action="append",
        help=("Path to save the output file, including the file name."
              + "\nIf not provided, result will be printed to the console."
              + "\nUse the file extension to specify the output format: .csv or .nc (NetCDF)")
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
        version=f'MusicBox {__version__}',
    )
    parser.add_argument(
        '--color-output',
        action='store_true',
        help='Enable color output for logs.'
    )
    parser.add_argument(
        '--plot',
        type=str,
        action='append',
        help='Plot a comma-separated list of species if gnuplot is available (e.g., CONC.A,CONC.B).'
    )
    parser.add_argument(
        '--plot-tool',
        type=str,
        choices=['gnuplot', 'matplotlib'],
        default='matplotlib',
        help='Choose plotting tool: gnuplot or matplotlib (default: matplotlib).'
    )
    parser.add_argument(
        '--plot-output-unit',
        type=str,
        choices=get_available_units(),
        default='mol m-3',
        help='Specify the output unit for plotting concentrations.'
    )
    return parser.parse_args()


def setup_logging(verbosity, color_output):
    log_level = logging.DEBUG if verbosity >= 2 else logging.INFO if verbosity == 1 else logging.CRITICAL
    datefmt = '%Y-%m-%d %H:%M:%S'
    format_string = '%(asctime)s - %(levelname)s - %(module)s.%(funcName)s - %(message)s'
    formatter = logging.Formatter(format_string, datefmt=datefmt)
    console_handler = logging.StreamHandler()

    if color_output:
        color_formatter = colorlog.ColoredFormatter(
            f'%(log_color)s{format_string}',
            datefmt=datefmt,
            log_colors={
                'DEBUG': 'green',
                'INFO': 'cyan',
                'WARNING': 'yellow',
                'ERROR': 'red',
                'CRITICAL': 'bold_red'})
        console_handler.setFormatter(color_formatter)
    else:
        console_handler.setFormatter(formatter)

    console_handler.setLevel(log_level)
    logging.basicConfig(level=log_level, handlers=[console_handler])


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

    if not musicBoxConfigFile:
        error = "Configuration file is required."
        logger.error(error)
        raise RuntimeError(error)

    # Create and load a MusicBox object
    myBox = MusicBox()
    logger.debug(f"Configuration file = {musicBoxConfigFile}")
    myBox.loadJson(musicBoxConfigFile)

    result = myBox.solve(callback=None)

    # Create an instance of DataOutput for multiple output formats.
    dataOutput = DataOutput(result, args)
    dataOutput.output()

    # Create an instance of PlotOutput
    plotOutput = PlotOutput(result, args)
    plotOutput.plot()

    end = datetime.datetime.now()
    logger.info(f"End time: {end}")
    logger.info(f"Elapsed time: {end - start} seconds")


if __name__ == "__main__":
    main()
