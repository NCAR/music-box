/**
 * Integration tests for all v1-format example configs.
 *
 * For each config in src/acom_music_box/examples/configs/ that uses the v1 format
 * (box model options / conditions / mechanism), verify that:
 *   1. The config loads via MusicBox.fromJsonFile (resolving any CSV filepaths)
 *   2. solve() completes without errors
 *   3. The result is a non-empty array of rows with time.s and CONC.* keys
 *
 * The waccm configs use the old (non-v1) format and are excluded.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';
import { initModule } from '@ncar/musica';
import { MusicBox } from '../../src/music_box.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CONFIGS_DIR = join(__dirname, '../../../src/acom_music_box/examples/configs');

// v1-format configs only (waccm uses a different legacy format)
const EXAMPLE_CONFIGS = [
  'analytical/my_config.json',
  'chapman/my_config.json',
  'flow_tube/my_config.json',
  'carbon_bond_5/my_config.json',
  'ts1/my_config.json',
];

before(async () => {
  await initModule();
});

describe('Example config integration tests', () => {
  for (const configRelPath of EXAMPLE_CONFIGS) {
    const name = configRelPath.split('/')[0];
    const configPath = join(CONFIGS_DIR, configRelPath);

    it(`${name} - loads and solves without errors`, { timeout: 300_000 }, async () => {
      const box = await MusicBox.fromJsonFile(configPath);
      const results = await box.solve();

      assert.ok(Array.isArray(results), 'solve() should return an array');
      assert.ok(results.length > 0, 'solve() should return at least one output row');
      assert.ok('time.s' in results[0], 'output rows should have a time.s key');

      // Verify all CONC.* values are non-negative
      for (const row of results) {
        for (const [key, value] of Object.entries(row)) {
          if (key.startsWith('CONC.')) {
            assert.ok(
              value >= 0,
              `${key} should be non-negative at t=${row['time.s']}, got ${value}`
            );
          }
        }
      }
    });
  }
});
