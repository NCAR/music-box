/**
 * A 10 second simulation with a 5 second chemistry time step and a 3 second
 * output time step -- the output step does not evenly divide the chemistry
 * step. Output must still land on every output-step multiple (0, 3, 6, 9)
 * plus the final simulation time (10).
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { MusicBox } from '../../src/music_box.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CONFIG_PATH = join(
  __dirname,
  '../../../python/tests/integration/configs/boundary_stepping/my_config.json'
);

describe('Boundary stepping', () => {
  it('outputs at every output-step multiple plus the final simulation time', async () => {
    const box = await MusicBox.fromJsonFile(CONFIG_PATH);
    const result = await box.solve();

    assert.deepEqual(result.data['time.s'], [0, 3, 6, 9, 10]);
  });
});
