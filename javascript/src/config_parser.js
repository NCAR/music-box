import { BOLTZMANN_CONSTANT } from './utils.js';

const TIME_UNIT_SECONDS = {
  s: 1,
  min: 60,
  hr: 3600,
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
 * Parse and normalize a music-box mechanism JSON into a musica v1-compatible object.
 *
 * Normalizations applied:
 *   1. Phase species: string array → object array (["M"] → [{name: "M"}])
 *   2. Arrhenius Ea (J) → C (K): C = -Ea / k_B
 *   3. Arrhenius missing parameters default: B=0, C=0, D=300, E=0
 *
 * @param {Object} mechanismJson - The value of config.mechanism
 * @returns {{ getJSON: () => Object }} Object compatible with MICM.fromMechanism
 */
export function parseMechanism(mechanismJson) {
  if (!mechanismJson) throw new Error('Missing mechanism configuration');

  // Deep clone to avoid mutating the original config
  const normalized = JSON.parse(JSON.stringify(mechanismJson));

  // Normalize phase species: strings → {name: s} objects
  if (Array.isArray(normalized.phases)) {
    for (const phase of normalized.phases) {
      if (Array.isArray(phase.species)) {
        phase.species = phase.species.map((s) => (typeof s === 'string' ? { name: s } : s));
      }
    }
  }

  // Normalize Arrhenius reactions
  if (Array.isArray(normalized.reactions)) {
    for (const reaction of normalized.reactions) {
      if (reaction.type === 'ARRHENIUS') {
        // Convert Ea (J) → C (K): C = -Ea / k_B
        if (reaction.Ea !== undefined) {
          reaction.C = -reaction.Ea / BOLTZMANN_CONSTANT;
          delete reaction.Ea;
        }
        // Fill in Arrhenius defaults for missing parameters
        if (reaction.B === undefined) reaction.B = 0.0;
        if (reaction.C === undefined) reaction.C = 0.0;
        if (reaction.D === undefined) reaction.D = 300.0;
        if (reaction.E === undefined) reaction.E = 0.0;
      }
    }
  }

  return {
    getJSON() {
      return normalized;
    },
  };
}

/**
 * Parse inline conditions from a music-box v1 config.
 *
 * Supports conditions["data"]: a flat array of row objects, each with a "time.s" key
 * plus any condition columns (ENV.*, CONC.*, PHOTO.*, EMIS.*, LOSS.*, USER.*).
 * This mirrors the semantics of the CSV files used by Python:
 *   - CONC.* values are concentration events applied at their exact time
 *   - All other columns are step-interpolated
 *
 * Example:
 *   [
 *     { "time.s": 0, "ENV.temperature.K": 217.6, "CONC.O3.mol m-3": 6.43e-6 },
 *     { "time.s": 3600, "PHOTO.O2_1.s-1": 1.12e-13 }
 *   ]
 *
 * @param {Object} conditionsJson - The value of config.conditions
 * @returns {Array} Array of row objects (empty array if none present)
 */
export function parseConditions(conditionsJson) {
  if (!conditionsJson) return [];
  return conditionsJson['data'] || [];
}
