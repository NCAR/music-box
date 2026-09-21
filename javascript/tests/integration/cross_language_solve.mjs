#!/usr/bin/env node
/**
 * Loads a music-box v1 config, solves it, and prints the result as JSON to
 * stdout. Lets a Python test solve a config with the JS/WASM backend by
 * running this as a subprocess (see test_cross_language_export.py).
 *
 * Usage: node cross_language_solve.mjs <config_path>
 */

import { initModule } from '@ncar/musica';
import { MusicBox } from '../../src/music_box.js';

async function main() {
  const configPath = process.argv[2];
  if (!configPath) {
    console.error('Usage: node cross_language_solve.mjs <config_path>');
    process.exit(1);
  }

  await initModule();
  const box = await MusicBox.fromJsonFile(configPath);
  const result = await box.solve();
  process.stdout.write(JSON.stringify(result));
}

main().catch((err) => {
  console.error(err.stack || String(err));
  process.exit(1);
});
