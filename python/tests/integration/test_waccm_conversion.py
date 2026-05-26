import os
import pytest
import tempfile
import sys
from acom_music_box.tools.waccmToMusicBox import main as waccmToMusicBoxMain
from acom_music_box import Examples


@pytest.fixture
def temp_dir():
    with tempfile.TemporaryDirectory() as tmpdirname:
        yield tmpdirname


def get_repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))


def run_waccm_to_music_box_with_args(args, cwd):
    original_argv = sys.argv
    original_cwd = os.getcwd()
    sys.argv = ['waccmToMusicBox'] + args
    try:
        os.chdir(cwd)
        waccmToMusicBoxMain()
    finally:
        os.chdir(original_cwd)
        sys.argv = original_argv


# Windows does not accept filenames with colon : characters.
# The ACOM WRF-Chem forecast system creates those named
# files on Linux: wrfout_hourly_d01_2025-08-20_08:00:00
# To handle those filenames in Windows, we create a link
# to the hyphenated filename by replacing colons with hyphens.
# myDir = directory containing the problematic files
# colonLink = desired filename including colons
def create_colon_link(myDir, colonLink):
    colon_path = os.path.join(myDir, colonLink)
    hyphen_path = colonLink.replace(":", "-")

    try:
        os.symlink(hyphen_path, colon_path)
    except FileExistsError:
        # Remove broken symlink (e.g. absolute path copied from another machine) and recreate
        if os.path.islink(colon_path) and not os.path.exists(colon_path):
            os.remove(colon_path)
            os.symlink(hyphen_path, colon_path)
    except OSError:
        # the colon link is not allowed under Windows
        pass

    return


def test_waccm_to_music_box_conversion(temp_dir):
    repo_root = get_repo_root()
    sample_data_dir = os.path.join(repo_root, "sample_waccm_data")

    # set up the output files
    csvOutPath = os.path.join("waccmExtract", "initial_conditions-waccm.csv")
    jsonOutPath = os.path.join("waccmExtract", "initial_conditions-waccm.json")

    # Set up arguments for the WACCM conversion
    args = [
        "--waccmDir", f"{sample_data_dir}",
        "--date", "20260208",
        "--time", "12:00",
        "--latitude", "3.1",
        "--longitude", "101.7",
        "--output", csvOutPath,
        "-o", jsonOutPath,
        "--verbose"
    ]

    # Run the waccmToMusicBox script with the arguments
    run_waccm_to_music_box_with_args(args, temp_dir)

    # Check if the output files are created
    assert os.path.exists(os.path.join(temp_dir, csvOutPath))
    assert os.path.exists(os.path.join(temp_dir, jsonOutPath))

    # set up the output files
    csvOutPath = os.path.join("wrfchemExtract", "initial_conditions-wrfchem.csv")
    jsonOutPath = os.path.join("wrfchemExtract", "initial_conditions-wrfchem.json")

    # Set up arguments for the WRF-Chem conversion
    wrf_chem_dir = os.path.join(sample_data_dir, "20250820", "wrf")
    args = [
        "--wrfchemDir", f"{wrf_chem_dir}",
        "--date", "20250820",
        "--time", "08:00",
        "--latitude", "47.0,49.0",
        "--longitude", "'-123.0,-121.0'",
        "--output", csvOutPath,
        "-o", jsonOutPath
    ]

    # Create symbolic links from Linux colon filenames pointing to Window-safe hyphen files.
    create_colon_link(os.path.join(sample_data_dir, "20250820", "wrf"), "wrfout_hourly_d01_2025-08-20_08:00:00")
    create_colon_link(os.path.join(sample_data_dir, "20250821", "wrf"), "wrfout_hourly_d01_2025-08-21_08:00:00")

    # Run the waccmToMusicBox script with the arguments
    run_waccm_to_music_box_with_args(args, temp_dir)

    # Check if the output files are created
    assert os.path.exists(os.path.join(temp_dir, csvOutPath))
    assert os.path.exists(os.path.join(temp_dir, jsonOutPath))
