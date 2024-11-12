import subprocess
import os
import glob
import pytest
import tempfile


@pytest.fixture
def temp_dir():
    with tempfile.TemporaryDirectory() as tmpdirname:
        yield tmpdirname


def test_print_results_to_terminal(temp_dir):
    result = subprocess.run(['music_box', '-e', 'Analytical'], capture_output=True, text=True, cwd=temp_dir)
    assert len(result.stdout) > 0


def test_create_netcdf_with_timestamp(temp_dir):
    subprocess.run(['music_box', '-e', 'Analytical', '--output-format', 'netcdf'], cwd=temp_dir)
    assert glob.glob(os.path.join(temp_dir, "music_box_*.nc"))


def test_create_csv_with_timestamp(temp_dir):
    subprocess.run(['music_box', '-e', 'Analytical', '--output-format', 'csv'], cwd=temp_dir)
    assert glob.glob(os.path.join(temp_dir, "music_box_*.csv"))


def test_create_named_csv(temp_dir):
    subprocess.run(['music_box', '-e', 'Analytical', '--output-format', 'csv', '-o', 'out.csv'], cwd=temp_dir)
    assert os.path.exists(os.path.join(temp_dir, "out.csv"))


def test_create_named_netcdf(temp_dir):
    subprocess.run(['music_box', '-e', 'Analytical', '--output-format', 'netcdf', '-o', 'out.nc'], cwd=temp_dir)
    assert os.path.exists(os.path.join(temp_dir, "out.nc"))


def test_create_directory_and_named_netcdf(temp_dir):
    os.makedirs(os.path.join(temp_dir, "results"), exist_ok=True)
    subprocess.run(['music_box', '-e', 'Analytical', '--output-format', 'netcdf', '-o', 'results/out.nc'], cwd=temp_dir)
    assert os.path.exists(os.path.join(temp_dir, "results/out.nc"))


def test_create_directory_and_named_csv(temp_dir):
    os.makedirs(os.path.join(temp_dir, "results"), exist_ok=True)
    subprocess.run(['music_box', '-e', 'Analytical', '--output-format', 'csv', '-o', 'results/out.csv'], cwd=temp_dir)
    assert os.path.exists(os.path.join(temp_dir, "results/out.csv"))


def test_create_directory_and_timestamped_csv(temp_dir):
    os.makedirs(os.path.join(temp_dir, "results"), exist_ok=True)
    subprocess.run(['music_box', '-e', 'Analytical', '--output-format', 'csv', '-o', 'results/'], cwd=temp_dir)
    assert glob.glob(os.path.join(temp_dir, "results/music_box_*.csv"))


def test_create_directory_and_timestamped_netcdf(temp_dir):
    os.makedirs(os.path.join(temp_dir, "results"), exist_ok=True)
    subprocess.run(['music_box', '-e', 'Analytical', '--output-format', 'netcdf', '-o', 'results/'], cwd=temp_dir)
    assert glob.glob(os.path.join(temp_dir, "results/music_box_*.nc"))
