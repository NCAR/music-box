.. _configuration:

Configuration Files
===================

MusicBox accepts a JSON configuration file that describes the box model options, chemical
mechanism, and simulation conditions. The same JSON format is understood by both the Python
and JavaScript implementations.

The top-level structure of a configuration file looks like this:

.. code-block:: json

    {
      "box model options": { ... },
      "mechanism": { ... },
      "conditions": { ... }
    }

To load a configuration file:

- **Python:** use :meth:`acom_music_box.music_box.MusicBox.loadJson`
- **JavaScript:** use ``MusicBox.fromJson(configObject)`` or ``await MusicBox.fromJsonFile(path)``

Box Model Options
-----------------

The ``"box model options"`` key controls simulation timing:

.. code-block:: json

    {
      "box model options": {
        "grid": "box",
        "chemistry time step [min]": 1.0,
        "output time step [min]": 1.0,
        "simulation length [day]": 3.0
      }
    }

Time values may be specified in any of the following units by appending the unit in square brackets:
``[s]``, ``[min]``, ``[hr]``, or ``[day]``.

Mechanism
---------

The ``"mechanism"`` key defines the chemical system following the
:ref:`mc:index` v1 format. It contains three sub-keys: ``species``, ``phases``, and ``reactions``.

.. code-block:: json

    {
      "mechanism": {
        "version": "1.0.0",
        "name": "my_mechanism",
        "species": [
          { "name": "O3" },
          { "name": "O" }
        ],
        "phases": [
          { "name": "gas", "species": ["O3", "O"] }
        ],
        "reactions": [
          {
            "type": "ARRHENIUS",
            "gas phase": "gas",
            "name": "O3_decomposition",
            "reactants": [ { "species name": "O3" } ],
            "products":  [ { "species name": "O" } ],
            "A": 1.0e-3,
            "Ea": 1.5e-20
          }
        ]
      }
    }

Supported reaction types include ``ARRHENIUS``, ``PHOTOLYSIS``, ``TROE``, and others. See the
:ref:`mc:reactions` page for the full list of types and their parameters.

.. note::

   **JavaScript only:** The JavaScript parser automatically normalizes the following fields
   before passing them to the MUSICA WASM solver:

   - Phase species strings are converted to objects: ``["M", "O"]`` → ``[{"name": "M"}, {"name": "O"}]``
   - Arrhenius ``Ea`` (Joules) is converted to ``C`` (Kelvin): ``C = -Ea / k_B``
   - Missing Arrhenius parameters default to ``B = 0``, ``C = 0``, ``D = 300``, ``E = 0``

Conditions
----------

The ``"conditions"`` key provides environmental data (temperature, pressure, photolysis rates,
etc.) and species concentrations over time. Two formats are supported for supplying this data;
both keys may appear together in the same config and their rows are merged.

.. list-table::
   :header-rows: 1
   :widths: 20 20 60

   * - Key
     - Supported by
     - Description
   * - ``data``
     - Python and JavaScript
     - Inline array of ``{headers, rows}`` blocks
   * - ``filepaths``
     - Python only
     - List of CSV file paths, resolved relative to the config file

Inline data (``data``)
~~~~~~~~~~~~~~~~~~~~~~

An array of ``{headers, rows}`` blocks — one block per logical data source, equivalent to one
CSV file. This is the only conditions format supported in JavaScript, and also works in Python.

.. code-block:: json

    {
      "conditions": {
        "data": [
          {
            "headers": ["time.s", "ENV.temperature.K", "ENV.pressure.Pa", "CONC.O3.mol m-3"],
            "rows": [[0.0, 217.6, 1394.3, 6.43e-6]]
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

CSV filepaths (``filepaths``) — Python only
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A list of CSV file paths, resolved relative to the config JSON file. Each CSV file has a header
row and one or more data rows.

.. code-block:: json

    {
      "conditions": {
        "filepaths": ["initial_concentrations.csv", "conditions.csv"]
      }
    }

Both keys may be used together; Python merges rows from all sources in the order they appear.

.. _column-naming:

Column Naming
~~~~~~~~~~~~~

Condition columns follow this naming convention regardless of whether data is loaded from CSV
files (Python) or inline arrays (JavaScript):

.. list-table::
   :header-rows: 1
   :widths: 30 15 55

   * - Column
     - Example
     - Description
   * - ``time.s``
     - ``0.0``
     - Time in seconds. Required in every data block.
   * - ``ENV.temperature.K``
     - ``217.6``
     - Air temperature in Kelvin. Step-interpolated.
   * - ``ENV.pressure.Pa``
     - ``1394.3``
     - Air pressure in Pascals. Step-interpolated.
   * - ``CONC.<species>.mol m-3``
     - ``6.43e-6``
     - Species concentration in mol m⁻³. Applied as a concentration event at its exact time only.
   * - ``PHOTO.<name>.s-1``
     - ``1.47e-12``
     - Photolysis rate in s⁻¹. Step-interpolated.
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
All other columns use step interpolation — the most recent value is held until the next time
point.
