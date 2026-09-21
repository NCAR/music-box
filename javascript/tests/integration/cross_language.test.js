/**
 * Solve a fixture in JS, export it, then solve the * exported file in Python 
 * and check the results match.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initModule } from '@ncar/musica';
import { MusicBox } from '../../src/music_box.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '../../..');
const PYTHON_BIN = join(REPO_ROOT, '.venv/bin/python');
const PYTHON_DRIVER = join(REPO_ROOT, 'python/tests/integration/cross_language_solve.py');
const PYTHON_AVAILABLE = existsSync(PYTHON_BIN) && existsSync(PYTHON_DRIVER);

const REL_TOL = 1e-10;
const ABS_TOL = 1e-12;

function isClose(a, b) {
  return Math.abs(a - b) <= Math.max(REL_TOL * Math.max(Math.abs(a), Math.abs(b)), ABS_TOL);
}

function assertResultsClose(result1, result2) {
  assert.deepEqual([...result1.columns].sort(), [...result2.columns].sort());
  assert.equal(result1.height, result2.height);
  for (const col of result1.columns) {
    const a = result1.data[col];
    const b = result2.data[col];
    assert.equal(a.length, b.length, `column ${col} length mismatch`);
    for (let i = 0; i < a.length; i++) {
      assert.ok(
        isClose(a[i], b[i]),
        `column ${col} row ${i}: JS=${a[i]} Python=${b[i]} (rel_tol=${REL_TOL}, abs_tol=${ABS_TOL})`
      );
    }
  }
}

function solveWithPython(configPath) {
  const stdout = execFileSync(PYTHON_BIN, [PYTHON_DRIVER, configPath], {
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 64,
  });
  return JSON.parse(stdout);
}

before(async () => {
  await initModule();
});

const FIXTURES = [
  {
    name: 'every-option fixture',
    path: join(REPO_ROOT, 'python/tests/integration/configs/js_python_parity/my_config.json'),
  },
  { name: 'chapman example', path: join(REPO_ROOT, 'examples/chapman/my_config.json') },
  { name: 'ts1 example', path: join(REPO_ROOT, 'examples/ts1/my_config.json') },
];

describe('Cross-language parity: JS export -> Python reload', () => {
  for (const { name, path } of FIXTURES) {
    it(`${name}: JS-exported config solves the same in Python`, { timeout: 300_000 }, async (t) => {
      if (!PYTHON_AVAILABLE) {
        t.skip(`Python venv not available at ${PYTHON_BIN}; skipping cross-language test.`);
        return;
      }

      const box = await MusicBox.fromJsonFile(path);
      const jsResult = await box.solve();

      const dir = await mkdtemp(join(tmpdir(), 'music-box-cross-lang-'));
      try {
        const exportPath = join(dir, 'exported_config.json');
        await box.export(exportPath);

        const pyResult = solveWithPython(exportPath);
        assertResultsClose(jsResult, pyResult);
      } finally {
        await rm(dir, { recursive: true, force: true });
      }
    });
  }
});
