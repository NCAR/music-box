Installing MusicBox
===================
MusicBox is made pip installable. As with any other Python package, we recommend the use of MusicBox within a virtual environment
to contain dependencies. This page provides instructions on setting up this environment with `conda <https://www.anaconda.com/docs/getting-started/miniconda/main>`_.

Virtual environment (conda)
---------------------------
After `installing conda <https://docs.conda.io/projects/conda/en/stable/user-guide/install/index.html>`_, create a new conda environment
with a minimum Python version of 3.9, and activate your new environment:

.. code-block:: console

    $ conda create --name musicbox python=<minimum-3.9> --yes
    $ conda activate musicbox

Pip
~~~~
Within your new conda environment, install MusicBox via pip:

.. code-block:: console
    
    $ pip install acom-music-box

Note that this step can also be performed without a virtual environment if a local installation is acceptable.

Verifying installation
~~~~~~~~~~~~~~~~~~~~~~
To verify that MusicBox was installed, run the following command within your conda environment:

.. code-block:: console
    
    $ conda list

This should print a list of all available packages within your conda environment, one of which should be `acom-music-box` with
the version listing matching the latest release as listed on our `Github <https://github.com/NCAR/music-box>`_.

If you've chosen to install MusicBox locally, the following command will function in the same manner:

.. code-block:: console
    
    $ pip list

With MusicBox successfully installed, you should be able to import the package from a Python shell or script. Note that the
full package name is `acom-music-box`::

    import acom_music_box

Developer installation
----------------------
For users that want to modify or contribute to MusicBox, please follow the editable installation instructions
on the `Contributing <https://ncar.github.io/music-box/branch/main/contributing/index.html>`_ page.