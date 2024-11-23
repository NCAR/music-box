import os
import pytest
import tempfile
import sys
from acom_music_box.tools.waccmToMusicBox import main as waccmToMusicBoxMain
from acom_music_box import Examples

@pytest.fixture
def temp_dir():
    with tempfile.TemporaryDirectory(delete=False) as tmpdirname:
        yield tmpdirname

def get_repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))

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

def test_waccm_to_music_box_conversion(temp_dir):
    repo_root = get_repo_root()
    sample_data_dir = os.path.join(repo_root, "sample_waccm_data")
    
    # Set up arguments for the conversion
    args = [
        f"waccmDir={sample_data_dir}",
        "date=20240904",
        "time=07:00",
        "latitude=3.1",
        "longitude=101.7",
        "output=csv,json"
    ]
    
    # Run the waccmToMusicBox script with the arguments
    run_waccm_to_music_box_with_args(args, temp_dir)
    
    # Check if the output files are created
    assert os.path.exists(os.path.join(os.path.dirname(Examples.TS1.path), "initial_conditions.csv"))
    assert os.path.exists(os.path.join(os.path.dirname(Examples.TS1.path), "initial_config.json"))
    assert os.path.exists(os.path.join(temp_dir, "config.zip"))
