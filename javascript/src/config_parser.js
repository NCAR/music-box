const TIME_UNIT_SECONDS = {
  s: 1,
  sec: 1,
  min: 60,
  hr: 3600,
  hour: 3600,
  day: 86400,
};

/**
 * Extract a time value from a config object by searching for keys like "key [unit]".
 * Returns the value in seconds, or null if not found.
 */
function extractTimeSeconds(options, key) {
  for (const [unit, multiplier] of Object.entries(TIME_UNIT_SECONDS)) {
    const fullKey = `${key} [${unit}]`;
    if (options[fullKey] !== undefined) {
      return options[fullKey] * multiplier;
    }
  }
  return null;
}

/**
 * Parse box model options from a music-box v1 config object.
 * Converts time values to seconds.
 *
 * @param {Object} config - Full music-box config JSON object
 * @returns {{ chemTimeStep: number, outputTimeStep: number, simulationLength: number, maxIterations: number|null }}
 */
export function parseBoxModelOptions(config) {
  const options = config['box model options'] || {};

  const chemTimeStep = extractTimeSeconds(options, 'chemistry time step');
  const outputTimeStep = extractTimeSeconds(options, 'output time step');
  const simulationLength = extractTimeSeconds(options, 'simulation length');
  const maxIterations = options['max iterations'] ?? null;

  if (chemTimeStep === null) throw new Error('Missing "chemistry time step [<unit>]" in box model options');
  if (outputTimeStep === null) throw new Error('Missing "output time step [<unit>]" in box model options');
  if (simulationLength === null) throw new Error('Missing "simulation length [<unit>]" in box model options');

  return { chemTimeStep, outputTimeStep, simulationLength, maxIterations };
}

/**
 * Parse a CSV string into a {headers, rows} block compatible with conditions.data.
 *
 * @param {string} csvText - CSV file contents
 * @returns {{ headers: string[], rows: number[][] }}
 */
export function parseCsvToBlock(csvText) {
  const lines = csvText.split('\n').map((l) => l.trim()).filter((l) => l.length > 0);
  if (lines.length === 0) return { headers: [], rows: [] };
  const headers = lines[0].split(',').map((h) => h.trim());
  const rows = lines.slice(1).map((line) => line.split(',').map((v) => Number(v.trim())));
  return { headers, rows };
}

/**
 * Parse inline conditions from a music-box v1 config.
 *
 * Supports conditions["data"]: an array of {headers, rows} blocks, matching the
 * format Python's ConditionsManager already accepts via _load_inline_data. Each
 * block is equivalent to one CSV file.
 *
 * Example (two blocks mirroring two CSV files):
 *   [
 *     {
 *       "headers": ["time.s", "ENV.temperature.K", "CONC.O3.mol m-3"],
 *       "rows": [[0.0, 217.6, 6.43e-6]]
 *     },
 *     {
 *       "headers": ["time.s", "PHOTO.O2_1.s-1", "PHOTO.O3_1.s-1"],
 *       "rows": [[0, 1.47e-12, 4.25e-5], [3600, 1.12e-13, 1.33e-6]]
 *     }
 *   ]
 *
 * Returns a flat array of row objects for use by ConditionsManager.
 *
 * @param {Object} conditionsJson - The value of config.conditions
 * @returns {Array} Flat array of row objects (empty array if none present)
 */
export function parseConditions(conditionsJson) {
  if (!conditionsJson) return [];
  const blocks = conditionsJson['data'] || [];
  const rows = [];
  for (const block of blocks) {
    const { headers, rows: blockRows } = block;
    for (const values of blockRows) {
      const obj = {};
      for (let i = 0; i < headers.length; i++) {
        obj[headers[i]] = values[i];
      }
      rows.push(obj);
    }
  }
  return rows;
}
