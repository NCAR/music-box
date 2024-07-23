import sqlite3
from tabulate import tabulate
import re

counted = """
WITH ReactantCounts AS (
    SELECT ReactionID, GROUP_CONCAT(CAST(count AS TEXT) || ' ' || Species) AS ReactantSpecies
    FROM (
        SELECT ReactionID, Species, COUNT(*) as count
        FROM Reactants
        GROUP BY ReactionID, Species
    )
    GROUP BY ReactionID
),
ProductCounts AS (
    SELECT ReactionID, GROUP_CONCAT(CAST(count AS TEXT) || ' ' || Species) AS ProductSpecies
    FROM (
        SELECT ReactionID, Species, COUNT(*) as count
        FROM Products
        GROUP BY ReactionID, Species
    )
    GROUP BY ReactionID
)
SELECT r.ReactionID, r.Rate, rates.RateType,
       rc.ReactantSpecies, pc.ProductSpecies
FROM Reactions r
INNER JOIN Rates rates ON r.Rate = rates.Rate
LEFT JOIN ReactantCounts rc ON r.ReactionID = rc.ReactionID
LEFT JOIN ProductCounts pc ON r.ReactionID = pc.ReactionID
WHERE r.Mechanism = 'MCM'
GROUP BY r.ReactionID, r.Rate, rates.RateType;
"""

statements = {
  "number_of_reactions": "SELECT COUNT(DISTINCT ReactionID) FROM Reactions WHERE Mechanism = 'MCM';",
  "number_of_rate_constants": "SELECT COUNT(DISTINCT RATE) FROM Reactions INNER JOIN Rates USING(Rate) WHERE Mechanism = 'MCM';",
  "rate_types": "SELECT RateType, COUNT(*) FROM Rates GROUP BY RateType;",
  "mcm_reactions_with_rate_type": "SELECT rates.RateType, COUNT(*) FROM Reactions r INNER JOIN Rates rates ON r.Rate = rates.Rate WHERE MEchanism = 'MCM' GROUP BY rates.RateType;",
  "photolysis_rate_paramters": "SELECT J, l, m, n FROM PhotolysisParameters;",
  "tokenized_rates": "SELECT Token, Definition FROM Tokens;",
  "counted": counted
}

def convert_to_float(s):
  if type(s) == str:
    return float(s.replace('D', 'E'))
  return s

def get_count(cursor, stmt):
  cursor.execute(stmt)
  stmt = cursor.fetchone()[0]
  return stmt

def get_all(cursor, stmt):
  cursor.execute(stmt)
  stmt = cursor.fetchall()
  return stmt
  
def group_reactions_by_rate_type(reactions):
  null = []
  tokenized = []
  photolysis = []
  for reaction in reactions:
    if reaction[2] is None:
      null.append(reaction)
    elif reaction[2] == 'Tokenized':
      tokenized.append(reaction)
    elif reaction[2] == 'Photolysis':
      photolysis.append(reaction)
  return (null, tokenized, photolysis)

def convert_tokenized_rates(rates, tokenized_rates):
  temperature_dependent = []
  power_rates = []
  named_tokenized = []
  for rate in rates:
    if 'TEMP' in rate[1]:
      temperature_dependent.append(rate)
    else:
      if '@' in rate[1]:
        power_rates.append(rate)
      else:
        named_tokenized.append(rate)
  
  # for list in [temperature_dependent, power_rates, named_tokenized]:
  #   for rate in list[:10]:
  #     print(rate[1])
  #   print()
  # print(tokenized_rates)

  # this will match all of the tokens, 
  # but also EXP and TEMP. So if you use it, filter out the ones you don't want
  tokens = r'\b[A-Z]+[A-Z0-9]*\b'

  counts = [
    ('Temperature Dependent', len(temperature_dependent)),
    ('Power', len(power_rates)),
    ('Named Tokenized Rates', len(named_tokenized)),
    ('Total', len(temperature_dependent) + len(power_rates) + len(named_tokenized))
  ]
  print()
  print(tabulate(counts, headers=['Tokenized Type', 'Count'], tablefmt='github'))

def convert_photolysis_rates(rates, photolysis_parameters):
  multiples = [i for i in rates if '*' in i[1]]
  non_multiples = [i for i in rates if '*' not in i[1]]
  counts = [
    ('Multiples', len(multiples)),
    ('Non Multiples', len(non_multiples)),
    ('Total', len(multiples) + len(non_multiples))
  ]
  print()
  print(tabulate(counts, headers=['Photolysis Type', 'Count'], tablefmt='github'))

def convert_null_rates(rates):
  temperature_dependent = []
  ro2_reactions = []
  non_ro2_reactions = []
  for rate in rates:
    if 'TEMP' in rate[1]:
      temperature_dependent.append(rate)
    else:
      if 'RO2' in rate[1]:
        ro2_reactions.append(rate)
      else:
        non_ro2_reactions.append(rate)
  counts = [
    ('Temperature Dependent', len(temperature_dependent)),
    ('RO2 Dependent', len(ro2_reactions)),
    ('Non RO2 Dependent', len(non_ro2_reactions)),
    ('Total', len(temperature_dependent) + len(ro2_reactions) + len(non_ro2_reactions))
  ]

  print()
  print(tabulate(counts, headers=['Null Type', 'Count'], tablefmt='github'))
  
def translate_mcm():
  conn = sqlite3.connect('data/mcm.db')
  cursor = conn.cursor()
  total_number_of_mcm_reactions = get_count(cursor, statements["number_of_reactions"])

  number_of_rate_types = get_all(cursor, statements["mcm_reactions_with_rate_type"])
  number_of_rate_types = [(('Null' if rate_type is None else rate_type), count) for rate_type, count in number_of_rate_types]
  total_number_of_rate_types = sum([x[1] for x in number_of_rate_types])
  number_of_rate_types.append(('Total', total_number_of_rate_types)) 

  assert(total_number_of_mcm_reactions == total_number_of_rate_types)
  print(tabulate(number_of_rate_types, headers=['Rate Type', 'Count'], tablefmt='github'))

  reactions = get_all(cursor, statements["counted"])
  assert(len(reactions) == total_number_of_mcm_reactions)

  photolysis_parameters = get_all(cursor, statements["photolysis_rate_paramters"])
  photolysis_parameters = {
    i[0]: {
      'l': convert_to_float(i[1]),
      'm': convert_to_float(i[2]),
      'n': convert_to_float(i[3])
    } for i in photolysis_parameters
  }
  tokenized_rates = get_all(cursor, statements["tokenized_rates"])
  tokenized_rates = {i[0]: i[1] for i in tokenized_rates}

  (null, tokenized, photolysis) = group_reactions_by_rate_type(reactions)
  tokenized = convert_tokenized_rates(tokenized, tokenized_rates)
  photolysis = convert_photolysis_rates(photolysis, photolysis_parameters)
  null = convert_null_rates(null)

translate_mcm()
