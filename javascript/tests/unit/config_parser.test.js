import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { parseBoxModelOptions, parseConditions } from '../../src/config_parser.js';

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
