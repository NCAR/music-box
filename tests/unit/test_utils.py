import pytest
from acom_music_box.utils import (
    convert_time, 
    convert_pressure, 
    convert_temperature, 
    convert_concentration, 
    calculate_air_density
)
from acom_music_box.constants import GAS_CONSTANT
import math

@pytest.mark.parametrize("data, key, expected", [
  ({'time [sec]': 60}, 'time', 60),
  ({'time [min]': 1}, 'time', 60),
  ({'time [hour]': 1}, 'time', 3600),
  ({'time [day]': 1}, 'time', 86400),
])
def test_convert_time(data, key, expected):
  assert convert_time(data, key) == expected


@pytest.mark.parametrize("data, key, expected", [
  ({'pressure [Pa]': 101325}, 'pressure', 101325),
  ({'pressure [atm]': 1}, 'pressure', 101325),
  ({'pressure [bar]': 1}, 'pressure', 100000),
  ({'pressure [kPa]': 101.325}, 'pressure', 101325),
  ({'pressure [hPa]': 1013.25}, 'pressure', 101325),
])
def test_convert_pressure(data, key, expected):
  assert convert_pressure(data, key) == expected

@pytest.mark.parametrize("data, key, expected", [
  ({'temp [K]': 273.15}, 'temp', 273.15),
  ({'temp [C]': 0}, 'temp', 273.15),
  ({'temp [F]': 32}, 'temp', 273.15),
])
def test_convert_temperature(data, key, expected):
  assert convert_temperature(data, key) == expected


@pytest.mark.parametrize("data, key, temperature, pressure, expected", [
  ({'concentration [mol m-3]': 1}, 'concentration', 298.15, 101325, 1),
  ({'concentration [mol cm-3]': 1e-3}, 'concentration', 298.15, 101325, 1),
  ({'concentration [molec m-3]': 6.02214076e+23}, 'concentration', 298.15, 101325, 1),
  ({'concentration [molec cm-3]': 6.02214076e+20}, 'concentration', 298.15, 101325, 1),
  ({'concentration [molecule m-3]': 6.02214076e+23}, 'concentration', 298.15, 101325, 1),
  ({'concentration [molecule cm-3]': 6.02214076e+20}, 'concentration', 298.15, 101325, 1),
  ({'concentration [ppth]': 1e-3}, 'concentration', 298.15, 101325, 1e-6 * calculate_air_density(298.15, 101325)),
  ({'concentration [ppm]': 1}, 'concentration', 298.15, 101325, 1e-6 * calculate_air_density(298.15, 101325)),
  ({'concentration [ppb]': 1}, 'concentration', 298.15, 101325, 1e-9 * calculate_air_density(298.15, 101325)),
  ({'concentration [ppt]': 1}, 'concentration', 298.15, 101325, 1e-12 * calculate_air_density(298.15, 101325)),
  ({'concentration [mol mol-1]': 1}, 'concentration', 298.15, 101325, 1 * calculate_air_density(298.15, 101325)),
])
def test_convert_concentration(data, key, temperature, pressure, expected):
  assert math.isclose(convert_concentration(data, key, temperature, pressure), expected)

def test_invalid_concentration():
    data = {'invalid_concentration': 100}
    with pytest.raises(ValueError):
        convert_concentration(data, 'invalid_concentration', 298.15, 101325)
