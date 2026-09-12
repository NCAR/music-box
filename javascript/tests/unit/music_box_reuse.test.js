import assert from 'node:assert/strict';
import { describe, it, before } from 'node:test';
import { initModule } from '@ncar/musica';
import { MusicBox } from '../../src/music_box.js';

before(async () => {
  await initModule();
});

// A -> B, fixed rate. A is only ever consumed and B is only ever produced, so each of them
// staying at (or moving away from) its initial value cleanly indicates whether a solve() call
// actually applied the initial conditions it was given, independent of whatever happened on a
// prior solve() call against the same reused solver/state.
function buildConfig(initialA, initialB) {
  return {
    'box model options': {
      grid: 'box',
      'chemistry time step [sec]': 10,
      'output time step [sec]': 10,
      'simulation length [sec]': 60,
    },
    conditions: {
      data: [
        {
          headers: [
            'time.s',
            'ENV.temperature.K',
            'ENV.pressure.Pa',
            'CONC.A.mol m-3',
            'CONC.B.mol m-3',
          ],
          rows: [[0, 298.15, 101325.0, initialA, initialB]],
        },
      ],
    },
    mechanism: {
      version: '1.0.0',
      name: 'reuse-music-box-test',
      species: [{ name: 'A' }, { name: 'B' }],
      phases: [{ name: 'gas', species: ['A', 'B'] }],
      reactions: [
        {
          type: 'LAMBDA_RATE_CONSTANT',
          name: 'A_to_B',
          'gas phase': 'gas',
          'lambda function': '(T, P, airDensity) => 1.0e-3',
          reactants: [{ 'species name': 'A', coefficient: 1 }],
          products: [{ 'species name': 'B', coefficient: 1 }],
        },
      ],
    },
  };
}

describe('MusicBox reuseSolver', () => {
  it('defaults to false and behaves exactly as a one-shot solve (no dispose needed)', async () => {
    const box = MusicBox.fromJson(buildConfig(1.0, 0.0));
    const results = await box.solve();
    assert.ok(results.height > 0);
    box.dispose(); // should be a harmless no-op when reuseSolver is false
  });

  it('reflects a second run\'s initial conditions rather than leaking the first run\'s state', async () => {
    const box = MusicBox.fromJson(buildConfig(1.0, 0.0), { reuseSolver: true });

    const first = await box.solve();
    const firstA = first.data['CONC.A.mol m-3'];
    const firstB = first.data['CONC.B.mol m-3'];
    assert.ok(firstA[firstA.length - 1] < firstA[0], 'A should decrease over the first run');
    assert.ok(firstB[firstB.length - 1] > firstB[0], 'B should increase over the first run');

    // Flip the initial conditions for the second run: A starts at 0 (nothing produces it, so
    // it must stay at ~0 throughout) and B starts at 1 (nothing consumes it, so it must stay
    // at ~1 throughout). Any leftover concentration from the first run's reused state would
    // show up here as A being greater than ~0 or B being less than ~1.
    box.updateConfig(buildConfig(0.0, 1.0));
    const second = await box.solve();
    const secondA = second.data['CONC.A.mol m-3'];
    const secondB = second.data['CONC.B.mol m-3'];

    for (const value of secondA) {
      assert.ok(Math.abs(value) < 1e-9, `expected A to stay ~0, got ${value}`);
    }
    for (const value of secondB) {
      assert.ok(Math.abs(value - 1.0) < 1e-9, `expected B to stay ~1, got ${value}`);
    }

    box.dispose();
  });

  it('dispose() lets the instance rebuild a fresh solver on the next solve()', async () => {
    const box = MusicBox.fromJson(buildConfig(1.0, 0.0), { reuseSolver: true });
    await box.solve();
    box.dispose();

    // Should not throw, and should behave like a fresh solve (mechanism recompiled).
    const results = await box.solve();
    assert.ok(results.height > 0);
    box.dispose();
  });
});
