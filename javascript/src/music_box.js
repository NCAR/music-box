import { initModule, MICM, SolverState } from '@ncar/musica';
import { parseBoxModelOptions, parseConditions, resolveConditionsFilepaths } from './config_parser.js';
import { ConditionsManager } from './conditions_manager.js';
import { readConfigFromFile } from './virtual_fs.js';

function evaluateJsLambda(source, reactionName) {
  const trimmed = (source || '').trim();
  if (!trimmed) {
    throw new Error(`Lambda reaction "${reactionName}" is missing a \"lambda function\" value`);
  }

  let fn;
  try {
    // NOTE: new Function() executes a string from the mechanism config.
    // Treat any mechanism config loaded from an untrusted source (e.g. browser uploads)
    // as equivalent to executing arbitrary code.
    fn = new Function(`return (${trimmed});`)();
  } catch (err) {
    const details = err instanceof Error ? err.message : String(err);
    throw new Error(
      `Lambda reaction "${reactionName}" must be a valid JavaScript function, e.g. (T, P, airDensity) => 1.0e-12. ${details}`,
      { cause: err }
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

function pruneUnknownRateParams(normalizedRateParams, acceptedRateParamKeys, warnedUnknownRateParams) {
  const filtered = { ...(normalizedRateParams || {}) };

  if (!(acceptedRateParamKeys && acceptedRateParamKeys.size > 0)) {
    return filtered;
  }

  for (const key of Object.keys(filtered)) {
    if (!acceptedRateParamKeys.has(key)) {
      if (!warnedUnknownRateParams.has(key)) {
        warnedUnknownRateParams.add(key);
        console.warn(
          `Ignoring unknown rate parameter key "${key}". ` +
            'Verify condition headers match mechanism-defined user parameters.'
        );
      }
      delete filtered[key];
    }
  }

  return filtered;
}

function normalizeRateParamsForSolver(rateParams, normalizerState) {
  if (!rateParams || typeof rateParams !== 'object') return {};

  return pruneUnknownRateParams(
    rateParams,
    normalizerState.acceptedRateParamKeys,
    normalizerState.warnedUnknownRateParams
  );
}

/**
 * The smallest value in a sorted array that is strictly greater than `value`,
 * or Infinity if there is none
 *
 * @param {number[]} sortedValues
 * @param {number} value
 * @returns {number}
 */
function bisectRight(sortedValues, value) {
  let lo = 0;
  let hi = sortedValues.length;
  while (lo < hi) {
    const mid = (lo + hi) >>> 1;
    if (sortedValues[mid] <= value) lo = mid + 1;
    else hi = mid;
  }
  return lo < sortedValues.length ? sortedValues[lo] : Infinity;
}

/**
 * JavaScript implementation of the music-box atmospheric chemistry box model.
 *
 * Accepts the same music-box v1 JSON config format as the Python implementation.
 * For inline conditions, use conditions.data (array of row objects) — the same
 * format supported by Python's ConditionsManager.
 *
 * Can be built up programmatically instead of from JSON:
 *   const box = new MusicBox();
 *   box.chemTimeStep = 2.0;
 *   box.outputTimeStep = 6.0;
 *   box.simulationLength = 60.0;
 *   box.loadMechanism(mechanismInstanceOrJSON);
 *   box.setCondition(0, { temperature: 298.15, concentrations: { A: 1.0 } });
 *   const result = await box.solve();
 */
export class MusicBox {
  constructor() {
    /** Chemistry time step, in seconds. */
    this.chemTimeStep = undefined;
    /** Output time step, in seconds. */
    this.outputTimeStep = undefined;
    /** Simulation length, in seconds. */
    this.simulationLength = undefined;
    /** Maximum solver substep iterations before solve() throws. */
    this.maxIterations = 1000;

    // A plain v1 mechanism JSON object, or anything with a getJSON() method (e.g. a musica
    // Mechanism instance) -- resolved to JSON on demand via _mechanismJSON().
    this._mechanism = null;
    this._conditionsManager = new ConditionsManager([]);
  }

  /**
   * Set the mechanism. Chainable.
   *
   * @param {{getJSON: () => Object}|Object} mechanism - A musica Mechanism instance (or
   *   anything with a getJSON() method), or a plain v1 mechanism JSON object.
   * @returns {MusicBox} this, for chaining
   */
  loadMechanism(mechanism) {
    this._mechanism = mechanism;
    return this;
  }

  /**
   * Set conditions at a specific time. Chainable. See ConditionsManager.setCondition().
   *
   * @param {number} t - Simulation time in seconds
   * @param {Object} [options] - See ConditionsManager.setCondition().
   * @returns {MusicBox} this, for chaining
   */
  setCondition(t, options) {
    this._conditionsManager.setCondition(t, options);
    return this;
  }

  /**
   * Replace all conditions at once. Chainable.
   *
   * @param {ConditionsManager|Object} conditions - A ConditionsManager instance, or a plain
   *   v1 conditions object ({data: [...]}).
   * @returns {MusicBox} this, for chaining
   */
  loadConditions(conditions) {
    this._conditionsManager =
      conditions instanceof ConditionsManager
        ? conditions
        : new ConditionsManager(parseConditions(conditions));
    return this;
  }

  /**
   * Create a MusicBox instance from a plain JSON object.
   *
   * @param {Object} jsonObject - music-box v1 config object
   * @returns {MusicBox}
   */
  static fromJson(jsonObject) {
    const box = new MusicBox();
    const { chemTimeStep, outputTimeStep, simulationLength, maxIterations } =
      parseBoxModelOptions(jsonObject);
    box.chemTimeStep = chemTimeStep;
    box.outputTimeStep = outputTimeStep;
    box.simulationLength = simulationLength;
    box.maxIterations = maxIterations ?? 1000;
    box._mechanism = jsonObject.mechanism;
    box._conditionsManager = new ConditionsManager(parseConditions(jsonObject.conditions));
    return box;
  }

  /**
   * Create a MusicBox instance from a JSON config file, resolving any CSV
   * "conditions.filepaths" relative to it.
   *
   * @param {string} filePath - Path to the config file. A real path on disk in Node;
   *   elsewhere it must already be a path in the virtual filesystem (see virtual_fs.js).
   * @returns {Promise<MusicBox>}
   */
  static async fromJsonFile(filePath) {
    const isNode = typeof process !== 'undefined' && process.versions?.node != null;

    if (isNode) {
      // webpackIgnore: Node-only modules; not included in browser bundles. Node's own fs/path
      // are used directly here since they already handle real paths correctly cross-platform,
      // unlike routing through the WASM module's virtual filesystem.
      const { readFile } = await import(/* webpackIgnore: true */ 'fs/promises');
      const { resolve, dirname } = await import(/* webpackIgnore: true */ 'node:path');
      const text = await readFile(filePath, 'utf8');
      const configDir = dirname(resolve(filePath));
      const config = await resolveConditionsFilepaths(JSON.parse(text), (relPath) =>
        readFile(resolve(configDir, relPath), 'utf8')
      );
      return MusicBox.fromJson(config);
    }

    const config = await readConfigFromFile(filePath);
    return MusicBox.fromJson(config);
  }

  /**
   * The mechanism as plain JSON, freshly resolved (and cloned, if it was already plain JSON)
   * so callers can safely mutate the result without affecting this instance's state.
   */
  _mechanismJSON() {
    if (typeof this._mechanism?.getJSON === 'function') {
      return this._mechanism.getJSON();
    }
    return structuredClone(this._mechanism);
  }

  /**
   * Returns a json representation of the box model configuration
   * @returns {Object} a music-box JSON config object
   */
  toJson() {
    const mechanism = this._mechanismJSON();
    mechanism.version = '1.0.0';

    // Lambda reactions are JS-only; Python can't load them. Keep them in the
    // export (they still work if reloaded in JS) but warn that it's not portable.
    const lambdaReactions = (mechanism.reactions || []).filter(
      (reaction) => reaction?.type === 'LAMBDA_RATE_CONSTANT'
    );
    if (lambdaReactions.length > 0) {
      const names = lambdaReactions.map((reaction) => reaction.name || '(unnamed)').join(', ');
      console.warn(
        `Exported mechanism contains ${lambdaReactions.length} LAMBDA_RATE_CONSTANT ` +
          `reaction(s) (${names}); these are a JS-only extension and will not load in the ` +
          `Python implementation of music-box. Disregarding them for portability -- they ` +
          `are still exported as-is and will work if this file is reloaded in JavaScript.`
      );
    }

    return {
      'box model options': {
        // Not a real, settable option -- MusicBox is always a box model. Always "box" here
        // only because Python's config parser currently requires the key to be present.
        grid: 'box',
        'chemistry time step [sec]': this.chemTimeStep,
        'output time step [sec]': this.outputTimeStep,
        'simulation length [sec]': this.simulationLength,
        'max iterations': this.maxIterations,
      },
      mechanism,
      conditions: this._conditionsManager.toDataBlocks(),
    };
  }

  /**
   * Writes this box model's current state to a v1 JSON file. Node-only.
   *
   * @param {string} filePath - Path to write the JSON file.
   * @returns {Promise<void>}
   */
  async export(filePath) {
    const isNode = typeof process !== 'undefined' && process.versions?.node != null;
    if (!isNode) {
      throw new Error('MusicBox.export(filePath) is only supported in Node; use toJson() elsewhere.');
    }

    // webpackIgnore: Node-only module; not included in browser bundles.
    const { writeFile } = await import(/* webpackIgnore: true */ 'fs/promises');
    const config = this.toJson();
    await writeFile(filePath, JSON.stringify(config, null, 2));
  }

  /**
   * Run the chemistry simulation.
   *
   * @returns {Promise<{columns: string[], height: number, data: Object.<string, number[]>}>}
   *   Result with a `columns` array of column names, `height` (number of rows), and
   *   `data` object mapping each column name to its array of values. Columns are
   *   `time.s`, `ENV.temperature.K`, `ENV.pressure.Pa`,
   *   `ENV.air number density.mol m-3`, then `CONC.<species>.mol m-3`.
   */
  async solve() {
    await initModule();

    const { chemTimeStep, outputTimeStep, simulationLength, maxIterations } = this;
    const mechanism = this._mechanismJSON();
    const micm = MICM.fromMechanism({ getJSON: () => mechanism });
    const state = micm.createState(1);
    const normalizerState = {
      acceptedRateParamKeys: new Set(Object.keys(state.getUserDefinedRateParameters())),
      warnedUnknownRateParams: new Set(),
    };

    try {
      registerLambdaCallbacks(micm, mechanism);

      const condsMgr = this._conditionsManager;
      // Every time any condition is applied
      const conditionTimes = condsMgr.getTimes();

      // Collect output as column arrays for efficient DataFrame construction
      const columns = {
        'time.s': [],
        'ENV.temperature.K': [],
        'ENV.pressure.Pa': [],
        'ENV.air number density.mol m-3': [],
      };

      function appendOutput(time) {
        const [conditions] = state.getConditions();
        const concs = state.getConcentrations();
        columns['time.s'].push(time);
        columns['ENV.temperature.K'].push(conditions.temperature);
        columns['ENV.pressure.Pa'].push(conditions.pressure);
        columns['ENV.air number density.mol m-3'].push(conditions.air_density);
        for (const [name, values] of Object.entries(concs)) {
          const key = `CONC.${name}.mol m-3`;
          if (!columns[key]) columns[key] = [];
          columns[key].push(Array.isArray(values) ? values[0] : values);
        }
      }

      // Solve the chemistry from currTime to targetTime, in as many solver sub-calls as
      // the solver needs, and return targetTime.
      function advanceTo(currTime, targetTime) {
        let t = currTime;
        let remaining = targetTime - currTime;
        let iters = 0;
        while (remaining > 0) {
          if (maxIterations !== null && ++iters > maxIterations) {
            throw new Error(
              `Solver exceeded maximum substep iterations (${maxIterations}) at time ${t.toFixed(2)} s`
            );
          }

          const result = micm.solve(state, remaining);

          if (result.state !== SolverState.Converged) {
            throw new Error(
              `Solver failed to converge at time ${t.toFixed(2)} s with state ${result.state}`
            );
          }

          t += result.stats.final_time;
          remaining -= result.stats.final_time;
        }
        return targetTime;
      }

      let currTime = 0;

      while (currTime <= simulationLength) {
        // Apply conditions
        const conds = condsMgr.getConditionsAtTime(currTime);
        state.setConditions({
          temperatures: conds.temperature,
          pressures: conds.pressure,
          airDensities: conds.airDensity,
        });
        state.setUserDefinedRateParameters(
          normalizeRateParamsForSolver(conds.rateParams || {}, normalizerState)
        );
        if (Object.keys(conds.concentrations).length > 0) {
          state.setConcentrations(conds.concentrations);
        }

        // Record output at every output-step boundary and always at the final time
        if (currTime % outputTimeStep === 0 || currTime === simulationLength) {
          appendOutput(currTime);
        }

        if (currTime >= simulationLength) break;

        // The next stopping point is whichever boundary is closest: the next output
        // time, the end of the current chemistry-step budget, the next condition
        // change, or the end of the simulation.
        const nextOutputTime = (Math.floor(currTime / outputTimeStep) + 1) * outputTimeStep;
        const nextChemBoundary = (Math.floor(currTime / chemTimeStep) + 1) * chemTimeStep;
        const nextConditionTime = bisectRight(conditionTimes, currTime);
        const targetTime = Math.min(nextOutputTime, nextChemBoundary, nextConditionTime, simulationLength);

        currTime = advanceTo(currTime, targetTime);
      }

      return { columns: Object.keys(columns), height: columns['time.s'].length, data: columns };
    } finally {
      state.delete();
      micm.delete();
    }
  }
}
