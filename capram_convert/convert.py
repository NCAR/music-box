import re
import json
import numpy as np

# file from https://capram.tropos.de/capram_24.html
with open("capram24_red.txt") as f:
    content = f.readlines()

##
# comments here taken from the capram file
##

# CLASS: HENRY, TYPE: TEMP3
# Phase transfer
# Kh = A exp(B (1/T - 1/298))
# B = dH/R [K]
# Further uptake parameters according to Schwartz's approach (alpha, Dg)  
# are read elsewhere in the program
# for example, henry['CO2'] = {A: '3.1e-2', B: '2423.0'}
henry = list()

# CLASS: AQUA, TYPE: PHOTABC photolysis reactions according to 
# j = A * exp (B *(1 - 1 /(cos (C * chi)); A = jmax; chi = zenith angle
aqua_photo = list()

# CLASS: AQUA;  TYPE: TEMP3
# TEmperature dependent reation
# k(T)=A*exp(B*(1/T-1/298))
# A=k(298 K)
# B=-Ea/R   
aqua_temp = list()

# CLASS: DISS, TYPE: DTEMP
# Temperature dependent dissociation
# Ke = A exp(B*(1/T - 1/298)); 
# B=-Ea/R  
# C = k(back reaction)
diss_with_c = list()
# CLASS: DISS, TYPE: DCONST
# Dissociation
# Ke = A 
# B= k(back reaction) 
diss_without_c = list()

# pattern that matches A, B, and optionall C constants for PHOTABC and TEMP3 reactions
# thanks chatgpt
constants_pattern = re.compile(r"(PHOTABC|TEMP3|DCONST|DTEMP):\s+A:\s+([\d\.e+-]+)\s+B:\s+([\d\.e+-]+)(?:\s+C:\s+([\d\.e+-]+))?")
reaction_pattern = r"^([^=]*)=([^=]*)$"

def parse_reactants_products(line):
    match = re.search(reaction_pattern, line.replace(" ", ""))
    if match:
        reactants = combine_stoichiometric_coeffs(match.group(1).strip())
        products = combine_stoichiometric_coeffs(match.group(2).strip())
    return reactants, products

def combine_stoichiometric_coeffs(species):
    #TODO: for the ceofficients, make sure they get put into the products with a yield
    # given this: O2m   +  FEpp = FEppp  + aH2O2  -2.0 Hp 
    # output this for the products: ['FEppp', 'aH2O2', '-2.0Hp']
    groups = [i for i in re.split(r'([+-])', species) if i != '+']
    result = []
    for i, group in enumerate(groups):
        if (i > 0) and (groups[i-1] == '-'):
            result.append(groups[i-1] + group)
        elif group != '-':
            result.append(group)

    return result

line_index = 0
# there are a few AQUA type reactions in the dissociation reactions, 
# when those exist, add them to the appropriate array
while line_index < len(content):
    line = content[line_index].strip()
    if line.startswith('CLASS'):
        type = line.split(':')[1].strip()
        if type == 'HENRY':
            reactants, products = parse_reactants_products(content[line_index + 1])
            match = constants_pattern.search(content[line_index + 2])
            type, A, B, C = match.group(1), float(match.group(2)), float(match.group(3)), match.group(4)
            henry.append(dict(reactants = reactants, products=products, A=A, B=B))
            line_index += 2
        elif type == 'AQUA':
            reactants, products = parse_reactants_products(content[line_index + 1])
            match = constants_pattern.search(content[line_index + 2])
            type, A, B, C = match.group(1), float(match.group(2)), float(match.group(3)), match.group(4)
            if type == 'PHOTABC':
                aqua_photo.append(dict(reactants = reactants, products=products, A=A, B=B, C=float(C)))
            elif type == 'TEMP3':
                aqua_temp.append(dict(reactants = reactants, products=products, A=A, B=B))
            else:
                print(f"Unknown aqua type: {type}")
            line_index += 2
        elif type == 'DISS':
            reactants, products = parse_reactants_products(content[line_index + 1])
            match = constants_pattern.search(content[line_index + 2])
            type, A, B, C = match.group(1), float(match.group(2)), float(match.group(3)), match.group(4)
            if C is None:
                diss_without_c.append(dict(reactants = reactants, products=products, A=A, B=B))
            else:
                diss_with_c.append(dict(reactants = reactants, products=products, A=A, B=B, C=float(C)))
        else:
            print(f'Unknown type: {type}')
    line_index += 1


species = dict()

henrys_law_reactions = list()
aerosol_phase_species = set()

aerosol_phase_name = "cloud water"

for item in henry:
    gas_phase = item['reactants'][0]
    aero_phase = item['products'][0]

    aerosol_phase_species.add(aero_phase)

    spec = dict(name=gas_phase, type="CHEM_SPEC")
    spec["HLC(298K) [M Pa-1]"] = item['A']
    spec["HLC exp factor [K]"] = item['B']
    spec["diffusion coeff [m2 s-1]"] = 1.00 # TODO: replace
    spec["N star"] = 1.00 # TODO: replace
    species[gas_phase] = spec

    species[aero_phase] = dict(name=aero_phase, type="CHEM_SPEC")

    henrys_law_reactions.append(
        {
            "type" : "HL_PHASE_TRANSFER",
            "gas-phase species" : gas_phase,
            "aerosol phase" : aerosol_phase_name,
            "aerosol-phase species" : aero_phase,
            "aerosol-phase water" : "aH2O" #TODO: verify this
        }
    )

aero_phase_species = [
]

for collection in [aqua_photo, aqua_temp, diss_with_c, diss_without_c]:
    for item in collection:
        for name in item['reactants']:
            if name not in species:
                spec = dict(name=name, type="CHEM_SPEC")
                species[name] = spec
        for name in item['products']:
            if name not in species:
                spec = dict(name=name, type="CHEM_SPEC")
                species[name] = spec

with open('species.json', 'w') as f:
    json.dump(
        { 
            "camp-data" : list(species.values())
        }, f, indent=2
    )

photolysis_reactions = [
    {
        "type":  "PHOTOLYSIS",
        "reactants": {
            reactant: {} for reactant in reaction["reactants"]
        },
        "products": {
            product: {} for product in reaction["products"]
        }
    }
    for reaction in aqua_photo
]

# CAMP uses this formula: A * exp(-Ea/Kb * (1/T)) * (T/D) ** B * (1 + E*P)
# CAPRAM uses A*exp(B * (1/T - 1/298))
# 
# The A in CAPRAM is not equal to A in CAMP. A in CAPRAM is the rate constant at 298 K (A=k(298K))
# 
# To convert CAPRAM's A into CAMP's A, 
#     A * exp(B*(1/T - 1/298)) 
#   = A * exp(B/T) * exp(-B/298)
#   = (A * exp(-B/298)) * exp(B/T) 
#   = A_ * exp(-B/298)
#   with A_ = A * exp(-B/298)
# Then specify the "C" option of the the CAMP configuaration 
# by setting it equal to -B of CAPRAM.
#
# CAMP's B, D, and E are all left as the default values
# For example
# CAPRAM A = 50, B=0 -> CAMP A = A(capram)*exp(-1 * B(capram) / 298), C(camp) = B(capram)
#
#

arrhenius_reactions = list()
for reaction in aqua_temp:
    arrhenius_reactions.append(
        {
            "type":  "ARRHENIUS",
            "reactants": {
                reactant: {} for reactant in reaction["reactants"]
            },
            "products": {
                product: {} for product in reaction["products"]
            },
            "A" : reaction['A'] * np.exp(-1 * reaction['B'] / 298),
            "C" : reaction['B'],
            "aerosol phase" : aerosol_phase_name,
            "aerosol-phase water" : "H2O_aq"
        }
    )
    aerosol_phase_species.update(reaction["reactants"])
    aerosol_phase_species.update(reaction["products"])
    

aqueous_equilibrium = list()
for reaction in diss_with_c:
    aqueous_equilibrium.append(
        {
            "type":  "AQUEOUS_EQUILIBRIUM",
            "reactants": {
                reactant: {} for reactant in reaction["reactants"]
            },
            "products": {
                product: {} for product in reaction["products"]
            },
            "A" : reaction['A'],
            "C" : reaction['B'],
            "k_reverse" : reaction['C'],
            "phase": aerosol_phase_name,
            "aerosol-phase water" : "H2O_aq"
        }
    )
    aerosol_phase_species.update(reaction["reactants"])
    aerosol_phase_species.update(reaction["products"])

for reaction in diss_without_c:
    aqueous_equilibrium.append(
        [
            {
                "type":  "AQUEOUS_EQUILIBRIUM",
                "reactants": {
                    reactant: {} for reactant in reaction["reactants"]
                },
                "products": {
                    product: {} for product in reaction["products"]
                },
                "A" : reaction['A'],
                "C" : 0,
                "k_reverse" : reaction['B'],
                "phase": aerosol_phase_name,
                "aerosol-phase water" : "H2O_aq"
            }
        ]
    )
    aerosol_phase_species.update(reaction["reactants"])
    aerosol_phase_species.update(reaction["products"])

mechanisms = { 
    "camp-data" : [
        {
            "name": "CAPRAM2.4 reduced",
            "type" : "MECHANISM",
            "url": "https://capram.tropos.de/capram_24.html",
            "reactions": [
                *photolysis_reactions,
                *arrhenius_reactions,
                *aqueous_equilibrium,
                *henrys_law_reactions
            ]
        },
        {
            "name" : aerosol_phase_name,
            "type" : "AERO_PHASE",
            "species" : list(aerosol_phase_species)
        },
        {
            "type" : "AERO_REP_MODAL_BINNED_MASS",
            "name" : "my aero rep 2",
            "modes/bins" :
            {
            "the mode" :
            {
                "type" : "MODAL",
                "phases" : [aerosol_phase_name],
                "shape" : "LOG_NORMAL"
            }
            }
        }
    ]
}

with open('mechanism.json', 'w') as f:
    json.dump(mechanisms, f, indent=2)