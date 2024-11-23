import os
import glob
import pytest
import tempfile
from acom_music_box.main import main
from unittest.mock import patch, MagicMock


@pytest.fixture
def temp_dir():
    with tempfile.TemporaryDirectory(delete=False) as tmpdirname:
        yield tmpdirname


def run_main_with_args(args, temp_dir):
    # Change the working directory temporarily
    with patch('sys.argv', ['music_box'] + args), patch('os.getcwd', return_value=temp_dir):
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)
            main()
        finally:
            os.chdir(original_cwd)


def test_print_results_to_terminal(temp_dir):
    run_main_with_args(['-e', 'Analytical'], temp_dir)
    # Add assertions to check the output


def test_create_netcdf_with_timestamp(temp_dir):
    run_main_with_args(['-e', 'Analytical', '--output-format', 'netcdf'], temp_dir)
    assert glob.glob(os.path.join(temp_dir, "music_box_*.nc"))


def test_create_csv_with_timestamp(temp_dir):
    run_main_with_args(['-e', 'Analytical', '--output-format', 'csv'], temp_dir)
    assert glob.glob(os.path.join(temp_dir, "music_box_*.csv"))


def test_create_named_csv(temp_dir):
    run_main_with_args(['-e', 'Analytical', '--output-format', 'csv', '-o', 'out.csv'], temp_dir)
    assert os.path.exists(os.path.join(temp_dir, "out.csv"))


def test_create_named_netcdf(temp_dir):
    run_main_with_args(['-e', 'Analytical', '--output-format', 'netcdf', '-o', 'out.nc'], temp_dir)
    assert os.path.exists(os.path.join(temp_dir, "out.nc"))


def test_create_directory_and_named_netcdf(temp_dir):
    os.makedirs(os.path.join(temp_dir, "results"), exist_ok=True)
    run_main_with_args(['-e', 'Analytical', '--output-format', 'netcdf', '-o', 'results/out.nc'], temp_dir)
    assert os.path.exists(os.path.join(temp_dir, "results/out.nc"))


def test_create_directory_and_named_csv(temp_dir):
    os.makedirs(os.path.join(temp_dir, "results"), exist_ok=True)
    run_main_with_args(['-e', 'Analytical', '--output-format', 'csv', '-o', 'results/out.csv'], temp_dir)
    assert os.path.exists(os.path.join(temp_dir, "results/out.csv"))


def test_create_directory_and_timestamped_csv(temp_dir):
    os.makedirs(os.path.join(temp_dir, "results"), exist_ok=True)
    run_main_with_args(['-e', 'Analytical', '--output-format', 'csv', '-o', 'results/'], temp_dir)
    assert glob.glob(os.path.join(temp_dir, "results/music_box_*.csv"))


def test_create_directory_and_timestamped_netcdf(temp_dir):
    os.makedirs(os.path.join(temp_dir, "results"), exist_ok=True)
    run_main_with_args(['-e', 'Analytical', '--output-format', 'netcdf', '-o', 'results/'], temp_dir)
    assert glob.glob(os.path.join(temp_dir, "results/music_box_*.nc"))
