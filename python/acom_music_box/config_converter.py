"""Convert an old-format MusicBox configuration to the current format.

Music Box Interactive exports the *old* configuration layout:

- ``environmental conditions`` — ``{temperature: {"initial value [K]": ...}, pressure: {...}}``
- ``initial conditions``       — ``{filepaths: [...csv...]}`` and/or an inline ``data`` table
- ``model components``         — ``[{type: "CAMP", "configuration file": "camp_data/config.json", ...}]``

with CSV columns named ``CONC.<sp> [mol m-3]`` / ``SURFACE.<rxn>.m`` / ``PHOTO.<j>.s-1``.

The current MusicBox expects a single self-contained file with a ``conditions``
section and an inline v1 ``mechanism``, and CSV columns named
``CONC.<sp>`` / ``SURF.<rxn>.effective radius.m`` / etc. This module rewrites the
config and its condition CSVs into that layout, converting the referenced CAMP
(v0) mechanism to v1 via musica (which preserves the ``irr__`` accumulator
tracers, so process-analysis / permm output keeps working).
"""

import argparse
import csv
import json
import logging
import os
import re

from musica.mechanism_configuration import parse, Version

from .utils import convert_temperature, convert_pressure

logger = logging.getLogger(__name__)

# permm/MICM condition column prefixes understood by the current ConditionsManager.
_RATE_PREFIXES = ("ENV", "CONC", "EMIS", "PHOTO", "LOSS", "USER", "SURF")


def convert_csv_header(col):
    """Convert one old-format CSV column name to the current convention.

    - ``CONC.<sp> [unit]``      -> ``CONC.<sp>.<unit>`` (e.g. ``CONC.O3.mol m-3``)
    - ``SURFACE.<rxn>.m``       -> ``SURF.<rxn>.effective radius.m``
    - ``SURFACE.<rxn>.# m-3``   -> ``SURF.<rxn>.particle number concentration.# m-3``
    - any other ``PREFIX.name [unit]`` -> ``PREFIX.name.unit`` (e.g.
      ``ENV.temperature [K]`` -> ``ENV.temperature.K``)
    - already dot-separated columns (``PHOTO.j.s-1``, ``time.s``,
      ``ENV.temperature.K``) are passed through unchanged.
    """
    c = col.strip()
    if c.startswith("CONC."):
        # Rewrite " [unit]" as a dot-separated ".unit" (e.g. "CONC.O3 [mol m-3]"
        # -> "CONC.O3.mol m-3"), keeping the unit like the SURF columns do.
        body = c[len("CONC."):]
        match = re.search(r"\[\s*(.*?)\s*\]\s*$", body)
        unit = match.group(1) if match else "mol m-3"
        species = re.sub(r"\s*\[.*\]\s*$", "", body).strip()
        if unit != "mol m-3":
            logger.warning(
                "Concentration column '%s' is in '%s'; the current MusicBox reads "
                "concentrations as mol m-3 and does not convert units.", c, unit)
        return f"CONC.{species}.{unit}"
    if c.startswith("SURFACE."):
        rest = c[len("SURFACE."):]
        if rest.endswith(".# m-3"):
            return f"SURF.{rest[:-len('.# m-3')]}.particle number concentration.# m-3"
        if rest.endswith(".m"):
            return f"SURF.{rest[:-len('.m')]}.effective radius.m"
        logger.warning(f"Unrecognized SURFACE column '{c}'; left unchanged.")
        return c
    # General case: rewrite a trailing " [unit]" (e.g. "ENV.pressure [Pa]") as ".unit".
    match = re.match(r"^(.*?)\s*\[\s*(.*?)\s*\]\s*$", c)
    if match:
        return f"{match.group(1)}.{match.group(2)}"
    return c


def convert_csv(old_path, new_path):
    """Rewrite an old conditions CSV with converted headers and a time column."""
    with open(old_path, newline="") as handle:
        rows = list(csv.reader(handle))
    if not rows:
        raise ValueError(f"Conditions CSV '{old_path}' is empty.")

    header = [convert_csv_header(c) for c in rows[0]]
    data_rows = rows[1:]

    # The current reader requires a 'time.s' column; old MBI initial-condition
    # CSVs omit it (single initial state at t=0).
    if "time.s" not in header:
        header = ["time.s"] + header
        data_rows = [["0.0"] + [v.strip() for v in r] for r in data_rows]

    with open(new_path, "w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(data_rows)
    logger.info(f"Converted conditions CSV -> {new_path}")


def _convert_mechanism(camp_config_path, override_species=None):
    """Parse a CAMP (v0) config and return an embeddable v1 mechanism dict.

    ``override_species`` are the old ``override species`` directives. A fixed
    ``mixing ratio mol mol-1`` is translated to a ``constant mixing ratio
    [mol mol-1]`` on the species, which musica fixes to ``air_density * ratio``
    for the whole run -- exactly what the old override did. Third-body species
    (e.g. M) already fix their concentration to air density, so they are left
    as-is.
    """
    mechanism = parse(camp_config_path)
    # The v0 parser stamps version 0.0.0; this is emitted as a v1 document.
    mechanism.version = Version(1, 0, 0)
    mech = mechanism.serialize()

    for name, spec in (override_species or {}).items():
        entry = next((s for s in mech["species"] if s.get("name") == name), None)
        if entry is None:
            logger.warning("override species '%s' is not in the mechanism; skipped.", name)
            continue
        if entry.get("is third body"):
            continue  # third bodies are already fixed to air density
        if "mixing ratio mol mol-1" in spec:
            entry["constant mixing ratio [mol mol-1]"] = spec["mixing ratio mol mol-1"]
        else:
            logger.warning(
                "override species '%s' uses unsupported keys %s and was not translated; "
                "set it in the conditions CSV.", name, list(spec))
    return mech


def _convert_inline_data(table):
    """Convert an old inline conditions data table to a new 'data' block.

    The old format is a list of two lists -- a header row and a value row --
    with old-style column names, e.g.::

        [["ENV.temperature [K]", "CONC.A [mol m-3]"], [298.0, 1e-9]]

    Returns a ``{"headers": [...], "rows": [[...]]}`` block with converted column
    names, prepending a ``time.s`` column when the table has none, or ``None`` when
    there is nothing to convert.
    """
    if not table:
        return None
    # Documented list-of-lists form; also accept a {headers, rows} dict defensively.
    if isinstance(table, dict):
        headers = [convert_csv_header(h) for h in table.get("headers", [])]
        rows = [list(r) for r in table.get("rows", [])]
    else:
        headers = [convert_csv_header(h) for h in table[0]]
        rows = [list(r) for r in table[1:]]
    if not headers:
        return None
    if "time.s" not in headers:
        headers = ["time.s"] + headers
        rows = [[0.0] + r for r in rows]
    return {"headers": headers, "rows": rows}


def convert_config(old_config_path, output_dir):
    """Convert an old-format MusicBox config (and its CSVs) into ``output_dir``.

    Writes ``<output_dir>/my_config.json`` plus a converted copy of each
    referenced conditions CSV. Returns the path to the written config file.
    """
    old_config_path = os.path.abspath(old_config_path)
    old_dir = os.path.dirname(old_config_path)
    os.makedirs(output_dir, exist_ok=True)

    with open(old_config_path) as handle:
        old = json.load(handle)

    new = {}

    # 1. Box model options carry over unchanged.
    if "box model options" in old:
        new["box model options"] = old["box model options"]

    # 2. Conditions: environmental values, inline data tables, and referenced CSVs
    #    all become entries in the new 'conditions' section (merged by time).
    conditions = {}
    data_blocks = []
    env = old.get("environmental conditions", {})
    if "temperature" in env and "pressure" in env:
        temperature = convert_temperature(env["temperature"], "initial value")
        pressure = convert_pressure(env["pressure"], "initial value")
        data_blocks.append({
            "headers": ["time.s", "ENV.temperature.K", "ENV.pressure.Pa"],
            "rows": [[0.0, temperature, pressure]],
        })

    # Both initial and evolving conditions become CSV filepaths and/or inline data
    # blocks in the new 'conditions' section; ConditionsManager merges them by time.
    # Evolving CSVs already carry a time.s column, so convert_csv keeps their timing.
    filepaths = []
    for section in ("initial conditions", "evolving conditions"):
        block = old.get(section, {})
        for rel in block.get("filepaths", []):
            src = os.path.join(old_dir, rel)
            base = os.path.basename(rel)
            convert_csv(src, os.path.join(output_dir, base))
            filepaths.append(base)
        inline = _convert_inline_data(block.get("data"))
        if inline:
            data_blocks.append(inline)

    if data_blocks:
        conditions["data"] = data_blocks
    if filepaths:
        conditions["filepaths"] = filepaths
    if conditions:
        new["conditions"] = conditions

    # 3. Mechanism: convert the CAMP model component to an inline v1 mechanism.
    components = old.get("model components", [])
    camp = next((c for c in components if c.get("type") == "CAMP"), None)
    if camp is None:
        raise ValueError("No CAMP 'model components' entry found to convert.")
    camp_config = os.path.join(old_dir, camp["configuration file"])
    new["mechanism"] = _convert_mechanism(camp_config, camp.get("override species"))

    if camp.get("suppress output"):
        logger.info("'suppress output' has no current equivalent and was dropped.")

    out_config = os.path.join(output_dir, "my_config.json")
    with open(out_config, "w") as handle:
        json.dump(new, handle, indent=2)
    logger.info(f"Converted MusicBox config -> {out_config}")
    return out_config


def main():
    parser = argparse.ArgumentParser(
        description="Convert an old-format MusicBox configuration to the current format.")
    parser.add_argument("config", help="Path to the old-format my_config.json")
    parser.add_argument(
        "-o", "--output", default="converted_config",
        help="Output directory for the converted config and CSVs (default: ./converted_config)")
    parser.add_argument("-v", "--verbose", action="count", default=0,
                        help="Increase logging verbosity.")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose >= 2 else logging.INFO if args.verbose == 1 else logging.WARNING)
    out = convert_config(args.config, args.output)
    print(out)


if __name__ == "__main__":
    main()
