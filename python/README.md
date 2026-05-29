# acom_music_box (Python)

[![CI Tests](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml)
[![codecov](https://codecov.io/github/NCAR/music-box/graph/badge.svg?token=OR7JEQJSRQ)](https://codecov.io/github/NCAR/music-box)
[![PyPI version](https://badge.fury.io/py/acom-music-box.svg)](https://pypi.org/project/acom-music-box)
[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/NCAR/music-box/main?urlpath=lab%2Ftree%2Ftutorials)

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

## Tool: modelToMusicBox

This tool allows you to extract chemical species concentrations from WACCM or WRF-Chem model output and write them as MusicBox initial conditions.
Use the built-in help to display all options including template configurations and output files:

```bash
modelToMusicBox --help
```

You may specify a single point in space and date-time by passing single values to date, time, latitude, and longitude.
Altitude defaults to the surface.
You may also specify a rectangle or a cube by specifying pairs of values for latitude, longitude, and altitude.
Use a lat-lon variable (PBLH) to bound the vertical dimension at a specific height.
Run the following examples from the root level of your github repository, where you can see the sample_waccm_data/ sub-directory.

```bash
modelToMusicBox --waccmDir "./sample_waccm_data" --date "20260208" --time "06:00" --latitude 3.1 --longitude 101.7 --verbose
```

The command above should print two lines of Comma-Separated Values (CSV) to the console.
Since this command is run with --verbose, you will see diagnostic output as well.

```bash
modelToMusicBox --wrfchemDir "./sample_waccm_data/20250820/wrf" --date "20250820" --time "08:00" --latitude 47.0,49.0 --longitude "'-123.0,-121.0'"
```

modelToMusicBox uses a MUSICA configuration file to create a list of common chemical species between MusicBox and WACCM or WRF-Chem.
The default configuration file is in the ts1 example because that example has many species.
Use the --template parameter to specify your own configuration file (usually my_config.json).

```bash
modelToMusicBox --wrfchemDir ./sample_waccm_data/20250820/wrf --date 20250820 --time 8:00 --latitude 47.0,49.0 --longitude "'-123.0,-121.0'" --altitude surface,PBLH --template ./examples/ts1 --output conditions/initial_conditions-wrfchem.csv --verbose
```

If you request a pair of dates and a pair of times, modelToMusicBox will create evolving conditions over time rather than initial conditions.
You can expect to generate multiple rows of model output with time in the first column of the CSV file.
For multiple date-times there is no time interpolation between the two date-times that you specify for evolving conditions.
The script will simply extract variables at whatever model time steps are found between those two bounds.

```bash
modelToMusicBox --waccmDir ./sample_waccm_data --date 20260208,20260208 --time 00:00,23:00 --latitude "'-4.0,-2.0'" --longitude 101.0,103.0 --altitude 567.8,4567.8 --template ./examples/ts1 --output conditions/evolving_conditions-waccm.csv --verbose -v
```

When you specify waccmDir and wrfchemDir, modelToMusicBox will scan all the NetCDF files in that directory to determine the date-time steps that they contain.
Then when you specify a date-time for the extraction, modelToMusicBox will look for the time step within 5 minutes of the requested date-time.
If you specify a pair of date-times for evolving conditions, modelToMusicBox will use your date window and hour stride to locate the proper time steps.
You may specify several directories to scan; for example, WRF-Chem forecast output is often saved into daily directories:

```bash
modelToMusicBox --wrfchemDir ./sample_waccm_data/20250820/wrf --wrfchemDir ./sample_waccm_data/20250821/wrf --date 20250820,20250821 --time 08:00,08:00 --stride 24 --latitude 47.0,49.0 --longitude "'-123.0,-121.0'" --template ./examples/ts1 --output conditions/evolving_conditions-wrfchem.csv --verbose
```

modelToMusicBox will also follow links to NetCDF files, in case you need to avoid copying multi-GB files around.

### End-to-end example
In this section we will fully import initial conditions from WRF-Chem and evolving conditions from WACCM.
We will run MusicBox after each step to ensure that the model conditions are affecting the output.
Begin this exercise with an up-to-date github repository, and move to the root level (>).
We will copy sample configuration files into this root level; do not add them to the repository, but leave them Untracked in github.

```bash
cp examples/chapman/my_config.json .
cp examples/chapman/*.csv .
```

Produce MusicBox output from the standard example:

```bash
music_box --config my_config.json --output chapman-out-01.csv --verbose
```

Since the WRF-Chem Lambert Conformal grid takes longer to extract, let’s use that model for initial conditions and WACCM for evolving conditions.

```bash
modelToMusicBox --template . --wrfchemDir sample_waccm_data/20250820/wrf --date 20250820 --time 08:00 --latitude 40.0 --longitude -105.27 --output initial_concentrations.csv --verbose
```

Run MusicBox with these new intial conditions derived from WRF-Chem model output.

```bash
music_box --config my_config.json --output chapman-out-02.csv --verbose
```

Use your favorite comparison tool (ls -l, diff, vim, spreadsheet, etc.) to confirm that the MusicBox output has indeed changed between Chapman output files 01 and 02.
Then create evolving conditions (with multiple time steps) from WACCM:

```bash
modelToMusicBox --template . --waccmDir sample_waccm_data --date 20260208,20260208 --time 00:00,23:00 --stride 6 --latitude 40.0 --longitude -105.27 --output conditions_Boulder.csv --verbose
```

Run MusicBox with the new evolving conditions:

```bash
music_box --config my_config.json --output chapman-out-03.csv --verbose
```

Finally, confirm that Chapman output file 03 is different from the first two output files.

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
pytest python/tests/unit/
pytest python/tests/integration/
```
