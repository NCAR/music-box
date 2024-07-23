import sqlite3
from tabulate import tabulate

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


def convert_tokenized_rates(rates):
  pass

def convert_photolysis_rates(rates, photolysis_parameters):
  print(photolysis_parameters)
  multiples = [i for i in rates if '*' in i[1]]
  non_multiples = [i for i in rates if '*' not in i[1]]
  # for rate in non_multiples[:15]:
  #   print(rate)
  # print()
  # for rate in multiples[:15]:
  #   print(rate)

def convert_null_rates(rates):
  pass

def translate_mcm():
  conn = sqlite3.connect('data/mcm.db')
  cursor = conn.cursor()
  total_number_of_mcm_reactions = get_count(cursor, statements["number_of_reactions"])

  number_of_rate_types = get_all(cursor, statements["mcm_reactions_with_rate_type"])
  number_of_rate_types = [(('Null' if rate_type is None else rate_type), count) for rate_type, count in number_of_rate_types]
  total_number_of_rate_types = sum([x[1] for x in number_of_rate_types])

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

  (null, tokenized, photolysis) = group_reactions_by_rate_type(reactions)
  tokenized = convert_tokenized_rates(tokenized)
  photolysis = convert_photolysis_rates(photolysis, photolysis_parameters)
  null = convert_null_rates(null)

translate_mcm()
