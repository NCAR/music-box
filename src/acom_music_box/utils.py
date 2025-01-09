import re
from .constants import GAS_CONSTANT, AVOGADRO_CONSTANT
import numpy as np

# The possible units we can convert to and from
# functions that do conversions update this dictionary for their units in
# the appropriate way
unit_conversions = {
    'mol m-3': 0,
    'mol cm-3': 0,
    'molec m-3': 0,
    'molecule m-3': 0,
    'molec cm-3': 0,
    'molecule cm-3': 0,
    'ppth': 0,
    'ppm': 0,
    'ppb': 0,
    'ppt': 0,
    'mol mol-1': 0
}


def extract_unit(data, key):
    """Extract the value and unit from the key in data."""
    pattern = re.compile(rf'{key} \[(.+)\]')
    for k, v in data.items():
        match = pattern.match(k)
        if match:
            return float(v), match.group(1)
    return None, None


def convert_time(data, key):
    """
    Convert the time from the input data to seconds.

    Args:
        data (dict): The input data.
        key (str): The key for the time in the input data.
    Returns:
        float: The time in seconds.
    """
    time_value, unit = extract_unit(data, key)

    if unit == 'sec':
        return time_value
    elif unit == 'min':
        return time_value * 60
    elif unit in ['hour', 'hr']:
        return time_value * 3600
    elif unit == 'day':
        return time_value * 86400
    else:
        raise ValueError(f"Unsupported time unit: {unit}")


def convert_pressure(data, key):
    """
    Convert the pressure from the input data to Pascals.

    Args:
        data (dict): The input data.
        key (str): The key for the pressure in the input data.
    Returns:
        float: The pressure in Pascals.
    """
    pressure_value, unit = extract_unit(data, key)

    if unit == 'Pa':
        return pressure_value
    elif unit == 'atm':
        return pressure_value * 101325
    elif unit == 'bar':
        return pressure_value * 100000
    elif unit == 'kPa':
        return pressure_value * 1000
    elif unit in ['hPa', 'mbar']:
        return pressure_value * 100
    else:
        raise ValueError(f"Unsupported pressure unit: {unit}")


def convert_temperature(data, key):
    """
    Convert the temperature from the input data to Kelvin.

    Args:
        data (dict): The input data.
        key (str): The key for the temperature in the input data.
    Returns:
        float: The temperature in Kelvin.
    """
    temperature_value, unit = extract_unit(data, key)

    if unit == 'K':
        return temperature_value
    elif unit == 'C':
        return temperature_value + 273.15
    elif unit == 'F':
        return (temperature_value - 32) * 5 / 9 + 273.15
    else:
        raise ValueError(f"Unsupported temperature unit: {unit}")


def convert_concentration(data, key, temperature, pressure):
    """
    Convert the concentration from the input data to moles per cubic meter.
    This function assumes you are passing data from a music box configuration.

    Args:
        data (dict): The input data.
        key (str): The key for the concentration in the input data.
        temperature (float): The temperature in Kelvin.
        pressure (float): The pressure in Pascals.
    Returns:
        float: The concentration in moles per cubic meter.
    """
    concentration_value, unit = extract_unit(data, key)
    return convert_to_number_density(concentration_value, unit, temperature, pressure)


def convert_to_number_density(data, input_unit, temperature, pressure):
    """
    Convert from some other units to mol m-3

    Args:
        data (float): The data to convert in the input unit.
        input_unit (str): The input units
        temperature (float): The temperature in Kelvin.
        pressure (float): The pressure in Pascals.
    Returns:
        float: The data in the output unit.
    """

    air_density = calculate_air_density(temperature, pressure)

    conversions = {a: b for a, b in unit_conversions.items()}
    conversions.update({
        'mol m-3': 1,  # mol m-3 is the base unit
        'mol cm-3': 1e6,  # cm3 m-3
        'molec m-3': 1 / AVOGADRO_CONSTANT,  # mol
        'molecule m-3': 1 / AVOGADRO_CONSTANT,  # mol
        'molec cm-3': 1e6 / AVOGADRO_CONSTANT,  # mol cm3 m-3
        'molecule cm-3': 1e6 / AVOGADRO_CONSTANT,  # mol cm3 m-3
        'ppth': 1e-3 * air_density,  # m3 mol-1
        'ppm': 1e-6 * air_density,  # m3 mol-1
        'ppb': 1e-9 * air_density,  # m3 mol-1
        'ppt': 1e-12 * air_density,  # m3 mol-1
        'mol mol-1': 1 * air_density  # m3 mol-1
    })

    if input_unit not in conversions:
        raise ValueError(f"Unable to convert from {input_unit} to mol m-3")

    conversion_factor = conversions.get(input_unit)

    if isinstance(data, np.ndarray):
        return data * conversion_factor
    elif isinstance(data, list):
        return [x * conversion_factor for x in data]
    else:
        return data * conversion_factor


def convert_from_number_density(data, output_unit, temperature, pressure):
    """
    Convert from mol m-3 to some other units

    Args:
        data (float): The data to convert in mol m-3.
        output_unit (str): The output units
        temperature (float): The temperature in Kelvin.
        pressure (float): The pressure in Pascals.
    Returns:
        float: The data in the output unit.
    """

    air_density = calculate_air_density(temperature, pressure)

    conversions = {a: b for a, b in unit_conversions.items()}
    conversions.update({
        'mol m-3': 1,  # mol m-3 is the base unit
        'mol cm-3': 1e-6,  # m3 cm-3
        'molec m-3': 1 * AVOGADRO_CONSTANT,  # mol-1
        'molecule m-3': 1 * AVOGADRO_CONSTANT,  # mol-1
        'molec cm-3': 1e-6 * AVOGADRO_CONSTANT,  # m3 cm-3 mol-1
        'molecule cm-3': 1e-6 * AVOGADRO_CONSTANT,  # m3 cm-3 mol-1
        'ppth': 1e3 / air_density,  # unitless
        'ppm': 1e6 / air_density,  # unitless
        'ppb': 1e9 / air_density,  # unitless
        'ppt': 1e12 / air_density,  # unitless
        'mol mol-1': 1 / air_density  # unitless
    })

    if output_unit not in conversions:
        raise ValueError(f"Unable to convert from mol m-3 to {output_unit}")

    conversion_factor = conversions.get(output_unit)

    if isinstance(data, np.ndarray):
        return data * conversion_factor
    elif isinstance(data, list):
        return [x * conversion_factor for x in data]
    else:
        return data * conversion_factor


def calculate_air_density(temperature, pressure):
    """
    Calculate the air density in moles m-3

    Args:
        temperature (float): The temperature in Kelvin.
        pressure (float): The pressure in Pascals.
    Returns:
        float: The air density in moles m-3
    """
    return pressure / (GAS_CONSTANT * temperature)


def get_available_units():
    """
    Get the list of available units for conversion.

    Returns:
        list: The list of available units.
    """
    return list(unit_conversions.keys())
