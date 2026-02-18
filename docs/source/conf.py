import sys
import os
import datetime
import acom_music_box
sys.path.insert(0, os.path.abspath('..'))

# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

version = acom_music_box.__version__
project = f'Music Box ({version})'
copyright = f'2024-{datetime.datetime.now().year}, NSF-NCAR/ACOM'
author = 'NSF-NCAR/ACOM'

release = f'{version}'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.autodoc',
    'sphinx_copybutton',
    'sphinx_design',
    'sphinx.ext.intersphinx',
    'nbsphinx'
]

templates_path = ['_templates']
exclude_patterns = []

templates_path = ['_templates']
exclude_patterns = []

highlight_language = 'python'

# do not require users locally compiling documentation to have all notebook libraries

nbsphinx_allow_errors = True

# -- link to MUSICA documentation ---

intersphinx_mapping = {
    'musica': ('https://musica.readthedocs.io/en/latest/', None),
    'micm': ('https://micm.readthedocs.io/en/latest/', None),
    'mc': ('https://mechanismconfiguration.readthedocs.io/en/latest/', None)
}

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_static_path = ['_static']
html_theme = 'pydata_sphinx_theme'

html_theme_options = {
    "navbar_start": ["navbar-logo"],
    "external_links": [],
    "github_url": "https://github.com/NCAR/music-box",
    "navbar_end": ["theme-switcher", "navbar-icon-links"],
    "pygment_light_style": "tango",
    "pygment_dark_style": "monokai"
}

html_css_files = [
    'custom.css'
]

html_favicon = '_static/favicon.png'
html_logo = "_static/MusicBox.svg"
