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
 * JavaScript implementation of the music-box atmospheric chemistry box model.
 *
 * Accepts the same music-box v1 JSON config format as the Python implementation.
 * For inline conditions, use conditions.data (array of row objects) — the same
 * format supported by Python's ConditionsManager.
 */
export class MusicBox {
  /**
   * @param {Object} config - music-box v1 JSON config object
   * @param {Object} [options]
   * @param {boolean} [options.reuseSolver=false] - When true, the compiled MICM solver and its
   *   state persist across solve() calls instead of being rebuilt and freed every call --
   *   compiling a mechanism (parsing species/reactions, building the solver's Jacobian
   *   structure) is the expensive part, while creating a state is not, so the perf win comes
   *   from keeping the *solver* alive, not from any per-call caching. Only the box model
   *   options and conditions are re-read on each solve() call; call updateConfig() first if
   *   those change. The mechanism itself (species/reactions) is fixed for the life of the
   *   instance -- create a new MusicBox for a different mechanism.
   *
   *   The caller is responsible for calling dispose() when done with a reusable instance, to
   *   free the persisted solver's WASM memory. With reuseSolver false (the default), solve()
   *   already frees everything itself every call and dispose() is a no-op.
   */
  constructor(config, { reuseSolver = false } = {}) {
    this._config = config;
    this._reuseSolver = reuseSolver;
    this._micm = null;
    this._state = null;
    this._normalizerState = null;
  }

  /**
   * Create a MusicBox instance from a plain JSON object.
   *
   * @param {Object} jsonObject - music-box v1 config object
   * @param {Object} [options] - see the constructor
   * @returns {MusicBox}
   */
  static fromJson(jsonObject, options) {
    return new MusicBox(jsonObject, options);
  }

  /**
   * Create a MusicBox instance from a JSON config file, resolving any CSV
   * "conditions.filepaths" relative to it.
   *
   * @param {string} filePath - Path to the config file. A real path on disk in Node;
   *   elsewhere it must already be a path in the virtual filesystem (see virtual_fs.js).
   * @param {Object} [options] - see the constructor
   * @returns {Promise<MusicBox>}
   */
  static async fromJsonFile(filePath, options) {
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
      return new MusicBox(config, options);
    }

    const config = await readConfigFromFile(filePath);
    return new MusicBox(config, options);
  }

  /**
   * Replace the box model options and/or conditions used by subsequent solve() calls, without
   * touching the mechanism. Only meaningful with { reuseSolver: true } -- otherwise each
   * solve() call already reads whatever is on `config` at call time.
   *
   * @param {Object} config - A full music-box v1 config object. Only `box model options` and
   *   `conditions` are used; `mechanism` is ignored (the compiled solver already reflects the
   *   mechanism this instance was created with).
   */
  updateConfig(config) {
    this._config = { ...this._config, ...config, mechanism: this._config.mechanism };
  }

  /**
   * Builds (or returns the already-cached, with reuseSolver) compiled solver, state, and
   * rate-parameter normalizer for this instance's mechanism.
   */
  _ensureSolver() {
    if (this._micm) {
      return { micm: this._micm, state: this._state, normalizerState: this._normalizerState };
    }

    const micm = MICM.fromMechanism({ getJSON: () => this._config.mechanism });
    registerLambdaCallbacks(micm, this._config.mechanism);
    const state = micm.createState(1);
    const normalizerState = {
      acceptedRateParamKeys: new Set(Object.keys(state.getUserDefinedRateParameters())),
      warnedUnknownRateParams: new Set(),
    };

    if (this._reuseSolver) {
      this._micm = micm;
      this._state = state;
      this._normalizerState = normalizerState;
    }

    return { micm, state, normalizerState };
  }

  /**
   * Frees this instance's persisted solver and state, if any. Only meaningful for an instance
   * created with { reuseSolver: true } -- call this once you are done re-running it (e.g. the
   * user picked a different mechanism), since solve() no longer frees them itself in that mode.
   */
  dispose() {
    if (this._state) {
      this._state.delete();
      this._state = null;
    }
    if (this._micm) {
      this._micm.delete();
      this._micm = null;
    }
    this._normalizerState = null;
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
   *   `data` object mapping each column name to its array of values. Columns are
   *   `time.s`, `ENV.temperature.K`, `ENV.pressure.Pa`,
   *   `ENV.air number density.mol m-3`, then `CONC.<species>.mol m-3`.
   */
  async solve() {
    await initModule();

    const { chemTimeStep, outputTimeStep, simulationLength, maxIterations } =
      parseBoxModelOptions(this._config);
    const { micm, state, normalizerState } = this._ensureSolver();

    try {
      const condsMgr = new ConditionsManager(parseConditions(this._config.conditions));
      // Build sorted list of concentration event times (mirrors Python's sorted_event_times)
      const concentrationEvents = condsMgr.concentrationEvents;
      const sortedEventTimes = Object.keys(concentrationEvents)
        .map(Number)
        .sort((a, b) => a - b);
      let nextEventIdx = 0;

      // Set initial conditions
      const t0 = condsMgr.getConditionsAtTime(0);
      state.setConditions({
        temperatures: t0.temperature,
        pressures: t0.pressure,
        airDensities: t0.airDensity,
      });

      // Apply concentration event at t=0 if present
      if (nextEventIdx < sortedEventTimes.length && sortedEventTimes[nextEventIdx] === 0) {
        state.setConcentrations(concentrationEvents[0]);
        nextEventIdx++;
      }

      state.setUserDefinedRateParameters(
        normalizeRateParamsForSolver(t0.rateParams || {}, normalizerState)
      );

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

      let currTime = 0;
      let nextOutputTime = 0;

      outer: while (currTime <= simulationLength) {
        // Collect output at all configured output times that have been reached
        while (nextOutputTime <= currTime) {
          appendOutput(currTime);
          nextOutputTime += outputTimeStep;

          // Bail out once we've emitted the last requested output timestamp.
          if (nextOutputTime > simulationLength) {
            break outer;
          }
        }

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
        state.setConditions({
          temperatures: conds.temperature,
          pressures: conds.pressure,
          airDensities: conds.airDensity,
        });
        state.setUserDefinedRateParameters(
          normalizeRateParamsForSolver(conds.rateParams || {}, normalizerState)
        );

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

        }
      }

      return { columns: Object.keys(columns), height: columns['time.s'].length, data: columns };
    } finally {
      if (!this._reuseSolver) {
        state.delete();
        micm.delete();
      }
    }
  }
}
