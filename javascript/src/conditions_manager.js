/** Prefixes that map to solver rate parameters */
const RATE_PARAM_PREFIXES = new Set(['PHOTO', 'EMIS', 'LOSS', 'USER', 'SURF']);

/**
 * Normalize a column name by stripping the trailing unit segment.
 * "PHOTO.O2_1.s-1" → "PHOTO.O2_1"
 */
function stripUnit(key) {
  const parts = key.split('.');
  if (parts.length < 2) {
    throw new Error(`Malformed rate parameter key "${key}": expected at least "PREFIX.name"`);
  }
  return parts.slice(0, 2).join('.');
}

/**
 * Manages simulation conditions from a flat array of time-indexed row objects.
 *
 * Accepts the output of parseConditions() — an array of row objects matching
 * the same column naming convention as the CSV files used by Python:
 *
 *   [
 *     { "time.s": 0, "ENV.temperature.K": 217.6, "CONC.O3.mol m-3": 6.43e-6, "PHOTO.O2_1.s-1": 1.47e-12 },
 *     { "time.s": 3600, "PHOTO.O2_1.s-1": 1.12e-13 }
 *   ]
 *
 * Column semantics (mirrors Python ConditionsManager):
 *   ENV.temperature.K      → temperature (K), step-interpolated
 *   ENV.pressure.Pa        → pressure (Pa), step-interpolated
 *   CONC.<species>.<unit>  → concentration event at exact time (not interpolated)
 *   PHOTO/EMIS/LOSS/USER.* → rate parameters, step-interpolated
 */
export class ConditionsManager {
  /**
   * @param {Array} dataRows - Array of row objects from parseConditions()
   */
  constructor(dataRows) {
    this._defaultTemp = 298.15;
    this._defaultPressure = 101325.0;

    // [{t, temp, pressure, rateParams}] — for step interpolation
    this._timePoints = [];

    // {t: {species: value}} — applied at exact time only (mirrors Python concentration_events)
    this._concentrationEvents = {};

    for (const row of (dataRows || [])) {
      const t = row['time.s'];
      if (t === undefined) continue;

      const temp = row['ENV.temperature.K'] !== undefined ? row['ENV.temperature.K'] : null;
      const pressure = row['ENV.pressure.Pa'] !== undefined ? row['ENV.pressure.Pa'] : null;
      const rateParams = {};

      for (const [key, value] of Object.entries(row)) {
        if (key === 'time.s') continue;
        const parts = key.split('.');
        const prefix = parts[0];

        if (prefix === 'CONC') {
          // Concentration event: stored separately, applied at exact time
          const species = parts[1];
          if (!this._concentrationEvents[t]) this._concentrationEvents[t] = {};
          this._concentrationEvents[t][species] = value;
        } else if (RATE_PARAM_PREFIXES.has(prefix)) {
          rateParams[stripUnit(key)] = value;
        }
        // ENV.temperature / ENV.pressure handled above; other ENV.* ignored
      }

      this._timePoints.push({ t, temp, pressure, rateParams });
    }

    this._timePoints.sort((a, b) => a.t - b.t);
  }

  /**
   * Concentration events dict: {time: {species: value}}.
   * Mirrors Python's concentration_events property.
   * @returns {Object}
   */
  get concentrationEvents() {
    return this._concentrationEvents;
  }

  /**
   * Get step-interpolated conditions at a given simulation time.
   * Returns the most recent value at or before `t` for each column.
   *
   * @param {number} t - Simulation time in seconds
   * @returns {{ temperature: number, pressure: number, rateParams: Object }}
   */
  getConditionsAtTime(t) {
    let temperature = this._defaultTemp;
    let pressure = this._defaultPressure;
    let rateParams = {};

    for (const point of this._timePoints) {
      if (point.t <= t) {
        if (point.temp !== null) temperature = point.temp;
        if (point.pressure !== null) pressure = point.pressure;
        Object.assign(rateParams, point.rateParams);
      } else {
        break;
      }
    }

    return { temperature, pressure, rateParams };
  }
}
