"""
Unit tests for the ConditionsManager class.
"""
import pytest
import pandas as pd
import numpy as np
import tempfile
import os
import json
import logging

from acom_music_box.conditions_manager import ConditionsManager

logger = logging.getLogger(__name__)


class TestConditionsManager:

    def test_initialization(self):
        """Test that a new ConditionsManager initializes correctly."""
        manager = ConditionsManager()
        assert len(manager) == 0
        assert not manager.has_conditions()

    def test_set_single_condition(self):
        """Test setting a single condition at one time point."""
        manager = ConditionsManager()
        manager.set_condition(time=0, temperature=300, pressure=101325)

        assert manager.has_conditions()
        assert len(manager) == 1
        assert 0 in manager.get_times()

        conds = manager.get_conditions_at_time(0)
        assert conds["temperature"] == 300
        assert conds["pressure"] == 101325

    def test_set_multiple_times(self):
        """Test setting conditions at multiple time points."""
        manager = ConditionsManager()
        manager.set_condition(time=0, temperature=300, pressure=101325)
        manager.set_condition(time=3600, temperature=310, pressure=101000)

        assert len(manager) == 2
        assert 0 in manager.get_times()
        assert 3600 in manager.get_times()

        conds_0 = manager.get_conditions_at_time(0)
        assert conds_0["temperature"] == 300

        conds_3600 = manager.get_conditions_at_time(3600)
        assert conds_3600["temperature"] == 310

    def test_upsert_existing_time(self):
        """Test that setting conditions at an existing time updates rather than duplicates."""
        manager = ConditionsManager()
        manager.set_condition(time=0, temperature=300)
        manager.set_condition(time=0, pressure=101325)

        assert len(manager) == 1

        conds = manager.get_conditions_at_time(0)
        assert conds["temperature"] == 300
        assert conds["pressure"] == 101325

    def test_method_chaining(self):
        """Test that set_condition returns self for method chaining."""
        manager = ConditionsManager()
        result = (manager
                  .set_condition(time=0, temperature=300)
                  .set_condition(time=3600, temperature=310))

        assert result is manager
        assert len(manager) == 2

    def test_step_interpolation(self):
        """Test step interpolation behavior."""
        manager = ConditionsManager()
        manager.set_condition(time=0, temperature=300, pressure=101325)
        manager.set_condition(time=3600, temperature=310, pressure=101000)

        # Interpolate at intermediate times
        conds_1800 = manager.get_conditions_at_time(1800)
        assert conds_1800["temperature"] == 300  # Should hold previous value

        conds_3600 = manager.get_conditions_at_time(3600)
        assert conds_3600["temperature"] == 310

        conds_5400 = manager.get_conditions_at_time(5400)
        assert conds_5400["temperature"] == 310  # Should hold last value

    def test_get_interpolated_dataframe(self):
        """Test building fully interpolated DataFrame."""
        manager = ConditionsManager()
        manager.set_condition(time=0, temperature=300, pressure=101325)
        manager.set_condition(time=100, temperature=310)

        df = manager.get_interpolated(simulation_length=200, output_step=50)

        assert len(df) == 5  # 0, 50, 100, 150, 200
        assert list(df["time.s"]) == [0, 50, 100, 150, 200]

        # Check step interpolation
        assert df["ENV.temperature.K"].iloc[0] == 300
        assert df["ENV.temperature.K"].iloc[1] == 300  # t=50, holds value from t=0
        assert df["ENV.temperature.K"].iloc[2] == 310  # t=100
        assert df["ENV.temperature.K"].iloc[3] == 310  # t=150, holds value from t=100
        assert df["ENV.temperature.K"].iloc[4] == 310  # t=200

    def test_concentrations_dict(self):
        """Test setting concentrations via dictionary."""
        manager = ConditionsManager()
        manager.set_condition(time=0, concentrations={"A": 1.0, "B": 0.5})

        conds = manager.get_conditions_at_time(0)
        assert conds["species_concentrations"]["A"] == 1.0
        assert conds["species_concentrations"]["B"] == 0.5

    def test_rate_parameters(self):
        """Test setting rate parameters."""
        manager = ConditionsManager()
        manager.set_condition(time=0, rate_parameters={
            "EMIS.NO.mol m-3 s-1": 1e-10,
            "PHOTO.O3_1.s-1": 0.001
        })

        conds = manager.get_conditions_at_time(0)
        assert "EMIS.NO.mol m-3 s-1" in conds["rate_parameters"]
        assert conds["rate_parameters"]["EMIS.NO.mol m-3 s-1"] == 1e-10

    def test_dataframe_input(self):
        """Test setting conditions from a DataFrame."""
        manager = ConditionsManager()

        df = pd.DataFrame({
            "time.s": [0, 3600],
            "ENV.temperature.K": [300, 310],
            "ENV.pressure.Pa": [101325, 101000],
            "CONC.A.mol m-3": [1.0, 0.5]
        })
        manager.set_from_dataframe(df)

        assert len(manager) == 2

        conds_0 = manager.get_conditions_at_time(0)
        assert conds_0["temperature"] == 300
        assert conds_0["species_concentrations"]["A"] == 1.0

        conds_3600 = manager.get_conditions_at_time(3600)
        assert conds_3600["temperature"] == 310
        assert conds_3600["species_concentrations"]["A"] == 0.5

    def test_add_from_dataframe_merge(self):
        """Test merging conditions from a DataFrame."""
        manager = ConditionsManager()
        manager.set_condition(time=0, temperature=300)

        df = pd.DataFrame({
            "time.s": [0, 3600],
            "ENV.pressure.Pa": [101325, 101000]
        })
        manager.add_from_dataframe(df)

        assert len(manager) == 2

        conds_0 = manager.get_conditions_at_time(0)
        assert conds_0["temperature"] == 300
        assert conds_0["pressure"] == 101325

    def test_validation_unknown_prefix(self):
        """Test that unknown column prefixes raise errors."""
        manager = ConditionsManager()

        with pytest.raises(ValueError, match="Invalid rate parameter format"):
            manager.set_condition(time=0, rate_parameters={"INVALID.param.unit": 1.0})

    def test_validation_dataframe_no_time(self):
        """Test that DataFrames without time.s column raise errors."""
        manager = ConditionsManager()

        df = pd.DataFrame({"ENV.temperature.K": [300]})

        with pytest.raises(ValueError, match="time.s"):
            manager.set_from_dataframe(df)

    def test_time_zero_warning_and_default(self):
        """Test warning and default values for missing time=0 conditions."""
        import warnings

        manager = ConditionsManager()
        manager.set_condition(time=3600, temperature=310)

        # Capture warnings
        with warnings.catch_warnings(record=True):
            df = manager.get_interpolated(simulation_length=100, output_step=50)

        # Should have added default values at time=0
        assert df["ENV.temperature.K"].iloc[0] == ConditionsManager.DEFAULT_TEMPERATURE
        assert df["ENV.pressure.Pa"].iloc[0] == ConditionsManager.DEFAULT_PRESSURE

    def test_template_generation(self):
        """Test generating a condition template."""
        manager = ConditionsManager()
        template = manager.get_template()

        assert "time.s" in template.columns
        assert "ENV.temperature.K" in template.columns
        assert "ENV.pressure.Pa" in template.columns
        assert len(template) == 1
        assert pd.isna(template["time.s"].iloc[0])

    def test_raw_property(self):
        """Test that raw property returns uninterpolated data."""
        manager = ConditionsManager()
        manager.set_condition(time=0, temperature=300)
        manager.set_condition(time=3600, temperature=310)

        raw_df = manager.raw
        assert len(raw_df) == 2
        assert list(raw_df["time.s"]) == [0, 3600]

    def test_normalize_legacy_column_bracket_format(self):
        """Test normalizing legacy bracket format columns."""
        manager = ConditionsManager()

        # Test bracket format conversion
        assert manager._normalize_legacy_column("ENV.temperature [K]") == "ENV.temperature.K"
        assert manager._normalize_legacy_column("CONC.A [mol m-3]") == "CONC.A.mol m-3"
        assert manager._normalize_legacy_column("PHOTO.O3 [s-1]") == "PHOTO.O3.s-1"

    def test_normalize_legacy_column_already_new_format(self):
        """Test that already normalized columns pass through."""
        manager = ConditionsManager()

        assert manager._normalize_legacy_column("ENV.temperature.K") == "ENV.temperature.K"
        assert manager._normalize_legacy_column("CONC.A.mol m-3") == "CONC.A.mol m-3"

    def test_load_from_json_config_legacy_format(self):
        """Test loading from legacy JSON config format."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create a test config file
            config = {
                "environmental conditions": {
                    "temperature": {"initial value [K]": 300},
                    "pressure": {"initial value [Pa]": 101325}
                },
                "initial conditions": {
                    "data": [
                        ["CONC.A [mol m-3]", "CONC.B [mol m-3]"],
                        [1.0, 0.5]
                    ]
                }
            }

            config_path = os.path.join(tmpdir, "config.json")
            with open(config_path, 'w') as f:
                json.dump(config, f)

            manager = ConditionsManager.from_config(config_path, config)

            conds = manager.get_conditions_at_time(0)
            assert conds["temperature"] == 300
            assert conds["pressure"] == 101325
            assert conds["species_concentrations"]["A"] == 1.0
            assert conds["species_concentrations"]["B"] == 0.5

    def test_load_from_json_config_new_format(self):
        """Test loading from new unified JSON config format."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create a test config file
            config = {
                "conditions": {
                    "data": [
                        {
                            "headers": ["time.s", "ENV.temperature.K", "ENV.pressure.Pa", "CONC.A.mol m-3"],
                            "rows": [
                                [0.0, 300.0, 101325.0, 1.0],
                                [3600.0, 310.0, 101000.0, 0.5]
                            ]
                        }
                    ]
                }
            }

            config_path = os.path.join(tmpdir, "config.json")
            with open(config_path, 'w') as f:
                json.dump(config, f)

            manager = ConditionsManager.from_config(config_path, config)

            assert len(manager) == 2

            conds_0 = manager.get_conditions_at_time(0)
            assert conds_0["temperature"] == 300.0
            assert conds_0["species_concentrations"]["A"] == 1.0

            conds_3600 = manager.get_conditions_at_time(3600)
            assert conds_3600["temperature"] == 310.0

    def test_load_from_csv_file(self):
        """Test loading conditions from CSV file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create a test CSV file
            csv_content = """time.s,ENV.temperature.K,ENV.pressure.Pa,CONC.A.mol m-3
0.0,300.0,101325.0,1.0
3600.0,310.0,101000.0,0.5
"""
            csv_path = os.path.join(tmpdir, "conditions.csv")
            with open(csv_path, 'w') as f:
                f.write(csv_content)

            config = {
                "conditions": {
                    "filepaths": ["conditions.csv"]
                }
            }

            config_path = os.path.join(tmpdir, "config.json")
            with open(config_path, 'w') as f:
                json.dump(config, f)

            manager = ConditionsManager.from_config(config_path, config)

            assert len(manager) == 2

            conds_0 = manager.get_conditions_at_time(0)
            assert conds_0["temperature"] == 300.0

    def test_get_conditions_before_first_time(self):
        """Test getting conditions before first specified time returns defaults."""
        manager = ConditionsManager()
        manager.set_condition(time=100, temperature=310)

        conds = manager.get_conditions_at_time(50)
        assert conds["temperature"] == ConditionsManager.DEFAULT_TEMPERATURE
        assert conds["pressure"] == ConditionsManager.DEFAULT_PRESSURE

    def test_concentration_normalization(self):
        """Test that concentration columns are normalized correctly."""
        manager = ConditionsManager()

        # Test various input formats
        manager.set_condition(time=0, concentrations={"A": 1.0})
        manager.set_condition(time=0, concentrations={"CONC.B.mol m-3": 2.0})

        conds = manager.get_conditions_at_time(0)
        assert conds["species_concentrations"]["A"] == 1.0
        assert conds["species_concentrations"]["B"] == 2.0

    def test_surf_rate_parameter_format(self):
        """Test SURF rate parameter format handling."""
        manager = ConditionsManager()
        manager.set_condition(time=0, rate_parameters={
            "SURF.surface.particle number concentration.# m-3": 1e12,
            "SURF.surface.effective radius.m": 1e-7
        })

        conds = manager.get_conditions_at_time(0)
        assert "SURF.surface.particle number concentration.# m-3" in conds["rate_parameters"]
        assert conds["rate_parameters"]["SURF.surface.particle number concentration.# m-3"] == 1e12


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
