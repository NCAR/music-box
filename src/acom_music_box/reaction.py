from typing import List


class Reaction:
    """
    Represents a chemical reaction with attributes such as name, type, reactants, and products.

    Attributes:
        name (str): The name of the reaction.
        reaction_type (str): The type of the reaction.
        reactants (List[Reactant]): A list of Reactant instances representing the reactants. Default is an empty list.
        products (List[Product]): A list of Product instances representing the products. Default is an empty list.
        scaling_factor (float, optional): A scaling factor for the reaction rate. Defaults to None.
    """

    def __init__(
            self,
            name=None,
            reaction_type=None,
            reactants=None,
            products=None,
            scaling_factor=None):
        """
        Initializes a new instance of the Reaction class.

        Args:
            name (str): The name of the reaction.
            reaction_type (str): The type of the reaction.
            reactants (List[Reactant]): A list of Reactant instances representing the reactants. Default is an empty list.
            products (List[Product]): A list of Product instances representing the products. Default is an empty list.
            scaling_factor (float, optional): A scaling factor for the reaction rate. Defaults to None.
        """
        self.name = name
        self.reaction_type = reaction_type
        self.reactants = reactants if reactants is not None else []
        self.products = products if products is not None else []
        self.scaling_factor = scaling_factor

    def __str__(self):
        return f"{self.name}: {self.reaction_type}"

    def __repr__(self):
        return f"{self.name}: {self.reaction_type}"

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

    def short_type(self):
        """
        Return the first letter of the reaction type.

        Returns:
            str: The first letter of the reaction type.
        """
        type_map = {
            "EMISSION": "EMIS",
            "PHOTOLYSIS": "PHOT",
            "FIRST_ORDER_LOSS": "LOSS",
            "BRANCHED": "BRAN",
            "ARRHENIUS": "ARRH",
            "TUNNELING": "TUNN",
            "TROE_TERNARY": "TROE",
        }
        return type_map.get(self.reaction_type, "UNKNOWN")


class Branched(Reaction):

    def __init__(
            self,
            name=None,
            reaction_type=None,
            reactants=None,
            alkoxy_products=None,
            nitrate_products=None,
            X=None,
            Y=None,
            a0=None,
            n=None):
        """
        Initializes an instance of the Branched class.

        This method initializes an instance of the Branched class with optional parameters for name,
        reaction type, reactants, alkoxy products, nitrate products, X, Y, a0, and n. If these parameters
        are not provided, they will be set to None.

        Args:
            name (str, optional): The name of the reaction. Defaults to None.
            reaction_type (str, optional): The type of the reaction. Defaults to None.
            reactants (list, optional): A list of reactants involved in the reaction. Defaults to None.
            alkoxy_products (list, optional): A list of alkoxy products produced by the reaction. Defaults to None.
            nitrate_products (list, optional): A list of nitrate products produced by the reaction. Defaults to None.
            X (float, optional): A parameter related to the reaction. Defaults to None.
            Y (float, optional): A parameter related to the reaction. Defaults to None.
            a0 (float, optional): A parameter related to the reaction. Defaults to None.
            n (float, optional): A parameter related to the reaction. Defaults to None.
        """

        super().__init__(
            name,
            reaction_type,
            reactants,
            alkoxy_products +
            nitrate_products)
        self.X = X
        self.Y = Y
        self.a0 = a0
        self.n = n
        self.alkoxy_products = alkoxy_products
        self.nitrate_products = nitrate_products


class Arrhenius(Reaction):
    def __init__(
            self,
            name=None,
            reaction_type=None,
            reactants=None,
            products=None,
            A=None,
            B=None,
            D=None,
            E=None,
            Ea=None):
        """
        Initializes an instance of the Arrhenius class.

        This method initializes an instance of the Arrhenius class with optional parameters for name,
        reaction type, reactants, products, and Arrhenius parameters A, B, D, E, Ea. If these parameters
        are not provided, they will be set to None.

        Args:
            name (str, optional): The name of the reaction. Defaults to None.
            reaction_type (str, optional): The type of the reaction. Defaults to None.
            reactants (list, optional): A list of reactants involved in the reaction. Defaults to None.
            products (list, optional): A list of products produced by the reaction. Defaults to None.
            A (float, optional): The pre-exponential factor in the Arrhenius equation. Defaults to None.
            B (float, optional): The temperature exponent in the Arrhenius equation. Defaults to None.
            D (float, optional): A parameter in the Arrhenius equation. Defaults to None.
            E (float, optional): A parameter in the Arrhenius equation. Defaults to None.
            Ea (float, optional): The activation energy in the Arrhenius equation. Defaults to None.
        """
        super().__init__(name, reaction_type, reactants, products)
        self.A = A
        self.B = B
        self.D = D
        self.E = E
        self.Ea = Ea


class Tunneling(Reaction):
    def __init__(
            self,
            name=None,
            reaction_type=None,
            reactants=None,
            products=None,
            A=None,
            B=None,
            C=None):
        """
        Initializes an instance of the Tunneling class.

        This method initializes an instance of the Tunneling class with optional parameters for name,
        reaction type, reactants, products, and Tunneling parameters A, B, C. If these parameters
        are not provided, they will be set to None.

        Args:
            name (str, optional): The name of the reaction. Defaults to None.
            reaction_type (str, optional): The type of the reaction. Defaults to None.
            reactants (list, optional): A list of reactants involved in the reaction. Defaults to None.
            products (list, optional): A list of products produced by the reaction. Defaults to None.
            A (float, optional): A parameter related to the reaction. Defaults to None.
            B (float, optional): A parameter related to the reaction. Defaults to None.
            C (float, optional): A parameter related to the reaction. Defaults to None.
        """
        super().__init__(name, reaction_type, reactants, products)
        self.A = A
        self.B = B
        self.C = C


class Troe_Ternary(Reaction):
    def __init__(
            self,
            name=None,
            reaction_type=None,
            reactants=None,
            products=None,
            k0_A=None,
            k0_B=None,
            k0_C=None,
            kinf_A=None,
            kinf_B=None,
            kinf_C=None,
            Fc=None,
            N=None):
        """
        Initializes an instance of the Troe_Ternary class.

        This method initializes an instance of the Troe_Ternary class with optional parameters for name,
        reaction type, reactants, products, and Troe_Ternary parameters k0_A, k0_B, k0_C, kinf_A, kinf_B,
        kinf_C, Fc, N. If these parameters are not provided, they will be set to None.

        Args:
            name (str, optional): The name of the reaction. Defaults to None.
            reaction_type (str, optional): The type of the reaction. Defaults to None.
            reactants (list, optional): A list of reactants involved in the reaction. Defaults to None.
            products (list, optional): A list of products produced by the reaction. Defaults to None.
            k0_A (float, optional): A parameter related to the reaction. Defaults to None.
            k0_B (float, optional): A parameter related to the reaction. Defaults to None.
            k0_C (float, optional): A parameter related to the reaction. Defaults to None.
            kinf_A (float, optional): A parameter related to the reaction. Defaults to None.
            kinf_B (float, optional): A parameter related to the reaction. Defaults to None.
            kinf_C (float, optional): A parameter related to the reaction. Defaults to None.
            Fc (float, optional): A parameter related to the reaction. Defaults to None.
            N (float, optional): A parameter related to the reaction. Defaults to None.
        """
        super().__init__(name, reaction_type, reactants, products)
        self.k0_A = k0_A
        self.k0_B = k0_B
        self.k0_C = k0_C
        self.kinf_A = kinf_A
        self.kinf_B = kinf_B
        self.kinf_C = kinf_C
        self.Fc = Fc
        self.N = N
