/**
 * CLI runner: solve a music-box config and print results as CSV to stdout.
 *
 * Usage (from project root):
 *   node javascript/bin/run.js <path-to-config.json>
 *
 * Output columns: time.s, CONC.<species>.mol m-3, ...
 */

import { MusicBox } from '../src/music_box.js';

const configPath = process.argv[2];
if (!configPath) {
  process.stderr.write('Usage: node javascript/bin/run.js <config.json>\n');
  process.exit(1);
}

const box = await MusicBox.fromJsonFile(configPath);
const results = await box.solve();

// Header row
process.stdout.write(results.columns.join(',') + '\n');

// Data rows
for (let i = 0; i < results.height; i++) {
  const row = results.columns.map(col => results.data[col][i]);
  process.stdout.write(row.join(',') + '\n');
}
