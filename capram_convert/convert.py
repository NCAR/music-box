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

line_index = 0
while line_index < len(content):
    line = content[line_index].strip()
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
            reaction = content[line_index + 1].strip().split('=')
            reactants = [i.strip() for i in reaction[0].strip().split('+')]
            products = [i.strip() for i in reaction[1].strip().split('+')]
            # thanks chatgpt
            pattern = re.compile(r"(?:PHOTABC|TEMP3):\s+A:\s+([\d\.e+-]+)\s+B:\s+([\d\.e+-]+)(?:\s+C:\s+([\d\.e+-]+))?")
            match = pattern.search(content[line_index + 2])
            if content[line_index + 2].startswith('PHOTABC'):
                A, B, C = match.group(1), match.group(2), match.group(3)
                aqua_photo.append(dict(reactants = reactants, products=products, A=A, B=B, C=C))
            elif content[line_index + 2].startswith('TEMP3'):
                A, B = match.group(1), match.group(2)
                aqua_temp.append(dict(reactants = reactants, products=products, A=A, B=B, C=C))
            else:
                print(f"Unknown aqua type: {content[line_index + 2]}")
        elif type == 'DISS':
            pass
        else:
            print(f'Unknown type: {type}')
    line_index += 1
