import os
import argparse
from acom_music_box import MusicBox
import datetime
import sys
import logging
import colorlog

def parse_arguments():
    parser = argparse.ArgumentParser(
        description='MusicBox simulation runner.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        '-c', '--config',
        type=str,
        required=True,
        help='Path to the configuration file.'
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
        '--color-output',
        action='store_true',
        help='Enable color output for logs.'
    )
    return parser.parse_args()

def setup_logging(verbosity, color_output):
    if verbosity >= 2:
        log_level = logging.DEBUG
    elif verbosity == 1:
        log_level = logging.INFO
    else:
        log_level = logging.CRITICAL

    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(module)s.%(funcName)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
    if color_output:
        color_formatter = colorlog.ColoredFormatter('%(log_color)s%(asctime)s - %(levelname)s - %(module)s.%(funcName)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S', log_colors={'DEBUG': 'green', 'INFO': 'cyan', 'WARNING': 'yellow', 'ERROR': 'red', 'CRITICAL': 'bold_red'})
        console_handler = logging.StreamHandler()
        console_handler.setLevel(log_level)
        console_handler.setFormatter(color_formatter)
        logging.basicConfig(level=log_level, handlers=[console_handler])
    else:
        console_handler = logging.StreamHandler()
        console_handler.setLevel(log_level)
        console_handler.setFormatter(formatter)
        logging.basicConfig(level=log_level, handlers=[console_handler])

def main():
    start = datetime.datetime.now()

    args = parse_arguments()
    setup_logging(args.verbose, args.color_output)

    logger = logging.getLogger(__name__)

    logger.debug(f"{__file__}")
    logger.info(f"Start time: {start}")

    logger.debug(f"Working directory = {os.getcwd()}")

    musicBoxConfigFile = args.config

    musicBoxOutputPath = args.output

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
        print(result)

    end = datetime.datetime.now()
    logger.info(f"End time: {end}")
    logger.info(f"Elapsed time: {end - start} seconds")

    sys.exit(0)

if __name__ == "__main__":
    main()
