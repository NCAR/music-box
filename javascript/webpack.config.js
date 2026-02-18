import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default {
  entry: './src/index.js',
  output: {
    filename: 'music-box.bundle.js',
    path: path.resolve(__dirname, 'dist'),
    library: {
      type: 'module',
    },
  },
  experiments: {
    asyncWebAssembly: true,
    outputModule: true,
  },
  resolve: {
    fallback: {
      // Node.js builtins used by musica's Emscripten wrapper inside if(ENVIRONMENT_IS_NODE) guards.
      // These code paths are never reached in browser; stubs prevent build errors.
      module: false,
      fs: false,
      path: false,
      url: false,
    },
  },
  mode: 'production',
};
