import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { BoxModelOptions } from '../../src/box_model_options.js';

describe('BoxModelOptions', () => {
  it('serializes to the v1 wire format', () => {
    const options = new BoxModelOptions({
      chemStepTime: 2.0,
      outputStepTime: 6.0,
      simulationLength: 60.0,
      grid: 'box',
      maxIterations: 100,
    });

    assert.deepEqual(options.getJSON(), {
      grid: 'box',
      'chemistry time step [sec]': 2.0,
      'output time step [sec]': 6.0,
      'simulation length [sec]': 60.0,
      'max iterations': 100,
    });
  });

  it('defaults grid to "box" and max iterations to 1000', () => {
    const options = new BoxModelOptions({
      chemStepTime: 1.0,
      outputStepTime: 1.0,
      simulationLength: 10.0,
    });

    const json = options.getJSON();
    assert.equal(json.grid, 'box');
    assert.equal(json['max iterations'], 1000);
  });

  it('round-trips through fromConfig()', () => {
    const config = {
      'box model options': {
        grid: 'box',
        'chemistry time step [min]': 1,
        'output time step [sec]': 30,
        'simulation length [hr]': 2,
        'max iterations': 50,
      },
    };

    const options = BoxModelOptions.fromConfig(config);
    assert.equal(options.chemStepTime, 60);
    assert.equal(options.outputStepTime, 30);
    assert.equal(options.simulationLength, 7200);
    assert.equal(options.maxIterations, 50);
  });

  it('fromConfig() defaults max iterations to 1000 when omitted', () => {
    const config = {
      'box model options': {
        grid: 'box',
        'chemistry time step [sec]': 1,
        'output time step [sec]': 1,
        'simulation length [sec]': 10,
      },
    };

    assert.equal(BoxModelOptions.fromConfig(config).maxIterations, 1000);
  });
});
