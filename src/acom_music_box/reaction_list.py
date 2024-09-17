import os
import json
from typing import List
from .reaction import Reaction, Branched, Arrhenius, Tunneling, Troe_Ternary
from .reactant import Reactant
from .product import Product

import logging
logger = logging.getLogger(__name__)


class ReactionList:
    """
    Represents a list of chemical reactions.

    Attributes:
        reactions (List[Reaction]): A list of Reaction instances.
    """

    def __init__(self, name=None, reactions=None):
        """
        Initializes an instance of the ReactionList class.

        This method initializes an instance of the ReactionList class with an optional name and list of reactions.
        If these parameters are not provided, they will be set to None.

        Args:
            name (str, optional): The name of the reaction list. Defaults to None.
            reactions (list, optional): A list of reactions in the reaction list. Defaults to None.
        """

        self.name = name
        self.reactions = reactions if reactions is not None else []

    @classmethod
    def from_UI_JSON(cls, UI_JSON, species_list):
        """
        Create a new instance of the ReactionList class from a JSON object.

        Args:
            UI_JSON (dict): A JSON object from the MusicBox Interactive UI representing the reaction list.

        Returns:
            ReactionList: A new instance of the ReactionList class.
        """
        list_name = UI_JSON['mechanism']['reactions']['camp-data'][0]['name']

        reactions = []

        for reaction in UI_JSON['mechanism']['reactions']['camp-data'][0]['reactions']:

            reactions.append(
                ReactionList.get_reactions_from_JSON(
                    reaction, species_list))

        return cls(list_name, reactions)

    @classmethod
    def from_config_JSON(cls, path_to_json, config_JSON, species_list):
        """
        Create a new instance of the ReactionList class from a JSON object.

        Args:
            UI_JSON (dict): A JSON object a config JSON representing the reaction list.

        Returns:
            ReactionList: A new instance of the ReactionList class.
        """

        reactions = []
        list_name = None

        # gets config file path
        config_file_path = os.path.join(
            os.path.dirname(path_to_json),
            config_JSON['model components'][0]['configuration file'])

        # opnens config path to read reaction file
        with open(config_file_path, 'r') as json_file:
            config = json.load(json_file)

            # assumes reactions file is second in the list
            if (len(config['camp-files']) > 1):
                reaction_file_path = os.path.dirname(
                    config_file_path) + "/" + config['camp-files'][1]
                with open(reaction_file_path, 'r') as reaction_file:
                    reaction_data = json.load(reaction_file)

                    # assumes there is only one mechanism

                    list_name = reaction_data['camp-data'][0]['name']
                    for reaction in reaction_data['camp-data'][0]['reactions']:
                        reactions.append(
                            ReactionList.get_reactions_from_JSON(
                                reaction, species_list))

        return cls(list_name, reactions)

    def add_reaction(self, reaction):
        """
        Add a Reaction instance to the ReactionList.

        Args:
            reaction (Reaction): The Reaction instance to be added.
        """
        self.reactions.append(reaction)

    @classmethod
    def get_reactants_from_JSON(self, reaction, species_list):
        """
        Retrieves reactants from a JSON object.

        This method iterates over the 'reactants' field of the provided JSON object,
        matches each reactant with a species from the provided species list, and
        creates a Reactant object for each one.

        Args:
            reaction (dict): A dictionary representing a reaction, as parsed from JSON.
            species_list (SpeciesList): A list of all possible species.

        Returns:
            list: A list of Reactant objects representing the reactants of the reaction.
        """
        reactants = []

        if ('reactants' in reaction.keys()):
            for reactant, reactant_info in reaction['reactants'].items():
                match = filter(
                    lambda x: x.name == reactant,
                    species_list.species)
                species = next(match, None)
                quantity = reactant_info['qty'] if 'qty' in reactant_info else None

                reactants.append(Reactant(species, quantity))
        return reactants

    @classmethod
    def get_products_from_JSON(self, reaction, species_list):
        """
        Extracts products from a JSON object.

        This method checks if the 'products' field is present in the provided JSON object.
        If it is, the method iterates over the 'products' field, matches each product with
        a species from the provided species list, and creates a Product object for each one.

        Args:
            reaction (dict): A dictionary representing a reaction, as parsed from JSON.
            species_list (SpeciesList): A list of all possible species.

        Returns:
            list: A list of Product objects representing the products of the reaction, or
                an empty list if the 'products' field is not present in the JSON object.
        """
        products = []
        if 'products' in reaction:
            for product, product_info in reaction['products'].items():
                match = filter(
                    lambda x: x.name == product,
                    species_list.species)
                species = next(match, None)
                yield_value = product_info['yield'] if 'yield' in product_info else None

                products.append(Product(species, yield_value))
        return products

    @classmethod
    def get_reactions_from_JSON(self, reaction, species_list):
        """
        Retrieves reactions from a JSON object.

        This method takes a reaction and a SpeciesList, and retrieves the corresponding reactions
        from a JSON object.

        Args:
            reaction (dict): A dictionary representing a reaction.
            species_list (SpeciesList): A SpeciesList containing the species involved in the reactions.

        Returns:
            Reaction: A Reaction object created from the provided JSON reaction.
        """

        name = reaction['MUSICA name'] if 'MUSICA name' in reaction else None
        scaling_factor = reaction['scaling factor'] if 'scaling factor' in reaction else None
        reaction_type = reaction['type']

        reactants = ReactionList.get_reactants_from_JSON(
            reaction, species_list)
        products = ReactionList.get_products_from_JSON(reaction, species_list)

        if reaction_type == 'WENNBERG_NO_RO2':
            alkoxy_products = []

            for alkoxy_product, alkoxy_product_info in reaction.get(
                    'alkoxy products', {}).items():
                match = filter(
                    lambda x: x.name == alkoxy_product,
                    species_list.species)
                species = next(match, None)
                yield_value = alkoxy_product_info.get('yield')

                alkoxy_products.append(Product(species, yield_value))

            nitrate_products = []

            for nitrate_product, nitrate_product_info in reaction.get(
                    'nitrate products', {}).items():
                match = filter(
                    lambda x: x.name == nitrate_product,
                    species_list.species)
                species = next(match, None)
                yield_value = nitrate_product_info.get('yield')

                nitrate_products.append(Product(species, yield_value))

            X = reaction.get('X')
            Y = reaction.get('Y')
            a0 = reaction.get('a0')
            n = reaction.get('n')
            return Branched(
                name,
                reaction_type,
                reactants,
                alkoxy_products,
                nitrate_products,
                X,
                Y,
                a0,
                n)
        elif reaction_type == 'ARRHENIUS':
            A = reaction.get('A')
            B = reaction.get('B')
            D = reaction.get('D')
            E = reaction.get('E')
            Ea = reaction.get('Ea')
            return Arrhenius(
                name,
                reaction_type,
                reactants,
                products,
                A,
                B,
                D,
                E,
                Ea)
        elif reaction_type == 'WENNBERG_TUNNELING':
            A = reaction.get('A')
            B = reaction.get('B')
            C = reaction.get('C')
            return Tunneling(name, reaction_type, reactants, products, A, B, C)
        elif reaction_type == 'TROE' or reaction_type == 'TERNARY_CHEMICAL_ACTIVATION':
            k0_A = reaction.get('k0_A')
            k0_B = reaction.get('k0_B')
            k0_C = reaction.get('k0_C')
            kinf_A = reaction.get('kinf_A')
            kinf_B = reaction.get('kinf_B')
            kinf_C = reaction.get('kinf_C')
            Fc = reaction.get('Fc')
            N = reaction.get('N')
            return Troe_Ternary(
                name,
                reaction_type,
                reactants,
                products,
                k0_A,
                k0_B,
                k0_C,
                kinf_A,
                kinf_B,
                kinf_C,
                Fc,
                N)
        else:
            return Reaction(
                name,
                reaction_type,
                reactants,
                products,
                scaling_factor)
