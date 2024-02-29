from typing import List

class Reaction:
    """
    Represents a chemical reaction with attributes such as name, type, reactants, and products.

    Attributes:
        name (str): The name of the reaction.
        reaction_type (str): The type of the reaction.
        reactants (List[Reactant]): A list of Reactant instances representing the reactants. Default is an empty list.
        products (List[Product]): A list of Product instances representing the products. Default is an empty list.
    """

    def __init__(self, name, reaction_type, reactants=None, products=None):
        """
        Initializes a new instance of the Reaction class.

        Args:
            name (str): The name of the reaction.
            reaction_type (str): The type of the reaction.
            reactants (List[Reactant]): A list of Reactant instances representing the reactants. Default is an empty list.
            products (List[Product]): A list of Product instances representing the products. Default is an empty list.
        """
        self.name = name
        self.reaction_type = reaction_type
        self.reactants = reactants if reactants is not None else []
        self.products = products if products is not None else []

    def add_reactant(self, reactant):
        """
        Add a Reactant instance to the list of reactants.

        Args:
            reactant (Reactant): The Reactant instance to be added.
        """
        self.reactants.append(reactant)

    def add_product(self, product):
        """
        Add a Product instance to the list of products.

        Args:
            product (Product): The Product instance to be added.
        """
        self.products.append(product)
