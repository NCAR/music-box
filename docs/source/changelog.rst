Changelog
=========

Version 3.0.0
-------------

Version 3.0.0 introduces breaking changes compared to the 2.x series.
The following changes may require updates to existing configurations and code:

- The ``Conditions`` and ``EvolvingConditions`` classes have been removed.
- The callback functionality has been removed from :meth:`~acom_music_box.MusicBox.solve`.
- CSV files now require a ``time.s`` column.
- Column naming conventions have changed from square brackets to dots, e.g.::

    CONC.A [mol m-3]  ->  CONC.A.mol m-3

- A unified conditions API is now provided via :meth:`~acom_music_box.MusicBox.set_condition`,
  :meth:`~acom_music_box.MusicBox.set_conditions`, and :meth:`~acom_music_box.MusicBox.add_conditions`.

Users upgrading from 2.x should update their input files, analysis scripts,
and any direct uses of the old conditions or callback APIs to the new
interfaces described above.

JSON Configuration Changes
^^^^^^^^^^^^^^^^^^^^^^^^^^

The JSON configuration format has been simplified. The old sections
``environmental conditions``, ``initial conditions``, and ``evolving conditions``
have been replaced with a single unified ``conditions`` section.

Old format (2.x):

.. code-block:: json

    {
      "environmental conditions": {
        "temperature": {"initial value [K]": 298.15},
        "pressure": {"initial value [Pa]": 101325.0}
      },
      "initial conditions": {
        "filepaths": ["initial_concentrations.csv"]
      },
      "evolving conditions": {
        "filepaths": ["evolving_conditions.csv"]
      }
    }

New format (3.x):

.. code-block:: json

    {
      "conditions": {
        "data": [
          {
            "headers": ["time.s", "ENV.temperature.K", "ENV.pressure.Pa"],
            "rows": [[0.0, 298.15, 101325.0]]
          }
        ],
        "filepaths": ["conditions.csv"]
      }
    }

CSV Column Naming
^^^^^^^^^^^^^^^^^

All CSV files must use dot-separated column names with units as the final component:

==================== ========================
Old format (2.x)     New format (3.x)
==================== ========================
``CONC.A [mol m-3]`` ``CONC.A.mol m-3``
``ENV.temperature [K]`` ``ENV.temperature.K``
``PHOTO.O3 [s-1]``   ``PHOTO.O3.s-1``
==================== ========================

Python API Changes
^^^^^^^^^^^^^^^^^^

Old API (2.x):

.. code-block:: python

    from acom_music_box import MusicBox, Conditions, EvolvingConditions

    box = MusicBox()
    box.loadJson("config.json")

    # Old way to set conditions
    box.initial_conditions.temperature = 298.15
    box.initial_conditions.species_concentrations["A"] = 1.0
    box.add_evolving_condition(3600, Conditions(temperature=310))

    # Old solve with callback
    result = box.solve(callback=my_callback)

New API (3.x):

.. code-block:: python

    from acom_music_box import MusicBox

    box = MusicBox()
    box.loadJson("config.json")

    # New unified conditions API
    box.set_condition(time=0, temperature=298.15, concentrations={"A": 1.0})
    box.set_condition(time=3600, temperature=310)

    # Or use DataFrame input
    import pandas as pd
    df = pd.DataFrame({
        "time.s": [0, 3600],
        "ENV.temperature.K": [298.15, 310],
        "CONC.A.mol m-3": [1.0, None]
    })
    box.set_conditions(df)

    # Solve without callback
    result = box.solve()
