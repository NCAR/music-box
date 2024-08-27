import os


class Example:
    def __init__(self, name, short_name, description, path):
        self.name = name
        self.short_name = short_name
        self.description = description
        self.path = path

    def __str__(self):
        return f'{self.name}: {self.description}'

    def __repr__(self):
        return f'{self.name}: {self.description}'

    @classmethod
    def from_config(cls, display_name, folder_name, short_name, description):
        path = os.path.join(os.path.dirname(__file__), 'configs', folder_name, 'my_config.json')
        return cls(name=display_name, short_name=short_name, description=description, path=path)


class _Examples:
    CarbonBond5 = Example.from_config(
        display_name='Carbon Bond IV',
        short_name='CB5',
        folder_name='carbon_bond_5',
        description='Carbon bond 5')
    Chapman = Example.from_config(
        display_name='Chapman',
        short_name='Chapman',
        folder_name='chapman',
        description='The Chapman cycle with conditions over Boulder, Colorado')
    FlowTube = Example.from_config(
        display_name='Flow Tube',
        short_name='FlowTube',
        folder_name='flow_tube',
        description='A fictitious flow tube experiment')
    Analytical = Example.from_config(
        display_name='Analytical',
        short_name='Analytical',
        folder_name='analytical',
        description='An example of an analytical solution to a simple chemical system')

    @classmethod
    def get_all(cls):
        return [cls.CarbonBond5, cls.Chapman, cls.FlowTube, cls.Analytical]

    def __iter__(self):
        return iter(self.get_all())

    def __getattr__(self, item):
        if hasattr(self, item):
            return getattr(self, item)
        raise AttributeError(f"'{self.__class__.__name__}' object has no attribute '{item}'")


Examples = _Examples()
