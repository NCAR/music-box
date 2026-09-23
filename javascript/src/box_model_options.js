import { parseBoxModelOptions } from './config_parser.js';

/**
 * Options for a box model simulation: grid type, chemistry/output time steps, simulation
 * length, and the solver substep cap. Mirrors Python's BoxModelOptions.
 */
export class BoxModelOptions {
  /**
   * @param {Object} [params]
   * @param {number} [params.chemStepTime] - Chemistry time step, in seconds.
   * @param {number} [params.outputStepTime] - Output time step, in seconds.
   * @param {number} [params.simulationLength] - Simulation length, in seconds.
   * @param {string} [params.grid='box'] - Grid type.
   * @param {number} [params.maxIterations=1000] - Maximum solver substep iterations.
   */
  constructor({
    chemStepTime,
    outputStepTime,
    simulationLength,
    grid = 'box',
    maxIterations = 1000,
  } = {}) {
    this.chemStepTime = chemStepTime;
    this.outputStepTime = outputStepTime;
    this.simulationLength = simulationLength;
    this.grid = grid;
    this.maxIterations = maxIterations;
  }

  /**
   * Create a BoxModelOptions from a v1 config's "box model options" section.
   *
   * @param {Object} config - Full music-box v1 config object
   * @returns {BoxModelOptions}
   */
  static fromConfig(config) {
    const { chemTimeStep, outputTimeStep, simulationLength, maxIterations } =
      parseBoxModelOptions(config);
    const grid = config['box model options']?.grid ?? 'box';

    return new BoxModelOptions({
      chemStepTime: chemTimeStep,
      outputStepTime: outputTimeStep,
      simulationLength,
      grid,
      maxIterations: maxIterations ?? 1000,
    });
  }

  /**
   * Serialize to the v1 "box model options" wire format (all times in seconds).
   *
   * @returns {Object}
   */
  getJSON() {
    return {
      grid: this.grid,
      'chemistry time step [sec]': this.chemStepTime,
      'output time step [sec]': this.outputStepTime,
      'simulation length [sec]': this.simulationLength,
      'max iterations': this.maxIterations,
    };
  }
}
