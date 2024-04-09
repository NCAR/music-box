class ReactionRate:
    """
    Represents a reaction rate with attributes such as the associated reaction and rate.

    Attributes:
        reaction (Reaction): The associated reaction.
        rate (float): The rate of the reaction in 1/s (inverse seconds).
    """

    def __init__(self, reaction, rate):
        """
        Initializes a new instance of the ReactionRate class.

        Args:
            reaction (Reaction): The associated reaction.
            rate (float): The rate of the reaction in 1/s (inverse seconds).
        """
        self.reaction = reaction
        self.rate = rate
