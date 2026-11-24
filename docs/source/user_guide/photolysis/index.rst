Photolysis, MusicBox Interactive, and model output
===================================================
This document describes how to incorporate the photolysis variables from WACCM and WRF-Chem into MusicBox Interactive. First you will run the examples in their standard configuration, then import your custom model output in CSV files.

Procedure:
-----------
#. Go through a few MusicBox examples and simply verify that you can run the standard configuration. Since the examples include .csv files, you can include them in a zip file like this::

    music-box/examples >>> zip -r carbon_bond_5.zip carbon_bond_5/

#. Verify that you have everything needed in the zip file::

    music-box/examples> unzip -l carbon_bond_5.zip
    Archive:  carbon_bond_5.zip
      Length      Date    Time    Name
    ---------  ---------- -----   ----
            0  10-27-2026 11:14   carbon_bond_5/
          756  10-27-2026 11:14   carbon_bond_5/initial_concentrations.csv
          820  10-27-2026 11:14   carbon_bond_5/initial_reaction_rates.csv
       198708  10-27-2026 11:14   carbon_bond_5/my_config.json
    ---------                     -------
       200284                     4 files

#. Upload Config zip file to MusicBox Interactive: https://musicbox-devel.acom.ucar.edu/

#. Run Simulation to verify that you get colorful plots. All of the examples (except waccm, which is empty) should show something realistic.

#. **Now load model results** directly from WRF-Chem and WACCM. Begin by running both models and generating output. These example commands run from the acom_music_box/tools directory, with carbon_bond_5_config.json copied in and renamed from the carbon bond example (originally my_config.json)::

    python3 modelToMusicBox.py --template carbon_bond_5_config.json --wrfchemDir "/home/drews/MusicBox/WRF-Chem/model-output/20250820/wrf/" --date 20250820,20250820 --time 06:00,18:00 --latitude 40.0 --longitude "'-105.0'" --altitude=2000 --verbose --output stuff/Boulder-wrf-chem- carbon_bond_5.csv

    python3 modelToMusicBox.py --template carbon_bond_5_config.json --waccmDir "/home/drews/MusicBox/WACCM/model-output/" --date 20260827,20260827 --time 00:00,12:00 --latitude 40.0 --longitude 255.0 --altitude=2000 --topoFile ~/MusicBox/WACCM/model-output/fv_0.9x1.25_nc3000_Nsw042_Nrs008_Co060_Fi001_ZR_sgh30_24km_GRNL_MERRA2_c171218.nc --verbose --output stuff/Boulder-waccm-carbon_bond_5.csv


