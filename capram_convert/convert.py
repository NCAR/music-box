import re
import json
import numpy as np

# file from https://capram.tropos.de/capram_24.html
with open("capram24_red.txt") as f:
    content = f.readlines()

##
# comments here taken from the capram file
##

# for example  molecules_to_identifier['CO2'] = 'aCO2'
# for example  molecules_to_identifier['aCO2'] = 'CO2'
molecules_identifier_mapping = {}

# CLASS: HENRY, TYPE: TEMP3
# Phase transfer
# Kh = A exp(B (1/T - 1/298))
# B = dH/R [K]
# Further uptake parameters according to Schwartz's approach (alpha, Dg)  
# are read elsewhere in the program
# for example, henry['CO2'] = {A: '3.1e-2', B: '2423.0'}
henry = {}

# CLASS: AQUA, TYPE: PHOTABC photolysis reactions according to 
# j = A * exp (B *(1 - 1 /(cos (C * chi)); A = jmax; chi = zenith angle
aqua_photo = []

# CLASS: AQUA;  TYPE: TEMP3
# TEmperature dependent reation
# k(T)=A*exp(B*(1/T-1/298))
# A=k(298 K)
# B=-Ea/R   
aqua_temp = []

# CLASS: DISS, TYPE: DTEMP
# Temperature dependent dissociation
# Ke = A exp(B*(1/T - 1/298)); 
# B=-Ea/R  
# C = k(back reaction)
diss_with_c = []
# CLASS: DISS, TYPE: DCONST
# Dissociation
# Ke = A 
# B= k(back reaction) 
diss_without_c = []

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
    if line.startswith('COMMENT  CLASS: AQUA, TYPE: PHOTABC'):
        pass
    if line.startswith('COMMENT  CLASS: AQUA;  TYPE: TEMP3'):
        pass
    if line.startswith('COMMENT  CLASS: DISS, TYPE: DCONST'):
        pass
    if line.startswith('CLASS'):
        type = line.split(':')[1].strip()
        if type == 'HENRY':
            mol = content[line_index + 1].strip().split(' = ')
            ident = mol[1].strip()
            mol = mol[0].strip()

            temp = content[line_index + 2].strip().split('TEMP3:')
            a = temp[1].split('B:')[0].strip().split('A:')[1].strip()
            b = temp[1].split('B:')[1].strip()

            molecules_identifier_mapping[mol] = ident
            molecules_identifier_mapping[ident] = mol
            henry[mol] = { 'A': a, 'B': b }

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
            reaction = content[line_index + 1].strip().split('=')
            reactants = [i.strip() for i in reaction[0].strip().split('+')]
            products = [i.strip() for i in reaction[1].strip().split('+')]
            match = constants_pattern.search(content[line_index + 2])
            type, A, B, C = match.group(1), float(match.group(2)), float(match.group(3)), match.group(4)
            if C is None:
                diss_without_c.append(dict(reactants = reactants, products=products, A=A, B=B))
            else:
                diss_with_c.append(dict(reactants = reactants, products=products, A=A, B=B, C=float(C)))
        else:
            print(f'Unknown type: {type}')
    line_index += 1


species = set(
    name for name,_ in molecules_identifier_mapping.items() if not name.startswith("a")
)

for list in [aqua_photo, aqua_temp, diss_with_c, diss_without_c]:
    for item in list:
        for spec in item['reactants']:
            species.add(spec)
        for spec in item['products']:
            species.add(spec)

with open('species.json', 'w') as f:
    json.dump(
        { 
            "camp-data" : [dict(name=name, type="CHEM_SPEC") for name in species] 
        }, f, indent=2
    )

henrys_law = [

]

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

arrhenius_reactions = [
    {
        "type":  "ARRHENIUS",
        "reactants": {
            reactant: {} for reactant in reaction["reactants"]
        },
        "products": {
            product: {} for product in reaction["products"]
        },
        "A" : reaction['A'] * np.exp(-1 * reaction['B'] / 298),
        "C" : reaction['B']
    }
    for reaction in aqua_temp
]

aqueous_equilibrium = [
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
        "k_reverse" : reaction['C']
    }
    for reaction in diss_with_c
]

aqueous_equilibrium.extend(
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
            "k_reverse" : reaction['B']
        }
        for reaction in diss_without_c
    ]
)

mechanisms = { 
    "camp-data" : [
        {
            "name": "CAPRAM2.4 reduced",
            "url": "https://capram.tropos.de/capram_24.html",
            "reactions": [
                *henrys_law,
                *photolysis_reactions,
                *arrhenius_reactions,
                *aqueous_equilibrium,
            ]
        }
    ]
}
with open('mechanism.json', 'w') as f:
    json.dump(mechanisms, f, indent=2)