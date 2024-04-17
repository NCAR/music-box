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

    def __init__(self, name=None, reaction_type=None, reactants=None, products=None, scaling_factor=None):
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
        self.scaling_factor = scaling_factor

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

class Branched(Reaction):
    def __init__(self, name=None, reaction_type=None, reactants=None, alkoxy_products=None, nitrate_products=None, X=None, Y=None, a0=None, n=None):
        super().__init__(name, reaction_type, reactants, alkoxy_products + nitrate_products)
        self.X = X
        self.Y = Y
        self.a0 = a0
        self.n = n
        self.alkoxy_products = alkoxy_products
        self.nitrate_products = nitrate_products

class Arrhenius(Reaction):
    def __init__(self, name=None, reaction_type=None, reactants=None, products=None, A=None, B=None, D=None, E=None, Ea=None):
        super().__init__(name, reaction_type, reactants, products)
        self.A = A
        self.B = B
        self.D = D
        self.E = E
        self.Ea = Ea

class Tunneling(Reaction):
    def __init__(self, name=None, reaction_type=None, reactants=None, products=None, A=None, B=None, C=None):
        super().__init__(name, reaction_type, reactants, products)
        self.A = A
        self.B = B
        self.C = C

class Troe_Ternary(Reaction):
    def __init__(self, name=None, reaction_type=None, reactants=None, products=None, k0_A=None, k0_B=None, k0_C=None, kinf_A=None, kinf_B=None, kinf_C=None, Fc=None, N=None):
        super().__init__(name, reaction_type, reactants, products)
        self.k0_A = k0_A
        self.k0_B = k0_B
        self.k0_C = k0_C
        self.kinf_A = kinf_A
        self.kinf_B = kinf_B
        self.kinf_C = kinf_C
        self.Fc = Fc
        self.N = N