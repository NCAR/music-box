/**
 * Unit tests for MusicBox.fromParts() -- composing a MusicBox from builder objects
 * (BoxModelOptions, a mechanism with getJSON(), a ConditionsManager) instead of a
 * pre-built plain JSON config.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initModule } from '@ncar/musica';
import { MusicBox } from '../../src/music_box.js';
import { BoxModelOptions } from '../../src/box_model_options.js';
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

describe('MusicBox.fromParts', () => {
  it('accepts a plain-JSON mechanism and plain-JSON conditions', () => {
    const config = loadEveryOptionConfig();
    const boxModelOptions = BoxModelOptions.fromConfig(config);

    const box = MusicBox.fromParts({
      boxModelOptions,
      mechanism: config.mechanism,
      conditions: config.conditions,
    });

    assert.deepEqual(box.toJson(), MusicBox.fromJson(config).toJson());
  });

  it('accepts a ConditionsManager instance for conditions', () => {
    const config = loadEveryOptionConfig();
    const boxModelOptions = BoxModelOptions.fromConfig(config);
    const conditionsManager = new ConditionsManager(parseConditions(config.conditions));

    const box = MusicBox.fromParts({
      boxModelOptions,
      mechanism: config.mechanism,
      conditions: conditionsManager,
    });

    assert.deepEqual(box.toJson(), MusicBox.fromJson(config).toJson());
  });

  it('solves to the same results as an equivalent MusicBox.fromJson()', async () => {
    const config = loadEveryOptionConfig();
    const boxModelOptions = BoxModelOptions.fromConfig(config);
    const conditionsManager = new ConditionsManager(parseConditions(config.conditions));

    const fromParts = await MusicBox.fromParts({
      boxModelOptions,
      mechanism: config.mechanism,
      conditions: conditionsManager,
    }).solve();
    const fromJson = await MusicBox.fromJson(config).solve();

    assert.deepEqual(fromParts, fromJson);
  });

  it('accepts a mechanism object with a getJSON() method', () => {
    const config = loadEveryOptionConfig();
    const boxModelOptions = BoxModelOptions.fromConfig(config);
    const mechanismObject = { getJSON: () => config.mechanism };

    const box = MusicBox.fromParts({
      boxModelOptions,
      mechanism: mechanismObject,
      conditions: config.conditions,
    });

    assert.deepEqual(box.toJson().mechanism, MusicBox.fromJson(config).toJson().mechanism);
  });
});
