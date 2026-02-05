"""
Conditions manager for handling simulation conditions in a unified DataFrame-based API.
"""
import pandas as pd
import numpy as np
import os
import logging

logger = logging.getLogger(__name__)


class ConditionsManager:
    """
    Internal class for managing simulation conditions using a DataFrame-based approach.

    This class provides a unified API for setting and retrieving conditions at specific
    times, with support for step interpolation to build a fully interpolated DataFrame
    at all simulation timesteps.

    Attributes:
        _df: pd.DataFrame - sparse storage (only user-specified times)
        _mechanism - reference for validation (optional)
    """

    # Column naming constants
    TIME_COLUMN = "time.s"
    TEMPERATURE_COLUMN = "ENV.temperature.K"
    PRESSURE_COLUMN = "ENV.pressure.Pa"

    # Valid prefixes for condition types
    VALID_PREFIXES = {"ENV", "CONC", "EMIS", "PHOTO", "LOSS", "USER", "SURF"}

    # Default values for required conditions
    DEFAULT_TEMPERATURE = 298.15  # K
    DEFAULT_PRESSURE = 101325.0  # Pa
    DEFAULT_CONCENTRATION = 0.0  # mol m-3

    def __init__(self, mechanism=None):
        """
        Initialize a new ConditionsManager.

        Args:
            mechanism: Optional mechanism reference for validation.
        """
        self._df = pd.DataFrame({self.TIME_COLUMN: pd.Series(dtype=float)})
        self._concentration_events = {}  # {time: {species: value}}
        self._mechanism = mechanism

    @property
    def raw(self) -> pd.DataFrame:
        """
        Returns the raw (sparse) DataFrame with only user-specified times.
        Contains ENV.*, PHOTO.*, EMIS.*, etc. but NOT concentrations.
        """
        return self._df.copy()

    @property
    def concentration_events(self) -> dict:
        """
        Returns the concentration events dictionary.

        Concentrations are only applied at exact times specified, not interpolated.
        Format: {time: {species_name: value}}

        Example:
            {0.0: {"A": 1.0, "B": 0.5}, 300.0: {"D": 1.0}}
        """
        return self._concentration_events.copy()

    def set_mechanism(self, mechanism):
        """
        Set the mechanism reference for validation.

        Args:
            mechanism: The mechanism to use for validation.
        """
        self._mechanism = mechanism

    def set_condition(
        self,
        time: float,
        *,
        temperature: float = None,
        pressure: float = None,
        concentrations: dict = None,
        rate_parameters: dict = None
    ) -> 'ConditionsManager':
        """
        Set conditions at a specific time. Returns self for chaining.

        Args:
            time: The time point in seconds.
            temperature: Temperature in Kelvin (optional).
            pressure: Pressure in Pascals (optional).
            concentrations: Dictionary of species name to concentration in mol m-3.
            rate_parameters: Dictionary of rate parameter names to values.
                             Keys should be in format: PREFIX.name.unit or PREFIX.name

        Returns:
            self for method chaining.
        """
        # Find or create row for this time
        time_mask = self._df[self.TIME_COLUMN] == time
        if not time_mask.any():
            # Create new row
            new_row = pd.DataFrame({self.TIME_COLUMN: [time]})
            self._df = pd.concat([self._df, new_row], ignore_index=True)
            self._df = self._df.sort_values(self.TIME_COLUMN).reset_index(drop=True)
            time_mask = self._df[self.TIME_COLUMN] == time

        row_idx = self._df.index[time_mask][0]

        # Set temperature if provided
        if temperature is not None:
            self._df.loc[row_idx, self.TEMPERATURE_COLUMN] = temperature

        # Set pressure if provided
        if pressure is not None:
            self._df.loc[row_idx, self.PRESSURE_COLUMN] = pressure

        # Set concentrations if provided (stored separately, not in _df)
        if concentrations:
            if time not in self._concentration_events:
                self._concentration_events[time] = {}
            for species, value in concentrations.items():
                # Normalize species name (strip CONC. prefix if present)
                species_name = species
                if species.startswith("CONC."):
                    parts = species.split(".")
                    species_name = parts[1] if len(parts) >= 2 else species
                self._validate_species(species_name)
                self._concentration_events[time][species_name] = value

        # Set rate parameters if provided
        if rate_parameters:
            for param_name, value in rate_parameters.items():
                col_name = self._normalize_rate_parameter_column(param_name)
                self._validate_rate_parameter(param_name)
                self._df.loc[row_idx, col_name] = value

        return self

    def _normalize_concentration_column(self, species: str) -> str:
        """
        Normalize a species name to a concentration column name.

        Args:
            species: Species name (e.g., "A" or "CONC.A.mol m-3")

        Returns:
            Normalized column name (e.g., "CONC.A.mol m-3")
        """
        if species.startswith("CONC."):
            return species if "." in species[5:] else f"{species}.mol m-3"
        return f"CONC.{species}.mol m-3"

    def _normalize_rate_parameter_column(self, param_name: str) -> str:
        """
        Normalize a rate parameter name to a column name.

        Args:
            param_name: Rate parameter name (e.g., "EMIS.NO.mol m-3 s-1")

        Returns:
            Normalized column name.
        """
        parts = param_name.split(".")
        if len(parts) >= 2 and parts[0] in self.VALID_PREFIXES:
            return param_name
        raise ValueError(
            f"Invalid rate parameter format: {param_name}. "
            f"Expected format: PREFIX.name.unit where PREFIX is one of {self.VALID_PREFIXES}"
        )

    def _validate_species(self, species: str):
        """
        Validate that a species exists in the mechanism.

        Args:
            species: Species name to validate.

        Raises:
            ValueError: If the species is not found in the mechanism.
        """
        if self._mechanism is None:
            return

        # Extract species name from column format
        if species.startswith("CONC."):
            species = species.split(".")[1]

        try:
            species_names = [s.name for s in self._mechanism.species]
            if species not in species_names:
                raise ValueError(
                    f"Unknown species: {species}. "
                    f"Available species: {species_names}"
                )
        except (AttributeError, TypeError):
            # Mechanism doesn't support species listing
            pass

    def _validate_rate_parameter(self, param_name: str):
        """
        Validate that a rate parameter is valid.

        Args:
            param_name: Rate parameter name to validate.

        Raises:
            ValueError: If the rate parameter format is invalid.
        """
        parts = param_name.split(".")
        if len(parts) < 2:
            raise ValueError(
                f"Invalid rate parameter format: {param_name}. "
                f"Expected format: PREFIX.name.unit"
            )

        prefix = parts[0]
        if prefix not in self.VALID_PREFIXES:
            raise ValueError(
                f"Invalid prefix in rate parameter: {prefix}. "
                f"Expected one of: {self.VALID_PREFIXES}"
            )

    def set_from_dataframe(self, df: pd.DataFrame) -> 'ConditionsManager':
        """
        Replace all conditions from a DataFrame. Must have 'time.s' column.

        CONC.* columns are extracted to concentration_events (exact time only).
        All other columns are stored in _df with step interpolation.

        Args:
            df: DataFrame with conditions. Must have 'time.s' column.

        Returns:
            self for method chaining.

        Raises:
            ValueError: If DataFrame doesn't have 'time.s' column.
        """
        if self.TIME_COLUMN not in df.columns:
            raise ValueError(f"DataFrame must have '{self.TIME_COLUMN}' column")

        self._validate_columns(df.columns)

        # Separate CONC columns from other columns
        conc_cols = [c for c in df.columns if c.startswith("CONC.")]
        other_cols = [c for c in df.columns if not c.startswith("CONC.")]

        # Store non-concentration columns in _df
        self._df = df[other_cols].copy()
        self._df = self._df.sort_values(self.TIME_COLUMN).reset_index(drop=True)

        # Store concentration columns in _concentration_events
        self._concentration_events = {}
        if conc_cols:
            for _, row in df.iterrows():
                time = float(row[self.TIME_COLUMN])
                concs = {}
                for col in conc_cols:
                    if pd.notna(row[col]):
                        species = col.split(".")[1]
                        concs[species] = row[col]
                if concs:
                    self._concentration_events[time] = concs

        return self

    def add_from_dataframe(self, df: pd.DataFrame) -> 'ConditionsManager':
        """
        Merge DataFrame with existing conditions.

        CONC.* columns are extracted to concentration_events (exact time only).
        All other columns are merged into _df with step interpolation.

        Args:
            df: DataFrame with conditions to merge. Must have 'time.s' column.

        Returns:
            self for method chaining.

        Raises:
            ValueError: If DataFrame doesn't have 'time.s' column.
        """
        if self.TIME_COLUMN not in df.columns:
            raise ValueError(f"DataFrame must have '{self.TIME_COLUMN}' column")

        self._validate_columns(df.columns)

        # Separate CONC columns from other columns
        conc_cols = [c for c in df.columns if c.startswith("CONC.")]
        other_cols = [c for c in df.columns if not c.startswith("CONC.")]

        # Merge non-concentration columns into _df
        for _, row in df.iterrows():
            time = float(row[self.TIME_COLUMN])
            time_mask = self._df[self.TIME_COLUMN] == time

            if time_mask.any():
                # Update existing row
                row_idx = self._df.index[time_mask][0]
                for col in other_cols:
                    if col != self.TIME_COLUMN and pd.notna(row[col]):
                        self._df.loc[row_idx, col] = row[col]
            else:
                # Add new row (only non-CONC columns)
                new_row = row[other_cols].to_frame().T
                self._df = pd.concat([self._df, new_row], ignore_index=True)

            # Store concentration columns in _concentration_events
            if conc_cols:
                concs = {}
                for col in conc_cols:
                    if pd.notna(row[col]):
                        species = col.split(".")[1]
                        concs[species] = row[col]
                if concs:
                    # time is already converted to float above
                    if time not in self._concentration_events:
                        self._concentration_events[time] = {}
                    self._concentration_events[time].update(concs)

        self._df = self._df.sort_values(self.TIME_COLUMN).reset_index(drop=True)
        return self

    def _validate_columns(self, columns):
        """
        Validate that all columns follow the naming convention.

        Args:
            columns: Column names to validate.

        Raises:
            ValueError: If any column has an invalid format.
        """
        for col in columns:
            if col == self.TIME_COLUMN:
                continue

            parts = col.split(".")
            if len(parts) < 2:
                raise ValueError(
                    f"Invalid column format: {col}. "
                    f"Expected format: PREFIX.name.unit"
                )

            prefix = parts[0]
            if prefix not in self.VALID_PREFIXES:
                raise ValueError(
                    f"Invalid prefix in column: {col}. "
                    f"Expected prefix to be one of: {self.VALID_PREFIXES}"
                )

    def get_interpolated(
        self,
        simulation_length: float,
        output_step: float
    ) -> pd.DataFrame:
        """
        Build fully interpolated DataFrame using step (hold previous value).

        Args:
            simulation_length: Total simulation length in seconds.
            output_step: Output time step in seconds.

        Returns:
            DataFrame with interpolated conditions at all output timesteps.
        """
        times = np.arange(0, simulation_length + output_step, output_step)
        result = pd.DataFrame({self.TIME_COLUMN: times})

        # Validate and set defaults for time=0
        self._validate_initial_conditions()

        for col in self._df.columns:
            if col == self.TIME_COLUMN:
                continue

            # Ensure column exists in result
            if col not in result.columns:
                result[col] = np.nan

            # Get non-null values
            mask = self._df[col].notna()
            if not mask.any():
                continue

            data_times = self._df.loc[mask, self.TIME_COLUMN].values
            data_values = self._df.loc[mask, col].values

            # Step interpolation: find most recent value <= each output time
            interpolated = np.full(len(times), np.nan)
            for i, t in enumerate(times):
                valid = np.where(data_times <= t)[0]
                if len(valid) > 0:
                    interpolated[i] = data_values[valid[-1]]

            result[col] = interpolated

        return result

    def _validate_initial_conditions(self):
        """
        Validate and set defaults for missing time=0 values.
        Warns and sets defaults for missing initial conditions.
        """
        # Check if time=0 exists
        time_zero_mask = self._df[self.TIME_COLUMN] == 0.0
        if not time_zero_mask.any():
            logger.warning("No conditions specified at time=0. Adding default row.")
            new_row = pd.DataFrame({self.TIME_COLUMN: [0.0]})
            self._df = pd.concat([new_row, self._df], ignore_index=True)
            self._df = self._df.sort_values(self.TIME_COLUMN).reset_index(drop=True)
            time_zero_mask = self._df[self.TIME_COLUMN] == 0.0

        row_idx = self._df.index[time_zero_mask][0]

        # Check temperature
        if self.TEMPERATURE_COLUMN not in self._df.columns or pd.isna(self._df.loc[row_idx, self.TEMPERATURE_COLUMN]):
            logger.warning(f"No initial temperature. Defaulting to {self.DEFAULT_TEMPERATURE} K")
            self._df.loc[row_idx, self.TEMPERATURE_COLUMN] = self.DEFAULT_TEMPERATURE

        # Check pressure
        if self.PRESSURE_COLUMN not in self._df.columns or pd.isna(self._df.loc[row_idx, self.PRESSURE_COLUMN]):
            logger.warning(f"No initial pressure. Defaulting to {self.DEFAULT_PRESSURE} Pa")
            self._df.loc[row_idx, self.PRESSURE_COLUMN] = self.DEFAULT_PRESSURE

        # Check concentrations in _concentration_events
        # Note: We don't warn for missing concentrations since they default to 0
        # in the solver. Users may intentionally start with zero concentrations.

    def get_template(self) -> pd.DataFrame:
        """
        Returns DataFrame with all possible columns from mechanism (all NaN).

        Returns:
            DataFrame template with 'time.s' and all mechanism columns.
        """
        columns = [self.TIME_COLUMN, self.TEMPERATURE_COLUMN, self.PRESSURE_COLUMN]

        if self._mechanism is not None:
            try:
                # Add species concentration columns
                for species in self._mechanism.species:
                    columns.append(f"CONC.{species.name}.mol m-3")

                # Add reaction rate columns based on reaction types
                for reaction in self._mechanism.reactions:
                    reaction_type = type(reaction).__name__.upper()
                    if hasattr(reaction, 'name'):
                        name = reaction.name
                        if reaction_type == "EMISSION":
                            columns.append(f"EMIS.{name}.mol m-3 s-1")
                        elif reaction_type == "PHOTOLYSIS":
                            columns.append(f"PHOTO.{name}.s-1")
                        elif reaction_type in ("FIRSTORDERLOSS", "LOSS"):
                            columns.append(f"LOSS.{name}.s-1")
                        elif reaction_type == "SURFACE":
                            columns.append(f"SURF.{name}.particle number concentration.# m-3")
                            columns.append(f"SURF.{name}.effective radius.m")
            except (AttributeError, TypeError) as exc:
                # Failed to introspect mechanism species/reactions; fall back to basic columns only.
                logger.debug(
                    "Unable to derive condition columns from mechanism in get_template: %s",
                    exc,
                )

        # Create empty DataFrame with NaN values
        df = pd.DataFrame(columns=columns)
        df.loc[0] = [np.nan] * len(columns)
        return df

    @classmethod
    def from_config(cls, path_to_json: str, config: dict) -> 'ConditionsManager':
        """
        Load conditions from JSON configuration.

        Requires a "conditions" section in the config with the new unified format.

        Args:
            path_to_json: Path to the JSON configuration file.
            config: The configuration dictionary.

        Returns:
            A ConditionsManager instance with loaded conditions.

        Raises:
            ValueError: If the config doesn't have a "conditions" section.
        """
        manager = cls()

        if "conditions" not in config:
            raise ValueError(
                "Configuration must have a 'conditions' section. "
                "See documentation for the expected format."
            )

        manager._load_from_conditions_section(path_to_json, config["conditions"])
        return manager

    def _load_from_conditions_section(self, path_to_json: str, conditions_config: dict):
        """
        Load conditions from the "conditions" section.

        Args:
            path_to_json: Path to the JSON configuration file.
            conditions_config: The "conditions" section of the config.
        """
        base_dir = os.path.dirname(path_to_json)

        # Load from CSV filepaths
        if "filepaths" in conditions_config:
            for filepath in conditions_config["filepaths"]:
                full_path = os.path.join(base_dir, filepath)
                self._read_csv(full_path)

        # Load from inline data
        if "data" in conditions_config:
            for data_block in conditions_config["data"]:
                self._load_inline_data(data_block)

    def _read_csv(self, file_path: str):
        """
        Load conditions from a CSV file.

        Args:
            file_path: Path to the CSV file.
        """
        df = pd.read_csv(file_path, skipinitialspace=True)
        self.add_from_dataframe(df)

    def _load_inline_data(self, data_block: dict):
        """
        Load conditions from inline data block.

        Expected format:
        {
            "headers": ["time.s", "ENV.temperature.K", ...],
            "rows": [[0.0, 300.0, ...], [3600.0, 310.0, ...]]
        }

        Args:
            data_block: Dictionary with 'headers' and 'rows' keys.
        """
        headers = data_block["headers"]
        rows = data_block["rows"]

        df = pd.DataFrame(rows, columns=headers)
        self.add_from_dataframe(df)

    def get_conditions_at_time(self, time: float) -> dict:
        """
        Get conditions at a specific time.

        ENV/rate parameters use step interpolation (most recent value at or before time).
        Concentrations are only returned if there's an exact time match.

        Args:
            time: The time point in seconds.

        Returns:
            Dictionary with temperature, pressure, species_concentrations, and rate_parameters.
            species_concentrations is only populated if there's an exact time match.
        """
        # Filter to times <= given time for step interpolation
        valid_df = self._df[self._df[self.TIME_COLUMN] <= time].copy()

        if len(valid_df) == 0:
            # No conditions at or before this time, use defaults
            temperature = self.DEFAULT_TEMPERATURE
            pressure = self.DEFAULT_PRESSURE
            rate_parameters = {}
        else:
            # Sort by time to ensure proper order for step interpolation
            valid_df = valid_df.sort_values(self.TIME_COLUMN)

            # For each column, find the most recent non-NaN value (step interpolation)
            def get_most_recent_value(col):
                """Get the most recent non-NaN value for a column."""
                if col not in valid_df.columns:
                    return None
                non_null = valid_df[col].dropna()
                if len(non_null) == 0:
                    return None
                return non_null.iloc[-1]

            # Get temperature and pressure with defaults
            temperature = get_most_recent_value(self.TEMPERATURE_COLUMN)
            if temperature is None:
                temperature = self.DEFAULT_TEMPERATURE

            pressure = get_most_recent_value(self.PRESSURE_COLUMN)
            if pressure is None:
                pressure = self.DEFAULT_PRESSURE

            rate_parameters = {}
            for col in self._df.columns:
                if col in [self.TIME_COLUMN, self.TEMPERATURE_COLUMN, self.PRESSURE_COLUMN]:
                    continue

                value = get_most_recent_value(col)
                if value is None:
                    continue

                # Skip any CONC columns that might still be in _df (legacy)
                if col.startswith("CONC."):
                    continue

                # Skip ENV columns that aren't temperature or pressure
                # (e.g., ENV.air_density.kg which is computed, not input)
                if col.startswith("ENV."):
                    continue

                rate_parameters[col] = value

        # Concentrations: only return if there's an exact time match
        species_concentrations = self._concentration_events.get(time, {})

        return {
            "temperature": temperature,
            "pressure": pressure,
            "species_concentrations": species_concentrations,
            "rate_parameters": rate_parameters
        }

    def has_conditions(self) -> bool:
        """Check if any conditions have been set."""
        has_df_conditions = len(self._df) > 0 and not self._df[self.TIME_COLUMN].isna().all()
        has_concentration_events = len(self._concentration_events) > 0
        return has_df_conditions or has_concentration_events

    def get_times(self) -> list:
        """Get list of times where conditions are specified (including concentration events)."""
        df_times = set(self._df[self.TIME_COLUMN].dropna().tolist())
        conc_times = set(self._concentration_events.keys())
        return sorted(df_times | conc_times)

    def __len__(self) -> int:
        """Return number of time points with conditions."""
        return len(self._df[self.TIME_COLUMN].dropna())
