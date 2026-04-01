"""
Parity test: verify the Python and JavaScript implementations produce identical results.

Both use the same MICM solver compiled from identical source — Python via a native
shared library, JavaScript via WebAssembly. Differences should be limited to
floating-point ordering, so we use a tight tolerance (rel_tol=1e-10).

Usage:
    python tests/parity_test.py

Exit code:
    0 — all examples passed
    1 — one or more examples failed or errored
"""

import io
import math
import os
import subprocess
import sys

import pandas as pd

from acom_music_box import MusicBox, Examples

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))


def run_python(config_path):
    box = MusicBox()
    box.loadJson(config_path)
    return box.solve()


def run_javascript(config_path):
    result = subprocess.run(
        ['npm', '--silent', 'run', 'runner', config_path],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
        timeout=300,
    )
    if result.returncode != 0:
        raise RuntimeError(f'JS runner failed (exit {result.returncode}):\n{result.stderr}')
    return pd.read_csv(io.StringIO(result.stdout))


def check_parity(example):
    py_df = run_python(example.path)
    js_df = run_javascript(example.path)

    conc_columns = [col for col in py_df.columns if col.startswith('CONC.')]

    if not conc_columns:
        raise AssertionError('No CONC.* columns found in Python output')

    if len(py_df) != len(js_df):
        raise AssertionError(f'Row count mismatch: Python={len(py_df)}, JS={len(js_df)}')

    missing = [col for col in conc_columns if col not in js_df.columns]
    if missing:
        raise AssertionError(f'JS output missing columns: {missing}')

    for col in conc_columns:
        for i, (py_val, js_val) in enumerate(zip(py_df[col], js_df[col])):
            if not math.isclose(py_val, js_val, rel_tol=1e-10, abs_tol=1e-30):
                raise AssertionError(
                    f'row {i}, {col}: Python={py_val!r} JS={js_val!r}'
                )


def main():
    examples = Examples.get_all()
    failures = []
    for example in examples:
        try:
            check_parity(example)
            print(f'  PASS  {example.short_name}')
        except Exception as e:
            print(f'  FAIL  {example.short_name}: {e}')
            failures.append(example.short_name)

    print()
    if failures:
        print(f'FAILED: {len(failures)}/{len(examples)} examples did not match')
        sys.exit(1)
    else:
        print(f'All {len(examples)} examples match.')


if __name__ == '__main__':
    main()
