"""Write MusicBox results in a format compatible with permm.

permm (https://github.com/barronh/permm) performs process analysis on chemical
mechanisms. It consumes two inputs:

1. a YAML mechanism file with ``species_list``, ``reaction_list`` (and optionally
   ``species_group_list``), where each reaction is written as
   ``"R1 + R2 ->[k] c*P1 + ..."`` (``->[j]`` for photolysis), and
2. an IOAPI-style NetCDF holding the integrated reaction rate (IRR) of every
   reaction, one variable per reaction (named to match the ``reaction_list`` key).

MusicBox mechanisms carry an inert product ``irr__<uuid>`` on every reaction whose
concentration is the accumulated integrated reaction rate for that reaction. This
writer reads those tracers straight out of the solved results, so no per-reaction
rate instrumentation is needed. The IRR values are written cumulatively (as-is).
"""

import logging
import os

import numpy as np
import xarray as xr
import yaml

logger = logging.getLogger(__name__)

# Prefix that marks a MusicBox integrated-reaction-rate accumulator tracer.
IRR_TRACER_PREFIX = "irr__"
# Suffix permm expects on reaction names / IRR variable names.
IRR_SUFFIX = "_IRR"


class ProcessAnalysisOutput:
    """Write a solved MusicBox result as a permm mechanism YAML + IRR NetCDF.

    Parameters
    ----------
    df : pandas.DataFrame
        The solved results from :meth:`MusicBox.solve`, with a ``time.s`` column
        and one ``CONC.<species>.mol m-3`` column per species (including the
        ``irr__<uuid>`` accumulator tracers).
    mechanism : musica.mechanism_configuration.Mechanism
        The mechanism used for the run (``MusicBox.mechanism``).
    out_path : str
        Output path/prefix. ``<out_path>.yaml`` and ``<out_path>.nc`` are written.
        Any extension on ``out_path`` is stripped first.
    """

    def __init__(self, df, mechanism, out_path):
        self.df = df
        self.mechanism = mechanism
        # Treat out_path as a prefix; drop a trailing extension if one was given.
        root, _ = os.path.splitext(out_path)
        self.prefix = root or out_path
        self.yaml_path = self.prefix + ".yaml"
        self.nc_path = self.prefix + ".nc"

    # -- reaction introspection -------------------------------------------------

    @staticmethod
    def _reactants(rxn):
        """Return the reactant components of a reaction, regardless of type."""
        if hasattr(rxn, "reactants") and rxn.reactants is not None:
            return list(rxn.reactants)
        # Surface reactions expose a single gas-phase reactant.
        if getattr(rxn, "gas_phase_species", None) is not None:
            return [rxn.gas_phase_species]
        return []

    @staticmethod
    def _products(rxn):
        """Return the product components of a reaction, regardless of type."""
        if hasattr(rxn, "products") and rxn.products is not None:
            return list(rxn.products)
        if hasattr(rxn, "gas_phase_products") and rxn.gas_phase_products is not None:
            return list(rxn.gas_phase_products)
        return []

    @staticmethod
    def _is_photolysis(rxn):
        return type(rxn).__name__ == "Photolysis"

    @staticmethod
    def _format_component(component):
        """Format a reactant/product as ``name`` or ``coef*name`` (coef != 1)."""
        coef = getattr(component, "coefficient", 1.0)
        if coef is None:
            coef = 1.0
        name = component.name
        if abs(coef - 1.0) < 1e-12:
            return name
        # ``:g`` keeps the string compact (2.0 -> "2", 0.65 -> "0.65").
        return f"{coef:g}*{name}"

    def _reaction_records(self):
        """Build the ordered list of permm reactions from the mechanism.

        Returns a list of dicts with keys ``name`` (unique, ``*_IRR``),
        ``equation`` (permm reaction string) and ``irr`` (the ``irr__`` tracer
        species name, or ``None`` if the reaction has no accumulator).
        """
        records = []
        used_names = {}
        for rxn in self.mechanism.reactions:
            reactants = self._reactants(rxn)
            products = self._products(rxn)

            irr_products = [p for p in products if p.name.startswith(IRR_TRACER_PREFIX)]
            real_products = [p for p in products if not p.name.startswith(IRR_TRACER_PREFIX)]
            irr_name = irr_products[0].name if irr_products else None

            photolysis = self._is_photolysis(rxn)
            arrow = "->[j]" if photolysis else "->[k]"

            reactant_names = [c.name for c in reactants]
            base = "_".join(reactant_names)
            if photolysis:
                base = (base + "_HV") if base else "HV"
            if not base:
                # Fall back to the reaction's own name (e.g. emissions with no reactants).
                base = getattr(rxn, "name", "") or type(rxn).__name__

            name = self._unique_name(base + IRR_SUFFIX, used_names)

            lhs = " + ".join(self._format_component(c) for c in reactants)
            rhs = " + ".join(self._format_component(c) for c in real_products)
            equation = f"{lhs} {arrow} {rhs}".strip()

            records.append({"name": name, "equation": equation, "irr": irr_name})
        return records

    @staticmethod
    def _unique_name(name, used_names):
        """Disambiguate duplicate reaction names with _a, _b, ... before _IRR."""
        if name not in used_names:
            used_names[name] = 0
            return name
        used_names[name] += 1
        # Insert the disambiguating letter before the _IRR suffix, permm-style.
        letter = chr(ord("a") + used_names[name] - 1)
        if name.endswith(IRR_SUFFIX):
            candidate = f"{name[:-len(IRR_SUFFIX)]}_{letter}{IRR_SUFFIX}"
        else:
            candidate = f"{name}_{letter}"
        # Guard against the (unlikely) case that the disambiguated name also collides.
        return ProcessAnalysisOutput._unique_name(candidate, used_names) if candidate in used_names else candidate

    # -- species / concentration lookup ----------------------------------------

    def _conc_column_map(self):
        """Map species name -> its ``CONC.<species>.mol m-3`` column in the result."""
        mapping = {}
        for col in self.df.columns:
            if col.startswith("CONC."):
                species = col[len("CONC."):].rsplit(".", 1)[0]
                mapping[species] = col
        return mapping

    def _real_species(self):
        """Real (non-tracer) species names declared in the mechanism."""
        return [s.name for s in self.mechanism.species if not s.name.startswith(IRR_TRACER_PREFIX)]

    # -- writers ----------------------------------------------------------------

    def _write_yaml(self, records):
        # Leave the composition empty so permm infers atoms from the species name
        # itself. (Copying the name into the value instead would break permm for
        # species like ``NO``/``YES``: permm rebuilds an unquoted YAML string and
        # YAML 1.1 then parses those names as booleans.)
        species_list = {name: "" for name in self._real_species()}
        reaction_list = {r["name"]: r["equation"] for r in records}
        doc = {
            "comment": f"permm mechanism generated by MusicBox from '{getattr(self.mechanism, 'name', 'mechanism')}'",
            "species_list": species_list,
            "reaction_list": reaction_list,
        }
        with open(self.yaml_path, "w") as handle:
            yaml.safe_dump(doc, handle, sort_keys=False, default_flow_style=False)
        logger.info(f"permm mechanism written to: {self.yaml_path}")

    def _write_netcdf(self, records):
        conc_cols = self._conc_column_map()
        time_s = self.df["time.s"].to_numpy(dtype=float)
        n_tstep = time_s.shape[0]

        data_vars = {}
        # Integrated reaction rates: one variable per reaction, matching the YAML key.
        missing = 0
        for r in records:
            irr = r["irr"]
            if irr is None or irr not in conc_cols:
                missing += 1
                continue
            values = self.df[conc_cols[irr]].to_numpy(dtype=float)
            data_vars[r["name"]] = xr.DataArray(
                values, dims=("TSTEP",), attrs={"units": "mol m-3", "long_name": r["name"]}
            )
        if missing:
            logger.warning(
                f"{missing} reaction(s) had no '{IRR_TRACER_PREFIX}' accumulator tracer; "
                "their IRR variables were omitted.")

        # Real-species concentrations (native MusicBox units).
        for species in self._real_species():
            col = conc_cols.get(species)
            if col is None:
                continue
            data_vars[species] = xr.DataArray(
                self.df[col].to_numpy(dtype=float),
                dims=("TSTEP",), attrs={"units": "mol m-3", "long_name": species}
            )

        # IOAPI-style time flag. MusicBox has no absolute start date, so anchor the
        # elapsed seconds at a synthetic base day (documented) — permm's IRR analysis
        # only depends on the relative step spacing.
        base_yyyyddd = 2000001
        seconds = time_s.astype(np.int64)
        yyyyddd = base_yyyyddd + (seconds // 86400)
        sod = seconds % 86400
        hhmmss = (sod // 3600) * 10000 + ((sod % 3600) // 60) * 100 + (sod % 60)
        n_var = max(len(data_vars), 1)
        tflag = np.empty((n_tstep, n_var, 2), dtype=np.int32)
        tflag[:, :, 0] = yyyyddd[:, None]
        tflag[:, :, 1] = hhmmss[:, None]
        data_vars["TFLAG"] = xr.DataArray(
            tflag, dims=("TSTEP", "VAR", "DATE-TIME"),
            attrs={"units": "<YYYYDDD,HHMMSS>", "long_name": "TFLAG"}
        )

        ds = xr.Dataset(
            data_vars,
            coords={"time": ("TSTEP", time_s)},
            attrs={
                "TITLE": "Integrated reaction rates generated by MusicBox for permm",
                "Conventions": "IOAPI-like",
            },
        )
        ds["time"].attrs = {"units": "s", "long_name": "elapsed simulation time"}
        ds.to_netcdf(self.nc_path)
        logger.info(f"permm IRR NetCDF written to: {self.nc_path}")

    def write(self):
        """Write both the permm mechanism YAML and the IRR NetCDF."""
        out_dir = os.path.dirname(self.prefix)
        if out_dir and not os.path.exists(out_dir):
            os.makedirs(out_dir, exist_ok=True)
            logger.info(f"Created directory: {out_dir}")

        records = self._reaction_records()
        self._write_yaml(records)
        self._write_netcdf(records)
