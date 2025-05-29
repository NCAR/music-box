
MusicBox
========

MusicBox: A MUSICA model for boxes and columns.

[![License](https://img.shields.io/github/license/NCAR/music-box.svg)](https://github.com/NCAR/music-box/blob/main/LICENSE)
[![CI Status](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml/badge.svg)](https://github.com/NCAR/music-box/actions/workflows/CI_Tests.yml)
[![codecov](https://codecov.io/github/NCAR/music-box/graph/badge.svg?token=OR7JEQJSRQ)](https://codecov.io/github/NCAR/music-box)
[![PyPI version](https://badge.fury.io/py/acom-music-box.svg)](https://badge.fury.io/py/acom-music-box)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14008358.svg)](https://doi.org/10.5281/zenodo.14008358)


Copyright (C) 2020 National Science Foundation - National Center for Atmospheric Research

# Installation
```
pip install acom-music-box
```
# Using the MusicBox API
MusicBox makes its chemical mechanism analysis and visualization available through a python API. The following example works through solving a simple chemistry system. Please refer to the [official documentation](https://ncar.github.io/music-box/branch/main/index.html) for further tutorials and examples. 

1. Import MusicBox, MusicBox conditions, and Musica mechanisms:
```
from acom_music_box import MusicBox, Conditions
import musica.mechanism_configuration as mc                                      
```

2. Define the chemical system of interest

MusicBox uses [Musica](https://ncar.github.io/musica/index.html) to create specific chemical species and phases of interest for chemical mechanisms.
```
A = mc.Species(name="A")
B = mc.Species(name="B")
C = mc.Species(name="C")  

species = {"A":A,"B":B,"C":C}

gas = mc.Phase(name="gas",species=list(species.values()))
```
3. Define a mechanism of interest

Through Musica, several different mechanisms can be explored to define reaction rates. Here, we use the Arrhenius equation as a simple example. Reaction parameters as well as additional mechanisms available can be found in our [mechanism configuration documentation](https://ncar.github.io/musica/api/python.html#module-musica.mechanism_configuration). 
```
arr1 = mc.Arrhenius(name="A->B", A=4.0e-3, C=50,reactants=[species["A"]], products=[species["B"]], gas_phase=gas)  

arr2 = mc.Arrhenius(name="B->C", A=1.2e-4, B=2.5, C=75, D=50, E=0.5, reactants=[species["B"]], products=[species["C"]], gas_phase=gas)

mechanism = mc.Mechanism(name="test_mechanism", species=list(species.values()),phases=[gas], reactions=[arr1, arr2])
```

4. Create a box model

To create a box model, including its mechanisms, conditions, length, time, and step times:
```
box_model = MusicBox()
box_model.load_mechanism(mechanism)
```

In the box model, the initial set of conditions represent the starting environment for the reactions. Both initial and evolving conditions are typically created alongside the creation of the box model:
```
box_model.initial_conditions = Conditions(temperature=300.0,pressure=101000.0,species_concentrations={ "A": 1.0,"B": 3.0,"C": 5.0,})
```

Evolving conditions represent a set of changes to the previous conditions of the box model. To add an evolving condition to the model, where the first float represents the time when the condition evolves:
```
box_model.add_evolving_condition(300.0,Conditions(temperature=290.0,pressure=100200.0,species_concentrations={"A": 1.0,"B": 3.0,"C": 10.0,}))
```


```
box_model.box_model_options.simulation_length = 600.0 # total simulation time
box_model.box_model_options.chem_step_time = 2 # time step for chemical reaction
box_model.box_model_options.output_step_time = 6 # time step between each output
```

5. Solve

To solve and view your newly-created box model, simply run:
```
df = box_model.solve()
print(df)
```

6. Example Output
<details><summary>&nbsp;&nbsp;&nbsp;<b>Click to Expand</b></summary>

```python
|     |   time.s |   ENV.temperature.K |   ENV.pressure.Pa |   ENV.air number density.mol m-3 |   CONC.A.mol m-3 |   CONC.B.mol m-3 |   CONC.C.mol m-3 |
|----:|---------:|--------------------:|------------------:|---------------------------------:|-----------------:|-----------------:|-----------------:|
|   0 |        0 |                 300 |            101000 |                          40.4917 |         1        |      3           |          5       |
|   1 |        6 |                 300 |            101000 |                          40.4917 |         0.972046 |      6.69421e-06 |          8.02795 |
|   2 |       12 |                 300 |            101000 |                          40.4917 |         0.944872 |      6.50707e-06 |          8.05512 |
|   3 |       18 |                 300 |            101000 |                          40.4917 |         0.918459 |      6.32517e-06 |          8.08153 |
|   4 |       24 |                 300 |            101000 |                          40.4917 |         0.892784 |      6.14835e-06 |          8.10721 |
|   5 |       30 |                 300 |            101000 |                          40.4917 |         0.867827 |      5.97648e-06 |          8.13217 |
|   6 |       36 |                 300 |            101000 |                          40.4917 |         0.843567 |      5.80941e-06 |          8.15643 |
|   7 |       42 |                 300 |            101000 |                          40.4917 |         0.819986 |      5.64701e-06 |          8.18001 |
|   8 |       48 |                 300 |            101000 |                          40.4917 |         0.797063 |      5.48915e-06 |          8.20293 |
|   9 |       54 |                 300 |            101000 |                          40.4917 |         0.774782 |      5.33571e-06 |          8.22521 |
|  10 |       60 |                 300 |            101000 |                          40.4917 |         0.753123 |      5.18655e-06 |          8.24687 |
|  11 |       66 |                 300 |            101000 |                          40.4917 |         0.73207  |      5.04156e-06 |          8.26792 |
|  12 |       72 |                 300 |            101000 |                          40.4917 |         0.711605 |      4.90063e-06 |          8.28839 |
|  13 |       78 |                 300 |            101000 |                          40.4917 |         0.691713 |      4.76363e-06 |          8.30828 |
|  14 |       84 |                 300 |            101000 |                          40.4917 |         0.672376 |      4.63047e-06 |          8.32762 |
|  15 |       90 |                 300 |            101000 |                          40.4917 |         0.65358  |      4.50103e-06 |          8.34642 |
|  16 |       96 |                 300 |            101000 |                          40.4917 |         0.63531  |      4.3752e-06  |          8.36469 |
|  17 |      102 |                 300 |            101000 |                          40.4917 |         0.61755  |      4.25289e-06 |          8.38245 |
|  18 |      108 |                 300 |            101000 |                          40.4917 |         0.600287 |      4.13401e-06 |          8.39971 |
|  19 |      114 |                 300 |            101000 |                          40.4917 |         0.583506 |      4.01844e-06 |          8.41649 |
|  20 |      120 |                 300 |            101000 |                          40.4917 |         0.567194 |      3.90611e-06 |          8.4328  |
|  21 |      126 |                 300 |            101000 |                          40.4917 |         0.551339 |      3.79692e-06 |          8.44866 |
|  22 |      132 |                 300 |            101000 |                          40.4917 |         0.535926 |      3.69078e-06 |          8.46407 |
|  23 |      138 |                 300 |            101000 |                          40.4917 |         0.520945 |      3.5876e-06  |          8.47905 |
|  24 |      144 |                 300 |            101000 |                          40.4917 |         0.506382 |      3.48731e-06 |          8.49361 |
|  25 |      150 |                 300 |            101000 |                          40.4917 |         0.492227 |      3.38983e-06 |          8.50777 |
|  26 |      156 |                 300 |            101000 |                          40.4917 |         0.478467 |      3.29507e-06 |          8.52153 |
|  27 |      162 |                 300 |            101000 |                          40.4917 |         0.465091 |      3.20295e-06 |          8.53491 |
|  28 |      168 |                 300 |            101000 |                          40.4917 |         0.45209  |      3.11342e-06 |          8.54791 |
|  29 |      174 |                 300 |            101000 |                          40.4917 |         0.439452 |      3.02638e-06 |          8.56055 |
|  30 |      180 |                 300 |            101000 |                          40.4917 |         0.427167 |      2.94178e-06 |          8.57283 |
|  31 |      186 |                 300 |            101000 |                          40.4917 |         0.415226 |      2.85955e-06 |          8.58477 |
|  32 |      192 |                 300 |            101000 |                          40.4917 |         0.403619 |      2.77961e-06 |          8.59638 |
|  33 |      198 |                 300 |            101000 |                          40.4917 |         0.392336 |      2.70191e-06 |          8.60766 |
|  34 |      204 |                 300 |            101000 |                          40.4917 |         0.381368 |      2.62638e-06 |          8.61863 |
|  35 |      210 |                 300 |            101000 |                          40.4917 |         0.370707 |      2.55296e-06 |          8.62929 |
|  36 |      216 |                 300 |            101000 |                          40.4917 |         0.360344 |      2.48159e-06 |          8.63965 |
|  37 |      222 |                 300 |            101000 |                          40.4917 |         0.350271 |      2.41222e-06 |          8.64973 |
|  38 |      228 |                 300 |            101000 |                          40.4917 |         0.340479 |      2.34479e-06 |          8.65952 |
|  39 |      234 |                 300 |            101000 |                          40.4917 |         0.330961 |      2.27924e-06 |          8.66904 |
|  40 |      240 |                 300 |            101000 |                          40.4917 |         0.32171  |      2.21552e-06 |          8.67829 |
|  41 |      246 |                 300 |            101000 |                          40.4917 |         0.312716 |      2.15359e-06 |          8.68728 |
|  42 |      252 |                 300 |            101000 |                          40.4917 |         0.303975 |      2.09339e-06 |          8.69602 |
|  43 |      258 |                 300 |            101000 |                          40.4917 |         0.295477 |      2.03487e-06 |          8.70452 |
|  44 |      264 |                 300 |            101000 |                          40.4917 |         0.287217 |      1.97798e-06 |          8.71278 |
|  45 |      270 |                 300 |            101000 |                          40.4917 |         0.279188 |      1.92269e-06 |          8.72081 |
|  46 |      276 |                 300 |            101000 |                          40.4917 |         0.271384 |      1.86894e-06 |          8.72861 |
|  47 |      282 |                 300 |            101000 |                          40.4917 |         0.263797 |      1.8167e-06  |          8.7362  |
|  48 |      288 |                 300 |            101000 |                          40.4917 |         0.256423 |      1.76591e-06 |          8.74358 |
|  49 |      294 |                 300 |            101000 |                          40.4917 |         0.249255 |      1.71655e-06 |          8.75074 |
|  50 |      300 |                 300 |            101000 |                          40.4917 |         0.242287 |      1.66856e-06 |          8.75771 |
|  51 |      306 |                 290 |            100200 |                          41.5562 |         0.971887 |      7.32221e-06 |         13.0281  |
|  52 |      312 |                 290 |            100200 |                          41.5562 |         0.944564 |      7.11636e-06 |         13.0554  |
|  53 |      318 |                 290 |            100200 |                          41.5562 |         0.918009 |      6.91629e-06 |         13.082   |
|  54 |      324 |                 290 |            100200 |                          41.5562 |         0.892201 |      6.72185e-06 |         13.1078  |
|  55 |      330 |                 290 |            100200 |                          41.5562 |         0.867118 |      6.53288e-06 |         13.1329  |
|  56 |      336 |                 290 |            100200 |                          41.5562 |         0.84274  |      6.34922e-06 |         13.1573  |
|  57 |      342 |                 290 |            100200 |                          41.5562 |         0.819048 |      6.17072e-06 |         13.1809  |
|  58 |      348 |                 290 |            100200 |                          41.5562 |         0.796022 |      5.99724e-06 |         13.204   |
|  59 |      354 |                 290 |            100200 |                          41.5562 |         0.773643 |      5.82864e-06 |         13.2264  |
|  60 |      360 |                 290 |            100200 |                          41.5562 |         0.751893 |      5.66478e-06 |         13.2481  |
|  61 |      366 |                 290 |            100200 |                          41.5562 |         0.730755 |      5.50552e-06 |         13.2692  |
|  62 |      372 |                 290 |            100200 |                          41.5562 |         0.710211 |      5.35074e-06 |         13.2898  |
|  63 |      378 |                 290 |            100200 |                          41.5562 |         0.690245 |      5.20031e-06 |         13.3097  |
|  64 |      384 |                 290 |            100200 |                          41.5562 |         0.67084  |      5.05412e-06 |         13.3292  |
|  65 |      390 |                 290 |            100200 |                          41.5562 |         0.65198  |      4.91203e-06 |         13.348   |
|  66 |      396 |                 290 |            100200 |                          41.5562 |         0.633651 |      4.77394e-06 |         13.3663  |
|  67 |      402 |                 290 |            100200 |                          41.5562 |         0.615837 |      4.63972e-06 |         13.3842  |
|  68 |      408 |                 290 |            100200 |                          41.5562 |         0.598524 |      4.50929e-06 |         13.4015  |
|  69 |      414 |                 290 |            100200 |                          41.5562 |         0.581697 |      4.38252e-06 |         13.4183  |
|  70 |      420 |                 290 |            100200 |                          41.5562 |         0.565344 |      4.25931e-06 |         13.4347  |
|  71 |      426 |                 290 |            100200 |                          41.5562 |         0.54945  |      4.13956e-06 |         13.4505  |
|  72 |      432 |                 290 |            100200 |                          41.5562 |         0.534003 |      4.02319e-06 |         13.466   |
|  73 |      438 |                 290 |            100200 |                          41.5562 |         0.518991 |      3.91008e-06 |         13.481   |
|  74 |      444 |                 290 |            100200 |                          41.5562 |         0.5044   |      3.80016e-06 |         13.4956  |
|  75 |      450 |                 290 |            100200 |                          41.5562 |         0.49022  |      3.69332e-06 |         13.5098  |
|  76 |      456 |                 290 |            100200 |                          41.5562 |         0.476438 |      3.58949e-06 |         13.5236  |
|  77 |      462 |                 290 |            100200 |                          41.5562 |         0.463044 |      3.48858e-06 |         13.537   |
|  78 |      468 |                 290 |            100200 |                          41.5562 |         0.450026 |      3.3905e-06  |         13.55    |
|  79 |      474 |                 290 |            100200 |                          41.5562 |         0.437374 |      3.29518e-06 |         13.5626  |
|  80 |      480 |                 290 |            100200 |                          41.5562 |         0.425078 |      3.20255e-06 |         13.5749  |
|  81 |      486 |                 290 |            100200 |                          41.5562 |         0.413128 |      3.11251e-06 |         13.5869  |
|  82 |      492 |                 290 |            100200 |                          41.5562 |         0.401514 |      3.02501e-06 |         13.5985  |
|  83 |      498 |                 290 |            100200 |                          41.5562 |         0.390226 |      2.93997e-06 |         13.6098  |
|  84 |      504 |                 290 |            100200 |                          41.5562 |         0.379255 |      2.85731e-06 |         13.6207  |
|  85 |      510 |                 290 |            100200 |                          41.5562 |         0.368593 |      2.77698e-06 |         13.6314  |
|  86 |      516 |                 290 |            100200 |                          41.5562 |         0.358231 |      2.69891e-06 |         13.6418  |
|  87 |      522 |                 290 |            100200 |                          41.5562 |         0.34816  |      2.62304e-06 |         13.6518  |
|  88 |      528 |                 290 |            100200 |                          41.5562 |         0.338372 |      2.5493e-06  |         13.6616  |
|  89 |      534 |                 290 |            100200 |                          41.5562 |         0.328859 |      2.47763e-06 |         13.6711  |
|  90 |      540 |                 290 |            100200 |                          41.5562 |         0.319614 |      2.40797e-06 |         13.6804  |
|  91 |      546 |                 290 |            100200 |                          41.5562 |         0.310628 |      2.34028e-06 |         13.6894  |
|  92 |      552 |                 290 |            100200 |                          41.5562 |         0.301895 |      2.27448e-06 |         13.6981  |
|  93 |      558 |                 290 |            100200 |                          41.5562 |         0.293408 |      2.21054e-06 |         13.7066  |
|  94 |      564 |                 290 |            100200 |                          41.5562 |         0.285159 |      2.1484e-06  |         13.7148  |
|  95 |      570 |                 290 |            100200 |                          41.5562 |         0.277143 |      2.088e-06   |         13.7229  |
|  96 |      576 |                 290 |            100200 |                          41.5562 |         0.269351 |      2.0293e-06  |         13.7306  |
|  97 |      582 |                 290 |            100200 |                          41.5562 |         0.261779 |      1.97225e-06 |         13.7382  |
|  98 |      588 |                 290 |            100200 |                          41.5562 |         0.254419 |      1.9168e-06  |         13.7456  |
|  99 |      594 |                 290 |            100200 |                          41.5562 |         0.247267 |      1.86291e-06 |         13.7527  |
| 100 |      600 |                 290 |            100200 |                          41.5562 |         0.240315 |      1.81054e-06 |         13.7597  |
```
</details><br></br>

# Command line tool
MusicBox provides a command line tool that can run configurations as well as some pre-configured examples. Basic plotting can be done if gnuplot is installed.

Checkout the command line options

```
music_box -h                                        
```

Run an example. Notice that the output, in csv format, is printed to the terminal.

```
music_box -e Chapman
```

Output can be saved to a csv file (the default format) and printed to the terminal.

```
music_box -e Chapman -o output
```

Output can be saved to a csv file by specifying the .csv extension for Comma-Separated Values.

```
music_box -e Chapman -o output.csv
```

Output can be saved to a file as netcdf file by specifying the .nc file extension.

```
music_box -e Chapman -o output.nc
```

Output can be saved to a file in csv format when a filename is not specified. In this case a timestamped csv file is made.

```
music_box -e Chapman
```

You may also specify multiple output files with different formats, using the file extension.

```
music_box -e Analytical -o results.csv -o results.nc
```

You can also run your own configuration

```
music_box -c my_config.json
```

## Plotting
Some basic plots can be made to show concentrations throughout the simulation

### matplotlib

```
music_box -e Chapman -o output.csv --plot O1D
```

You can also make multiple plots by specifying groupings of species

```
music_box -e TS1 --plot O3 --plot PAN,HF 
```

Note that the windows may overlap each other

By default all plot units are in `mol m-3`. You can see a list of unit options to specify with `--plot-output-unit`

```
music_box -h
```

It is used like this

```
 music_box -e TS1 --plot O3 --plot-output-unit "ppb"
```

### gnuplot
If you want ascii plots (maybe you're running over ssh and can't view a graphical window), you can set
the plot tool to gnuplo (`--plot-tool gnuplot`) to view some output

```
music_box -e Chapman -o output.csv --plot O1D --plot-tool gnuplot
```

# Development and Contributing

For local development, install `music-box` as an editable installation:

```
pip install -e '.[dev]'
```

## Tests

```
pytest
```
