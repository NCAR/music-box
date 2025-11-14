############
Contributing
############

The code for MusicBox is hosted on `GitHub <https://github.com/NCAR/music-box>`_. For any proposed changes (bug fixes, new 
features, documentation updates, etc.), please start by opening an `issue <https://github.com/NCAR/music-box/issues/new/choose>`_
describing your request or planned contribution.

Creating a development environment
-----------------------------------
To contribute to MusicBox and test changes locally, we recommend making a `conda <https://www.anaconda.com/docs/getting-started/miniconda/main>`_ environment:

.. code-block:: console

    $ git clone https://github.com/NCAR/music-box
    $ cd music-box
    $ conda create --name musicbox python=<minimum-3.9> --yes
    $ conda activate musicbox

After the GitHub repository is cloned and the virtual environment made, MusicBox should be built and installed with an ediable installation:

.. code-block:: console

    $ pip install -e .


Testing with continuous integration
------------------------------------
MusicBox uses GitHub Actions to automatically test and validate changes whenever a pull request is opened. 
A pull request will be considered for merging when it passes all tests in the test suite, indicated by a green checkmark.

Before pushing your changes, you can run the same tests locally using:

.. code-block:: console

    $ pytest

Style guide
-----------
MusicBox follows the `PEP 8 <https://peps.python.org/pep-0008/>`_ style guide for Python code. Please attempt to do the same on any new contributions.
To maintain consistency, we use a GitHub action that autoformats for PEP 8 conventions after each PR is pulled. 

Documentation
-------------
All of our docs are stored in the ``docs`` directory and is built using `Sphinx <https://www.sphinx-doc.org/en/master/>`_. 
There are several Python dependencies that are necessary to build the documentation locally. These dependencies can be installed by 
running the following from your cloned ``music-box`` directory:

.. code-block:: console

    $ cd docs
    $ pip install -r requirements.txt

To build the documentation locally after edits:

- On macOS/Linux: ``make html``
- On Windows (cmd or PowerShell): ``.\make.bat html``