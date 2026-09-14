/**
 * Integration tests for virtual_fs.js -- needs the real musica WASM module, so it lives
 * with the other integration tests. Exercises the in-memory (MEMFS) side, not the
 * "/host"-mounted real disk.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { initModule } from '@ncar/musica';
import {
  getVirtualFileSystem,
  writeConfigFiles,
  readConfigFromFile,
  resolveConditionsFilepathsFromFile,
} from '../../src/virtual_fs.js';

before(async () => {
  await initModule();
});

describe('writeConfigFiles + readConfigFromFile', () => {
  it('writes a config and its referenced CSVs, then reads the resolved config back', async () => {
    const config = {
      'box model options': {
        'chemistry time step [sec]': 1,
        'output time step [sec]': 1,
        'simulation length [sec]': 3600,
      },
      conditions: { filepaths: ['initial_concentrations.csv'] },
      mechanism: { name: 'Virtual FS Test', species: [], reactions: [] },
    };

    await writeConfigFiles('/test/virtual-fs/round-trip', {
      'my_config.json': JSON.stringify(config),
      'initial_concentrations.csv': 'time.s,CONC.O3.mol m-3\n0,6.43e-6\n',
    });

    const resolved = await readConfigFromFile('/test/virtual-fs/round-trip/my_config.json');

    assert.equal(resolved.conditions.filepaths, undefined);
    assert.equal(resolved.conditions.data.length, 1);
    assert.deepEqual(resolved.conditions.data[0].headers, ['time.s', 'CONC.O3.mol m-3']);
    assert.equal(resolved.mechanism.name, 'Virtual FS Test');
  });

  it('writes a CSV nested under a subdirectory the config references', async () => {
    const config = { conditions: { filepaths: ['csv/initial.csv'] } };

    await writeConfigFiles('/test/virtual-fs/nested', {
      'my_config.json': JSON.stringify(config),
      'csv/initial.csv': 'time.s,ENV.temperature.K\n0,298.15\n',
    });

    const resolved = await readConfigFromFile('/test/virtual-fs/nested/my_config.json');
    assert.deepEqual(resolved.conditions.data[0].headers, ['time.s', 'ENV.temperature.K']);
  });

  it('throws when a referenced CSV was never written', async () => {
    const config = { conditions: { filepaths: ['missing.csv'] } };
    await writeConfigFiles('/test/virtual-fs/missing', { 'my_config.json': JSON.stringify(config) });

    await assert.rejects(() => readConfigFromFile('/test/virtual-fs/missing/my_config.json'));
  });
});

describe('resolveConditionsFilepathsFromFile', () => {
  it('resolves an in-memory config against files written separately, without reading the config itself from disk', async () => {
    const config = {
      mechanism: { name: 'In-Memory Config' },
      conditions: { filepaths: ['rates.csv'] },
    };

    await writeConfigFiles('/test/virtual-fs/in-memory', {
      'rates.csv': 'time.s,PHOTO.O2_1.s-1\n0,1.47e-12\n',
    });

    const resolved = await resolveConditionsFilepathsFromFile(config, '/test/virtual-fs/in-memory');

    assert.equal(resolved.mechanism.name, 'In-Memory Config');
    assert.deepEqual(resolved.conditions.data[0].headers, ['time.s', 'PHOTO.O2_1.s-1']);
  });
});

describe('getVirtualFileSystem', () => {
  it('returns the same FS writeConfigFiles/readConfigFromFile use', async () => {
    const FS = await getVirtualFileSystem();
    FS.mkdirTree('/test/virtual-fs/direct');
    FS.writeFile('/test/virtual-fs/direct/data.txt', 'hello');
    assert.equal(FS.readFile('/test/virtual-fs/direct/data.txt', { encoding: 'utf8' }), 'hello');
  });
});
