import assert from 'node:assert/strict';
import { describe, it, before } from 'node:test';
import { initModule } from '@ncar/musica';
import { MusicBox } from '../../src/music_box.js';

before(async () => {
  await initModule();
});

describe('MusicBox lambda reactions', () => {
  it('registers lambda callbacks and solves from v1 JSON', async () => {
    const config = {
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
            rows: [[0, 298.15, 101325.0, 1.0, 0.0]],
          },
        ],
      },
      mechanism: {
        version: '1.0.0',
        name: 'lambda-music-box-test',
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

    const box = MusicBox.fromJson(config);
    const results = await box.solve();

    assert.ok(results.height > 0);
    assert.ok(results.columns.includes('CONC.A.mol m-3'));
    assert.ok(results.columns.includes('CONC.B.mol m-3'));

    const aValues = results.data['CONC.A.mol m-3'];
    const bValues = results.data['CONC.B.mol m-3'];
    assert.ok(aValues[aValues.length - 1] < aValues[0], 'A should decrease over time');
    assert.ok(bValues[bValues.length - 1] > bValues[0], 'B should increase over time');
  });
});
