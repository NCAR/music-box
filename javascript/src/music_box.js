import { initModule, MICM, SolverState } from '@ncar/musica';
import { parseBoxModelOptions, parseMechanism, parseConditions } from './config_parser.js';
import { ConditionsManager } from './conditions_manager.js';

/**
 * JavaScript implementation of the music-box atmospheric chemistry box model.
 *
 * Accepts the same music-box v1 JSON config format as the Python implementation.
 * For inline conditions, use conditions.data (array of row objects) — the same
 * format supported by Python's ConditionsManager.
 */
export class MusicBox {
  /**
   * @param {Object} config - music-box v1 JSON config object
   */
  constructor(config) {
    this._config = config;
  }

  /**
   * Create a MusicBox instance from a plain JSON object.
   *
   * @param {Object} jsonObject - music-box v1 config object
   * @returns {MusicBox}
   */
  static fromJson(jsonObject) {
    return new MusicBox(jsonObject);
  }

  /**
   * Create a MusicBox instance from a JSON file path (Node.js only).
   *
   * @param {string} filePath - Path to the music-box v1 JSON config file
   * @returns {Promise<MusicBox>}
   */
  static async fromJsonFile(filePath) {
    // webpackIgnore: fs/promises is Node.js-only; not included in browser bundles
    const { readFile } = await import(/* webpackIgnore: true */ 'fs/promises');
    const text = await readFile(filePath, 'utf8');
    return new MusicBox(JSON.parse(text));
  }

  /**
   * Run the chemistry simulation.
   *
   * Mirrors the Python solve() loop:
   *   1. Apply concentration events at t=0
   *   2. Main loop: apply concentration events at current time, update env/rates, integrate
   *
   * @returns {Promise<Array<Object>>} Array of output rows, each with time.s and
   *   CONC.<species>.mol m-3 keys.
   */
  async solve() {
    await initModule();

    const { chemTimeStep, outputTimeStep, simulationLength, maxIterations } =
      parseBoxModelOptions(this._config);
    const mechanism = parseMechanism(this._config.mechanism);
    const micm = MICM.fromMechanism(mechanism);
    const state = micm.createState(1);
    const condsMgr = new ConditionsManager(parseConditions(this._config.conditions));

    // Build sorted list of concentration event times (mirrors Python's sorted_event_times)
    const concentrationEvents = condsMgr.concentrationEvents;
    const sortedEventTimes = Object.keys(concentrationEvents)
      .map(Number)
      .sort((a, b) => a - b);
    let nextEventIdx = 0;

    // Set initial conditions
    const t0 = condsMgr.getConditionsAtTime(0);
    state.setConditions({ temperatures: t0.temperature, pressures: t0.pressure });

    // Apply concentration event at t=0 if present
    if (nextEventIdx < sortedEventTimes.length && sortedEventTimes[nextEventIdx] === 0) {
      state.setConcentrations(concentrationEvents[0]);
      nextEventIdx++;
    }

    if (Object.keys(t0.rateParams).length > 0) {
      state.setUserDefinedRateParameters(t0.rateParams);
    }

    const results = [collectOutput(0, state)];
    let currTime = 0;
    let nextOutputTime = outputTimeStep;

    while (currTime < simulationLength) {
      // Apply any concentration events at or before current time
      while (
        nextEventIdx < sortedEventTimes.length &&
        sortedEventTimes[nextEventIdx] <= currTime
      ) {
        state.setConcentrations(concentrationEvents[sortedEventTimes[nextEventIdx]]);
        nextEventIdx++;
      }

      // Update environment and rate parameters at current time
      const conds = condsMgr.getConditionsAtTime(currTime);
      state.setConditions({ temperatures: conds.temperature, pressures: conds.pressure });
      if (Object.keys(conds.rateParams).length > 0) {
        state.setUserDefinedRateParameters(conds.rateParams);
      }

      // Integrate one chemistry step (may require multiple sub-steps)
      let elapsed = 0;
      let iters = 0;
      while (elapsed < chemTimeStep) {
        if (maxIterations !== null && ++iters > maxIterations) {
          state.delete();
          throw new Error(
            `Solver exceeded maximum substep iterations (${maxIterations}) at time ${currTime.toFixed(2)} s`
          );
        }

        const result = micm.solve(state, chemTimeStep - elapsed);

        if (result.state !== SolverState.Converged) {
          state.delete();
          throw new Error(
            `Solver failed to converge at time ${currTime.toFixed(2)} s with state ${result.state}`
          );
        }

        elapsed += result.stats.final_time;
        currTime += result.stats.final_time;

        if (currTime >= nextOutputTime && nextOutputTime <= simulationLength) {
          results.push(collectOutput(currTime, state));
          nextOutputTime += outputTimeStep;
        }
      }
    }

    state.delete();
    return results;
  }
}

/**
 * Collect a single output row from the current solver state.
 *
 * @param {number} time - Current simulation time in seconds
 * @param {import('@ncar/musica').State} state - MICM state object
 * @returns {Object} Row with time.s and CONC.<species>.mol m-3 keys
 */
function collectOutput(time, state) {
  const concs = state.getConcentrations();
  const row = { 'time.s': time };
  for (const [name, values] of Object.entries(concs)) {
    row[`CONC.${name}.mol m-3`] = Array.isArray(values) ? values[0] : values;
  }
  return row;
}
