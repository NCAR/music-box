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

def parse_species(input_path):
    species = {}
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

def parse_reactions(input_path):
  reactions = []
  path = os.path.join(input_path, 'reactions.dum')
  with open(path, 'r') as file:
    lines = iter(file.readlines())
    
  current_reaction = None
  
  for line in lines:
    line = line.strip()
    
    if not line or line.startswith("!"):
      continue  # Skip empty lines and comments
    
    # Check if the line contains a reaction
    match = re.match(r"^(.*?)(?:=>)(.*?)([+\-]?\d\.\d{3}E[+\-]?\d{2}\s+[+\-]?\d+\.\d\s+[+\-]?\d+)", line)
    if match:
      # Save the previous reaction before starting a new one
      if current_reaction:
        reactions.append(current_reaction)
      
      reactants = match.group(1).strip()
      products = match.group(2).strip()
      reaction_values = match.group(3).strip()
      
      # Parse A, n, E/R
      A, n, ER = map(float, reaction_values.split())
      
      current_reaction = {
        "reactants": reactants,
        "products": products,
        "A": A,
        "n": n,
        "E/R": ER,
        "type": "regular",
        "extra_values": None,
      }
    
    elif line.startswith("/"):
      # Handle special reactions
      if current_reaction:
        extra_values = line.strip("/").split()
        current_reaction["extra_values"] = [float(val) for val in extra_values]
    
    else:
      # Handle multi-line products
      if current_reaction and current_reaction["products"][-1] == "+":
        current_reaction["products"] += " " + line.strip()
  
  # Add the last reaction
  if current_reaction:
    reactions.append(current_reaction)
  
  print(reactions)
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

    species = parse_species(input)
    rections = parse_reactions(input)