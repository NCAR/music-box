/**
 * Unit tests for building a MusicBox programmatically: new MusicBox(), then setting
 * chemTimeStep/outputTimeStep/simulationLength/maxIterations, loadMechanism(), and
 * setCondition() directly, instead of MusicBox.fromJson(config).
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initModule } from '@ncar/musica';
import { MusicBox } from '../../src/music_box.js';
import { ConditionsManager } from '../../src/conditions_manager.js';
import { parseConditions } from '../../src/config_parser.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const EVERY_OPTION_FIXTURE_PATH = join(
  __dirname,
  '../../../python/tests/integration/configs/js_python_parity/my_config.json'
);

function loadEveryOptionConfig() {
  return JSON.parse(readFileSync(EVERY_OPTION_FIXTURE_PATH, 'utf8'));
}

before(async () => {
  await initModule();
});

describe('MusicBox built up programmatically', () => {
  it('setting fields directly matches an equivalent fromJson()', () => {
    const config = loadEveryOptionConfig();

    const box = new MusicBox();
    box.chemTimeStep = config['box model options']['chemistry time step [sec]'];
    box.outputTimeStep = config['box model options']['output time step [sec]'];
    box.simulationLength = config['box model options']['simulation length [sec]'];
    box.maxIterations = config['box model options']['max iterations'];
    box.loadMechanism(config.mechanism);
    // setCondition() is the real API surface for conditions; a ConditionsManager built
    // straight from the parsed rows is the faithful equivalent to test against fromJson().
    box._conditionsManager = new ConditionsManager(parseConditions(config.conditions));

    assert.deepEqual(box.toJson(), MusicBox.fromJson(config).toJson());
  });

  it('loadMechanism() and setCondition() are chainable', () => {
    const config = loadEveryOptionConfig();
    const box = new MusicBox();

    const returned = box
      .loadMechanism(config.mechanism)
      .setCondition(0, { temperature: 298.15, pressure: 101325, concentrations: { A: 1.0 } });

    assert.strictEqual(returned, box);
  });

  it('setCondition() built conditions solve like an equivalent fromJson()', async () => {
    const config = loadEveryOptionConfig();

    const box = new MusicBox();
    box.chemTimeStep = config['box model options']['chemistry time step [sec]'];
    box.outputTimeStep = config['box model options']['output time step [sec]'];
    box.simulationLength = config['box model options']['simulation length [sec]'];
    box.maxIterations = config['box model options']['max iterations'];
    box.loadMechanism(config.mechanism);
    box
      .setCondition(0, {
        temperature: 298.15,
        pressure: 101325,
        concentrations: { Srf: 1.0, A: 1.0, F: 0.5, I: 0.5 },
        rateParameters: {
          'PHOTO.photo1.s-1': 1.0e-4,
          'EMIS.emis1.mol m-3 s-1': 1.0e-8,
          'LOSS.loss1.s-1': 1.0e-3,
          'USER.ud1.s-1': 1.0e-5,
          'SURF.surf1.particle number concentration.# m-3': 1.0e12,
          'SURF.surf1.effective radius.m': 1.0e-7,
        },
      })
      .setCondition(30, {
        temperature: 300,
        pressure: 101000,
        concentrations: { A: 0.5 },
        rateParameters: {
          'PHOTO.photo1.s-1': 2.0e-4,
          'EMIS.emis1.mol m-3 s-1': 5.0e-9,
          'LOSS.loss1.s-1': 2.0e-3,
          'USER.ud1.s-1': 2.0e-5,
          'SURF.surf1.particle number concentration.# m-3': 5.0e11,
          'SURF.surf1.effective radius.m': 2.0e-7,
        },
      });

    const fromParts = await box.solve();
    const fromJson = await MusicBox.fromJson(config).solve();

    assert.deepEqual(fromParts, fromJson);
  });

  it('accepts a mechanism object with a getJSON() method', () => {
    const config = loadEveryOptionConfig();
    const box = new MusicBox();
    box.loadMechanism({ getJSON: () => config.mechanism });

    assert.deepEqual(box._mechanismJSON(), config.mechanism);
  });

  it('loadConditions() accepts a ConditionsManager instance', () => {
    const config = loadEveryOptionConfig();
    const manager = new ConditionsManager(parseConditions(config.conditions));

    const box = new MusicBox().loadConditions(manager);
    assert.strictEqual(box._conditionsManager, manager);
  });

  it('loadConditions() accepts a plain conditions object', async () => {
    const config = loadEveryOptionConfig();

    const box = MusicBox.fromJson(config);
    box.loadConditions(config.conditions);

    assert.deepEqual(await box.solve(), await MusicBox.fromJson(config).solve());
  });

  it('always serializes grid as "box", regardless of what was loaded', () => {
    const config = loadEveryOptionConfig();
    config['box model options'].grid = 'not-a-real-grid-type';

    const box = MusicBox.fromJson(config);
    assert.equal(box.toJson()['box model options'].grid, 'box');
  });

  it('a fresh MusicBox has no settable grid property', () => {
    const box = new MusicBox();
    assert.equal('grid' in box, false);
  });
});
