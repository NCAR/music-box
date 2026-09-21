/**
 * Unit tests for MusicBox.toJson() / MusicBox.export().
 *
 * The "every option" fixture covers all five box model options and one of
 * every reaction type, with two time points covering every condition type.
 * It's the same file the Python round-trip and cross-language tests use.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initModule } from '@ncar/musica';
import { MusicBox } from '../../src/music_box.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const EVERY_OPTION_FIXTURE_PATH = join(
  __dirname,
  '../../../python/tests/integration/configs/js_python_parity/my_config.json'
);

const EXPECTED_REACTION_TYPES = [
  'ARRHENIUS',
  'BRANCHED_NO_RO2',
  'EMISSION',
  'FIRST_ORDER_LOSS',
  'PHOTOLYSIS',
  'SURFACE',
  'TERNARY_CHEMICAL_ACTIVATION',
  'TROE',
  'TUNNELING',
  'USER_DEFINED',
].sort();

/** Fresh parse each call so tests never share (and cannot accidentally mutate) state. */
function loadEveryOptionConfig() {
  return JSON.parse(readFileSync(EVERY_OPTION_FIXTURE_PATH, 'utf8'));
}

/** Same fixture, plus a JS-only LAMBDA_RATE_CONSTANT reaction (K -> L). */
function loadEveryOptionConfigWithLambda() {
  const config = loadEveryOptionConfig();
  config.mechanism.species.push({ name: 'K' }, { name: 'L' });
  config.mechanism.phases[0].species.push({ name: 'K' }, { name: 'L' });
  config.mechanism.reactions.push({
    type: 'LAMBDA_RATE_CONSTANT',
    name: 'lambda1',
    'gas phase': 'gas',
    'lambda function': '(T, P, airDensity) => 5.0e-4',
    reactants: [{ 'species name': 'K', coefficient: 1 }],
    products: [{ 'species name': 'L', coefficient: 1 }],
  });
  const t0 = config.conditions.data[0];
  t0.headers.push('CONC.K.mol m-3');
  t0.rows[0].push(1.0);
  return config;
}

function assertEveryOptionStructure(exported) {
  const opts = exported['box model options'];
  assert.equal(opts.grid, 'box');
  assert.equal(opts['chemistry time step [sec]'], 2.0);
  assert.equal(opts['output time step [sec]'], 6.0);
  assert.equal(opts['simulation length [sec]'], 60.0);
  assert.equal(opts['max iterations'], 100);

  assert.equal(exported.mechanism.version, '1.0.0');
  const exportedTypes = [...new Set(exported.mechanism.reactions.map((r) => r.type))].sort();
  assert.deepEqual(exportedTypes, EXPECTED_REACTION_TYPES);

  const blocks = exported.conditions.data;
  assert.equal(blocks.length, 2, 'expected exactly one data block per distinct time');

  const t0Headers = new Set(blocks[0].headers);
  for (const header of [
    'ENV.temperature.K',
    'ENV.pressure.Pa',
    'CONC.Srf.mol m-3',
    'CONC.A.mol m-3',
    'PHOTO.photo1.s-1',
    'EMIS.emis1.mol m-3 s-1',
    'LOSS.loss1.s-1',
    'USER.ud1.s-1',
    'SURF.surf1.particle number concentration.# m-3',
    'SURF.surf1.effective radius.m',
  ]) {
    assert.ok(t0Headers.has(header), `t=0 block missing header "${header}"`);
  }

  const t30Headers = new Set(blocks[1].headers);
  for (const header of [
    'ENV.temperature.K',
    'ENV.pressure.Pa',
    'CONC.A.mol m-3',
    'PHOTO.photo1.s-1',
    'EMIS.emis1.mol m-3 s-1',
    'LOSS.loss1.s-1',
    'USER.ud1.s-1',
    'SURF.surf1.particle number concentration.# m-3',
    'SURF.surf1.effective radius.m',
  ]) {
    assert.ok(t30Headers.has(header), `t=30 block missing header "${header}"`);
  }
}

before(async () => {
  await initModule();
});

describe('MusicBox.toJson() structure', () => {
  it('exports every option correctly before any solve() call', () => {
    const box = MusicBox.fromJson(loadEveryOptionConfig());
    assertEveryOptionStructure(box.toJson());
  });

  it('exports every option correctly after a solve() call', async () => {
    const box = MusicBox.fromJson(loadEveryOptionConfig());
    await box.solve();
    assertEveryOptionStructure(box.toJson());
  });
});

describe('MusicBox export round trip', () => {
  it('toJson() -> fromJson() round trip matches the original solve() results exactly', async () => {
    const box1 = MusicBox.fromJson(loadEveryOptionConfig());
    const result1 = await box1.solve();

    const box2 = MusicBox.fromJson(box1.toJson());
    const result2 = await box2.solve();

    assert.deepStrictEqual(result1, result2);
  });

  it('export(filePath) -> fromJsonFile() round trip matches the original solve() results exactly', async () => {
    const box1 = MusicBox.fromJson(loadEveryOptionConfig());
    const result1 = await box1.solve();

    const dir = await mkdtemp(join(tmpdir(), 'music-box-export-'));
    try {
      const filePath = join(dir, 'config.json');
      await box1.export(filePath);

      const box2 = await MusicBox.fromJsonFile(filePath);
      const result2 = await box2.solve();

      assert.deepStrictEqual(result1, result2);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});

describe('MusicBox lambda reaction export (JS-only)', () => {
  it('round trips a LAMBDA_RATE_CONSTANT reaction through toJson()', async () => {
    const box1 = MusicBox.fromJson(loadEveryOptionConfigWithLambda());
    const result1 = await box1.solve();

    const exported = box1.toJson();
    assert.ok(
      exported.mechanism.reactions.some((r) => r.type === 'LAMBDA_RATE_CONSTANT'),
      'exported mechanism should still contain the LAMBDA_RATE_CONSTANT reaction'
    );

    const box2 = MusicBox.fromJson(exported);
    const result2 = await box2.solve();

    assert.deepStrictEqual(result1, result2);
  });

  it('warns that LAMBDA_RATE_CONSTANT reactions are JS-only and non-portable', () => {
    const box = MusicBox.fromJson(loadEveryOptionConfigWithLambda());
    const originalWarn = console.warn;
    const warnings = [];
    console.warn = (...args) => warnings.push(args.join(' '));
    try {
      box.toJson();
    } finally {
      console.warn = originalWarn;
    }

    assert.equal(warnings.length, 1);
    assert.match(warnings[0], /LAMBDA_RATE_CONSTANT/);
    assert.match(warnings[0], /lambda1/);
    assert.match(warnings[0], /will not load in the Python implementation/);
  });

  it('does not warn when the mechanism has no LAMBDA_RATE_CONSTANT reactions', () => {
    const box = MusicBox.fromJson(loadEveryOptionConfig());
    const originalWarn = console.warn;
    const warnings = [];
    console.warn = (...args) => warnings.push(args.join(' '));
    try {
      box.toJson();
    } finally {
      console.warn = originalWarn;
    }

    assert.equal(warnings.length, 0);
  });
});
