/**
 * Integration tests for all v1-format example configs.
 *
 * For each config in examples/ that uses the v1 format
 * (box model options / conditions / mechanism), verify that:
 *   1. The config loads via MusicBox.fromJsonFile (resolving any CSV filepaths)
 *   2. solve() completes without errors
 *   3. The result has a non-empty time.s column and CONC.* columns with non-negative values
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
const CONFIGS_DIR = join(__dirname, '../../../examples');

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
      console.log(results)

      assert.ok(results.height > 0, 'solve() should return at least one output row');
      assert.ok(results.columns.includes('time.s'), 'output should have a time.s column');

      // Verify all CONC.* columns are non-negative
      for (const col of results.columns) {
        if (col.startsWith('CONC.')) {
          for (const value of results.data[col]) {
            assert.ok(value >= 0, `${col} should be non-negative, got ${value}`);
          }
        }
      }
    });
  }
});
