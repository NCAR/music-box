import sys

# Class Logger is included here for completeness,
# but not used because progress() is such a lighweight function.
class Logger:
    """
    Logs messages to the console, which can then be captured to a log file.

    Attributes:
    """

    def __init__(self):
        """
        Initializes a new instance of the Reaction class.

        Args:
            name (str): The name of the reaction.
            reaction_type (str): The type of the reaction.
            reactants (List[Reactant]): A list of Reactant instances representing the reactants. Default is an empty list.
            products (List[Product]): A list of Product instances representing the products. Default is an empty list.
            scaling_factor (float, optional): A scaling factor for the reaction rate. Defaults to None.
        """
        pass



# Display progress message on the console.
# endString = set this to '' for no return
def progress(message, endString='\n'):
    if (True):   # disable here in production
        print(message, end=endString)
        sys.stdout.flush()
