import argparse
import logging
import colorlog
import os
import pandas as pd
import re


def parse_arguements():
    parser = argparse.ArgumentParser(
        description='GECKO-A to MusicBox Conversion tool.')
    parser.add_argument('-i', '--input', type=str,
                        help='Path to a directory containing GECKO-A configuration files.')
    parser.add_argument('-o', '--output', type=str,
                        help='Path to save the output file, including the file name. If not provided, defaults to mechanism.json.')
    parser.add_argument('-v', '--verbose', action='count', default=0,
                        help='Increase logging verbosity. Use -v for info, -vv for debug.')
    parser.add_argument('--color-output', action='store_true',
                        help='Enable color output for logs.')
    parser.add_argument('--version', action='version',
                        version='MusicBox 0.1.0')
    return parser.parse_args()


def setup_logging(verbosity, color_output):
    log_level = logging.DEBUG if verbosity >= 2 else logging.INFO if verbosity == 1 else logging.CRITICAL
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


def parse_reactions(input_path, logger):
    reactions = []
    path = os.path.join(input_path, 'reactions.dum')
    with open(path, 'r') as file:
        lines = iter(file.readlines())

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

                # Append the completed reaction to the list
                reactions.append(current_reaction)

                # Reset for the next reaction
                current_reaction = None
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

    reaction_types = [
        'FALLOFF', 'HV', 'ISOM', 'EXTRA',
    ]
    # remove any reactants whose name is a reaction type
    for r in reactions:
        r['reactants'] = [s for s in r['reactants']
                          if s['species name'] not in reaction_types]
        r['products'] = [s for s in r['products']
                         if s['species name'] not in reaction_types]
    return reactions


def parse_molecular_weights(input_path, logger):
    paths = [
        ('gasspe.dum', 2),
        ('partspe.dum', 1)
    ]

    molecular_weights = {}

    for path, skip in paths:
        # read a csv separated by /, skip the first 2 lines
        df = pd.read_csv(
            os.path.join(input_path, path),
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
    peroxy radicals defined by gecko
    """

    peroxy_groups = {}

    for peroxy in range(1, 10):
        # the path is always pero#.dat
        path = os.path.join(input_path, f"pero{peroxy}.dat")
        with open(path, 'r') as file:
            lines = file.readlines()
            n_species = int(lines[0].split()[0])
            species = []
            if (n_species > 0):
                for line in lines[1:]:
                    species.append(line.strip())
                # each file ends with END, remove that species
                del species[-1]
            peroxy_groups[f"PERO{peroxy}"] = species

    return peroxy_groups


def convert_reactions_to_musica(reactions, logger):
    """
    Convert GECKO-A reactions to MusicBox format.
    """
    converted_reactions = []
    for r in reactions:
        if r['type'] == 'regular':
            converted_reaction = {
                "type": "ARRHENIUS",
                "A": r['A'],
                "B": r['n'],
                "C": -r['E/R'],
                "reactants": r["reactants"],
                "products": r['products']
            }
        elif r['type'] == 'FALLOFF':
            converted_reaction = {
                "type": "TROE",
                "k0_A": r['A'],
                "k0_B": r['n'],
                "k0_C": -r['E/R'],
                "kinf_A": r['extra_values'][0],
                "kinf_B": r['extra_values'][1],
                "kinf_C": r['extra_values'][2],
                "Fc": r['extra_values'][3],
                "reactants": r["reactants"],
                "products": r['products']
            }
        elif r['type'] == 'HV':
            converted_reaction = {
                "type": "PHOTOLYSIS",
                "name": "PHOTO." + str(int(r['extra_values'][0])),
                "scaling factor": r['extra_values'][1],
                "reactants": r["reactants"],
                "products": r['products']
            }
        elif r['type'] == 'ISOM':
            converted_reaction = {
                "type": "ISOMERIZATION",
                "A": r['A'],
                "B": r['n'],
                "C": -r['E/R'],
                "taylor series": r['extra_values'][::-1],
                "reactants": r["reactants"],
                "products": r['products']
            }
        elif r['type'] == 'EXTRA' and r['extra_values'][0] == 100:
            # This is the O + O2 + M -> O3 + M reaction
            # The rate constant parameters are from TS1 because I couldn't figure out where they exist in GECKO
            reactants = r["reactants"]
            reactants.append({'species name': 'O2', 'coefficient': 1.0})
            reactants.append({'species name': 'M', 'coefficient': 1.0})
            converted_reaction = {
                "type": "ARRHENIUS",
                "A": r['A'],
                "B": r['n'],
                "C": -r['E/R'],
                "reactants": reactants,
                "products": r['products']
            }
        elif r['type'] == 'EXTRA' and r['extra_values'][0] == 500:
            # This adds H2O as a reactant
            reactants = r["reactants"]
            reactants.append({'species name': 'H2O', 'coefficient': 1.0})
            converted_reaction = {
                "type": "ARRHENIUS",
                "A": r['A'],
                "B": r['n'],
                "C": -r['E/R'],
                "reactants": reactants,
                "products": r['products']
            }
        elif r['type'] == 'EXTRA' and r['extra_values'][0] == 501:
            # This adds H2O and M as reactants
            reactants = r["reactants"]
            reactants.append({'species name': 'H2O', 'coefficient': 1.0})
            reactants.append({'species name': 'M', 'coefficient': 1.0})
            converted_reaction = {
                "type": "ARRHENIUS",
                "A": r['A'],
                "B": r['n'],
                "C": -r['E/R'],
                "reactants": reactants,
                "products": r['products']
            }
        elif r['type'] == 'EXTRA' and r['extra_values'][0] == 550:
            # This is the combination of an Arrhenius and a Troe reaction
            converted_reaction = {
                "type": "ARRHENIUS",
                "A": r['A'],
                "B": r['n'],
                "C": -r['E/R'],
                "reactants": r["reactants"],
                "products": r['products']
            }
            converted_reactions.append(converted_reaction)
            converted_reaction = {
                "type": "TROE",
                "k0_A": r['extra_values'][1],
                "k0_B": r['extra_values'][2],
                "k0_C": -r['extra_values'][3],
                "kinf_A": r['extra_values'][4],
                "kinf_B": r['extra_values'][5],
                "kinf_C": -r['extra_values'][6],
                "Fc": 0,
                "reactants": r["reactants"],
                "products": r['products']
            }
        else:
            logger.warning(
                f"Unknown reaction type, skipping conversion. Reaction data: {r}")
            continue

        converted_reactions.append(converted_reaction)
    return converted_reactions


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

    species = parse_species(input, logger)
    reactions = parse_reactions(input, logger)
    molecular_weights = parse_molecular_weights(input, logger)
    chemical_formulas = parse_chemical_formulas(input, logger)
    peroxy_groups = read_peroxy_species(input, logger)

    type_counts = {}
    for r in reactions:
        # name = "_".join([s['name'] for s in r['reactants'] + r['products']])
        # print(name, r['reactants'], r['products'])
        type_counts[r['type']] = type_counts.get(r['type'], 0) + 1

    logger.debug(f"parsed {len(species)} species")
    logger.debug(f"parsed {len(reactions)} reactions")
    logger.debug(f"reaction type counts: {type_counts}")
    logger.debug(f"parsed {len(molecular_weights)} molecular weights")
    logger.debug(f"parsed {len(peroxy_groups)} peroxy groups")
    for peroxy, peroxy_species in peroxy_groups.items():
        logger.debug(f"{peroxy}: {len(peroxy_species)} species")
    unique_species = set()
    for r in reactions:
        for s in r['reactants'] + r['products']:
            unique_species.add(s['species name'])

    # Output species to mechanism file
    import json
    species_list = []
    for _, row in species.iterrows():
        name = row["GECKO-A Name"]
        entry = {"name": name}
        mw = molecular_weights.get("G" + name)
        if mw is not None and float(mw) != 1:
            # Convert g/mol to kg/mol
            entry["molecular weight [kg mol-1]"] = float(mw) / 1000.0
        formula = chemical_formulas.get(name)
        if formula is not None:
            entry["__chemical formula"] = formula
        species_list.append(entry)

    reactions = convert_reactions_to_musica(reactions, logger)

    mechanism_json = {
        "version": "1.0.0",
        "name": "GECKO mechanism",
        "species": species_list,
        "reactions": reactions
    }

    # Use output flag or default to mechanism.json
    output_file = output if output else 'mechanism.json'

    with open(output_file, 'w') as f:
        json.dump(mechanism_json, f, indent=2)
    logger.info(f'GECKO mechanism written to {output_file}')


if __name__ == "__main__":
    main()
