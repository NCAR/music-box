# MusicBox Configuration Options

Configuration for the MusicBox model is written in a JSON file passed to the model at runtime. This config file also points the model to any additional input files supplied by the user, and allows configuration for these files.

config.json contains four main sections, each specifying different parts of the MusicBox configuration.
##### MusicBox configuration file sections:
* **Box model options**- Basic model settings.
* **Initial conditions**- Configuration for inital enviornmental conditions.
* **Evolving conditions**- Configuration for conditions changing over time.
* **Model components**- Settings for the chemical solver.

##### Base structure for config.json:
```json
{
    "box model options": {},
    "initial conditions": {},
    "evolving conditions": {},
    "model components": {}
}
```


___
### Box Model Options

Box model options configure the basic settings for the box model run, including grid options and time step lengths.

grid
:   string, required
:   Grid type for model run. "box" is the only currently supported grid.

chemistry time step [units] 
:   float/int, required
:   Time unit options: `"sec"`, `"min"`, `"hour"`, `"day"`

output time step [units] 
:   float/int, required
:   Time unit options: `"sec"`, `"min"`, `"hour"`, `"day"`

simulation length [units] 
:   float/int, required
:   Time unit options: `"sec"`, `"min"`, `"hour"`, `"day"`

simulation start
:   specified as JSON object:
`{
      "time zone" : "UTC-8",
      "year" : 2020,
      "month" : 6,
      "day" : 10,
      "hour" : 13
    }`


**Example box model options configuration:**
```json
{
  "box model options" : {
    "grid"                      : "box",
    "chemistry time step [min]" : 5.0,
    "output time step [hr]"     : 1.0,
    "simulation length [hr]"    : 2.5,
    "simulation start" : {
      "time zone" : "UTC-8",
      "year" : 2020,
      "month" : 6,
      "day" : 10,
      "hour" : 13
    }
  }
}
```

### Initial Conditions

Initial environmental conditions, concentrations for chemical species, and reaction rates/rate constants that have a MUSICA name can be set here. **The conditions you set here will remain at the value you specify until updated by the solver (as is the case for chemical species concentrations) or overwritten by evolving conditions**.

input data files
:   For use of initial conditions data files, the file name is included as a key within the `"initial conditions"` JSON object.
`"initial conditions": {fileName: {}}`
:   file options:
    :   delimiter
        :   MusicBox will use `,` as a default delimiter. A custom delimiter can be specified.
        :   `fileName: {"delimiter": "&"}`
    :   properties
        :   Properties for data colunmns within a conditions file can be specified with the `properties` key. Individual columns are specified with the column name from the data file, and all columns can be specified with the `*` key.
        :   Properties are specified with this general format:
        `fileName: {"properties": {PREFIX.PropertyName: {property: value}}`
        :   **Changing units:**
        :   Units are changed by specifying the desired data column title and the desired units:
        `fileName: {"properties": {"ENV.pressure": {"units": "kPa"}}}`
        :   **Shifting time data:**
        :   Time data for evolving conditions files can be shifted to a specified time value.
        :   `"properties" : {
        "time.hr" : {
          "shift first entry to" :{
            "time zone" : "UTC-8",
            "year" : 2020,
            "month" : 6,
            "day" : 10,
            "hour" : 13
          }
        }
      }`
        :   **Renaming columns:**
        :   Column names can be changed by specifying the MusicBox name.
        :   `"properties" : {
        "*" : { "MusicBox name" : "PHOT.*" }}`

#### Input file formatting:
**Initial conditions input files should be comma-separated text files with variable names on the first line, followed by a single line of data describing the initial value for each variable.** Variable names that are not recognized by MusicBox will be ignored.

Variable names should be structured as follows:
`PREFIX.PropertyName`

The `PREFIX` indicates what type of property is being set. The property types corresponding to each recognized prefix are described below. The Property Name is the name of the property in the mechanism.

| Prefix      | Property Type | Use | Default Unit |
| :-----------: | ----------- |-| - |
| `CONC`      | Chemical species concentrations       | Used with chemical species specified in the chemical mechanism | mol/m^3 |
| `ENV`   | Enviornmental conditions        | Used to specify temperature and pressure | K or Pa |
| `EMIS`   | Emission of a chemical species         | Used to specify the rate constant for an emission reaction specified in the chemical mechansim | mol m-3 s-1 |
| `LOSS`   | First-order loss of a chemical species        | Used to specify the rate constant for an loss reaction specified in the chemical mechansim | s-1 |
| `PHOT`   | Photolysis of a chemical species        | Used to specify the rate constant for a photolysis reaction specified in the chemical mechansim | s-1 |

___
chemical species
:   Without an initial conditions file, inital concentrations of chemical species can be set directly inside the JSON file. Species specifed in the configuration must also be present in the chemical mechanism.
```json
{"chemical species": {
    "Ar": {"initial value [mol m-3]": 0.0334},
    "CO2": {"initial value [mol m-3]": 0.00146}
    }
}
```
___
enviornmental conditions
:   Without an initial conditions file, inital concentrations of chemical species can also be set directly inside the JSON file.
```json
{"enviornmental conditions": {
    "Temperature": {"initial value [K]": 206},
    "Pressure": {"initial value [Pa]": 6150}
    }
}
```
___
**Example initial conditions configuration with an input file and specifed delimiter:**
```json
{
  "initial conditions" : {
    "initial_conditions_data.csv": {
        "delimiter": "&",
        "properties": {
            "ENV.pressure": {"units": "kPa"}
        }
    }
  }
}
```
**Example initial conditions configuration specifying chemical species and enviornmental conditions:**
```json
{
    "chemical species": {
        "Ar": {"initial value [mol m-3]": 0.0334},
        "CO2": {"initial value [mol m-3]": 0.00146},
        "H2O": {"initial value [mol m-3]": 1.19e-05},
        "N2": {"initial value [mol m-3]": 2.8},
        "O2": {"initial value [mol m-3]": 0.75},
        "O3": {"initial value [mol m-3]": 8.1e-06}
    },
    "environmental conditions": {
        "temperature": {"initial value [K]": 206.6374207},
        "pressure": {"initial value [Pa]": 6152.049805}
    }
}
```
---
### Evolving Conditions
**Evolving conditions files contain model conditions that change during the simulation.** These can be environmental conditions, chemical species concentrations, or rates/rate constants for reactions with a MUSICA name. **Evolving conditions take precedence over initial conditions.**

input data files
:   For use of initial conditions data files, the file name is included as a key within the 'evolving conditions' JSON object.
`"evolving conditions": {fileName: {}}`
:   file options:
    :   delimiter
        :   MusicBox will use `,` as a default delimiter. A custom delimiter can be specified.
        :   `fileName: {"delimiter": "&"}`
    :   properties
        :   Properties for data colunmns within a conditions file can be specified with the `properties` key. Individual columns are specified with the column name from the data file, and all columns can be specified with the `*` key.
        :   Properties are specified with this general format:
        `fileName: {"properties": {PREFIX.PropertyName: {property: value}}`
        :   **Changing units:**
        :   Units are changed by specifying the desired data column title and the desired units:
        `fileName: {"properties": {"ENV.pressure": {"units": "kPa"}}}`
        :   **Shifting time data:**
        :   Time data for evolving conditions files can be shifted to a specified time value.
        :   `"properties" : {
        "time.hr" : {
          "shift first entry to" :{
            "time zone" : "UTC-8",
            "year" : 2020,
            "month" : 6,
            "day" : 10,
            "hour" : 13
          }
        }
      }`
        :   **Renaming columns:**
        :   Column names can be changed by specifying the MusicBox name.
        :   `"properties" : {
        "*" : { "MusicBox name" : "PHOT.*" }}`
    :   time offset
        :   Offset for time data, alternative to shifting time data with *properties* key.
        :   `fileName: {"time offset": {"years": 10}`
    :   linear combinations
        :   The concentrations of different chemical species may be tethered and scaled with a linear combination. Linear combinations are specified with the format shown below. Note: the properties linked with a linear combination must be of the `CONC` prefix.
        ```
        filename: {"linear combinations": combinationName: {
                    "properties": {
                        "CONC.Species1": {},
                        "CONC.Species2": {}
                    },
                    "scale factor": "1"
                }
        }
        ```
#### Input file formatting:
**Evolving conditions input files should be comma-separated text files or NetCDF files.**

**Text files:**
In text files, the variable names should appear on the first line, followed by a single line of data for each time the variable(s) should be updated during the simulation. The first variable should be `time`.

The default unit for `time` values is seconds, and alternative units can be used by changing the column name to `time.min` or `time.hr`.

**NetCDF files**
NetCDF files should have a dimension of `time`, and variables whose only dimension is `time`.

Variable names should be structured as follows:
`PREFIX.PropertyName`

The `PREFIX` indicates what type of property is being set. The property types corresponding to each recognized prefix are described below. The Property Name is the name of the property in the mechanism.

| Prefix      | Property Type | Use | Default Unit |
| :-----------: | ----------- |-| - |
| `CONC`      | Chemical species concentrations       | Used with chemical species specified in the chemical mechanism | mol/m^3 |
| `ENV`   | Enviornmental conditions        | Used to specify temperature and pressure | K or Pa |
| `EMIS`   | Emission of a chemical species         | Used to specify the rate constant for an emission reaction specified in the chemical mechansim | mol m-3 s-1 |
| `LOSS`   | First-order loss of a chemical species        | Used to specify the rate constant for an loss reaction specified in the chemical mechansim | s-1 |
| `PHOT`   | Photolysis of a chemical species        | Used to specify the rate constant for a photolysis reaction specified in the chemical mechansim | s-1 |
___
**Example evolving conditions configuration with three input files**
```json
{
"evolving conditions" : {
    "emissions.csv" : {
      "properties" : {
        "time.hr" : {
          "shift first entry to" :{
            "time zone" : "UTC-8",
            "year" : 2020,
            "month" : 6,
            "day" : 10,
            "hour" : 13
          }
        }
      }
    },
    "wall_loss_rates_011519.txt" : {
      "delimiter" : ";",
      "time axis" : "columns",
      "properties" : {
        "simtime" : {
          "MusicBox name" : "time",
          "units" : "hr",
          "shift first entry to" :{
            "time zone" : "UTC-8",
            "year" : 2020,
            "month" : 6,
            "day" : 10,
            "hour" : 13
          }
        },
        "*" : {
          "MusicBox name" : "LOSS.*",
          "units" : "min-1"
        }
      }
    },
    "parking_lot_photo_rates.nc" : {
      "time offset" : { "years" : 15 },
      "properties" : {
        "*" : { "MusicBox name" : "PHOT.*" }
      }
    }
  }
}

```
___
**Example evolving conditions configuration with a linear combination scaling NOx concentrations**
```json
{
"evolving conditions": {
    "evolving_data.csv" : {
      "properties" : {
        "*" : {"MusicBox name": "CONC.*"}
      },
      "linear combinations": {
          "NOx": {
              "properties": {
              "CONC.NO": {},
              "CONC.NO2": {}
              },
              "scale factor": 1
          }
      }
    }
  }
}
```
___
### Model Components
The model components section of the MusicBox configuration specifies settings for the chemical solver. For most use cases of MusicBox, modifying the model components is not neccesary. **The standard Model Components configuration for the CAMP solver is shown below:**
```json
{
"model components": [
        {
            "type": "CAMP",
            "configuration file": "camp_data/config.json",
            "override species": {
                "M": {
                    "mixing ratio mol mol-1": 1.0
                }
            },
            "suppress output": {
                "M": {}
            }
        }
    ]
}
```
##### Model component options:
type
:   Chemical solver type. `"CAMP"` is default.

configuration file
:   Path to CAMP configuration file. Default is `"camp_data/config.json"`.

override species
:   Overrides species concentration with specified value. By default, `M` is set to 1 mol/mol.

supress output:
:   Chemical species which will not be shown in output data by the model. By default `M` is supressed.
___

### Example configuration files
___
##### Configuration for simple box model with specified reaction rates:
#
```json
{
    "box model options": {
        "grid": "box",
        "chemistry time step [sec]": 1.0,
        "output time step [sec]": 1.0,
        "simulation length [hr]": 1.0
    },
    "chemical species": {
        "a-pinene": {
            "initial value [mol m-3]": 8e-08
        },
        "O3": {
            "initial value [mol m-3]": 2e-05
        }
    },
    "environmental conditions": {
        "temperature": {
            "initial value [K]": 298.15
        },
        "pressure": {
            "initial value [Pa]": 101325.0
        }
    },
    "evolving conditions": {},
    "initial conditions": {
        "initial_reaction_rates.csv": {}
    },
    "model components": [
        {
            "type": "CAMP",
            "configuration file": "camp_data/config.json",
            "override species": {
                "M": {
                    "mixing ratio mol mol-1": 1.0
                }
            },
            "suppress output": {
                "M": {}
            }
        }
    ]
}
```
___
##### Configuration with multiple input files and linear combinations:
#
```json
{
  "box model options" : {
    "grid"                    : "box",
    "chemistry time step [s]" : 1.0,
    "output time step [s]"    : 10.0,
    "simulation length [s]"   : 50.0
  },
  "initial conditions" : {
    "init_O_O1D_O3.csv" : {
      "properties" : {
        "CONC.O3" : { "variability" : "tethered" }
      },
      "linear combinations" : {
        "atomic oxygen" : {
          "properties" : {
            "CONC.O" : { },
            "CONC.O1D" : { }
          }
        }
      }
    }
  },
  "environmental conditions" : {
    "temperature" : { "initial value [K]"   : 298.15 },
    "pressure"    : { "initial value [atm]" : 1.0    }
  },
  "evolving conditions" : {
    "evo_N2_Ar_O2.csv" : {
      "linear combinations" : {
        "N2 Ar" : {
          "properties" : {
            "CONC.N2" : { },
            "CONC.Ar" : { }
          }
        }
      }
    },
    "emit_all.csv" : { }
  },
  "model components" : [
    {
      "type" : "CAMP",
      "configuration file" : "camp_data/config.json",
      "override species" : {
        "M" : { "mixing ratio mol mol-1" : 1.0 }
      },
      "suppress output" : {
        "M" : { }
      }
    }
  ]
}
```

___
