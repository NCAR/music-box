import { initModule } from '@ncar/musica';
import { resolveConditionsFilepaths } from './config_parser.js';

/**
 * The musica WASM module's virtual filesystem (Emscripten FS). In Node, @ncar/musica also
 * mounts the real filesystem at "/host".
 *
 * @returns {Promise<Object>} the Emscripten FS object
 */
export async function getVirtualFileSystem() {
  const { FS } = await initModule();
  return FS;
}

function posixDirname(path) {
  const index = path.lastIndexOf('/');
  return index <= 0 ? '/' : path.slice(0, index);
}

function posixJoin(baseDir, relPath) {
  const rel = String(relPath).replace(/\\/g, '/');
  const combined = rel.startsWith('/') ? rel : `${baseDir}/${rel}`;
  const parts = [];
  for (const segment of combined.split('/')) {
    if (segment === '' || segment === '.') continue;
    if (segment === '..') {
      parts.pop();
      continue;
    }
    parts.push(segment);
  }
  return `/${parts.join('/')}`;
}

/**
 * Writes a set of files into the virtual filesystem under `baseDir`, creating any
 * intermediate directories a nested path needs.
 *
 * @param {string} baseDir - Virtual FS directory to write into (created if missing)
 * @param {Object.<string, string|Uint8Array>} files - File contents keyed by path relative
 *   to `baseDir`
 */
export async function writeConfigFiles(baseDir, files) {
  const FS = await getVirtualFileSystem();
  FS.mkdirTree(baseDir);

  const createdDirs = new Set([baseDir]);
  for (const relPath of Object.keys(files)) {
    const fullPath = posixJoin(baseDir, relPath);
    const dir = posixDirname(fullPath);
    if (!createdDirs.has(dir)) {
      FS.mkdirTree(dir);
      createdDirs.add(dir);
    }
    FS.writeFile(fullPath, files[relPath]);
  }
}

/**
 * Resolves an in-memory config's "conditions.filepaths" by reading each referenced CSV from
 * the virtual filesystem, relative to `baseDir`.
 *
 * @param {Object} config - music-box v1 config object; not mutated
 * @param {string} baseDir - Virtual FS directory the config's filepaths are relative to
 * @returns {Promise<Object>} a new config object with "conditions.filepaths" resolved
 */
export async function resolveConditionsFilepathsFromFile(config, baseDir) {
  const FS = await getVirtualFileSystem();
  return resolveConditionsFilepaths(config, (relPath) =>
    FS.readFile(posixJoin(baseDir, relPath), { encoding: 'utf8' })
  );
}

/**
 * Reads a music-box v1 config from a JSON file in the virtual filesystem, resolving any
 * "conditions.filepaths" relative to the file's own directory.
 *
 * @param {string} path - Virtual FS path to the config JSON file
 * @returns {Promise<Object>} the resolved config object
 */
export async function readConfigFromFile(path) {
  const FS = await getVirtualFileSystem();
  const config = JSON.parse(FS.readFile(path, { encoding: 'utf8' }));
  return resolveConditionsFilepathsFromFile(config, posixDirname(path));
}
