import argparse
import logging
import colorlog
import json
import os
import numpy as np
import pandas as pd
import re

import musica.mechanism_configuration as mc
from musica import _musica


# ---------------------------------------------------------------------------
# Tokens that appear in GECKO-A reaction lines but are not real species.
# ---------------------------------------------------------------------------

# Keywords that introduce a continuation line of rate parameters. parse_reactions
# records these as the reaction "type".
KEYWORD_TYPES = {'FALLOFF', 'HV', 'ISOM', 'EXTRA'}

# Lumped peroxy-radical "pools". A reaction "X + PEROn => ..." means X reacts with
# the summed concentration of every RO2 in pool n (membership in pero{n}.dat).
RO2_POOLS = {f"PERO{i}" for i in range(1, 10)} | {"MEPERO"}

THIRD_BODY_TOKEN = "TBODY"      # GECKO surrogate for the third body M
OXYGEN_TOKEN = "OXYGEN"         # molecular O2, treated as 0.2 * M (not in dictionary)
PARTITION_IN = "AIN"            # gas -> particle condensation
PARTITION_OUT = "AOU"           # particle -> gas evaporation
NULL_TOKEN = "NOTHING"          # null product (loss to background)

# Every non-species token, used when cleaning reactant/product lists.
NON_SPECIES_TOKENS = (
    KEYWORD_TYPES
    | RO2_POOLS
    | {THIRD_BODY_TOKEN, OXYGEN_TOKEN, PARTITION_IN, PARTITION_OUT, NULL_TOKEN}
)

# Special species we synthesize and add to the gas phase.
THIRD_BODY = "M"
MOLECULAR_OXYGEN = "O2"
WATER = "H2O"

ATOMIC_WEIGHTS = {  # g/mol, used as a last-resort molecular weight from atom counts
    'C': 12.011, 'H': 1.008, 'N': 14.007, 'O': 15.999,
    'S': 32.06, 'F': 18.998, 'Cl': 35.45, 'Br': 79.904,
}


def parse_arguements():
    parser = argparse.ArgumentParser(
        description='GECKO-A to MusicBox Conversion tool.')
    parser.add_argument('-i', '--input', type=str,
                        help='Path to a directory containing GECKO-A configuration files.')
    parser.add_argument('-o', '--output', type=str,
                        help='Path to save the music-box configuration file. '
                             'If not provided, defaults to my_config.json.')
    parser.add_argument('-p', '--photolysis-table', type=str,
                        help='Path to a GECKO-A .phot table (j-values vs solar '
                             'zenith angle). Used to fill the photolysis rates in '
                             'the configuration. If omitted, photolysis rates are 0.')
    parser.add_argument('-z', '--solar-zenith-angle', type=float, default=0.0,
                        help='Solar zenith angle in degrees to read the photolysis '
                             'table at (linearly interpolated). Default 0 (overhead sun).')
    parser.add_argument('--temperature', type=float, default=298.15,
                        help='Initial temperature in K (default 298.15).')
    parser.add_argument('--pressure', type=float, default=101325.0,
                        help='Initial pressure in Pa (default 101325).')
    parser.add_argument('--initial-concentration', type=float, default=1.0,
                        help='Initial concentration in mol m-3 applied to every '
                             'species (default 1.0). A placeholder until real '
                             'initial conditions are available.')
    parser.add_argument('--simulation-length-hours', type=float, default=1.0,
                        help='Simulation length in hours (default 1).')
    parser.add_argument('--output-step-minutes', type=float, default=1.0,
                        help='Output time step in minutes (default 1).')
    parser.add_argument('--chemistry-step-minutes', type=float, default=1.0,
                        help='Chemistry time step in minutes (default 1).')
    parser.add_argument('-v', '--verbose', action='count', default=0,
                        help='Increase logging verbosity. Use -v for info, -vv for debug.')
    parser.add_argument('--color-output', action='store_true',
                        help='Enable color output for logs.')
    parser.add_argument('--version', action='version',
                        version='MusicBox 0.1.0')
    return parser.parse_args()


def setup_logging(verbosity, color_output):
    # Default to WARNING so unmapped-reaction warnings always print; -v adds
    # INFO, -vv adds DEBUG.
    log_level = logging.DEBUG if verbosity >= 2 else logging.INFO if verbosity == 1 else logging.WARNING
    datefmt = '%Y-%m-%d %H:%M:%S'
    format_string = '%(asctime)s - %(levelname)s - %(module)s.%(funcName)s - %(message)s'
    formatter = logging.Formatter(format_string, datefmt=datefmt)
    console_handler = logging.StreamHandler()

    if color_output:
        color_formatter = colorlog.ColoredFormatter(
            f'%(log_color)s{format_string}',
            datefmt=datefmt,
            log_colors={
                'DEBUG': 'green',
                'INFO': 'cyan',
                'WARNING': 'yellow',
                'ERROR': 'red',
                'CRITICAL': 'bold_red'})
        console_handler.setFormatter(color_formatter)
    else:
        console_handler.setFormatter(formatter)

    console_handler.setLevel(log_level)
    logging.basicConfig(level=log_level, handlers=[console_handler])


# ---------------------------------------------------------------------------
# Parsing of the raw GECKO-A files
# ---------------------------------------------------------------------------

def parse_species(input_path, logger):
    # this defines the species in the system and some properties they have
    path = os.path.join(input_path, 'dictionary.out')

    df = pd.read_fwf(
        path,
        skiprows=1,  # Skip the first line with metadata
        infer_nrows=1000,
        names=[
            "GECKO-A Name", "Structural Format", "Short Code", "Molar Mass",
            "Stability Flag", "C", "H", "N", "O", "S", "F", "Cl", "Br"
        ]
    )
    # drop the last row reprsenting the end
    df = df.drop(df.tail(1).index)

    dtypes = {
        "GECKO-A Name": str,
        "Structural Format": str,
        "Short Code": str,
        "Molar Mass": float,
        "Stability Flag": int,
        "C": int, "H": int, "N": int, "O": int, "S": int,
        "F": int, "Cl": int, "Br": int
    }

    # set the dtypes
    df = df.astype(dtypes)

    return df


def _join_continuations(raw_lines):
    """
    Join GECKO-A backslash ('\\') line continuations into logical lines.

    A trailing backslash means the logical line continues on the next physical
    line. Continuations are concatenated directly (no inserted whitespace)
    because a single token can be split across the break, e.g. "G402\\" + "000"
    must rejoin to "G402000".
    """
    logical = []
    buffer = ""
    for raw in raw_lines:
        line = raw.rstrip('\n').rstrip('\r')
        if line.rstrip().endswith('\\'):
            idx = line.rfind('\\')
            buffer += line[:idx]
        else:
            buffer += line
            logical.append(buffer)
            buffer = ""
    if buffer:
        logical.append(buffer)
    return logical


def parse_reactions(input_path, logger):
    reactions = []
    path = os.path.join(input_path, 'reactions.dum')
    with open(path, 'r') as file:
        lines = iter(_join_continuations(file.readlines()))

    current_reaction = None
    multi_line_products = None

    def parse_species_list(species_str):
        """
        Parse a string of species and coefficients into a list of dictionaries.
        """
        species_list = []
        for part in species_str.split('+'):
            part = part.strip()
            if ' ' in part:
                coefficient, name = part.split(' ', 1)
                species_list.append(
                    {'species name': name.strip(), 'coefficient': float(coefficient)})
            else:
                # sometimes part can be an emptry string, ignore it
                if part:
                    species_list.append(
                        {'species name': part, 'coefficient': 1.0})
        return species_list

    for line in lines:
        line = line.strip()

        if not line or line.startswith("!"):
            continue  # Skip empty lines and comments

        # match a reaction that is all on one line, with arrhenius values
        match = re.match(
            r"^(.*?)(?:=>)(.*?)([+\-]?\d\.\d{3}E[+\-]?\d{2}\s+[+\-]?\d+\.\d\s+[+\-]?\d+)", line)

        if match:
            if current_reaction:
                reactions.append(current_reaction)

            reactants = match.group(1).strip()
            products = match.group(2).strip()
            reaction_values = match.group(3).strip()

            A, n, ER = map(float, reaction_values.split())

            current_reaction = {
                "reactants": parse_species_list(reactants),
                "products": parse_species_list(products),
                "A": A,
                "n": n,
                "E/R": ER,
                "type": "regular",
                "extra_values": None,
            }
            multi_line_products = None

        # special reactions with extra values will be a line with 2 slashes
        elif line.count("/") == 2:
            if current_reaction:
                first_slash = line.find("/")
                second_slash = line.find("/", first_slash + 1)
                extra_numbers = line[first_slash + 1:second_slash]
                extra_values = extra_numbers.split()
                current_reaction["type"] = line[:first_slash].strip()
                current_reaction["extra_values"] = [
                    float(val) for val in extra_values]
                reactions.append(current_reaction)
                current_reaction = None
            else:
                raise RuntimeError(
                    f"Reaction parsing error: found extra values without a preceding reaction. Line: {line}")

        # some reactions span multiple lines, this is the start of that
        elif re.match(r"^(.*?)=>\s*(.*?\+)\s*$", line):
            if current_reaction:
                reactions.append(current_reaction)
                current_reaction = None

            match = re.match(r"^(.*?)=>\s*(.*?\+)\s*$", line)
            reactants = match.group(1).strip()
            products = match.group(2).strip()
            current_reaction = {
                "reactants": [],
                "products": [],
                "A": None,
                "n": None,
                "E/R": None,
                "type": "regular",
                "extra_values": None,
            }

            current_reaction["reactants"] = parse_species_list(reactants)
            multi_line_products = True
            current_reaction["products"].extend(parse_species_list(products))

        # this is the continuation of a multi-line reaction
        elif multi_line_products:
            # Regex to detect products and reaction values on the same line
            match = re.match(
                r"^(.*?)([+\-]?\d\.\d{3}E[+\-]?\d{2}\s+[+\-]?\d+\.\d\s+[+\-]?\d+)", line)
            if match:
                products = match.group(1).strip()
                reaction_values = match.group(2).strip()

                # Parse the products
                current_reaction["products"].extend(
                    parse_species_list(products))

                # Parse the reaction values (A, n, E/R)
                A, n, ER = map(float, reaction_values.split())
                current_reaction["A"] = A
                current_reaction["n"] = n
                current_reaction["E/R"] = ER

                # The reaction is rate-complete, but a keyword continuation line
                # (HV/EXTRA/ISOM/FALLOFF) may still follow, so leave it current.
                # It is appended when the next reaction starts or at EOF, exactly
                # like the single-line path.
                multi_line_products = None
            else:
                # Only products, continue accumulating
                additional_products = line.strip()
                current_reaction["products"].extend(
                    parse_species_list(additional_products))
                if not additional_products.endswith("+"):
                    multi_line_products = None  # End multi-line tracking

        # some lines are comments or other sections and we can skip them
        else:
            logger.debug(f"Skipping line: {line}")
            continue

    if current_reaction:
        reactions.append(current_reaction)

    return reactions


def parse_molecular_weights(input_path, logger):
    paths = [
        ('gasspe.dum', 2),
        ('partspe.dum', 1)
    ]

    molecular_weights = {}

    for path, skip in paths:
        full = os.path.join(input_path, path)
        if not os.path.exists(full):
            continue
        # read a csv separated by /, skip the first 2 lines
        df = pd.read_csv(
            full,
            sep='/',
            skiprows=skip,
            header=None,
            names=['Species', 'Molecular Weight', 'Empty'],
            engine='python'
        )

        # we don't need the empty column
        df = df.drop(columns=['Empty'])

        # drop the last row
        df = df.drop(df.tail(1).index)

        df['Species'] = df['Species'].str.strip()

        molecular_weights.update(df.set_index('Species')[
                                 'Molecular Weight'].to_dict())

    return molecular_weights


def parse_chemical_formulas(input_path, logger):
    """
    Parse chemical formulas from a file.
    """
    chemical_formulas = {}
    path = os.path.join(input_path, 'dictionary.out')
    df = pd.read_fwf(
        path,
        skiprows=1,
        header=None,
        widths=[9, 100],
        names=[
            "Species", "Formula"
        ],
        dtype=str
    )

    # drop the last row which is END
    df = df.drop(df.tail(1).index)

    df['Species'] = df['Species'].str.strip()
    df['Formula'] = df['Formula'].str.strip()

    chemical_formulas.update(df.set_index('Species')['Formula'].to_dict())

    return chemical_formulas


def read_peroxy_species(input_path, logger):
    """
    Peroxy radicals are chains of molecules that end in oxygen and are highly reactive
    Often, many species are grouped together and modeled as a lumped species

    This function reads all of the peroxy radical files to determine what species correspond to the
    peroxy radicals defined by gecko. MEPERO is a special methylperoxy pool with no membership file.
    """

    peroxy_groups = {}

    for peroxy in range(1, 10):
        # the path is always pero#.dat
        path = os.path.join(input_path, f"pero{peroxy}.dat")
        species = []
        if os.path.exists(path):
            with open(path, 'r') as file:
                lines = file.readlines()
                n_species = int(lines[0].split()[0])
                if (n_species > 0):
                    for line in lines[1:]:
                        species.append(line.strip())
                    # each file ends with END, remove that species
                    del species[-1]
        peroxy_groups[f"PERO{peroxy}"] = species

    # MEPERO has no membership file
    peroxy_groups["MEPERO"] = []

    return peroxy_groups


def parse_size(input_path, logger):
    """Parse size.dum (authoritative per-type reaction counts) for validation."""
    path = os.path.join(input_path, 'size.dum')
    counts = {}
    if not os.path.exists(path):
        return counts
    with open(path, 'r') as f:
        for line in f:
            if '!' not in line:
                continue
            value_part, label = line.split('!', 1)
            value_part = value_part.strip()
            if not value_part.replace('-', '').isdigit():
                continue
            counts[label.strip()] = int(value_part)
    return counts


# ---------------------------------------------------------------------------
# Classification: detect the special tokens and produce clean species lists
# ---------------------------------------------------------------------------

def _clean(species_list):
    """Drop non-species tokens (operators / NOTHING) from a parsed species list."""
    return [s for s in species_list if s['species name'] not in NON_SPECIES_TOKENS]


def classify_reactions(reactions, logger):
    """
    Annotate each parsed reaction with its handling category and clean the
    reactant/product lists of the non-species tokens.

    Adds, per reaction:
      - 'category': one of regular, falloff, photolysis, isomerization, extra,
                    third_body, oxygen, ro2, partitioning
      - 'ro2_pool': name of the RO2 pool (PERO2, MEPERO, ...) when category == ro2
      - 'partition': 'AIN' or 'AOU' when category == partitioning
    """
    for r in reactions:
        reactant_names = {s['species name'] for s in r['reactants']}
        product_names = {s['species name'] for s in r['products']}
        tokens = reactant_names | product_names

        keyword = r['type'] if r['type'] in KEYWORD_TYPES else None

        if keyword == 'FALLOFF':
            r['category'] = 'falloff'
        elif keyword == 'HV':
            r['category'] = 'photolysis'
        elif keyword == 'ISOM':
            r['category'] = 'isomerization'
        elif keyword == 'EXTRA':
            r['category'] = 'extra'
        elif tokens & {PARTITION_IN, PARTITION_OUT}:
            r['category'] = 'partitioning'
            r['partition'] = PARTITION_IN if PARTITION_IN in tokens else PARTITION_OUT
        elif tokens & RO2_POOLS:
            r['category'] = 'ro2'
            r['ro2_pool'] = next(iter(tokens & RO2_POOLS))
        elif OXYGEN_TOKEN in tokens:
            r['category'] = 'oxygen'
        elif THIRD_BODY_TOKEN in tokens:
            r['category'] = 'third_body'
        else:
            r['category'] = 'regular'

        r['reactants'] = _clean(r['reactants'])
        r['products'] = _clean(r['products'])

    return reactions


# ---------------------------------------------------------------------------
# Building musica objects
# ---------------------------------------------------------------------------

def _strip_prefix(name):
    """Remove the gas (G) or aerosol (A) phase prefix to recover the dictionary name."""
    if name and name[0] in ('G', 'A'):
        return name[1:]
    return name


def _str_props(props):
    """musica other_properties must map str -> str; JSON-encode non-string values."""
    if not props:
        return None
    return {k: (v if isinstance(v, str) else json.dumps(v)) for k, v in props.items()}


def build_species_and_phases(reactions, species_df, molecular_weights,
                             chemical_formulas, peroxy_groups, logger):
    """
    Build mc.Species for every species referenced by the (classified, cleaned)
    reactions plus the synthesized species, and group them into a gas Phase and
    an aerosol Phase.

    Returns (species_objects, gas_phase, aerosol_phase, species_by_name).
    """
    # dictionary-derived lookups (keyed by the unprefixed GECKO name)
    dict_mass = {}
    dict_atoms = {}
    for _, row in species_df.iterrows():
        name = row["GECKO-A Name"]
        dict_mass[name] = float(row["Molar Mass"])
        dict_atoms[name] = {e: int(row[e]) for e in ATOMIC_WEIGHTS}

    def molecular_weight_kg_mol(name):
        # 1) prefixed gasspe/partspe value (skip the 1.0 placeholder)
        mw = molecular_weights.get(name)
        if mw is not None and float(mw) not in (0.0, 1.0):
            return float(mw) / 1000.0
        stripped = _strip_prefix(name)
        # 2) dictionary molar mass
        mass = dict_mass.get(stripped)
        if mass is not None and mass > 0:
            return mass / 1000.0
        # 3) compute from atom counts
        atoms = dict_atoms.get(stripped)
        if atoms and any(atoms.values()):
            return sum(ATOMIC_WEIGHTS[e] * n for e, n in atoms.items()) / 1000.0
        return None

    # collect every species name appearing in the reactions
    names = set()
    for r in reactions:
        for s in r['reactants'] + r['products']:
            names.add(s['species name'])

    species_by_name = {}
    gas_names = []
    aerosol_names = []

    def make_species(name, **kwargs):
        if name in species_by_name:
            return species_by_name[name]
        mw = kwargs.pop('molecular_weight_kg_mol', molecular_weight_kg_mol(name))
        other = kwargs.pop('other_properties', {})
        formula = chemical_formulas.get(_strip_prefix(name))
        if formula:
            other.setdefault("__chemical formula", formula)
        sp = mc.Species(
            name=name,
            molecular_weight_kg_mol=mw,
            other_properties=_str_props(other) or None,
            **kwargs,
        )
        species_by_name[name] = sp
        return sp

    # The music-box / MICM box solver is single-phase, and there is no native
    # gas<->aerosol transfer reaction, so every species (including the GECKO
    # aerosol-phase "A..." species used by the AIN/AOU partitioning reactions)
    # goes into one gas phase. Aerosol-origin species are tagged so the
    # distinction is not lost.
    for name in sorted(names):
        if name.startswith('A'):
            make_species(name, other_properties={"__gecko phase": "aerosol"})
            aerosol_names.append(name)
        else:
            make_species(name)
        gas_names.append(name)

    # synthesized gas-phase species
    make_species(THIRD_BODY, molecular_weight_kg_mol=None, is_third_body=True)
    gas_names.append(THIRD_BODY)
    # O2 = 0.2 * M in GECKO; pin its mixing ratio so reactions that consume it
    # reproduce the [O2] = 0.2 * M factor.
    make_species(MOLECULAR_OXYGEN, molecular_weight_kg_mol=0.032,
                 constant_mixing_ratio_mol_mol=0.2)
    gas_names.append(MOLECULAR_OXYGEN)
    make_species(WATER, molecular_weight_kg_mol=0.018)
    gas_names.append(WATER)

    # lumped RO2 pools, with their membership recorded for downstream use
    for pool, members in peroxy_groups.items():
        if pool in species_by_name:
            continue
        make_species(pool, molecular_weight_kg_mol=None,
                     other_properties={"__ro2 pool members": members})
        gas_names.append(pool)

    gas_phase = mc.Phase(
        name="gas",
        species=[species_by_name[n] for n in gas_names],
    )
    logger.debug(f"{len(gas_names)} species in the gas phase "
                 f"({len(aerosol_names)} of GECKO aerosol origin)")

    species_objects = [species_by_name[n] for n in gas_names]
    return species_objects, gas_phase, species_by_name


def _components(species_list, species_by_name):
    """Convert a parsed species list into musica (coefficient, Species) tuples."""
    return [(s['coefficient'], species_by_name[s['species name']])
            for s in species_list]


def _extra_reactant(species_by_name, name, coefficient=1.0):
    return (coefficient, species_by_name[name])


def convert_reactions(reactions, species_by_name, gas_phase, logger):
    """
    Convert classified GECKO-A reactions into musica reaction objects.

    Returns (reaction_objects, photolysis_map) where photolysis_map is a dict
    keyed by j_value_id, recording the solver rate parameter ("PHOTO.<id>"), the
    evolving-conditions CSV column ("PHOTO.<id>.s-1"), and how many reactions
    share that j-value.
    """
    converted = []
    photolysis_map = {}  # unique reaction name -> GECKO j-value id
    photo_counters = {}  # j_id -> running count, to build unique per-reaction names
    counters = {}
    # reactions that do NOT map to a native MICM rate type -> {description: count},
    # warned in a summary after the loop.
    unmapped = {}

    def note_unmapped(description):
        unmapped[description] = unmapped.get(description, 0) + 1

    def name_for(prefix):
        counters[prefix] = counters.get(prefix, 0) + 1
        return f"{prefix}.{counters[prefix]}"

    for r in reactions:
        reactants = _components(r['reactants'], species_by_name)
        products = _components(r['products'], species_by_name)
        category = r['category']

        if category == 'regular':
            converted.append(mc.Arrhenius(
                A=r['A'], B=r['n'], C=-r['E/R'], D=1.0,
                reactants=reactants, products=products, gas_phase=gas_phase))

        elif category == 'third_body':
            # X + TBODY -> ... : k * [M]
            converted.append(mc.Arrhenius(
                A=r['A'], B=r['n'], C=-r['E/R'], D=1.0,
                reactants=reactants + [_extra_reactant(species_by_name, THIRD_BODY)],
                products=products, gas_phase=gas_phase))

        elif category == 'oxygen':
            # X + OXYGEN -> ... : k * [O2] with [O2] = 0.2 * M
            converted.append(mc.Arrhenius(
                A=r['A'], B=r['n'], C=-r['E/R'], D=1.0,
                reactants=reactants + [_extra_reactant(species_by_name, MOLECULAR_OXYGEN)],
                products=products, gas_phase=gas_phase))

        elif category == 'falloff':
            converted.append(_convert_falloff(
                r, reactants, products, gas_phase, note_unmapped))

        elif category == 'photolysis':
            j_id = int(r['extra_values'][0])
            multiplier = r['extra_values'][1] if len(r['extra_values']) > 1 else 1.0
            # Each photolysis reaction needs a UNIQUE name: MICM prepends "PHOTO."
            # to the name to form the rate parameter and deduplicates reactions
            # that would otherwise collide, so sharing a name across the (many)
            # reactions that reuse one TUV cross-section would silently drop all
            # but one. We give each a unique "<j_id>_<k>" name (no dots, which the
            # music-box rate-parameter normalizer splits on) and later assign every
            # one the same j-value interpolated for its j_id.
            photo_counters[j_id] = photo_counters.get(j_id, 0) + 1
            name = f"{j_id}_{photo_counters[j_id]}"
            converted.append(mc.Photolysis(
                name=name, scaling_factor=multiplier,
                reactants=reactants, products=products, gas_phase=gas_phase))
            photolysis_map[name] = j_id

        elif category == 'isomerization':
            # k = A T^n exp(-(E/R)/T) * (c1 T^4 + c2 T^3 + c3 T^2 + c4 T + c5)
            # musica TaylorSeries: k = (sum c_j T^j) * A exp(C/T) (T/D)^B
            taylor = list(reversed(r['extra_values']))  # [c5, c4, c3, c2, c1]
            converted.append(mc.TaylorSeries(
                A=r['A'], B=r['n'], C=-r['E/R'], D=1.0,
                taylor_coefficients=_musica.VectorDouble(taylor),
                reactants=reactants, products=products, gas_phase=gas_phase))

        elif category == 'extra':
            converted.extend(_convert_extra(
                r, reactants, products, species_by_name, gas_phase, name_for,
                note_unmapped))

        elif category == 'ro2':
            # X + RO2pool -> ... : rate depends on the externally summed RO2 pool
            # concentration, which musica has no native operator for. Emit as a
            # UserDefined reaction carrying the pool id and Arrhenius parameters.
            note_unmapped(
                "RO2 pool reaction(s) (PERO/MEPERO; no summed-RO2 operator) "
                "-> USER_DEFINED, inert until a rate is supplied externally")
            converted.append(mc.UserDefined(
                name=name_for(f"RO2.{r['ro2_pool']}"),
                reactants=reactants, products=products, gas_phase=gas_phase,
                other_properties=_str_props({
                    "__ro2 pool": r['ro2_pool'],
                    "__gecko arrhenius": {"A": r['A'], "n": r['n'], "E/R": r['E/R']},
                })))
            # print(converted[-1].to_equation())

        elif category == 'partitioning':
            # Gas <-> particle mass transfer; musica has no native partitioning
            # operator. Emit as UserDefined preserving the direction.
            note_unmapped(
                "gas/particle partitioning reaction(s) (AIN/AOU; no transfer "
                "operator) -> USER_DEFINED, inert until a rate is supplied externally")
            converted.append(mc.UserDefined(
                name=name_for(f"PART.{r['partition']}"),
                reactants=reactants, products=products, gas_phase=gas_phase,
                other_properties=_str_props({"__gecko partitioning": r['partition']})))

        else:
            logger.warning(f"Unknown reaction category '{category}', skipping: {r}")

    for description, count in sorted(unmapped.items()):
        logger.warning(f"{count} {description}")

    return converted, photolysis_map


def _convert_falloff(r, reactants, products, gas_phase, note_unmapped):
    """
    GECKO FALLOFF (Troe). Low-pressure limit comes from the continuation-line
    parameters (focf1-3); high-pressure limit is the main-line Arrhenius.
        FALLOFF / focf1 focf2 focf3 focf4 focf5 focf6 focf7 /
    """
    focf = r['extra_values']
    if focf[4] != 0.0 or focf[5] != 0.0 or focf[6] != 0.0:
        note_unmapped(
            "FALLOFF reaction(s) with a temperature-dependent fcent (focf5-7) "
            "-> approximated by Troe with a constant Fc")
    return mc.Troe(
        k0_A=focf[0], k0_B=focf[1], k0_C=-focf[2],
        kinf_A=r['A'], kinf_B=r['n'], kinf_C=-r['E/R'],
        Fc=focf[3],
        reactants=reactants, products=products, gas_phase=gas_phase)


def _convert_extra(r, reactants, products, species_by_name, gas_phase, name_for,
                   note_unmapped):
    """
    GECKO EXTRA reactions (hardwired rates keyed by a code; see spakkextra4.f).
    Returns a list because code 501 expands into two reactions.
    """
    code = int(r['extra_values'][0])
    A, n, ER = r['A'], r['n'], r['E/R']

    if code == 100:
        # O + O2 + M -> O3 : k * [M] * [O2]   ([O2] = 0.2 * M)
        return [mc.Arrhenius(
            A=A, B=n, C=-ER, D=1.0,
            reactants=reactants
            + [_extra_reactant(species_by_name, THIRD_BODY),
               _extra_reactant(species_by_name, MOLECULAR_OXYGEN)],
            products=products, gas_phase=gas_phase)]

    if code == 500:
        # reaction with H2O : k * [H2O]
        return [mc.Arrhenius(
            A=A, B=n, C=-ER, D=1.0,
            reactants=reactants + [_extra_reactant(species_by_name, WATER)],
            products=products, gas_phase=gas_phase)]

    if code == 501:
        # k = k1*[H2O] + k2*[H2O]*[M]
        #   k1 from the main-line Arrhenius; k2 = focf2 * exp(-focf4/T)
        focf = r['extra_values']
        r1 = mc.Arrhenius(
            A=A, B=n, C=-ER, D=1.0,
            reactants=reactants + [_extra_reactant(species_by_name, WATER)],
            products=products, gas_phase=gas_phase)
        r2 = mc.Arrhenius(
            A=focf[1], B=focf[2], C=-focf[3], D=1.0,
            reactants=reactants
            + [_extra_reactant(species_by_name, WATER),
               _extra_reactant(species_by_name, THIRD_BODY)],
            products=products, gas_phase=gas_phase)
        return [r1, r2]

    if code == 550:
        # OH + HNO3: k = k0 + k3*M / (1 + k3*M/k2), no native musica form.
        focf = r['extra_values']
        note_unmapped(
            "EXTRA 550 reaction(s) (OH+HNO3, k0+k3M/(1+k3M/k2)) "
            "-> USER_DEFINED, inert until a rate is supplied externally")
        return [mc.UserDefined(
            name=name_for("EXTRA.550"),
            reactants=reactants, products=products, gas_phase=gas_phase,
            other_properties=_str_props({
                "__gecko extra code": 550,
                "__k0 arrhenius": {"A": A, "n": n, "E/R": ER},
                "__k2 arrhenius": {"A": focf[1], "n": focf[2], "E/R": focf[3]},
                "__k3 arrhenius": {"A": focf[4], "n": focf[5], "E/R": focf[6]},
            }))]

    if code == 502:
        # Reaction with the H2O dimer (Scribano et al., 2006):
        #   k = k_arrhenius(T) * kd(T) * [H2O]^2
        #   kd(T) = 4.7856e-4 * exp(1851/T - 5.10485e-3*T)
        #           * 8.314 * T * 1e6 / (1.01325e5 * 6.02e23)   [molec-1 cm3]
        # The exp(-5.10485e-3*T) factor (exponential linear in T) has no native
        # musica rate form, so this stays UserDefined. The two H2O reactants make
        # musica supply the [H2O]^2 dependence; the externally supplied rate
        # coefficient is k_arrhenius(T) * kd(T), fully specified below.
        note_unmapped(
            "EXTRA 502 reaction(s) (H2O dimer; exp linear in T) "
            "-> USER_DEFINED, inert until a rate is supplied externally")
        return [mc.UserDefined(
            name=name_for("EXTRA.502"),
            reactants=reactants
            + [_extra_reactant(species_by_name, WATER),
               _extra_reactant(species_by_name, WATER)],
            products=products, gas_phase=gas_phase,
            other_properties=_str_props({
                "__gecko extra code": 502,
                "__gecko arrhenius": {"A": A, "n": n, "E/R": ER},
                "__water dimer kd [molec-1 cm3]":
                    "4.7856e-4*exp(1851/T - 5.10485e-3*T)"
                    "*8.314*T*1e6/(1.01325e5*6.02e23)",
                "__rate": "arrhenius(A,n,E/R) * kd(T) * [H2O]^2",
            }))]

    # Any other code, undefined in the available spakkextra4.f.
    note_unmapped(
        f"EXTRA code {code} reaction(s) (undefined in available GECKO source) "
        "-> USER_DEFINED, inert until a rate is supplied externally")
    return [mc.UserDefined(
        name=name_for(f"EXTRA.{code}"),
        reactants=reactants, products=products, gas_phase=gas_phase,
        other_properties=_str_props({
            "__gecko extra code": code,
            "__gecko arrhenius": {"A": A, "n": n, "E/R": ER},
        }))]


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

# map our internal categories onto the labels reported in size.dum
SIZE_LABELS = {
    'photolysis': 'HV reactions',
    'third_body': 'third body M reactions',
    'oxygen': 'O2 reactions',
    'extra': 'EXTRA reactions',
    'ro2': 'CH3O2/RO2 reactions',
    'falloff': 'fall off reactions',
    'isomerization': 'R(O.) isomerization reactions',
    'partitioning': 'gas <-> part. equilibrium',
}


def validate_counts(reactions, size_counts, logger):
    """
    Cross-check parsed reaction counts against size.dum. Note size.dum's quirks:
      * the file header says counts are reported "as generated + 1", so most
        category lines (and the total) read one higher than the generated count;
      * "gas <-> part. equilibrium" counts AIN/AOU pairs, i.e. half the number of
        individual partitioning reactions we emit;
      * "CH3O2/RO2 reactions" excludes the MEPERO pool, which we include.
    The authoritative check is therefore the total reaction count.
    """
    if not size_counts:
        logger.info("No size.dum found; skipping count validation.")
        return
    category_counts = {}
    for r in reactions:
        category_counts[r['category']] = category_counts.get(r['category'], 0) + 1

    # Authoritative check: generated total == reported total - 1.
    reported_total = size_counts.get('total number of reactions')
    if reported_total is not None:
        expected = reported_total - 1
        parsed = len(reactions)
        status = "OK" if parsed == expected else "MISMATCH"
        log = logger.info if status == "OK" else logger.warning
        log(f"[{status}] total reactions: parsed {parsed}, "
            f"size.dum reports {reported_total} (generated = {expected})")

    # Per-category: informational, since size.dum mixes counting conventions.
    for category, label in SIZE_LABELS.items():
        ours = category_counts.get(category, 0)
        expected = size_counts.get(label)
        if expected is None:
            continue
        logger.info(f"  {label}: parsed {ours}, size.dum reports {expected}")


# ---------------------------------------------------------------------------
# Photolysis table (.phot) -> conditions
# ---------------------------------------------------------------------------

def parse_phot_table(path, logger):
    """
    Parse a GECKO-A .phot file into {j_id: (sza_array, j_array)}.

    Each channel begins with a header line of one of the forms
        PHOT <label> <j_id> <n_points>
        PHOT <j_id> <n_points>
    so the j-value id is always the second-to-last token. Following lines are
    "<sza_deg> <j_value>" pairs; lines starting with '/' are comments.
    """
    tables = {}
    current = None
    with open(path, 'r') as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith('/'):
                continue
            if line.startswith('PHOT'):
                tokens = line.split()
                current = int(tokens[-2])
                tables[current] = ([], [])
                continue
            parts = line.split()
            if current is not None and len(parts) >= 2:
                tables[current][0].append(float(parts[0]))
                tables[current][1].append(float(parts[1]))

    parsed = {
        j_id: (np.asarray(sza, dtype=float), np.asarray(j, dtype=float))
        for j_id, (sza, j) in tables.items()
    }
    logger.debug(f"parsed {len(parsed)} photolysis channels from {path}")
    return parsed


def build_photolysis_rates(photolysis_map, phot_path, sza, logger):
    """
    Return {"PHOTO.<name>.s-1": rate} for every photolysis reaction, where rate is
    its j_id's value linearly interpolated from the .phot table at the given solar
    zenith angle. Reactions sharing a j_id get the same value. np.interp clamps to
    the table endpoints, so SZA >= 90 deg gives j = 0 (night). Missing inputs or
    channels yield 0.0 with a warning.

    photolysis_map maps each unique reaction name to its GECKO j-value id.
    """
    if not photolysis_map:
        return {}
    items = sorted(photolysis_map.items(), key=lambda kv: (kv[1], kv[0]))
    if not phot_path:
        logger.warning(
            "Photolysis reactions are present but no --photolysis-table was given; "
            "writing 0.0 for all photolysis rates.")
        return {f"PHOTO.{name}.s-1": 0.0 for name, _ in items}

    if not (0.0 <= sza <= 90.0):
        logger.warning(
            f"Solar zenith angle {sza} is outside [0, 90]; clamped to the table "
            "endpoints (>= 90 deg is night, j = 0).")

    tables = parse_phot_table(phot_path, logger)
    rates = {}
    missing = set()
    for name, j_id in items:
        if j_id in tables:
            grid, values = tables[j_id]
            rates[f"PHOTO.{name}.s-1"] = float(np.interp(sza, grid, values))
        else:
            rates[f"PHOTO.{name}.s-1"] = 0.0
            missing.add(j_id)
    if missing:
        ms = sorted(missing)
        logger.warning(
            f"{len(missing)} j-value id(s) used by the mechanism are absent from "
            f"{phot_path}; wrote 0.0 for those reactions: "
            f"{ms[:10]}{'...' if len(ms) > 10 else ''}")
    return rates


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    args = parse_arguements()
    setup_logging(args.verbose, args.color_output)

    logger = logging.getLogger(__name__)

    logger.debug(f"{__file__}")
    input = args.input
    output = args.output

    if not input:
        error = "No input directory provided."
        logger.error(error)
        raise ValueError(error)

    logger.debug(f"Input directory: {input}")
    logger.debug(f"Output file: {output}")

    species_df = parse_species(input, logger)
    reactions = parse_reactions(input, logger)
    molecular_weights = parse_molecular_weights(input, logger)
    chemical_formulas = parse_chemical_formulas(input, logger)
    peroxy_groups = read_peroxy_species(input, logger)
    size_counts = parse_size(input, logger)

    reactions = classify_reactions(reactions, logger)

    category_counts = {}
    for r in reactions:
        category_counts[r['category']] = category_counts.get(r['category'], 0) + 1
    logger.debug(f"parsed {len(species_df)} dictionary species")
    logger.debug(f"parsed {len(reactions)} reactions")
    logger.debug(f"reaction category counts: {category_counts}")

    validate_counts(reactions, size_counts, logger)

    species_objects, gas_phase, species_by_name = \
        build_species_and_phases(
            reactions, species_df, molecular_weights, chemical_formulas,
            peroxy_groups, logger)

    reaction_objects, photolysis_map = convert_reactions(
        reactions, species_by_name, gas_phase, logger)

    mechanism = mc.Mechanism(
        name="GECKO mechanism",
        species=species_objects,
        phases=[gas_phase],
        reactions=reaction_objects,
        version=mc.Version(1, 0, 0),
    )

    # Photolysis rates for the single chosen solar zenith angle, baked into the
    # initial conditions (held constant for the run by step interpolation).
    photolysis_rates = build_photolysis_rates(
        photolysis_map, args.photolysis_table, args.solar_zenith_angle, logger)

    # Placeholder initial concentrations: the same value for every species. M
    # (third body) and O2 (fixed mixing ratio) are derived from T/P, so they are
    # not given an explicit concentration.
    fixed = {THIRD_BODY, MOLECULAR_OXYGEN}
    concentrations = {
        f"CONC.{name}.mol m-3": args.initial_concentration
        for name in species_by_name if name not in fixed
    }

    headers = (["time.s", "ENV.temperature.K", "ENV.pressure.Pa"]
               + list(concentrations) + list(photolysis_rates))
    row = ([0.0, args.temperature, args.pressure]
           + list(concentrations.values()) + list(photolysis_rates.values()))

    config = {
        "box model options": {
            "grid": "box",
            "chemistry time step [min]": args.chemistry_step_minutes,
            "output time step [min]": args.output_step_minutes,
            "simulation length [hour]": args.simulation_length_hours,
        },
        "conditions": {
            "data": [{"headers": headers, "rows": [row]}],
        },
        "mechanism": mechanism.serialize(),
    }

    output_file = output if output else 'my_config.json'
    with open(output_file, 'w') as f:
        json.dump(config, f, separators=(',', ':'))
    logger.info(
        f'MusicBox configuration written to {output_file} '
        f'({len(species_objects)} species, {len(reaction_objects)} reactions, '
        f'{len(photolysis_rates)} photolysis rates at SZA={args.solar_zenith_angle} deg, '
        f'all concentrations = {args.initial_concentration} mol m-3). '
        f'Run: {args.simulation_length_hours} h, output every '
        f'{args.output_step_minutes} min.')


if __name__ == "__main__":
    main()
