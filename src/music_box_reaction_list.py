from typing import List

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

    def add_reaction(self, reaction):
        """
        Add a Reaction instance to the ReactionList.

        Args:
            reaction (Reaction): The Reaction instance to be added.
        """
        self.reactions.append(reaction)
