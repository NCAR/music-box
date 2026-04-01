"""
Parity tests between the Python and JavaScript implementations of music-box.

Both use the same MICM solver compiled from identical source — Python via a
native shared library, JavaScript via WebAssembly. Differences should be
limited to floating-point ordering, so we use the same tight tolerance as the
existing Chapman integration tests.

For each v1-format example config:
  1. Run the Python solver and collect CONC.* columns.
  2. Run the JS solver via `node javascript/bin/run.js <config>` and parse its CSV output.
  3. Assert that every CONC.* value matches within rel_tol=1e-10, abs_tol=1e-30.
"""

import io
import math
import os
import subprocess

import pandas as pd
import pytest

from acom_music_box import MusicBox

# Absolute path to the project root (two levels up from this file)
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

JS_RUNNER = os.path.join(PROJECT_ROOT, 'javascript', 'bin', 'run.js')

# v1-format example configs — same set covered by the JS integration tests
EXAMPLE_CONFIGS = [
    'analytical/my_config.json',
    'chapman/my_config.json',
    'flow_tube/my_config.json',
    'carbon_bond_5/my_config.json',
    'ts1/my_config.json',
]


def run_python(config_path):
    """Return the solve() DataFrame for the given config."""
    box = MusicBox()
    box.loadJson(config_path)
    return box.solve()


def run_javascript(config_path):
    """Run the JS solver and return its output as a DataFrame."""
    result = subprocess.run(
        ['node', JS_RUNNER, config_path],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
        timeout=300,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f'JS runner failed (exit {result.returncode}):\n{result.stderr}'
        )
    return pd.read_csv(io.StringIO(result.stdout))


@pytest.mark.parametrize('config_rel_path', EXAMPLE_CONFIGS, ids=lambda p: p.split('/')[0])
def test_parity(config_rel_path):
    config_path = os.path.join(PROJECT_ROOT, 'examples', config_rel_path)

    py_df = run_python(config_path)
    js_df = run_javascript(config_path)

    conc_columns = [col for col in py_df.columns if col.startswith('CONC.')]

    assert len(conc_columns) > 0, 'No CONC.* columns found in Python output'
    assert len(py_df) == len(js_df), (
        f'Row count mismatch: Python={len(py_df)}, JS={len(js_df)}'
    )

    missing = [col for col in conc_columns if col not in js_df.columns]
    assert not missing, f'JS output missing columns: {missing}'

    for col in conc_columns:
        for i, (py_val, js_val) in enumerate(zip(py_df[col], js_df[col])):
            assert math.isclose(py_val, js_val, rel_tol=1e-10, abs_tol=1e-30), (
                f'{config_rel_path}: row {i}, {col}: '
                f'Python={py_val!r} JS={js_val!r}'
            )
