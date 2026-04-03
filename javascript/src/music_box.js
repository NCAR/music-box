import { initModule, MICM, SolverState } from '@ncar/musica';
import { parseBoxModelOptions, parseConditions, parseCsvToBlock } from './config_parser.js';
import { ConditionsManager } from './conditions_manager.js';

function evaluateJsLambda(source, reactionName) {
  const trimmed = (source || '').trim();
  if (!trimmed) {
    throw new Error(`Lambda reaction "${reactionName}" is missing a \"lambda function\" value`);
  }

  let fn;
  try {
    fn = new Function(`return (${trimmed});`)();
  } catch {
    throw new Error(
      `Lambda reaction "${reactionName}" must be a valid JavaScript function, e.g. (T, P, airDensity) => 1.0e-12`
    );
  }

  if (typeof fn !== 'function') {
    throw new Error(
      `Lambda reaction "${reactionName}" must evaluate to a function, e.g. (T, P, airDensity) => 1.0e-12`
    );
  }

  return (T, P, airDensity) => {
    const value = fn(T, P, airDensity);
    if (typeof value !== 'number' || Number.isNaN(value)) {
      throw new Error(`Lambda reaction "${reactionName}" returned a non-numeric value`);
    }
    return value;
  };
}

function defaultLambdaReactionName(reaction, index) {
  const lhs = Array.isArray(reaction.reactants)
    ? reaction.reactants
        .map((component) => component?.['species name'] || component?.name)
        .filter(Boolean)
        .join('_')
    : '';
  const rhs = Array.isArray(reaction.products)
    ? reaction.products
        .map((component) => component?.['species name'] || component?.name)
        .filter(Boolean)
        .join('_')
    : '';

  if (lhs || rhs) {
    return `${lhs || 'reactants'}_to_${rhs || 'products'}`;
  }

  return `lambda_reaction_${index + 1}`;
}

function registerLambdaCallbacks(micm, mechanism) {
  const reactions = Array.isArray(mechanism?.reactions) ? mechanism.reactions : [];
  const lambdaReactions = reactions.filter((reaction) => reaction?.type === 'LAMBDA_RATE_CONSTANT');

  for (const [index, reaction] of lambdaReactions.entries()) {
    const reactionName = (reaction.name || '').trim() || defaultLambdaReactionName(reaction, index);
    reaction.name = reactionName;
    const callback = evaluateJsLambda(reaction['lambda function'], reactionName);
    micm.setReactionRateCallback(`Lambda.${reactionName}`, callback);
  }
}

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
    // webpackIgnore: Node.js-only modules; not included in browser bundles
    const { readFile } = await import(/* webpackIgnore: true */ 'fs/promises');
    const { resolve, dirname } = await import(/* webpackIgnore: true */ 'node:path');
    const text = await readFile(filePath, 'utf8');
    const config = JSON.parse(text);

    // Resolve conditions.filepaths (CSV files) relative to the config file's directory
    // and merge them into conditions.data so the rest of the pipeline is uniform.
    if (config.conditions?.filepaths?.length > 0) {
      const configDir = dirname(resolve(filePath));
      if (!config.conditions.data) config.conditions.data = [];
      for (const relPath of config.conditions.filepaths) {
        const csvText = await readFile(resolve(configDir, relPath), 'utf8');
        config.conditions.data.push(parseCsvToBlock(csvText));
      }
    }

    return new MusicBox(config);
  }

  /**
   * Run the chemistry simulation.
   *
   * Mirrors the Python solve() loop:
   *   1. Apply concentration events at t=0
   *   2. Main loop: apply concentration events at current time, update env/rates, integrate
   *
   * @returns {Promise<{columns: string[], height: number, data: Object.<string, number[]>}>}
   *   Result with a `columns` array of column names, `height` (number of rows), and
   *   `data` object mapping each column name to its array of values.
   */
  async solve() {
    await initModule();

    const { chemTimeStep, outputTimeStep, simulationLength, maxIterations } =
      parseBoxModelOptions(this._config);
    const micm = MICM.fromMechanism({ getJSON: () => this._config.mechanism });
    const state = micm.createState(1);

    try {
      registerLambdaCallbacks(micm, this._config.mechanism);

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

      // Collect output as column arrays for efficient DataFrame construction
      const columns = { 'time.s': [] };

      function appendOutput(time) {
        const concs = state.getConcentrations();
        columns['time.s'].push(time);
        for (const [name, values] of Object.entries(concs)) {
          const key = `CONC.${name}.mol m-3`;
          if (!columns[key]) columns[key] = [];
          columns[key].push(Array.isArray(values) ? values[0] : values);
        }
      }

      appendOutput(0);
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
            throw new Error(
              `Solver exceeded maximum substep iterations (${maxIterations}) at time ${currTime.toFixed(2)} s`
            );
          }

          const result = micm.solve(state, chemTimeStep - elapsed);

          if (result.state !== SolverState.Converged) {
            throw new Error(
              `Solver failed to converge at time ${currTime.toFixed(2)} s with state ${result.state}`
            );
          }

          elapsed += result.stats.final_time;
          currTime += result.stats.final_time;

          if (currTime >= nextOutputTime && nextOutputTime <= simulationLength) {
            appendOutput(currTime);
            nextOutputTime += outputTimeStep;
          }
        }
      }

      return { columns: Object.keys(columns), height: columns['time.s'].length, data: columns };
    } finally {
      state.delete();
      micm.delete();
    }
  }
}
