.. _javascript:

##########################
JavaScript Implementation
##########################

Music-box provides a JavaScript implementation backed by the same `MUSICA <https://github.com/NCAR/musica>`_
WebAssembly chemistry solver used by the Python package. It accepts the same music-box v1 JSON config
format (see :ref:`Configuration Files <configuration>`), making it suitable for Node.js scripts and
browser applications where file I/O is unavailable.

Installation
============

.. code-block:: console

    $ npm install @ncar/music-box

Quick Start
===========

Load a bundled example (Node.js or browser)
---------------------------------------------

Each example config is published with the package and can be imported directly as JSON:

.. code-block:: javascript

    import { MusicBox } from '@ncar/music-box';
    import chapmanConfig from '@ncar/music-box/examples/chapman/my_config.json' with { type: 'json' };

    const box = MusicBox.fromJson(chapmanConfig);
    const results = await box.solve();
    console.log(results);
    // [{ 'time.s': 0, 'CONC.O3.mol m-3': 6.43e-6, ... }, ...]

Available examples: ``analytical``, ``chapman``, ``flow_tube``, ``carbon_bond_5``, ``ts1``.

Node.js — load from a local file
----------------------------------

.. code-block:: javascript

    import { MusicBox } from '@ncar/music-box';

    const box = await MusicBox.fromJsonFile('./examples/chapman/my_config.json');
    const results = await box.solve();
    console.log(results);
    // [{ 'time.s': 0, 'CONC.O3.mol m-3': 6.43e-6, ... }, ...]

Node.js or Browser — inline config
-------------------------------------

Conditions can be supplied inline as ``conditions.data`` arrays instead of CSV filepaths —
see :ref:`Configuration Files → Conditions <column-naming>` for the full format and column
naming reference.

.. code-block:: javascript

    import { MusicBox } from '@ncar/music-box';

    const config = {
      'box model options': {
        'chemistry time step [min]': 1.0,
        'output time step [min]': 10.0,
        'simulation length [hr]': 1.0,
      },
      conditions: {
        data: [
          {
            headers: ['time.s', 'ENV.temperature.K', 'ENV.pressure.Pa',
                      'CONC.O3.mol m-3', 'CONC.O2.mol m-3'],
            rows: [[0.0, 217.6, 1394.3, 6.43e-6, 0.162]],
          },
          {
            headers: ['time.s', 'PHOTO.O2_1.s-1', 'PHOTO.O3_1.s-1'],
            rows: [
              [0,    1.47e-12, 4.25e-5],
              [3600, 1.12e-13, 1.33e-6],
            ],
          },
        ],
      },
      mechanism: { /* ... */ },
    };

    const box = MusicBox.fromJson(config);
    const results = await box.solve();

API Reference
=============

For full API documentation — including all parameters, return types, and descriptions — see
the :ref:`JavaScript API Reference <js-api-ref>`.

Development
===========

All npm commands are run from the **repository root** (where ``package.json`` lives):

.. code-block:: console

    $ npm install              # install dependencies
    $ npm test                 # run all tests (unit + integration)
    $ npm run test:unit        # unit tests only
    $ npm run test:integration # integration tests only
    $ npm run test:coverage    # tests with coverage report
    $ npm run build            # build browser bundle → dist/music-box.bundle.js
