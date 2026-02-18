# acom_music_box (Python)

[![CI Tests](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml)
[![codecov](https://codecov.io/github/NCAR/music-box/graph/badge.svg?token=OR7JEQJSRQ)](https://codecov.io/github/NCAR/music-box)
[![PyPI version](https://badge.fury.io/py/acom-music-box.svg)](https://pypi.org/project/acom-music-box)
[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/NCAR/music-box/96b7c7b619791bfbddafc6c8e34fb7982f26c4ca?urlpath=lab%2Ftree%2Ftutorials)

Python implementation of the [MusicBox](https://github.com/NCAR/music-box) atmospheric chemistry box model, built on the [MUSICA](https://github.com/NCAR/musica) framework.

## Installation

```bash
pip install acom_music_box
```

### GPU Support

GPU-accelerated solving requires the NVIDIA PyPI index:

```bash
pip install --upgrade setuptools pip wheel
pip install nvidia-pyindex
pip install acom_music_box[gpu]
```

## Quick Start

### In-code mechanism

Define species, reactions, and initial conditions entirely in Python:

```python
from acom_music_box import MusicBox, Conditions
import musica.mechanism_configuration as mc

# Define species
A = mc.Species(name="A")
B = mc.Species(name="B")
C = mc.Species(name="C")

gas = mc.Phase(name="gas", species=[A, B, C])

# Define reactions
arr1 = mc.Arrhenius(name="A->B", A=4.0e-3, C=50, reactants=[A], products=[B], gas_phase=gas)
arr2 = mc.Arrhenius(name="B->C", A=1.2e-4, B=2.5, C=75, D=50, E=0.5, reactants=[B], products=[C], gas_phase=gas)

mechanism = mc.Mechanism(name="example", species=[A, B, C], phases=[gas], reactions=[arr1, arr2])

# Create and configure the box model
box = MusicBox()
box.load_mechanism(mechanism)

box.initial_conditions = Conditions(
    temperature=300.0,
    pressure=101000.0,
    species_concentrations={"A": 1.0, "B": 3.0, "C": 5.0},
)

# Optionally add evolving conditions at a specific time (seconds)
box.add_evolving_condition(300.0, Conditions(
    temperature=290.0,
    pressure=100200.0,
    species_concentrations={"A": 1.0, "B": 3.0, "C": 10.0},
))

box.box_model_options.simulation_length = 20   # seconds
box.box_model_options.chem_step_time = 1       # seconds
box.box_model_options.output_step_time = 4     # seconds

df = box.solve()
print(df)
```

### From a JSON configuration file

Load a music-box v1 JSON config from disk:

```python
from acom_music_box import MusicBox

box = MusicBox()
box.readConditionsFromJson("my_config.json")
df = box.solve()
print(df)
```

### Plotting results

```python
import matplotlib.pyplot as plt

df.plot(
    x='time.s',
    y=['CONC.A.mol m-3', 'CONC.B.mol m-3', 'CONC.C.mol m-3'],
    title='Concentration over time',
    ylabel='Concentration (mol m-3)',
    xlabel='Time (s)',
)
plt.show()
```

## Command Line Tool

MusicBox includes a `music_box` CLI for running configurations and built-in examples.

```bash
music_box -h
```

Run a built-in example (output printed to terminal as CSV):

```bash
music_box -e Chapman
```

Save output to a file:

```bash
music_box -e Chapman -o output.csv
music_box -e Chapman -o output.nc        # NetCDF format
music_box -e Analytical -o results.csv -o results.nc   # multiple outputs
```

Run your own configuration:

```bash
music_box -c my_config.json
```

### Plotting from the CLI

Plot species concentrations using matplotlib:

```bash
music_box -e Chapman -o output.csv --plot O1D
```

Plot multiple species groups:

```bash
music_box -e TS1 --plot O3 --plot PAN,HF
```

Change output units (default is `mol m-3`):

```bash
music_box -e TS1 --plot O3 --plot-output-unit ppb
```

## Tool: waccmToMusicBox

Extract chemical species concentrations from WACCM or WRF-Chem output and write them as MusicBox initial conditions:

```bash
waccmToMusicBox --waccmDir "./sample_waccm_data" --date "20240904" --time "07:00" --latitude 3.1 --longitude 101.7

waccmToMusicBox --wrfchemDir "./sample_waccm_data" --date "20250820" --time "08:00" --latitude 47.0,49.0 --longitude "'-123.0,-121.0'"
```

For advanced options including template configs and multiple output formats:

```bash
waccmToMusicBox --help
```

## Development

Install as an editable package with dev dependencies:

```bash
pip install -e '.[dev]'
```

Run the test suite:

```bash
pytest
```

Run only unit or integration tests:

```bash
pytest tests/unit/
pytest tests/integration/
```
