import subprocess
import os
import glob
import pytest
import tempfile
import sys
from acom_music_box.main import main

from acom_music_box import Examples


@pytest.fixture
def temp_dir():
  with tempfile.TemporaryDirectory() as tmpdirname:
    yield tmpdirname


def run_main_with_args(args, cwd):
  original_argv = sys.argv
  original_cwd = os.getcwd()
  sys.argv = ['music_box'] + args
  original_stdout = sys.stdout
  sys.stdout = tempfile.TemporaryFile(mode='w+')
  try:
    os.chdir(cwd)
    main()
    sys.stdout.seek(0)
    output = sys.stdout.read()
  finally:
    os.chdir(original_cwd)
    sys.stdout.close()
    sys.stdout = original_stdout
    sys.argv = original_argv
  return output


def test_print_results_to_terminal(temp_dir):
  output = run_main_with_args(['-e', 'Analytical'], temp_dir)
  assert len(output) > 0


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


def test_run_configuration_file(temp_dir):
  result = subprocess.run(['music_box', '-c', Examples.Analytical.path], capture_output=True, text=True, cwd=temp_dir)
  assert result.returncode == 0
