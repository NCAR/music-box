from acom_music_box import MusicBox

import os
import pytest
import tempfile
import sys
from acom_music_box.main import main as musicBoxMain
from acom_music_box.tools.waccmToMusicBox import main as waccmToMusicBoxMain
import pandas as pd
import math
import pathlib


@pytest.fixture
def temp_dir():
    with tempfile.TemporaryDirectory() as tmpdirname:
        yield tmpdirname


def get_repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))


# cmdName = "waccmToMusicBox" or "music_box"
# args = command-line parameters
# cmd = temporary directory for running this test
def run_command_with_args(cmdName, args, cwd):
    original_argv = sys.argv
    original_cwd = os.getcwd()
    sys.argv = [cmdName] + args
    try:
        os.chdir(cwd)
        if (cmdName == "waccmToMusicBox"):
            waccmToMusicBoxMain()
        if (cmdName == "music_box"):
            musicBoxMain()
    finally:
        os.chdir(original_cwd)
        sys.argv = original_argv


def test_waccm_evolving_conditions(temp_dir):
    print(f"temp_dir = {temp_dir}")

    # Step 1: Create a required CSV by converting WACCM data.
    repo_root = get_repo_root()
    sample_data_dir = os.path.join(repo_root, "sample_waccm_data")

    # set up the output files
    configPath = os.path.join(repo_root, "python", "tests", "integration",
        "configs", "waccm_evolving_conditions")
    csvOutPath = os.path.join(repo_root, "python", "tests", "integration",
        "configs", "waccm_evolving_conditions", "evolving_conditions.csv")

    # make sure to create entirely new test file
    pathlib.Path(csvOutPath).unlink(missing_ok=True)

    # Set up arguments for the WACCM conversion
    args = [
        "--waccmDir", f"{sample_data_dir}",
        "--date", "20260208,20260208",
        "--time", "00:00,23:00",
        "--latitude", "2.7,13.8",
        "--longitude", "101.7,123.8",
        "--altitude", "567.8,4567.8",
        "--template", configPath,
        "--output", csvOutPath,
        "--verbose"
    ]

    # Run the waccmToMusicBox script with the arguments
    run_command_with_args("waccmToMusicBox", args, temp_dir)
    assert os.path.exists(csvOutPath)

    # Step 2: Now run MusicBox with that CSV file containing WACCM data.
    # This portion of the test will fail if waccmToMusicBox did not run correctly.

    # capture the output file
    configPath = os.path.join(repo_root, "python", "tests", "integration",
        "configs", "waccm_evolving_conditions", "my_config.json")
    outputPath = os.path.join(temp_dir,
        "configs", "waccm_evolving_conditions", "evolving_output.csv")

    # make sure to create entirely new test file
    pathlib.Path(outputPath).unlink(missing_ok=True)

    # Set up arguments for the WACCM conversion
    args = [
        "--config", configPath,
        "--output", outputPath,
        "--verbose", "-v"
    ]

    # Run the waccmToMusicBox script with the arguments
    run_command_with_args("music_box", args, temp_dir)
    print(f"outputPath = {outputPath}")
    assert os.path.exists(outputPath)

