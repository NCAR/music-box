import sqlite3
import re
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
    "counted": counted
}

def get_count(cursor, stmt):
    cursor.execute(stmt)
    stmt = cursor.fetchone()[0]
    return stmt

def get_all(cursor, stmt):
    cursor.execute(stmt)
    stmt = cursor.fetchall()
    return stmt

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

    for reaction in reactions[:15]:
        print(reaction)

translate_mcm()
