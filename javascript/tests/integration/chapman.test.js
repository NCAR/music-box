/**
 * Integration test for the Chapman mechanism using inline conditions.
 * Mirrors the Python test_chapman.py integration test.
 *
 * Uses the same mechanism from tests/integration/configs/chapman/chapman.v1.config.json
 * with conditions inlined from initial_concentrations.csv and conditions_Boulder.csv,
 * using the unified conditions.data format shared by both Python and JavaScript.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { initModule } from '@ncar/musica';
import { MusicBox } from '../../src/music_box.js';

// Full Chapman config with inline conditions using the {headers, rows} block format
// that Python's ConditionsManager already accepts via _load_inline_data.
const CHAPMAN_CONFIG = {
  'box model options': {
    'chemistry time step [min]': 1.0,
    'output time step [min]': 30.0,
    'simulation length [min]': 60.0,
  },
  // Inline conditions mirroring the two CSV files used by the Python integration test.
  // Block 1 → initial_concentrations.csv (one row at t=0 with T, P, and all species)
  // Block 2 → conditions_Boulder.csv (time-varying T, P, and photolysis rates)
  conditions: {
    data: [
      {
        headers: [
          'time.s',
          'ENV.temperature.K',
          'ENV.pressure.Pa',
          'CONC.O.mol m-3',
          'CONC.O1D.mol m-3',
          'CONC.O2.mol m-3',
          'CONC.O3.mol m-3',
          'CONC.N2.mol m-3',
        ],
        rows: [
          [0.0, 217.6, 1394.3, 3.58e-11, 1.83e-17, 0.162, 6.43e-6, 0.601],
        ],
      },
      {
        headers: [
          'time.s',
          'ENV.pressure.Pa',
          'ENV.temperature.K',
          'PHOTO.O2_1.s-1',
          'PHOTO.O3_1.s-1',
          'PHOTO.O3_2.s-1',
        ],
        rows: [
          [0,    1394.3, 217.6, 1.47e-12, 4.25e-5,  4.33514e-4],
          [3600, 1394.3, 217.6, 1.12e-13, 1.33e-6,  2.92129e-4],
        ],
      },
    ],
  },
  mechanism: {
    version: '1.0.0',
    name: 'Chapman',
    species: [
      { name: 'M', 'is third body': true },
      { name: 'O1D' },
      { name: 'O' },
      { name: 'O2' },
      { name: 'O3' },
      { name: 'N2' },
    ],
    phases: [
      {
        name: 'gas',
        species: ['M', 'O', 'O2', 'O3', 'O1D', 'N2'],
      },
    ],
    reactions: [
      {
        type: 'PHOTOLYSIS',
        'gas phase': 'gas',
        reactants: [{ 'species name': 'O2' }],
        products: [{ 'species name': 'O', coefficient: 2.0 }],
        name: 'O2_1',
      },
      {
        type: 'PHOTOLYSIS',
        'gas phase': 'gas',
        reactants: [{ 'species name': 'O3' }],
        products: [{ 'species name': 'O1D' }, { 'species name': 'O2' }],
        name: 'O3_1',
      },
      {
        type: 'PHOTOLYSIS',
        'gas phase': 'gas',
        reactants: [{ 'species name': 'O3' }],
        products: [{ 'species name': 'O' }, { 'species name': 'O2' }],
        name: 'O3_2',
      },
      {
        type: 'ARRHENIUS',
        'gas phase': 'gas',
        reactants: [{ 'species name': 'O1D' }, { 'species name': 'N2' }],
        products: [{ 'species name': 'O' }, { 'species name': 'N2' }],
        A: 1.29476026340e7,
        Ea: -1.518e-21,
      },
      {
        type: 'ARRHENIUS',
        'gas phase': 'gas',
        reactants: [{ 'species name': 'O1D' }, { 'species name': 'O2' }],
        products: [{ 'species name': 'O' }, { 'species name': 'O2' }],
        A: 1.98730645080e7,
        Ea: -7.59e-22,
      },
      {
        type: 'ARRHENIUS',
        'gas phase': 'gas',
        reactants: [{ 'species name': 'O' }, { 'species name': 'O3' }],
        products: [{ 'species name': 'O2', coefficient: 2.0 }],
        A: 4.81771260800e6,
        Ea: 2.8428e-20,
      },
      {
        type: 'ARRHENIUS',
        'gas phase': 'gas',
        reactants: [
          { 'species name': 'O' },
          { 'species name': 'O2' },
          { 'species name': 'M' },
        ],
        products: [{ 'species name': 'O3' }, { 'species name': 'M' }],
        A: 2.17597076000e2,
        B: -2.4,
      },
    ],
  },
};

before(async () => {
  await initModule();
});

describe('Chapman mechanism integration test', () => {
  it('solves from inline config and concentrations change', async () => {
    const box = MusicBox.fromJson(CHAPMAN_CONFIG);
    const results = await box.solve();

    assert.ok(results.length > 0, 'Should produce output rows');

    const initial = results[0];
    assert.ok('time.s' in initial, 'Output rows should have time.s');
    assert.ok('CONC.O3.mol m-3' in initial, 'Output rows should have O3 concentration');

    const final = results[results.length - 1];
    assert.ok(final['time.s'] > 0, 'Final time should be > 0');

    assert.notEqual(
      final['CONC.O3.mol m-3'],
      initial['CONC.O3.mol m-3'],
      'O3 concentration should change during simulation'
    );
  });

  it('produces multiple output rows at correct time intervals', async () => {
    const box = MusicBox.fromJson(CHAPMAN_CONFIG);
    const results = await box.solve();

    // 60-minute simulation with 30-minute output step → initial + 2 more
    assert.ok(results.length >= 2, `Expected at least 2 output rows, got ${results.length}`);

    for (let i = 1; i < results.length; i++) {
      assert.ok(
        results[i]['time.s'] >= results[i - 1]['time.s'],
        'Output times should be non-decreasing'
      );
    }
  });

  it('O3 concentration stays in physically reasonable range', async () => {
    const box = MusicBox.fromJson(CHAPMAN_CONFIG);
    const results = await box.solve();

    for (const row of results) {
      const o3 = row['CONC.O3.mol m-3'];
      assert.ok(o3 >= 0, `O3 should be non-negative, got ${o3}`);
      assert.ok(o3 < 1e-4, `O3 should be < 1e-4 mol/m3, got ${o3}`);
    }
  });

  it('all species concentrations are non-negative', async () => {
    const box = MusicBox.fromJson(CHAPMAN_CONFIG);
    const results = await box.solve();

    for (const row of results) {
      for (const [key, value] of Object.entries(row)) {
        if (key.startsWith('CONC.')) {
          assert.ok(value >= 0, `${key} should be non-negative at t=${row['time.s']}, got ${value}`);
        }
      }
    }
  });

  it('MusicBox.fromJson creates instance correctly', () => {
    const box = MusicBox.fromJson(CHAPMAN_CONFIG);
    assert.ok(box instanceof MusicBox);
  });
});
