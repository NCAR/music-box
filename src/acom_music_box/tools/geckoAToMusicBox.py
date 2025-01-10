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
        species_list = []
        for part in species_str.split('+'):
            part = part.strip()
            if ' ' in part:
                coefficient, name = part.split(' ', 1)
                species_list.append({'name': name.strip(), 'coefficient': float(coefficient)})
            else:
                if part:
                    species_list.append({'name': part, 'coefficient': 1.0})
        return species_list
    
    for line in lines:
        line = line.strip()
        
        if not line or line.startswith("!"):
            continue  # Skip empty lines and comments
        
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
        
        elif line.count("/") == 2:
            if current_reaction:
                first_slash = line.find("/")
                second_slash = line.find("/", first_slash + 1)
                extra_numbers = line[first_slash + 1:second_slash]
                extra_values = extra_numbers.split()
                current_reaction["type"] = line[:first_slash].strip()
                current_reaction["extra_values"] = [float(val) for val in extra_values]
        
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

        else:
            logger.debug(f"Skipping line: {line}")
            continue
    
    if current_reaction:
        reactions.append(current_reaction)
    
    for r in reactions:
      print(r)
    return reactions

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
    if not output:
      error = "No output file provided."
      logger.error(error)
      raise ValueError(error)
    
    logger.debug(f"Input directory: {input}")
    logger.debug(f"Output file: {output}")

    species = parse_species(input, logger)
    rections = parse_reactions(input, logger)