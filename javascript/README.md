# @ncar/music-box (JavaScript)

JavaScript implementation of the [music-box](https://github.com/NCAR/music-box) atmospheric chemistry box model, powered by the [MUSICA](https://github.com/NCAR/musica) WebAssembly chemistry solver.

## Features

- Accepts the same music-box v1 JSON config format as the Python implementation
- Supports inline conditions (no file I/O required) — works in browser environments
- Powered by `@ncar/musica` WASM for cross-platform chemistry integration

## Installation

```bash
npm install @ncar/music-box
```

Or with a local musica build:

```bash
npm install
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
    'initial conditions': {
      'ENV.temperature.K': 298.15,
      'ENV.pressure.Pa': 101325.0,
      'CONC.O3.mol m-3': 1e-9,
    },
    'evolving conditions': [
      { 'time.s': 0, 'PHOTO.O2_1.s-1': 1.47e-12, 'PHOTO.O3_1.s-1': 4.25e-5 },
      { 'time.s': 3600, 'PHOTO.O2_1.s-1': 1.12e-13, 'PHOTO.O3_1.s-1': 1.33e-6 },
    ],
  },
  mechanism: { /* ... */ },
};

const box = MusicBox.fromJson(config);
const results = await box.solve();
```

## Config Format

The JavaScript implementation accepts the same music-box v1 JSON format as the Python implementation, with an extended `conditions` block for inline data:

```json
{
  "box model options": {
    "chemistry time step [min]": 1.0,
    "output time step [min]": 1.0,
    "simulation length [day]": 3.0
  },
  "conditions": {
    "initial conditions": {
      "ENV.temperature.K": 298.15,
      "ENV.pressure.Pa": 101325.0,
      "CONC.O3.mol m-3": 1e-9
    },
    "evolving conditions": [
      { "time.s": 0, "PHOTO.O2_1.s-1": 1.47e-12, "PHOTO.O3_1.s-1": 4.25e-5 },
      { "time.s": 3600, "PHOTO.O2_1.s-1": 1.12e-13, "PHOTO.O3_1.s-1": 1.33e-6 }
    ]
  },
  "mechanism": { ... }
}
```

### Column Naming Convention

Same as CSV files:

| Prefix | Example | Description |
|--------|---------|-------------|
| `ENV.temperature.K` | `217.6` | Air temperature (K) |
| `ENV.pressure.Pa` | `1394.3` | Air pressure (Pa) |
| `CONC.<species>.mol m-3` | `6.43e-6` | Species concentration |
| `PHOTO.<name>.s-1` | `1.47e-12` | Photolysis rate |
| `EMIS.<name>.<unit>` | `0.001` | Emission rate |
| `LOSS.<name>.<unit>` | `0.001` | Loss rate |
| `USER.<name>.<unit>` | `1.0` | User-defined rate parameter |

## API Reference

### `MusicBox`

```javascript
// Create from JSON object
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

// Parse time options (converts to seconds)
const { chemTimeStep, outputTimeStep, simulationLength, maxIterations } = parseBoxModelOptions(config);

// Parse and normalize mechanism for MICM
const mechanism = parseMechanism(config.mechanism); // has .getJSON()

// Parse inline conditions
const { initialConditions, evolvingConditions } = parseConditions(config.conditions);
```

### `ConditionsManager`

```javascript
import { ConditionsManager, parseConditions } from '@ncar/music-box';

const mgr = new ConditionsManager(parseConditions(config.conditions));
const { temperature, pressure, concentrations, rateParams } = mgr.getConditionsAtTime(t);
```

## Development

```bash
# Install dependencies
npm install

# Run all tests
npm test

# Run unit tests only
npm run test:unit

# Run integration tests only
npm run test:integration

# Build browser bundle
npm run build
```

## Mechanism Config Differences

The JavaScript implementation normalizes two differences between music-box and musica v1 format:

1. **Phase species**: `["M", "O"]` → `[{"name": "M"}, {"name": "O"}]`
2. **Arrhenius `Ea` → `C`**: `C = -Ea / k_B` (where k_B = 1.38064852×10⁻²³ J/K)
