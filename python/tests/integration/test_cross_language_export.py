"""
Solve a fixture in Python, export it, then solve the exported file in JS 
and check the results match.
down.
"""

import json
import math
import shutil
import subprocess
from pathlib import Path

import pytest

from acom_music_box import MusicBox

REPO_ROOT = Path(__file__).resolve().parents[3]
NODE_DRIVER = REPO_ROOT / "javascript" / "tests" / "integration" / "cross_language_solve.mjs"
NODE_BIN = shutil.which("node")

REL_TOL = 1e-10
ABS_TOL = 1e-12

FIXTURES = [
    (
        "every-option fixture",
        REPO_ROOT / "python/tests/integration/configs/js_python_parity/my_config.json",
    ),
    ("chapman example", REPO_ROOT / "examples/chapman/my_config.json"),
    ("ts1 example", REPO_ROOT / "examples/ts1/my_config.json"),
]


def _solve_with_node(config_path):
    result = subprocess.run(
        [NODE_BIN, str(NODE_DRIVER), str(config_path)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=300,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Node driver failed (exit {result.returncode}): {result.stderr}")
    return json.loads(result.stdout)


def _assert_results_close(df, js_result):
    js_columns = set(js_result["columns"])
    py_columns = set(df.columns)
    assert js_columns == py_columns, f"Column sets differ: python={py_columns} js={js_columns}"
    assert len(df) == js_result["height"]

    for column in df.columns:
        py_values = df[column].tolist()
        js_values = js_result["data"][column]
        assert len(py_values) == len(js_values), f"Column {column} length mismatch"
        for i, (py_val, js_val) in enumerate(zip(py_values, js_values)):
            assert math.isclose(py_val, js_val, rel_tol=REL_TOL, abs_tol=ABS_TOL), (
                f"Column {column} row {i}: python={py_val} js={js_val}"
            )


@pytest.mark.skipif(NODE_BIN is None, reason="node executable not found on PATH")
@pytest.mark.parametrize("name,config_path", FIXTURES, ids=[name for name, _ in FIXTURES])
def test_python_exported_config_solves_the_same_in_js(tmp_path, name, config_path):
    """A Python-exported config solves the same in Python and in JS."""
    box = MusicBox()
    box.loadJson(str(config_path))
    py_result = box.solve()

    export_path = tmp_path / "exported_config.json"
    box.export(str(export_path))

    js_result = _solve_with_node(export_path)
    _assert_results_close(py_result, js_result)
