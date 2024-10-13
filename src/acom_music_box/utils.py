import re
from .constants import GAS_CONSTANT, AVOGADRO_CONSTANT


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

    Args:
        data (dict): The input data.
        key (str): The key for the concentration in the input data.
        temperature (float): The temperature in Kelvin.
        pressure (float): The pressure in Pascals.
    Returns:
        float: The concentration in moles per cubic meter.
    """
    concentration_value, unit = extract_unit(data, key)
    air_density = calculate_air_density(temperature, pressure)

    unit_conversions = {
        'mol m-3': 1,  # mol m-3 is the base unit
        'mol cm-3': 1e6,  # cm3 m-3
        'molec m-3': 1 / AVOGADRO_CONSTANT,  # mol
        'molecule m-3': 1 / AVOGADRO_CONSTANT,  # mol
        'molec cm-3': 1e6 / AVOGADRO_CONSTANT,  # mol cm3 m-3
        'molecule cm-3': 1e6 / AVOGADRO_CONSTANT,  # mol cm3 m-3
        'ppth': 1e-3 * air_density,  # moles / m^3
        'ppm': 1e-6 * air_density,  # moles / m^3
        'ppb': 1e-9 * air_density,  # moles / m^3
        'ppt': 1e-12 * air_density,  # moles / m^3
        'mol mol-1': 1 * air_density  # moles / m^3
    }

    if unit in unit_conversions:
        return concentration_value * unit_conversions[unit]
    else:
        raise ValueError(f"Unsupported concentration unit: {unit}")


def calculate_air_density(temperature, pressure):
    """
    Calculate the air density in moles/m^3.

    Args:
        temperature (float): The temperature in Kelvin.
        pressure (float): The pressure in Pascals.
    Returns:
        float: The air density in moles/m^3.
    """
    return pressure / (GAS_CONSTANT * temperature)
