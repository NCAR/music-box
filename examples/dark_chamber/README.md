## Use case 1: Simple box model

Simple simulation of a chamber experiment without photolysis.
The experiment starts with a known set of conditions for gas-phase species, and follows the evolution of the chamber at fixed temperature and pressure for 2.5 hours.
The MICM mechanism chosen should include the species N2, O2, Ar, CO2, and O, which start out at some non-zero concentration, as well as other species whose initial concentrations start at zero. (MICM mechanism 272&mdash;Chapman chemistry&mdash;is compatible with this configuration.)

Initial conditions are specified in the configuration file, rather than a separate data file.

If the MusicBox executable is in `MusicBox/build`, the simulation can be run with:

```
cd MusicBox/build
./musicbox ../examples/dark_chamber/use_case_1.json
```

Results will be in a text file named `output.csv`.

**NOTES:**

- Although MusicBox uses SI units internally, the initial pressure is specified in atm and MusicBox automatically performs the conversion. (Similar for the time units.)
- The prognostic variables (the chemical species concentrations) start at the specified initial conditions and evolve based on the results of the chemistry solver.
- Temperature and pressure remain constant throughout the simulation.
Because no start date/time is specified, the model outputs simulation times in seconds (the default time unit) starting at 0 s


## Use case 2: Simple box model with input file

This scenario is the same as Use Case 1, except that the user has decided to add additional species to the initial conditions of the chamber and move their concentrations and the environmental conditions to an input file. They choose a comma-separated text file in standard MusicBox format for the initial concentrations. The file named `use_case_2_initial.csv` contains the initial conditions.

In the input data file, the `CONC.` prefix indicates that the property is a chemical species concentration and `ENV.` indicates that the property is an environmental property.

The `use_case_2.json` file includes the configuration data for this scenario. The `use_case_2_initial

**NOTES:**

- As the user does not specify units for the input species concentrations, they are assumed to be in the standard MusicBox units of moles m–3.
- Temperature is in the standard units (K), but pressure is in non-MusicBox units of atm, so the user must specify the units in the configuration file.

