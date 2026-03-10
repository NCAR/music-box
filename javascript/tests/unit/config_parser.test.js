import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { parseBoxModelOptions, parseMechanism, parseConditions } from '../../src/config_parser.js';
import { BOLTZMANN_CONSTANT } from '../../src/utils.js';

describe('parseBoxModelOptions', () => {
  it('converts minutes to seconds', () => {
    const config = {
      'box model options': {
        'chemistry time step [min]': 1.0,
        'output time step [min]': 10.0,
        'simulation length [min]': 60.0,
      },
    };
    const opts = parseBoxModelOptions(config);
    assert.equal(opts.chemTimeStep, 60.0);
    assert.equal(opts.outputTimeStep, 600.0);
    assert.equal(opts.simulationLength, 3600.0);
    assert.equal(opts.maxIterations, null);
  });

  it('converts days to seconds', () => {
    const config = {
      'box model options': {
        'chemistry time step [min]': 1.0,
        'output time step [min]': 1.0,
        'simulation length [day]': 3.0,
      },
    };
    const opts = parseBoxModelOptions(config);
    assert.equal(opts.simulationLength, 3 * 86400);
  });

  it('accepts seconds directly', () => {
    const config = {
      'box model options': {
        'chemistry time step [s]': 30.0,
        'output time step [s]': 300.0,
        'simulation length [s]': 3600.0,
      },
    };
    const opts = parseBoxModelOptions(config);
    assert.equal(opts.chemTimeStep, 30.0);
  });

  it('reads max iterations', () => {
    const config = {
      'box model options': {
        'chemistry time step [s]': 60.0,
        'output time step [s]': 60.0,
        'simulation length [s]': 3600.0,
        'max iterations': 100,
      },
    };
    const opts = parseBoxModelOptions(config);
    assert.equal(opts.maxIterations, 100);
  });

  it('throws when chemistry time step is missing', () => {
    const config = {
      'box model options': {
        'output time step [s]': 60.0,
        'simulation length [s]': 3600.0,
      },
    };
    assert.throws(() => parseBoxModelOptions(config), /chemistry time step/);
  });
});

describe('parseMechanism', () => {
  it('normalizes phase species strings to objects', () => {
    const mechanism = {
      name: 'test',
      version: '1.0.0',
      species: [],
      phases: [{ name: 'gas', species: ['M', 'O', 'O2'] }],
      reactions: [],
    };
    const result = parseMechanism(mechanism);
    const json = result.getJSON();
    assert.deepEqual(json.phases[0].species, [{ name: 'M' }, { name: 'O' }, { name: 'O2' }]);
  });

  it('leaves already-object phase species unchanged', () => {
    const mechanism = {
      name: 'test',
      version: '1.0.0',
      species: [],
      phases: [{ name: 'gas', species: [{ name: 'M' }, { name: 'O' }] }],
      reactions: [],
    };
    const result = parseMechanism(mechanism);
    const json = result.getJSON();
    assert.deepEqual(json.phases[0].species, [{ name: 'M' }, { name: 'O' }]);
  });

  it('converts Ea to C using Boltzmann constant for Chapman O1D+N2 reaction', () => {
    // From chapman.v1.config.json: Ea = -1.518e-21 J
    // Expected C = -Ea / k_B = 1.518e-21 / 1.38064852e-23 ≈ 109.95
    const mechanism = {
      name: 'test',
      version: '1.0.0',
      species: [],
      phases: [],
      reactions: [
        { type: 'ARRHENIUS', A: 1.29476e7, Ea: -1.518e-21, 'gas phase': 'gas', reactants: [], products: [] },
      ],
    };
    const result = parseMechanism(mechanism);
    const json = result.getJSON();
    const rxn = json.reactions[0];
    assert.ok(rxn.C !== undefined, 'C should be defined');
    assert.ok(rxn.Ea === undefined, 'Ea should be removed');
    assert.ok(Math.abs(rxn.C - 109.948) < 0.01, `C should be ~109.95, got ${rxn.C}`);
  });

  it('converts Ea to C for Chapman O1D+O2 reaction', () => {
    // Ea = -7.59e-22 J → C ≈ 54.97
    const mechanism = {
      name: 'test',
      version: '1.0.0',
      species: [],
      phases: [],
      reactions: [
        { type: 'ARRHENIUS', A: 1.9873e7, Ea: -7.59e-22, 'gas phase': 'gas', reactants: [], products: [] },
      ],
    };
    const result = parseMechanism(mechanism);
    const json = result.getJSON();
    const rxn = json.reactions[0];
    assert.ok(Math.abs(rxn.C - 54.974) < 0.01, `C should be ~54.97, got ${rxn.C}`);
  });

  it('converts Ea to C for Chapman O+O3 reaction (positive Ea → negative C)', () => {
    // Ea = 2.8428e-20 J → C ≈ -2059.03
    const mechanism = {
      name: 'test',
      version: '1.0.0',
      species: [],
      phases: [],
      reactions: [
        { type: 'ARRHENIUS', A: 4.818e6, Ea: 2.8428e-20, 'gas phase': 'gas', reactants: [], products: [] },
      ],
    };
    const result = parseMechanism(mechanism);
    const json = result.getJSON();
    const rxn = json.reactions[0];
    assert.ok(Math.abs(rxn.C - (-2059.03)) < 0.1, `C should be ~-2059.03, got ${rxn.C}`);
  });

  it('adds default Arrhenius parameters when missing', () => {
    const mechanism = {
      name: 'test',
      version: '1.0.0',
      species: [],
      phases: [],
      reactions: [
        { type: 'ARRHENIUS', A: 1.0, Ea: 0.0, 'gas phase': 'gas', reactants: [], products: [] },
      ],
    };
    const result = parseMechanism(mechanism);
    const json = result.getJSON();
    const rxn = json.reactions[0];
    assert.equal(rxn.B, 0.0);
    assert.equal(rxn.D, 300.0);
    assert.equal(rxn.E, 0.0);
  });

  it('preserves existing B parameter', () => {
    const mechanism = {
      name: 'test',
      version: '1.0.0',
      species: [],
      phases: [],
      reactions: [
        { type: 'ARRHENIUS', A: 217.6, B: -2.4, 'gas phase': 'gas', reactants: [], products: [] },
      ],
    };
    const result = parseMechanism(mechanism);
    const json = result.getJSON();
    const rxn = json.reactions[0];
    assert.equal(rxn.B, -2.4);
    assert.equal(rxn.C, 0.0);
  });

  it('does not mutate the input object', () => {
    const mechanism = {
      name: 'test',
      version: '1.0.0',
      species: [],
      phases: [{ name: 'gas', species: ['O', 'O2'] }],
      reactions: [{ type: 'ARRHENIUS', A: 1.0, Ea: -1e-21, reactants: [], products: [] }],
    };
    parseMechanism(mechanism);
    assert.equal(mechanism.phases[0].species[0], 'O', 'original should be unchanged');
    assert.ok(mechanism.reactions[0].Ea !== undefined, 'original Ea should remain');
  });

  it('passes through PHOTOLYSIS reactions unchanged', () => {
    const mechanism = {
      name: 'test',
      version: '1.0.0',
      species: [],
      phases: [],
      reactions: [
        {
          type: 'PHOTOLYSIS',
          name: 'O2_1',
          'gas phase': 'gas',
          reactants: [{ 'species name': 'O2' }],
          products: [{ 'species name': 'O', coefficient: 2.0 }],
        },
      ],
    };
    const result = parseMechanism(mechanism);
    const json = result.getJSON();
    const rxn = json.reactions[0];
    assert.equal(rxn.type, 'PHOTOLYSIS');
    assert.equal(rxn.name, 'O2_1');
  });

  it('throws on missing mechanism', () => {
    assert.throws(() => parseMechanism(null), /Missing mechanism/);
    assert.throws(() => parseMechanism(undefined), /Missing mechanism/);
  });

  it('returns object with getJSON method', () => {
    const result = parseMechanism({
      name: 'test',
      version: '1.0.0',
      species: [],
      phases: [],
      reactions: [],
    });
    assert.equal(typeof result.getJSON, 'function');
  });
});

describe('parseConditions', () => {
  it('returns empty array for null input', () => {
    assert.deepEqual(parseConditions(null), []);
    assert.deepEqual(parseConditions(undefined), []);
  });

  it('returns empty array when data key is absent', () => {
    assert.deepEqual(parseConditions({}), []);
  });

  it('converts a single {headers, rows} block to flat row objects', () => {
    const conditions = {
      data: [
        {
          headers: ['time.s', 'ENV.temperature.K', 'CONC.O3.mol m-3'],
          rows: [
            [0.0, 217.6, 6.43e-6],
            [3600.0, 220.0, 5.0e-6],
          ],
        },
      ],
    };
    const result = parseConditions(conditions);
    assert.equal(result.length, 2);
    assert.equal(result[0]['time.s'], 0.0);
    assert.equal(result[0]['ENV.temperature.K'], 217.6);
    assert.equal(result[0]['CONC.O3.mol m-3'], 6.43e-6);
    assert.equal(result[1]['time.s'], 3600.0);
    assert.equal(result[1]['ENV.temperature.K'], 220.0);
  });

  it('merges multiple blocks into a single flat array', () => {
    const conditions = {
      data: [
        {
          headers: ['time.s', 'ENV.temperature.K'],
          rows: [[0.0, 217.6]],
        },
        {
          headers: ['time.s', 'PHOTO.O2_1.s-1'],
          rows: [[0.0, 1.47e-12], [3600.0, 1.12e-13]],
        },
      ],
    };
    const result = parseConditions(conditions);
    assert.equal(result.length, 3);
    assert.equal(result[0]['ENV.temperature.K'], 217.6);
    assert.equal(result[1]['PHOTO.O2_1.s-1'], 1.47e-12);
    assert.equal(result[2]['PHOTO.O2_1.s-1'], 1.12e-13);
  });

  it('ignores filepaths key (Python-only feature)', () => {
    const conditions = { filepaths: ['foo.csv'] };
    assert.deepEqual(parseConditions(conditions), []);
  });
});
