import argparse
import logging
import colorlog
import os
import pandas as pd
import re

def parse_arguements():
    parser = argparse.ArgumentParser(description='GECKO-A to MusicBox Conversion tool.')
    parser.add_argument('-i', '--input', type=str, help='Path to a directory containing GECKO-A configuration files.')
    parser.add_argument('-o', '--output', type=str, help='Path to save the output file, including the file name. If not provided, result will be printed to the console.')
    parser.add_argument('-v', '--verbose', action='count', default=0, help='Increase logging verbosity. Use -v for info, -vv for debug.')
    parser.add_argument('--color-output', action='store_true', help='Enable color output for logs.')
    parser.add_argument('--version', action='version', version='MusicBox 0.1.0')
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

    dtypes={
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
                species_list.append({'name': name.strip(), 'coefficient': float(coefficient)})
            else:
                # sometimes part can be an emptry string, ignore it
                if part:
                    species_list.append({'name': part, 'coefficient': 1.0})
        return species_list
    
    for line in lines:
        line = line.strip()
        
        if not line or line.startswith("!"):
            continue  # Skip empty lines and comments
        
        # match a reaction that is all on one line, with arrhenius values
        match = re.match(r"^(.*?)(?:=>)(.*?)([+\-]?\d\.\d{3}E[+\-]?\d{2}\s+[+\-]?\d+\.\d\s+[+\-]?\d+)", line)

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
                current_reaction["extra_values"] = [float(val) for val in extra_values]
                reactions.append(current_reaction)
                current_reaction = None
        
        # some reactions span multiple lines, this is the start of that
        elif re.match(r"^(.*?)=>\s*(.*?\+)\s*$", line):
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
            match = re.match(r"^(.*?)([+\-]?\d\.\d{3}E[+\-]?\d{2}\s+[+\-]?\d+\.\d\s+[+\-]?\d+)", line)
            if match:
                products = match.group(1).strip()
                reaction_values = match.group(2).strip()
                
                # Parse the products
                current_reaction["products"].extend(parse_species_list(products))
                
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
                current_reaction["products"].extend(parse_species_list(additional_products))
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
        r['reactants'] = [s for s in r['reactants'] if s['name'] not in reaction_types]
        r['products'] = [s for s in r['products'] if s['name'] not in reaction_types]
    return reactions
  
def parse_initial_conditions(input_path, logger):
    paths = [
      ('gasspe.dum', 2),
      ('partspe.dum', 1)
    ]

    concentrations = {}

    for path, skip in paths:
      # read a csv separated by /, skip the first 2 lines
      df = pd.read_csv(
          os.path.join(input_path, path),
          sep='/',
          skiprows=skip,
          header=None,
          names=['Species', 'Initial Concentration', 'Empty'],
          engine='python'
      )

      # we don't need the empty column
      df = df.drop(columns=['Empty'])

      # drop the last row
      df = df.drop(df.tail(1).index)

      df['Species'] = df['Species'].str.strip()

      concentrations.update(df.set_index('Species')['Initial Concentration'].to_dict())

    return concentrations

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
    initial_conditions = parse_initial_conditions(input, logger)
    peroxy_groups = read_peroxy_species(input, logger)

    type_counts = {}
    for r in reactions:
        name = "_".join([s['name'] for s in r['reactants'] + r['products']])
        print(name, r['reactants'], r['products'])
        type_counts[r['type']] = type_counts.get(r['type'], 0) + 1
    
    logger.debug(f"parsed {len(species)} species")
    logger.debug(f"parsed {len(reactions)} reactions")
    logger.debug(f"reaction type counts: {type_counts}")
    logger.debug(f"parsed {len(initial_conditions)} initial conditions")
    logger.debug(f"parsed {len(peroxy_groups)} peroxy groups")
    for peroxy, species in peroxy_groups.items():
        logger.debug(f"{peroxy}: {len(species)} species")
    unique_species = set()
    for r in reactions:
        for s in r['reactants'] + r['products']:
            unique_species.add(s['name'])

    conditions = set(initial_conditions.keys())
    # find species that don't have initial conditions
    missing_conditions = unique_species - conditions - set(peroxy_groups.keys()) - set(['NOTHING'])
    # print(missing_conditions)

if __name__ == "__main__":
    main()