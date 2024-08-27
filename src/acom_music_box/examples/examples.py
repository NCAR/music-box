import os

class Example:
    def __init__(self, name, description, path):
        self.name = name
        self.description = description
        self.path = path
    
    def __str__(self):
        return f'{self.name}: {self.description}'
    
    def __repr__(self):
        return f'{self.name}: {self.description}'

    @classmethod
    def from_config(cls, display_name, folder_name, description):
        path = os.path.join(os.path.dirname(__file__), 'configs', folder_name, 'my_config.json')
        return cls(name=display_name, description=description, path=path)

# Create instances
CarbonBond5 = Example.from_config(
    display_name='Carbon Bond IV', 
    folder_name='carbon_bond_5',
    description= 'Carbon bond 5')
Chapman= Example.from_config(
    display_name='Chapman', 
    folder_name='chapman',
    description= 'The Chapman cycle with conditions over Boulder, Colorado')
FlowTube = Example.from_config(
    display_name='Flow Tube', 
    folder_name='flow_tube',
    description= 'A fictitious flow tube experiment')
Analytical = Example.from_config(
    display_name='Analytical', 
    folder_name='analytical',
    description= 'An example of an analytical solution to a simple chemical system')