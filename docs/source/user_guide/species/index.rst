.. _species:

Defining chemical systems
=========================

This section covers the components of a chemical system as defined in MusicBox: Species, Phases, Reactions, and Mechanisms.
As a reminder, this section assumes you have imported::
   
   import musica.mechanism_configuration as mc

Species
--------
Chemical species are the fundamental units that participate in reactions. Define species using the `Species` class::
   
   X = mc.Species(name="X")
   Y = mc.Species(name="Y")
   Z = mc.Species(name="Z")

   species = {"X":X,"Y":Y,"Z":Z}

Species can be initialized with various chemistry-related paramaters (e.g., molecular weight, density, etc.). See the `MUSICA Species
documentation <https://ncar.github.io/musica/api/python.html#musica.mechanism_configuration.Species>`_ for further details.

Phases
-------
Species can be grouped into a phase. Most simple models use a single gas phase::
   
   gas = mc.Phase(name="gas",species=list(species.values()))

Reactions
----------
Reactions are defined with using rate-based classes such as `Arrhenius`.
Each class takes a unique set of rate parameters and the participating species::

   arr1 = mc.Arrhenius(name="X->Y", A=4.0e-3, C=50, reactants=[species["X"]], products=[species["Y"]], gas_phase=gas)
   arr2 = mc.Arrhenius(name="Y->Z", A=4.0e-3, C=50, reactants=[species["Y"]], products=[species["Z"]], gas_phase=gas)
   
For passing later on into a `Mechanism`, it is helpful to store your selected reactions into a dictionary::

   rxns = {"X->Y": arr1, "Y->Z": arr2} 

Several other reaction types are made available through MusicBox. Click the dropdowns below to learn more information about a specific reaction.
Full details of each class can be found in the :ref:`API Reference <api-ref>`.

.. dropdown:: Arrhenius

   .. math::

      A e^{C/T} (\frac{T}{D})^B (1.0 + E \times P)

   - A: pre-exponential factor [(:math:`\mathrm{mol\ m}{-3})^{(n-1)}s^{-1}`]
   - B: temperature exponent [unitless]
   - C: exponential term [:math:`\mathrm{K} ^{-1}`]
   - D: reference temperature [:math:`\mathrm{K}`]
   - E: pressure scaling term [:math:`\mathrm{Pa}^{-1}`]
   - T: temperature [:math:`\mathrm{K} ^{-1}`]
   - P: pressure [:math:`\mathrm{Pa}`]
   - n = number of reactants

   Example usage::
      
      arr = mc.Arrhenius(name="arr_ex", A=4.0e-3, C=50, reactants=[species["X"]], products=[species["Y"]], gas_phase=gas)

.. dropdown:: Branched

   .. math::

      k_{\text{nitrate}} = \left( X e^{-Y / T} \right) 
      \left( \frac{A}{A+ Z} \right)
      
      k_{\text{alkoxy}} = \left( X e^{-Y / T} \right) 
      \left( \frac{Z}{Z + A} \right)

   - X: Pre-exponential branching factor [(:math:`\mathrm{mol\ m}{-3})^{(n-1)}s^{-1}`].
   - Y: Exponential branching factor [:math:`\mathrm{K} ^{-1}`].
   - T: Temperature [:math:`\mathrm{K}`]
   - Z: normalization term [unitless]. Denoted `a0` in `Branched` class parameters.
   - A: Branching ratio parameter [unitless]. Denoted `n` in `Branched` class parameters.

   Example usage::

      branched = mc.Branched(name="branched_ex", X=1.2, Y=204.3, a0=1e-03, n=2,
         reactants=[species["X"]],
         nitrate_products = [species["Y"]],
         alkoxy_products=[species["Z"]],
         gas_phase=gas)

.. dropdown:: Emission

   .. math::

      \rightarrow X


   - X: Species being emmitted

   Example usage::
      
      emission = mc.Emission(name="emission_ex", products =[species["Y"], species["Z"]], gas_phase=gas)

.. dropdown:: First-order Loss

   .. math::

      X \rightarrow

   - X: Species being lost

   Example usage::

      loss = mc.FirstOrderLoss(name="loss_ex", reactants=[species["X"],species["Y"]], gas_phase=gas)

.. dropdown:: Photolysis

   .. math::

      X + h\nu \rightarrow Y_1 \; (+ Y_2 \ldots)

   - X: Species being photolyzed
   - :math:`h\nu`: photon
   - Y: Photolysis products

   Example usage::

      photo = mc.Photolysis(name="photo_ex", reactants=[species["X"]], products=[species["Y"]], gas_phase=gas)
      
.. dropdown:: Surface

   .. math::

      k_{\text{surface}} = \frac{4N_a \pi r_e^2}{\frac{r_e}{D_g} + \frac{4}{v(T) \gamma}}

   - :math:`N_a`: concentration of particles [particles :math:`\mathrm{m}^{-3}`]
   - :math:`r_e`: effective particle radius [:math:`\mathrm{m}`]
   - :math:`D_g`: gas-phase diffusion coefficiente of the reactant [:math:`\mathrm{m}^{2}\mathrm{s}^{-1}`]
   - :math:`\gamma`: reaction probability [unitless]
   - v: mean free speed of the gas-phase reactant

   .. math::

      v = \sqrt{ \frac{8 R T}{\pi M_W} }

   - R: ideal gas constant [:math:`\mathrm{J}\mathrm{K}^{-1}\mathrm{mol}^{-1}`]
   - T: temperature [:math:`\mathrm{K}`]
   - MW: Molecular weight of the gas-phase reactant [:math:`\mathrm{kg}\mathrm{mol}^{-1}`]


   Note that, of the reaction rate parameters, the `Surface` reaction class only requires the input of a reaction probability parameter.
   Diffusion coefficients and molecular weights must be handled with the initialization of `Species` invovled in a Surface reaction::

      X = mc.Species(name="X", diffusion_coefficient_m2_s=200, molecular_weight_kg_mol=1)
      Y = mc.Species(name="Y", diffusion_coefficient_m2_s=200, molecular_weight_kg_mol=1)
      Z = mc.Species(name="Z", diffusion_coefficient_m2_s=200, molecular_weight_kg_mol=1)
      species = {"X": X, "Y": Y, "Z": Z}
      gas = mc.Phase(name="gas", species=list(species.values()))

   Additional parameters are handled internally. 

   Example usage::

      surface = mc.Surface(name="surface_ex", reaction_probability=0.9, gas_phase_species = X, gas_phase_products=[species["Y"]], gas_phase=gas)

.. dropdown:: Troe (fall-off)
   
   .. math::

      \frac{k_0 [M]}{1 + \frac{k_0 [M]}{k_{\infty}}} 
      \cdot F_C^{\left(1 + \frac{1}{N \left( \log_{10} \left( \frac{k_0 [M]}{k_{\infty}} \right) \right)^2} \right)^{-1}}

   - :math:`k_0`: low-pressure limiting rate constant, Arrhenius form
   - :math:`k_{\infty}`: high-pressure limiting rate constant, Arrhenius form
   - M: air density [:math:`\mathrm{mol}\ \mathrm{m}^{-3}`]
   - Fc: Troe parameter to determine shape of fall-off curve [unitless].
   - N: Troe parameter to determine shape of fall-off curve [unitless].

   Example usage::
      
      troe = mc.Troe(name="troe_ex", k0_A=7.23e21, k0_B=167,
         k0_C=3,kinf_A=4.32e-18,kinf_B=-3.1,kinf_C=402.1,Fc=0.9, N=1.2, reactants=[species["X"]],products=[species["Z"]], gas_phase=gas)

   Note that the `Troe` class takes each component of the :math:`k_0` and :math:`k_{\infty}` reaction rates as arguments:

   - k0_A: Pre-exponential factor for the low-pressure limit [(:math:`\mathrm{mol\ m}{-3})^{(n-1)}s^{-1}`].
   - k0_B: Temperature exponent for the low-pressure limit [unitless].
   - k0_C: Exponential term for the low-pressure limit [:math:`\mathrm{K}^{-1}`].
   - kinf_A: Pre-exponential factor for the high-pressure limit [(:math:`\mathrm{mol\ m}{-3})^{(n-1)}s^{-1}`].
   - kinf_B: Temperature exponent for the high-pressure limit [unitless].
   - kinf_C: Exponential term for the high-pressure limit [:math:`\mathrm{K}^{-1}`].
   
   For more information on these parameters,please see :mod:`musica.mechanism_configuration`. 

.. dropdown:: Tunneling
   
   .. math::

      A e^{\frac{-B}{T}}e^{\frac{C}{T^{3}}}

   - A: pre-exponential factor [(:math:`\mathrm{mol\ m}{-3})^{(n-1)}s^{-1}`]
   - B: tunneling parameter for temperature dependence [:math:`\mathrm{K} ^{-1}`]
   - C: tunneling parameter for tempetarute dependence [:math:`\mathrm{K} ^{-3}`]
   - T: temperature [:math:`\mathrm{K}`]
   - n = number of reactants


   Example usage::

      tunnel = mc.Tunneling(name="tunn_ex", A=1.2, B=2.3, C=302.3, reactants=[species["X"]], products=[species["Y"]], gas_phase=gas)

Additional reactions than those listed below may be present in the `mechanism_configuration` class, but are not yet 
supported via MusicBox and will be implemented in future versions.

Mechanisms
----------
A mechanism defines a collection of chemical species, their associated phases, and the reactions between them. Mechanisms can be defined as
follows::

   mechanism = mc.Mechanism(name="tutorial_mechanism", species=list(species.values()), phases=[gas], reactions=list(rxns.values()))