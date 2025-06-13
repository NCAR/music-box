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
   rxns = {"X->Y": arr1, "Y->Z": arr2} 

Several other reaction types are made available through MusicBox. Click the dropdowns below to learn more information about a specific reaction.
Full details of each class can be found in the :ref:`API Reference <api-ref>`. Additional reactions than those listed below may be present in the
`mechanism_configuration` class, but are not yet supported via MusicBox and will be implemented in future versions.

.. dropdown:: Arrhenius

   .. math::

      A e^{-E_a / (k_b T)} (T D)^B (1.0 + E^* P)

   .. code-block::
      
      arr = mc.Arrhenius(name="arr_ex", A=4.0e-3, C=50, reactants=[species["X"]], products=[species["Y"]], gas_phase=gas)

.. dropdown:: Branched

   .. math::

      k_{\text{nitrate}} = \left( X e^{-Y / T} \right) 
      \left( \frac{A(T, [M], n)}{A(T, [M], n) + Z} \right)
      
      k_{\text{alkoxy}} = \left( X e^{-Y / T} \right) 
      \left( \frac{Z}{Z + A(T, [M], n)} \right)

      A(T, [M], n) = \frac{2 \times 10^{-22} e^n [M]}
      {1 + 2 \times 10^{-22} e^n [M]^{0.43} \left( \frac{T}{298} \right)^{-80.41} 
      \left( 1 + \left[ \log \left( 2 \times 10^{-22} e^n [M]^{0.43} \left( \frac{T}{298} \right)^{-8} \right) \right]^2 \right)}

      Z(\alpha_0, n) = A\left(T=293\,\mathrm{K}, [M] = 2.45 \times 10^{19}\,\mathrm{molec\,cm}^{-3}, n\right) 
      (1 - \alpha_0) \, \alpha_0

   .. code-block::

      branched = mc.Branched(name="branched_ex", X=1.2, Y=204.3, a0=1e-03, n=2,
         reactants=[species["X"]],
         nitrate_products = [species["Y"]],
         alkoxy_products=[species["Z"]],
         gas_phase=gas)

.. dropdown:: Emission

   .. math::

      \rightarrow X

   .. code-block::
      
      emission = mc.Emission(name="emission_ex",scaling_factor=2,products =[species["Y"],species["Z"]], gas_phase=gas)

.. dropdown:: First-order Loss

   .. math::

      X \rightarrow

   .. code-block::

      loss = mc.FirstOrderLoss(name="loss_ex",scaling_factor=2,reactants=[species["X"],species["Y"]], gas_phase=gas)

.. dropdown:: Photolysis

   .. math::

      X + h\nu \rightarrow Y_1 \; (+ Y_2 \ldots)

   .. code-block::

      photo = mc.Photolysis(name="photo_ex", scaling_factor=1.2, reactants=[species["X"]], products=[species["Y"]], gas_phase=gas)
      
.. dropdown:: Surface
   
   double check

   .. math::

      r_{\text{surface}} = k_{\text{surface}} [X]

      k_{\text{surface}} = 4 N_a \pi r_e^2 \left( r_e D_g + 4 v(T) \gamma \right)

      v = \sqrt{ \frac{8 R T}{\pi M_W} }

   Surface needs additional species parameters defined.

   .. code-block::

      X = mc.Species(name="X", diffusion_coefficient_m2_s=200,molecular_weight_kg_mol=1)
      Y = mc.Species(name="Y", diffusion_coefficient_m2_s=200,molecular_weight_kg_mol=1)
      Z = mc.Species(name="Z", diffusion_coefficient_m2_s=200,molecular_weight_kg_mol=1)
      species = {"X": X, "Y": Y, "Z": Z}
      gas = mc.Phase(name="gas", species=list(species.values()))

   .. code-block::

      surface = mc.Surface(name="surface_ex",reaction_probability=0.9,gas_phase_species = X,gas_phase_products=[species["Y"]],gas_phase=gas)

.. dropdown:: Troe (fall-off)
   
   check
   
   .. math::

      k = \frac{k_0 [M]}{1 + \frac{k_0 [M]}{k_{\infty}}} 
      \cdot F_C^{\left(1 + \frac{1}{N \left( \log_{10} \left( \frac{k_0 [M]}{k_{\infty}} \right) \right)^2} \right)^{-1}}

   .. code-block::
      
      test = mc.Troe(name="troe_ex", k0_A=7.23e21, k0_B=167,
         k0_C=3,kinf_A=4.32e-18,kinf_B=-3.1,kinf_C=402.1,Fc=0.9, N=1.2, reactants=[species["X"]],products=[species["Z"]], gas_phase=gas)


.. dropdown:: Tunneling
   
   .. math::

      A e^{-B T} e^{C T^{3}}

   .. code-block::

      test = mc.Tunneling(name="tunn_ex", A=1.2, B=2.3, C=302.3, reactants=[species["X"]], products=[species["Y"]], gas_phase=gas)

Mechanisms
----------