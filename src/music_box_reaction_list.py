from typing import List
from music_box_reaction import Reaction, Branched, Arrhenius, Tunneling, Troe_Ternary
from music_box_reactant import Reactant
from music_box_product import Product

class ReactionList:
    """
    Represents a list of chemical reactions.

    Attributes:
        reactions (List[Reaction]): A list of Reaction instances.
    """

    def __init__(self, name=None, reactions=None):
        """
        Initializes a new instance of the ReactionList class.

        Args:
            reactions (List[Reaction]): A list of Reaction instances. Default is an empty list.
        """

        self.name = name
        self.reactions = reactions if reactions is not None else []

    @classmethod
    def from_UI_JSON(cls, UI_JSON, species_list):
        """
        Create a new instance of the ReactionList class from a JSON object.

        Args:
            UI_JSON (dict): A JSON object representing the reaction list.

        Returns:
            ReactionList: A new instance of the ReactionList class.
        """
        reactions = []

        for reaction in UI_JSON['mechanism']['reactions']['camp-data'][0]['reactions']:
            name = reaction['MUSICA name'] if 'MUSICA name' in reaction else None
            reaction_type = reaction['type']

            reactants = []

            for reactant, reactant_info in reaction['reactants'].items():
                match = filter(lambda x: x.name == reactant, species_list.species)
                species = next(match, None)
                quantity = reactant_info['qty'] if 'qty' in reactant_info else None

                reactants.append(Reactant(species, quantity))

            products = []

            if 'products' in reaction:
                for product, product_info in reaction['products'].items():
                    match = filter(lambda x: x.name == product, species_list.species)
                    species = next(match, None)
                    yield_value = product_info['yield'] if 'yield' in product_info else None

                    products.append(Product(species, yield_value))
                    
            if reaction_type == 'WENNBERG_NO_RO2':
                alkoxy_products = []

                for alkoxy_product, alkoxy_product_info in reaction['alkoxy products'].items():
                    match = filter(lambda x: x.name == alkoxy_product, species_list.species)
                    species = next(match, None)
                    yield_value = alkoxy_product_info['yield'] if 'yield' in alkoxy_product_info else None

                    alkoxy_products.append(Product(species, yield_value))

                nitrate_products = []

                for nitrate_product, nitrate_product_info in reaction['nitrate products'].items():
                    match = filter(lambda x: x.name == nitrate_product, species_list.species)
                    species = next(match, None)
                    yield_value = nitrate_product_info['yield'] if 'yield' in nitrate_product_info else None

                    nitrate_products.append(Product(species, yield_value))

                X = reaction['X']
                Y = reaction['Y']
                a0 = reaction['a0']
                n = reaction['n']
                reactions.append(Branched(name, reaction_type, reactants, alkoxy_products, nitrate_products, X, Y, a0, n))
            elif reaction_type == 'ARRHENIUS':
                A = reaction['A']
                B = reaction['B']
                D = reaction['D']
                E = reaction['E']
                Ea = reaction['Ea']
                reactions.append(Arrhenius(name, reaction_type, reactants, products, A, B, D, E, Ea))
            elif reaction_type == 'WENNBERG_TUNNELING':
                A = reaction['A']
                B = reaction['B']
                C = reaction['C']
                reactions.append(Tunneling(name, reaction_type, reactants, products, A, B, C))
            elif reaction_type == 'TROE' or reaction_type == 'TERNARY_CHEMICAL_ACTIVATION':
                k0_A = reaction['k0_A']
                k0_B = reaction['k0_B']
                k0_C = reaction['k0_C']
                kinf_A = reaction['kinf_A']
                kinf_B = reaction['kinf_B']
                kinf_C = reaction['kinf_C']
                Fc = reaction['Fc']
                N = reaction['N']
                reactions.append(Troe_Ternary(name, reaction_type, reactants, products, k0_A, k0_B, k0_C, kinf_A, kinf_B, kinf_C, Fc, N))
            else:
                reactions.append(Reaction(name, reaction_type, reactants, products))

        return cls(reactions)

    def add_reaction(self, reaction):
        """
        Add a Reaction instance to the ReactionList.

        Args:
            reaction (Reaction): The Reaction instance to be added.
        """
        self.reactions.append(reaction)
