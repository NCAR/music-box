# MusicBox

[![License](https://img.shields.io/github/license/NCAR/music-box.svg)](https://github.com/NCAR/music-box/blob/main/LICENSE)
[![CI Tests](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml)
[![JavaScript Tests](https://github.com/NCAR/music-box/actions/workflows/javascript.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/javascript.yml)
[![codecov](https://codecov.io/github/NCAR/music-box/graph/badge.svg?token=OR7JEQJSRQ)](https://codecov.io/github/NCAR/music-box)
[![PyPI version](https://badge.fury.io/py/acom-music-box.svg)](https://pypi.org/project/acom-music-box)
[![npm version](https://img.shields.io/npm/v/%40ncar%2Fmusic-box)](https://www.npmjs.com/package/@ncar/music-box)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14008358.svg)](https://doi.org/10.5281/zenodo.14008358)
[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/NCAR/music-box/96b7c7b619791bfbddafc6c8e34fb7982f26c4ca?urlpath=lab%2Ftree%2Ftutorials)

Copyright (C) 2020 National Science Foundation - National Center for Atmospheric Research

MusicBox is a box model for atmospheric chemistry simulations, built on the [MUSICA](https://github.com/NCAR/musica) framework. It provides both a Python package for scientific computing workflows and a JavaScript package for browser and Node.js environments — both driven by the same underlying MUSICA chemistry solver.

# Installation

## Python

```bash
pip install acom_music_box
```

For GPU support:

```bash
pip install nvidia-pyindex
pip install acom_music_box[gpu]
```

For detailed Python usage, examples, and development information, see the [Python README](src/README.md).

## JavaScript

```bash
npm install @ncar/music-box
```

For detailed JavaScript usage, browser integration, and development information, see the [JavaScript README](javascript/README.md).

# Quick Start

## Python

```python
from acom_music_box import MusicBox, Conditions
import musica.mechanism_configuration as mc

A = mc.Species(name="A")
B = mc.Species(name="B")
gas = mc.Phase(name="gas", species=[A, B])

reaction = mc.Arrhenius(name="A->B", A=4.0e-3, C=50, reactants=[A], products=[B], gas_phase=gas)
mechanism = mc.Mechanism(name="simple", species=[A, B], phases=[gas], reactions=[reaction])

box = MusicBox()
box.load_mechanism(mechanism)
box.initial_conditions = Conditions(temperature=300.0, pressure=101000.0, species_concentrations={"A": 1.0, "B": 0.0})
box.box_model_options.simulation_length = 100
box.box_model_options.chem_step_time = 1
box.box_model_options.output_step_time = 10

df = box.solve()
print(df)
```

## JavaScript

```javascript
import { MusicBox } from '@ncar/music-box';

const config = {
  'box model options': {
    'chemistry time step [min]': 1.0,
    'output time step [min]': 10.0,
    'simulation length [min]': 60.0,
  },
  conditions: {
    data: [
      {
        headers: ['time.s', 'ENV.temperature.K', 'ENV.pressure.Pa', 'CONC.O3.mol m-3'],
        rows: [[0.0, 298.15, 101325.0, 1e-9]],
      },
    ],
  },
  mechanism: { /* ... */ },
};

const box = MusicBox.fromJson(config);
const results = await box.solve();
console.log(results);
```

# Documentation

- [Full Documentation](https://ncar.github.io/music-box/branch/main/index.html) — API reference, tutorials, and guides
- [Interactive Tutorials](https://mybinder.org/v2/gh/NCAR/music-box/96b7c7b619791bfbddafc6c8e34fb7982f26c4ca?urlpath=lab%2Ftree%2Ftutorials) — Run tutorials in your browser via Binder

# Contributing

We welcome contributions from the community. For local development, install as an editable package:

```bash
pip install -e '.[dev]'
```

Run the Python test suite:

```bash
pytest
```

Run the JavaScript test suite from the repository root:

```bash
npm install
npm test
```

# Citation

Please cite MusicBox using its DOI:

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14008358.svg)](https://doi.org/10.5281/zenodo.14008358)
