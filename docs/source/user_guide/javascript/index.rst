##########################
JavaScript Implementation
##########################

Music-box provides a JavaScript implementation backed by the same `MUSICA <https://github.com/NCAR/musica>`_
WebAssembly chemistry solver used by the Python package. It accepts the same music-box v1 JSON config
format, making it suitable for Node.js scripts and browser applications where file I/O is unavailable.

Installation
============

.. code-block:: console

    $ npm install @ncar/music-box

Quick Start
===========

Node.js (loading from a file)
------------------------------

.. code-block:: javascript

    import { MusicBox } from '@ncar/music-box';

    const box = await MusicBox.fromJsonFile('./configs/chapman.v1.config.json');
    const results = await box.solve();
    console.log(results);

Node.js or Browser (inline config)
------------------------------------

.. code-block:: javascript

    import { MusicBox } from '@ncar/music-box';

    const config = {
      'box model options': {
        'chemistry time step [min]': 1.0,
        'output time step [min]': 10.0,
        'simulation length [min]': 60.0,
      },
      conditions: {
        data: [
          {
            headers: ['time.s', 'ENV.temperature.K', 'ENV.pressure.Pa', 'CONC.O3.mol m-3'],
            rows: [[0.0, 298.15, 101325.0, 1e-9]],
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

Inline Conditions Format
========================

The ``conditions.data`` key accepts an array of ``{headers, rows}`` blocks — one block per
logical data source, equivalent to one CSV file. This is the same format Python's
``ConditionsManager`` accepts.

.. code-block:: json

    {
      "conditions": {
        "data": [
          {
            "headers": ["time.s", "ENV.temperature.K", "ENV.pressure.Pa",
                        "CONC.O3.mol m-3", "CONC.O2.mol m-3"],
            "rows": [[0.0, 217.6, 1394.3, 6.43e-6, 0.162]]
          },
          {
            "headers": ["time.s", "PHOTO.O2_1.s-1", "PHOTO.O3_1.s-1"],
            "rows": [
              [0,    1.47e-12, 4.25e-5],
              [3600, 1.12e-13, 1.33e-6]
            ]
          }
        ]
      }
    }

Column naming follows the same convention as the CSV files used by the Python implementation:

.. list-table::
   :header-rows: 1
   :widths: 30 15 55

   * - Column
     - Example
     - Description
   * - ``ENV.temperature.K``
     - ``217.6``
     - Air temperature in Kelvin. Step-interpolated.
   * - ``ENV.pressure.Pa``
     - ``1394.3``
     - Air pressure in Pascals. Step-interpolated.
   * - ``CONC.<species>.mol m-3``
     - ``6.43e-6``
     - Species concentration. Applied at its exact time only (concentration event).
   * - ``PHOTO.<name>.s-1``
     - ``1.47e-12``
     - Photolysis rate. Step-interpolated.
   * - ``EMIS.<name>.<unit>``
     - ``0.001``
     - Emission rate. Step-interpolated.
   * - ``LOSS.<name>.<unit>``
     - ``0.001``
     - Loss rate. Step-interpolated.
   * - ``USER.<name>.<unit>``
     - ``1.0``
     - User-defined rate parameter. Step-interpolated.

``CONC.*`` columns are treated as concentration events and applied only at their exact time.
All other columns use step interpolation (hold the most recent value until the next time point).

API Reference
=============

MusicBox
--------

.. code-block:: javascript

    // Create from a plain JSON object (works in browser and Node.js)
    const box = MusicBox.fromJson(configObject);

    // Create from a JSON file path (Node.js only)
    const box = await MusicBox.fromJsonFile('/path/to/config.json');

    // Run the simulation
    const results = await box.solve();
    // Returns an array of output rows:
    // [{ 'time.s': 0, 'CONC.O3.mol m-3': 6.43e-6, ... }, ...]

parseBoxModelOptions
---------------------

Extracts timing parameters from ``config['box model options']``, converting all time
units (``[s]``, ``[min]``, ``[hr]``, ``[day]``) to seconds.

.. code-block:: javascript

    import { parseBoxModelOptions } from '@ncar/music-box';

    const { chemTimeStep, outputTimeStep, simulationLength, maxIterations } =
      parseBoxModelOptions(config);

parseMechanism
--------------

Normalizes a music-box v1 mechanism object for use with the MUSICA WASM solver.
Returns an object with a ``getJSON()`` method compatible with ``MICM.fromMechanism()``.

Normalizations applied:

- Phase species strings → objects: ``["M", "O"]`` → ``[{"name": "M"}, {"name": "O"}]``
- Arrhenius ``Ea`` (J) → ``C`` (K): ``C = -Ea / k_B``
- Missing Arrhenius parameters default to ``B = 0``, ``C = 0``, ``D = 300``, ``E = 0``

.. code-block:: javascript

    import { parseMechanism } from '@ncar/music-box';

    const mechanism = parseMechanism(config.mechanism);
    // mechanism.getJSON() returns musica v1-compatible JSON

parseConditions
---------------

Converts ``conditions.data`` blocks into a flat array of row objects for use by
``ConditionsManager``.

.. code-block:: javascript

    import { parseConditions } from '@ncar/music-box';

    const dataRows = parseConditions(config.conditions);
    // [{ 'time.s': 0, 'ENV.temperature.K': 217.6, ... }, ...]

ConditionsManager
-----------------

Manages step interpolation of environmental conditions and collection of concentration events.

.. code-block:: javascript

    import { ConditionsManager, parseConditions } from '@ncar/music-box';

    const mgr = new ConditionsManager(parseConditions(config.conditions));

    // Step-interpolated values at time t (seconds)
    const { temperature, pressure, rateParams } = mgr.getConditionsAtTime(t);

    // Concentration events: { time: { speciesName: value } }
    const events = mgr.concentrationEvents;

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

Repository Layout
-----------------

.. code-block:: text

    music-box/
    ├── package.json           ← npm metadata and scripts
    ├── package-lock.json
    ├── webpack.config.js      ← browser bundle config
    ├── javascript/
    │   ├── src/
    │   │   ├── index.js
    │   │   ├── music_box.js
    │   │   ├── config_parser.js
    │   │   ├── conditions_manager.js
    │   │   └── utils.js
    │   └── tests/
    │       ├── unit/
    │       └── integration/
    └── src/acom_music_box/    ← Python implementation
