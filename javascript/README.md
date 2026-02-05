# @ncar/music-box (JavaScript)

JavaScript implementation of the [music-box](https://github.com/NCAR/music-box) atmospheric chemistry box model, powered by the [MUSICA](https://github.com/NCAR/musica) WebAssembly chemistry solver.

## Features

- Accepts the same music-box v1 JSON config format as the Python implementation
- Supports inline conditions via `conditions.data` — no file I/O required, works in browser environments
- Powered by `@ncar/musica` WASM for cross-platform chemistry integration

## Repository Layout

Build files (`package.json`, `package-lock.json`, `webpack.config.js`) live at the repository root. Source and tests are under `javascript/`:

```
music-box/
├── package.json           # npm package metadata and scripts
├── package-lock.json
├── webpack.config.js      # browser bundle configuration
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
└── src/acom_music_box/    # Python implementation (unchanged)
```

## Installation

```bash
npm install @ncar/music-box
```

## Quick Start

### Node.js (from file)

```javascript
import { MusicBox } from '@ncar/music-box';

const box = await MusicBox.fromJsonFile('./configs/chapman.v1.config.json');
const results = await box.solve();
console.log(results);
```

### Node.js or Browser (from object)

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
      {
        headers: ['time.s', 'PHOTO.O2_1.s-1', 'PHOTO.O3_1.s-1'],
        rows: [
          [0,    1.47e-12, 4.25e-5],
          [3600, 1.12e-13, 1.33e-6],
        ],
      },
    ],
  },
  mechanism: { /* ... */ },
};

const box = MusicBox.fromJson(config);
const results = await box.solve();
```

## Config Format

The JavaScript implementation accepts the same music-box v1 JSON format as the Python implementation. For inline conditions, use `conditions.data` — an array of `{headers, rows}` blocks, one per logical data source (equivalent to one CSV file each):

```json
{
  "box model options": {
    "chemistry time step [min]": 1.0,
    "output time step [min]": 1.0,
    "simulation length [day]": 3.0
  },
  "conditions": {
    "data": [
      {
        "headers": ["time.s", "ENV.temperature.K", "ENV.pressure.Pa",
                    "CONC.O3.mol m-3", "CONC.O2.mol m-3"],
        "rows": [[0.0, 217.6, 1394.3, 6.43e-6, 0.162]]
      },
      {
        "headers": ["time.s", "PHOTO.O2_1.s-1", "PHOTO.O3_1.s-1"],
        "rows": [
          [0,    1.47e-12, 4.25e-5],
          [3600, 1.12e-13, 1.33e-6]
        ]
      }
    ]
  },
  "mechanism": { "..." : "..." }
}
```

This is the same format Python's `ConditionsManager` already accepts via `conditions.data`.

### Column Naming Convention

Same as CSV files:

| Column | Example | Description |
|--------|---------|-------------|
| `ENV.temperature.K` | `217.6` | Air temperature (K), step-interpolated |
| `ENV.pressure.Pa` | `1394.3` | Air pressure (Pa), step-interpolated |
| `CONC.<species>.mol m-3` | `6.43e-6` | Species concentration, applied at exact time |
| `PHOTO.<name>.s-1` | `1.47e-12` | Photolysis rate, step-interpolated |
| `EMIS.<name>.<unit>` | `0.001` | Emission rate, step-interpolated |
| `LOSS.<name>.<unit>` | `0.001` | Loss rate, step-interpolated |
| `USER.<name>.<unit>` | `1.0` | User-defined rate parameter, step-interpolated |

`CONC.*` columns are applied at their exact time only (concentration events); all other columns use step interpolation.

## API Reference

### `MusicBox`

```javascript
// Create from JSON object (Node.js and browser)
const box = MusicBox.fromJson(configObject);

// Create from file (Node.js only)
const box = await MusicBox.fromJsonFile('/path/to/config.json');

// Run simulation
const results = await box.solve();
// Returns: Array of { 'time.s': number, 'CONC.<species>.mol m-3': number, ... }
```

### Parser Functions

```javascript
import { parseBoxModelOptions, parseMechanism, parseConditions } from '@ncar/music-box';

// Parse time options — converts all units to seconds
const { chemTimeStep, outputTimeStep, simulationLength, maxIterations } =
  parseBoxModelOptions(config);

// Parse and normalize mechanism for MICM
// Converts Ea→C for Arrhenius reactions; normalizes phase species to objects
const mechanism = parseMechanism(config.mechanism); // exposes .getJSON()

// Parse conditions.data blocks into a flat array of row objects
const dataRows = parseConditions(config.conditions);
```

### `ConditionsManager`

```javascript
import { ConditionsManager, parseConditions } from '@ncar/music-box';

const mgr = new ConditionsManager(parseConditions(config.conditions));

// Step-interpolated temperature, pressure, and rate parameters at time t
const { temperature, pressure, rateParams } = mgr.getConditionsAtTime(t);

// Concentration events: { time: { species: value } }
const events = mgr.concentrationEvents;
```

## Development

All npm commands are run from the **repository root**:

```bash
# Install dependencies
npm install

# Run all tests
npm test

# Run unit tests only
npm run test:unit

# Run integration tests only
npm run test:integration

# Run tests with coverage
npm run test:coverage

# Build browser bundle (output: dist/music-box.bundle.js)
npm run build
```

## Mechanism Config Differences

The JavaScript implementation normalizes two differences between music-box v1 and the musica v1 format expected by the WASM solver:

1. **Phase species**: `["M", "O"]` → `[{"name": "M"}, {"name": "O"}]`
2. **Arrhenius `Ea` → `C`**: `C = -Ea / k_B` where k_B = 1.38064852×10⁻²³ J/K
   - Missing parameters default to: `B = 0`, `C = 0`, `D = 300`, `E = 0`
