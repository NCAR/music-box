def convert_time(data, key):
    """
    Convert the time from the input data to seconds.

    Args:
        data (dict): The input data.
        key (str): The key for the time in the input data.

    Returns:
        float: The time in seconds.
    """
    time = None

    for unit in ['sec', 'min', 'hour', 'hr', 'day']:
        if f'{key} [{unit}]' in data:
            time_value = float(data[f'{key} [{unit}]'])
            if unit == 'sec':
                time = time_value
            elif unit == 'min':
                time = time_value * 60
            elif unit == 'hour' or unit == 'hr':
                time = time_value * 3600
            elif unit == 'day':
                time = time_value * 86400
            break
    return time


def convert_pressure(data, key):
    """
    Convert the pressure from the input data to Pascals.

    Args:
        data (dict): The input data.
        key (str): The key for the pressure in the input data.

    Returns:
        float: The pressure in Pascals.
    """
    pressure = None
    for unit in ['Pa', 'atm', 'bar', 'kPa', 'hPa', 'mbar']:
        if f'{key} [{unit}]' in data:
            pressure_value = float(data[f'{key} [{unit}]'])
            if unit == 'Pa':
                pressure = pressure_value
            elif unit == 'atm':
                pressure = pressure_value * 101325
            elif unit == 'bar':
                pressure = pressure_value * 100000
            elif unit == 'kPa':
                pressure = pressure_value * 1000
            elif unit == 'hPa' or unit == 'mbar':
                pressure = pressure_value * 100
            break
    return pressure


def convert_temperature(data, key):
    """
    Convert the temperature from the input data to Kelvin.

    Args:
        data (dict): The input data.
        key (str): The key for the temperature in the input data.

    Returns:
        float: The temperature in Kelvin.
    """
    temperature = None
    for unit in ['K', 'C', 'F']:
        if f'{key} [{unit}]' in data:
            temperature_value = float(data[f'{key} [{unit}]'])
            if unit == 'K':
                temperature = temperature_value
            elif unit == 'C':
                temperature = temperature_value + 273.15
            elif unit == 'F':
                temperature = (temperature_value - 32) * 5 / 9 + 273.15
            break
    return temperature


def convert_concentration(data, key):
    """
    Convert the concentration from the input data to molecules per cubic meter.

    Args:
        data (dict): The input data.
        key (str): The key for the concentration in the input data.

    Returns:
        float: The concentration in molecules per cubic meter.
    """
    concentration = None
    for unit in ['mol m-3', 'mol cm-3', 'molec m-3', 'molec cm-3']:
        if f'{key} [{unit}]' in data:
            concentration_value = float(data[f'{key} [{unit}]'])
            if unit == 'mol m-3':
                concentration = concentration_value
            elif unit == 'mol cm-3':
                concentration = concentration_value * 1e3
            elif unit == 'molec m-3':
                concentration = concentration_value / 6.02214076e23
            elif unit == 'molec cm-3':
                concentration = concentration_value * 1e3 / 6.02214076e23
            break
    return concentration
