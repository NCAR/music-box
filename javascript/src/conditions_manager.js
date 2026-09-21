/** Prefixes that map to solver rate parameters */
const RATE_PARAM_PREFIXES = new Set(['PHOTO', 'EMIS', 'LOSS', 'USER', 'SURF']);

/**
 * Normalize a column name by stripping the trailing unit segment.
 *
 * For simple rate parameters:
 *   "PHOTO.O2_1.s-1" → "PHOTO.O2_1"
 *
 * For SURF parameters, preserve the property segment and express the unit
 * in brackets to mirror the Python solver normalization:
 *   "SURF.usr_NO2_aer.effective radius.m" → "SURF.usr_NO2_aer.effective radius [m]"
 */
function stripUnit(key) {
  const parts = key.split('.');
  if (parts.length < 2) {
    throw new Error(`Malformed rate parameter key "${key}": expected at least "PREFIX.name"`);
  }

  const prefix = parts[0];

  if (prefix === 'SURF') {
    // SURF keys: SURF.<name>.<property>.<unit>
    // Normalize to: SURF.<name>.<property> [unit]
    if (parts.length < 4) {
      return parts.slice(0, 2).join('.');
    }
    const name = parts[1];
    const unit = parts[parts.length - 1];
    const property = parts.slice(2, parts.length - 1).join('.');
    return `${prefix}.${name}.${property} [${unit}]`;
  }

  // Default: keep "PREFIX.name", drop the trailing ".<unit>" segment
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
 *   ENV.temperature.K              -> temperature (K), step-interpolated
 *   ENV.pressure.Pa                -> pressure (Pa), step-interpolated
 *   ENV.air number density.mol m-3 -> air number density (mol/m³), step-interpolated;
 *                                     falls back to the ideal gas law (P / (R·T)) when unset
 *   CONC.<species>.<unit>          -> concentration event at exact time (not interpolated)
 *   PHOTO/EMIS/LOSS/USER.*         -> rate parameters, step-interpolated
 */
export class ConditionsManager {
  /**
   * @param {Array} dataRows - Array of row objects from parseConditions()
   */
  constructor(dataRows) {
    this._defaultTemp = 298.15;
    this._defaultPressure = 101325.0;

    // [{t, temp, pressure, airDensity, rateParams, rawRateParams}] — for step interpolation
    this._timePoints = [];

    // {t: {species: value}} — applied at exact time only (mirrors Python concentration_events)
    this._concentrationEvents = {};

    // Track the most recently seen env/rate values per time for duplicate detection, across
    // both the rows parsed below and any later setCondition() calls.
    // Maps t -> { temp, pressure, airDensity, rateParams }
    this._seenEnvAt = new Map();

    for (const row of (dataRows || [])) {
      const t = row['time.s'];
      if (t === undefined) continue;

      const temp = row['ENV.temperature.K'] !== undefined ? row['ENV.temperature.K'] : null;
      const pressure = row['ENV.pressure.Pa'] !== undefined ? row['ENV.pressure.Pa'] : null;
      const airDensity =
        row['ENV.air number density.mol m-3'] !== undefined
          ? row['ENV.air number density.mol m-3']
          : null;
      const rateParams = {};
      const rawRateParams = {};

      for (const [key, value] of Object.entries(row)) {
        if (key === 'time.s') continue;
        const parts = key.split('.');
        const prefix = parts[0];

        if (prefix === 'CONC') {
          this._recordConcentrationEvent(t, parts[1], value);
        } else if (RATE_PARAM_PREFIXES.has(prefix)) {
          rateParams[stripUnit(key)] = value;
          // Kept alongside the stripped key so a caller writing this row back out as a CSV
          // header does not need to know the prefix convention itself.
          rawRateParams[key] = value;
        }
        // ENV.temperature / ENV.pressure / ENV.air number density handled above; other ENV.* ignored
      }

      this._recordTimePoint(t, { temp, pressure, airDensity, rateParams, rawRateParams });
    }

    this._timePoints.sort((a, b) => a.t - b.t);
  }

  /**
   * Records a concentration event, warning if it silently overwrites one already set at this
   * exact time (e.g. a CSV block and an inline block both setting the same species).
   */
  _recordConcentrationEvent(t, species, value) {
    if (this._concentrationEvents[t]?.[species] !== undefined) {
      console.warn(
        `Duplicate condition: CONC.${species} at time=${t}s already set to ` +
        `${this._concentrationEvents[t][species]}; overwriting with ${value}. ` +
        `Inline data takes precedence over CSV.`
      );
    }
    if (!this._concentrationEvents[t]) this._concentrationEvents[t] = {};
    this._concentrationEvents[t][species] = value;
  }

  /**
   * Records a time point, warning if any of its ENV/rate values overwrite ones already set at
   * this exact time. Does not sort _timePoints -- callers do that once after they are done
   * adding points, since the constructor adds many at once and setCondition() adds one at a time.
   */
  _recordTimePoint(t, { temp, pressure, airDensity, rateParams, rawRateParams }) {
    const prev = this._seenEnvAt.get(t);
    if (prev !== undefined) {
      if (temp !== null && prev.temp !== null) {
        console.warn(
          `Duplicate condition: ENV.temperature.K at time=${t}s already set to ` +
          `${prev.temp}; overwriting with ${temp}. Inline data takes precedence over CSV.`
        );
      }
      if (pressure !== null && prev.pressure !== null) {
        console.warn(
          `Duplicate condition: ENV.pressure.Pa at time=${t}s already set to ` +
          `${prev.pressure}; overwriting with ${pressure}. Inline data takes precedence over CSV.`
        );
      }
      if (airDensity !== null && prev.airDensity !== null) {
        console.warn(
          `Duplicate condition: ENV.air number density.mol m-3 at time=${t}s already set to ` +
          `${prev.airDensity}; overwriting with ${airDensity}. Inline data takes precedence over CSV.`
        );
      }
      for (const key of Object.keys(rateParams)) {
        if (prev.rateParams[key] !== undefined) {
          console.warn(
            `Duplicate condition: ${key} at time=${t}s already set to ` +
            `${prev.rateParams[key]}; overwriting with ${rateParams[key]}. ` +
            `Inline data takes precedence over CSV.`
          );
        }
      }
    }
    this._seenEnvAt.set(t, { temp, pressure, airDensity, rateParams });

    this._timePoints.push({ t, temp, pressure, airDensity, rateParams, rawRateParams });
  }

  /**
   * Sets the conditions at a specific time, creating a new time point. Chainable, mirroring
   * Python's ConditionsManager.set_condition(). Lets a caller build up conditions
   * programmatically instead of assembling {headers, rows} data blocks by hand -- call
   * toDataBlocks() afterward to get the wire format.
   *
   * @param {number} t - Simulation time in seconds
   * @param {Object} [options]
   * @param {number} [options.temperature] - Temperature in Kelvin
   * @param {number} [options.pressure] - Pressure in Pascals
   * @param {number} [options.airDensity] - Air number density in mol m-3
   * @param {Object<string, number>} [options.concentrations] - {species: value in mol m-3},
   *   applied at this exact time only, not step-interpolated
   * @param {Object<string, number>} [options.rateParameters] - {"PREFIX.name.unit": value},
   *   e.g. {"PHOTO.photo1.s-1": 1.0e-4} -- same header convention as a CSV/inline column
   * @returns {ConditionsManager} this, for chaining
   */
  setCondition(
    t,
    { temperature = null, pressure = null, airDensity = null, concentrations = {}, rateParameters = {} } = {}
  ) {
    const rateParams = {};
    const rawRateParams = {};
    for (const [key, value] of Object.entries(rateParameters)) {
      const prefix = key.split('.')[0];
      if (!RATE_PARAM_PREFIXES.has(prefix)) {
        throw new Error(
          `Invalid rate parameter key "${key}": expected prefix to be one of ` +
            `${[...RATE_PARAM_PREFIXES].join(', ')}`
        );
      }
      rateParams[stripUnit(key)] = value;
      rawRateParams[key] = value;
    }

    this._recordTimePoint(t, { temp: temperature, pressure, airDensity, rateParams, rawRateParams });
    for (const [species, value] of Object.entries(concentrations)) {
      this._recordConcentrationEvent(t, species, value);
    }

    this._timePoints.sort((a, b) => a.t - b.t);

    return this;
  }

  /**
   * Serializes the current conditions back into the v1 wire format: one {headers, rows} data
   * block per configured time. Used by MusicBox.toJson(), and by any caller that built
   * conditions with setCondition() and now needs the wire format.
   *
   * @returns {{ data: Array<{headers: string[], rows: number[][]}> }}
   */
  toDataBlocks() {
    const dataBlocks = [];

    for (const t of this.getTimes()) {
      const headers = ['time.s'];
      const values = [t];

      const { temp, pressure, airDensity, rawRateParams } = this.getRawConditionsAtTime(t);
      if (temp !== null) {
        headers.push('ENV.temperature.K');
        values.push(temp);
      }
      if (pressure !== null) {
        headers.push('ENV.pressure.Pa');
        values.push(pressure);
      }
      if (airDensity !== null) {
        headers.push('ENV.air number density.mol m-3');
        values.push(airDensity);
      }
      for (const [key, value] of Object.entries(rawRateParams)) {
        headers.push(key);
        values.push(value);
      }

      if (this._concentrationEvents[t] !== undefined) {
        for (const species of Object.keys(this._concentrationEvents[t]).sort()) {
          headers.push(`CONC.${species}.mol m-3`);
          values.push(this._concentrationEvents[t][species]);
        }
      }

      dataBlocks.push({ headers, rows: [values] });
    }

    return { data: dataBlocks };
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
   * Every configured time point, sorted by time, before step interpolation. Unlike
   * getConditionsAtTime(t), a point here only has the columns actually set at that time --
   * temp/pressure/airDensity are null, and rateParams/rawRateParams omit a key, when that
   * point didn't set it. rateParams has the unit suffix stripped (what the solver takes);
   * rawRateParams keeps the original header string, for a caller that needs to write it
   * back out as a CSV header (e.g. to round-trip a config).
   *
   * @returns {Array<{t: number, temp: number|null, pressure: number|null, airDensity: number|null, rateParams: Object, rawRateParams: Object}>}
   */
  get timePoints() {
    return this._timePoints;
  }

  /**
   * Returns every time that has a condition set, sorted ascending.
   *
   * @returns {Array<number>}
   */
  getTimes() {
    const times = new Set(this._timePoints.map((point) => point.t));
    for (const t of Object.keys(this._concentrationEvents)) {
      times.add(Number(t));
    }
    return [...times].sort((a, b) => a - b);
  }

  /**
   * The ENV/rate values explicitly set at exactly this time -- unlike
   * getConditionsAtTime, nothing is carried forward from earlier times.
   * Multiple rows sharing this time (e.g. a CSV block plus an inline block)
   * are merged in the same later-wins order getConditionsAtTime uses.
   *
   * @param {number} t - Simulation time in seconds
   * @returns {{ temp: number|null, pressure: number|null, airDensity: number|null, rawRateParams: Object }}
   */
  getRawConditionsAtTime(t) {
    let temp = null;
    let pressure = null;
    let airDensity = null;
    const rawRateParams = {};

    for (const point of this._timePoints) {
      if (point.t !== t) continue;
      if (point.temp !== null) temp = point.temp;
      if (point.pressure !== null) pressure = point.pressure;
      if (point.airDensity !== null) airDensity = point.airDensity;
      Object.assign(rawRateParams, point.rawRateParams);
    }

    return { temp, pressure, airDensity, rawRateParams };
  }

  /**
   * Get step-interpolated conditions at a given simulation time.
   * Returns the most recent value at or before `t` for each column.
   *
   * airDensity stays `null` until a row sets it, so a single configured value applies
   * from its time point onward; if it's never set, the caller (state.setConditions) falls
   * back to the ideal gas law.
   *
   * @param {number} t - Simulation time in seconds
   * @returns {{ temperature: number, pressure: number, airDensity: number|null, rateParams: Object }}
   */
  getConditionsAtTime(t) {
    let temperature = this._defaultTemp;
    let pressure = this._defaultPressure;
    let airDensity = null;
    let rateParams = {};

    for (const point of this._timePoints) {
      if (point.t <= t) {
        if (point.temp !== null) temperature = point.temp;
        if (point.pressure !== null) pressure = point.pressure;
        if (point.airDensity !== null) airDensity = point.airDensity;
        Object.assign(rateParams, point.rateParams);
      } else {
        break;
      }
    }

    return { temperature, pressure, airDensity, rateParams };
  }
}
