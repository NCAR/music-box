import sqlite3
import re

statements = {
    "number_of_reactions": "SELECT COUNT(DISTINCT ReactioNID) FROM Reactions WHERE Mechanism = 'MCM';",
    "number_of_rate_constants": "SELECT COUNT(DISTINCT RATE) FROM Reactions INNER JOIN Rates USING(Rate) WHERE Mechanism = 'MCM';",
    "rate_types": "SELECT RateType, COUNT(*) FROM Rates GROUP BY RateType;",
    "reactions_with_rate_types": "SELECT r.ReactionID, r.Rate, rates.RateType FROM Reactions r INNER JOIN Rates rates ON r.Rate = rates.Rate;",
    "get_reactants_and_products_per_reaction": "SELECT r.ReactionID, r.Rate, GROUP_CONCAT(reactants.Species, ', ') AS ReactantSpecies, GROUP_CONCAT(products.Species, ', ') AS ProductSpecies FROM Reactions r LEFT JOIN Reactants reactants ON r.ReactionID = reactants.ReactionID LEFT JOIN Products products ON r.ReactionID = products.ReactionID WHERE r.Mechanism = 'MCM' GROUP BY r.ReactionID;"
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
    print(get_count(cursor, statements["number_of_reactions"]))
    print(get_count(cursor, statements["number_of_rate_constants"]))
    print(get_all(cursor, statements["rate_types"]))
    print(get_all(cursor, statements["reactions_with_rate_types"])[:10])
    print(get_all(cursor, statements["get_reactants_and_products_per_reaction"])[:10])

translate_mcm()
