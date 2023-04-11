import re

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

# CLASS: DISS, TYPE: DCONST
# Dissociation
# Ke = A 
# B= k(back reaction) 
diss = []


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
is_diss = False
while line_index < len(content):
    line = content[line_index].strip()
    if line.startswith('COMMENT  CLASS: AQUA, TYPE: PHOTABC'):
        pass
    if line.startswith('COMMENT  CLASS: AQUA;  TYPE: TEMP3'):
        pass
    if line.startswith('COMMENT  CLASS: DISS, TYPE: DCONST'):
        is_diss = True
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
            type, A, B, C = match.group(1), match.group(2), match.group(3), match.group(4)
            if type == 'PHOTABC':
                aqua_photo.append(dict(reactants = reactants, products=products, A=A, B=B, C=C))
            elif type == 'TEMP3':
                if is_diss:
                    diss.append(dict(reactants = reactants, products=products, A=A, B=B))
                else:
                    aqua_temp.append(dict(reactants = reactants, products=products, A=A, B=B))
            else:
                print(f"Unknown aqua type: {type}")
            line_index += 2
        elif type == 'DISS':
            reaction = content[line_index + 1].strip().split('=')
            reactants = [i.strip() for i in reaction[0].strip().split('+')]
            products = [i.strip() for i in reaction[1].strip().split('+')]
            match = constants_pattern.search(content[line_index + 2])
            type, A, B, C = match.group(1), match.group(2), match.group(3), match.group(4)
            if C is None:
                diss.append(dict(reactants = reactants, products=products, A=A, B=B))
            else:
                diss.append(dict(reactants = reactants, products=products, A=A, B=B, C=C))
        else:
            print(f'Unknown type: {type}')
    line_index += 1
