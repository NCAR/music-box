Simple simulation of a chamber experiment without photolysis.
The experiment starts with a known set of conditions for gas-phase species, and follows the evolution of the chamber at fixed temperature and pressure for 2.5 hours.
The MICM mechanism chosen includes the species NO2, NO, O3, and ISOP, which start out at some non-zero concentration, as well as other species whose initial concentrations start at zero.
Initial conditions are specified in the configuration file, rather than a separate data file.
If the MusicBox executable is in `MusicBox/build`, the simulation can be run with:

```
cd MusicBox/build
./musicbox ../examples/dark_chamber/config.json
```

Results will be in a text or NetCDF file named `output.csv` or `output.nc` depending on whether or not the NetCDF library was included in the MusicBox build.
