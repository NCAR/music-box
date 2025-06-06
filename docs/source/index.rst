.. acom_music_box documentation master file, created by
   sphinx-quickstart on Mon Apr 29 18:31:30 2024.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

..
.. # (over and under) for module headings
.. = for sections
.. - for subsections
.. ^ for subsubsections
.. ~ for subsubsubsections
.. " for paragraphs

#####################################
Welcome to Music Box's documentation!
#####################################

.. grid:: 1 1 2 2
    :gutter: 2

    .. grid-item-card:: Getting started
        :img-top: _static/index_getting_started.svg
        :link: getting_started.ipynb

        Check out the getting started guide to install music box.

    .. grid-item-card::  User guide
        :img-top: _static/index_user_guide.svg
        :link: user_guide/index
        :link-type: doc

        Learn how to configure music box for your mechanisms here!

    .. grid-item-card::  API reference
        :img-top: _static/index_api.svg
        :link: api/index
        :link-type: doc

        The source code for music box is heavily documented. This reference will help you understand the internals of music box.

    .. grid-item-card::  Contributors guide
        :img-top: _static/index_contribute.svg
        :link: contributing/index
        :link-type: doc

        If you'd like to contribute some new science code or update the docs,
        checkout the contributors guide!


.. toctree::
   :maxdepth: 2
   :caption: Contents:

   getting_started
   user_guide/index
   api/index
   contributing/index
   citing_and_bibliography/index

Indices and tables
==================

* :ref:`genindex`
* :ref:`search`
