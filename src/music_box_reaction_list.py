from typing import List

class ReactionList:
    """
    Represents a list of chemical reactions.

    Attributes:
        mechanisms (List[Reaction]): A list of Reaction instances.
    """

    def __init__(self, mechanisms=None):
        """
        Initializes a new instance of the ReactionList class.

        Args:
            mechanisms (List[Reaction]): A list of Reaction instances. Default is an empty list.
        """
        self.mechanisms = mechanisms if mechanisms is not None else []

    def add_reaction(self, reaction):
        """
        Add a Reaction instance to the ReactionList.

        Args:
            reaction (Reaction): The Reaction instance to be added.
        """
        self.mechanisms.append(reaction)
