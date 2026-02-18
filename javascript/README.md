# @ncar/music-box (JavaScript)

[![JavaScript Tests](https://github.com/NCAR/music-box/actions/workflows/javascript.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/javascript.yml)
[![npm version](https://img.shields.io/npm/v/%40ncar%2Fmusic-box)](https://www.npmjs.com/package/@ncar/music-box)

JavaScript implementation of the [MusicBox](https://github.com/NCAR/music-box) atmospheric chemistry box model, powered by the [MUSICA](https://github.com/NCAR/musica) WebAssembly chemistry solver.

Works in both Node.js and browser environments. Accepts the same music-box v1 JSON config format as the Python package — no file I/O required when conditions are supplied inline.

## Installation

```bash
npm install @ncar/music-box
```

## Quick Start

### Node.js — load from a file

```javascript
import { MusicBox } from '@ncar/music-box';

const box = await MusicBox.fromJsonFile('./configs/chapman.v1.config.json');
const results = await box.solve();
console.log(results);
// [{ 'time.s': 0, 'CONC.O3.mol m-3': 6.43e-6, ... }, ...]
```

### Node.js or Browser — inline config object

```javascript
import { MusicBox } from '@ncar/music-box';

const config = {
  'box model options': {
    'chemistry time step [min]': 1.0,
    'output time step [min]': 10.0,
    'simulation length [hr]': 1.0,
  },
  conditions: {
    data: [
      {
        headers: ['time.s', 'ENV.temperature.K', 'ENV.pressure.Pa',
                  'CONC.O3.mol m-3', 'CONC.O2.mol m-3'],
        rows: [[0.0, 217.6, 1394.3, 6.43e-6, 0.162]],
      },
      {
        headers: ['time.s', 'PHOTO.O2_1.s-1', 'PHOTO.O3_1.s-1'],
        rows: [
          [0,    1.47e-12, 4.25e-5],
          [3600, 1.12e-13, 1.33e-6],
        ],
      },
    ],
  },
  mechanism: {
    // see config format docs for full mechanism structure
  },
};

const box = MusicBox.fromJson(config);
const results = await box.solve();
```

## Conditions Format

The `conditions.data` key accepts an array of `{headers, rows}` blocks — one block per logical data source, equivalent to one CSV file. This is identical to the format the Python implementation accepts via `conditions.data`.

```json
{
  "conditions": {
    "data": [
      {
        "headers": ["time.s", "ENV.temperature.K", "ENV.pressure.Pa"],
        "rows": [[0.0, 217.6, 1394.3]]
      },
      {
        "headers": ["time.s", "PHOTO.O2_1.s-1", "PHOTO.O3_1.s-1"],
        "rows": [
          [0,    1.47e-12, 4.25e-5],
          [3600, 1.12e-13, 1.33e-6]
        ]
      }
    ]
  }
}
```

### Column Naming Convention

| Column | Example | Description |
|--------|---------|-------------|
| `ENV.temperature.K` | `217.6` | Air temperature in Kelvin. Step-interpolated. |
| `ENV.pressure.Pa` | `1394.3` | Air pressure in Pascals. Step-interpolated. |
| `CONC.<species>.mol m-3` | `6.43e-6` | Species concentration. Applied at exact time only. |
| `PHOTO.<name>.s-1` | `1.47e-12` | Photolysis rate. Step-interpolated. |
| `EMIS.<name>.<unit>` | `0.001` | Emission rate. Step-interpolated. |
| `LOSS.<name>.<unit>` | `0.001` | Loss rate. Step-interpolated. |
| `USER.<name>.<unit>` | `1.0` | User-defined rate parameter. Step-interpolated. |

`CONC.*` columns are treated as concentration events and applied only at their exact time. All other columns use step interpolation (hold the most recent value until the next time point).

## API Reference

### `MusicBox`

```javascript
import { MusicBox } from '@ncar/music-box';

// Create from a JSON object (Node.js and browser)
const box = MusicBox.fromJson(configObject);

// Create from a JSON file path (Node.js only)
const box = await MusicBox.fromJsonFile('/path/to/config.json');

// Run the simulation
const results = await box.solve();
// Returns: Array of output rows, e.g.:
// [{ 'time.s': 0, 'CONC.O3.mol m-3': 6.43e-6, ... }, ...]
```

### `parseBoxModelOptions`

Extracts timing parameters from `config['box model options']`, converting all time units (`[s]`, `[min]`, `[hr]`, `[day]`) to seconds.

```javascript
import { parseBoxModelOptions } from '@ncar/music-box';

const { chemTimeStep, outputTimeStep, simulationLength, maxIterations } =
  parseBoxModelOptions(config);
```

### `parseMechanism`

Normalizes a music-box v1 mechanism object for the MUSICA WASM solver. Returns an object with a `getJSON()` method compatible with `MICM.fromMechanism()`.

Normalizations applied:
- Phase species strings → objects: `["M", "O"]` → `[{"name": "M"}, {"name": "O"}]`
- Arrhenius `Ea` (J) → `C` (K): `C = -Ea / k_B` where k_B = 1.38064852×10⁻²³ J/K
- Missing Arrhenius parameters default to `B = 0`, `C = 0`, `D = 300`, `E = 0`

```javascript
import { parseMechanism } from '@ncar/music-box';

const mechanism = parseMechanism(config.mechanism);
// mechanism.getJSON() returns musica v1-compatible JSON
```

### `parseConditions`

Converts `conditions.data` blocks into a flat array of row objects for use by `ConditionsManager`.

```javascript
import { parseConditions } from '@ncar/music-box';

const dataRows = parseConditions(config.conditions);
// [{ 'time.s': 0, 'ENV.temperature.K': 217.6, ... }, ...]
```

### `ConditionsManager`

Manages step interpolation of environmental conditions and collection of concentration events.

```javascript
import { ConditionsManager, parseConditions } from '@ncar/music-box';

const mgr = new ConditionsManager(parseConditions(config.conditions));

// Step-interpolated temperature, pressure, and rate parameters at time t (seconds)
const { temperature, pressure, rateParams } = mgr.getConditionsAtTime(t);

// Concentration events: { time: { speciesName: value } }
const events = mgr.concentrationEvents;
```

## Development

All npm commands are run from the **repository root** (where `package.json` lives):

```bash
npm install              # install dependencies
npm test                 # run all tests (unit + integration)
npm run test:unit        # unit tests only
npm run test:integration # integration tests only
npm run test:coverage    # tests with coverage report
npm run build            # build browser bundle → dist/music-box.bundle.js
```

### Repository Layout

```
music-box/
├── package.json           ← npm metadata and scripts
├── package-lock.json
├── webpack.config.js      ← browser bundle config
├── javascript/
│   ├── src/
│   │   ├── index.js
│   │   ├── music_box.js
│   │   ├── config_parser.js
│   │   ├── conditions_manager.js
│   │   └── utils.js
│   └── tests/
│       ├── unit/
│       └── integration/
└── src/acom_music_box/    ← Python implementation
```
