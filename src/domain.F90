! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_domain module

!> The abstract domain_t type and related functions
module musica_domain

  use musica_iterator,                 only : iterator_t

  implicit none
  private

  public :: domain_t, domain_state_t, domain_state_mutator_t,                 &
            domain_state_accessor_t, domain_iterator_t,                       &
            domain_ptr, domain_state_ptr, domain_state_mutator_ptr,           &
            domain_state_accessor_ptr, domain_iterator_ptr

  !> A model domain of abstract structure
  !!
  !! Extending classes of domain_t define the structure of the domain and can
  !! be used to build domain state objects and related accessors/mutators.
  !!
  !! The general usage of \c domain_t objects is to:
  !! - create a domain_t object using the
  !!   \c musica_domain_factory::domain_builder function
  !! - register any needed state variables and properies using the \c domain_t
  !!   type-bound \c register \c mutator and \c accessor functions for the
  !!   domain subset you are interested in (e.g., all cells, surface cells,
  !!   columns)
  !! - use the \c domain_t type-bound \c new_state function to get a state
  !!   object to use for the domain
  !! - during solving, use the accessors and mutators registered during
  !!   initialization with the \c domain_state_t::get and
  !!   \c domain_state_t::update functions to access or modify the current
  !!   values of state variables
  !!
  !! Although the structure of the abstract domain types permits run-time
  !! registration of state parameters and variables, it is compatible with
  !! models that use a fixed set of parameters. In this case the domain
  !! registration, accessor and mutator functions would check to make sure
  !! a state variable that is requested is present in the model, and return
  !! an error or warning if they are not found.
  !!
  !! \todo develop a complete set of \c domain_t examples
  !!
  type, abstract :: domain_t
  contains
    !> Creates a new state for the domain
    procedure(new_state), deferred :: new_state

    !> @name Registers domain properities and state variables
    !! @{

    !> Registers a state variable for all cells
    procedure(register_cell_state_variable), deferred ::                      &
      register_cell_state_variable
    !> Registers a named collection of state variables for all cells
    procedure(register_cell_state_variable_set), deferred ::                  &
      register_cell_state_variable_set
    !> Registers a flag for all cells
    procedure(register_cell_flag), deferred :: register_cell_flag

    !> @}

    !> @name Returns mutators for registered domain properties and state variables
    !! @{

    !> Gets a mutator for a state variable for all cells
    procedure(cell_state_mutator), deferred :: cell_state_mutator
    !> Gets mutators for a named collection of state variables for all
    !! cells
    procedure(cell_state_set_mutator), deferred :: cell_state_set_mutator
    !> Gets a mutator for a flag for all cells
    procedure(cell_flag_mutator), deferred :: cell_flag_mutator

    !> @}

    !> @name Returns accessors for registered domain properties and state variables
    !! @{

    !> Gets an accessor for a state variable for all cells
    procedure(cell_state_accessor), deferred :: cell_state_accessor
    !> Gets accessors for a named collection of state variables for all
    !! cells
    procedure(cell_state_set_accessor), deferred :: cell_state_set_accessor
    !> Gets an accessor for a flag for all cells
    procedure(cell_flag_accessor), deferred :: cell_flag_accessor

    !> @}

    !> Check if a property has been registered
    !! @{

    !> Check for a state variable for all cells
    procedure(is_cell_state_variable), deferred :: is_cell_state_variable
    !> Check for a flag for all cells
    procedure(is_cell_flag), deferred :: is_cell_flag

    !> @}

    !> Gets units for registered properties
    !! @{

    !> Gets units for a state variable for all cells
    procedure(cell_state_units), deferred :: cell_state_units

    !> @}

    !> @name Iterators over the domain
    !! @{

    !> Sets up an iterator over all domain cells
    procedure(cell_iterator), deferred :: cell_iterator

    !! @}

    !> Outputs the registered mutators and accessors
    procedure(output_registry), deferred :: output_registry
  end type domain_t

  !> Abstract domain state
  type, abstract :: domain_state_t
  contains
    !> Gets the value of a state variable
    procedure(state_get), deferred :: get
    !> Updates the value of a state variable
    procedure(state_update), deferred :: update
  end type domain_state_t

  !> Abstract domain state mutator
  type, abstract :: domain_state_mutator_t
  end type domain_state_mutator_t

  !> Abstract domain state accessor
  type, abstract :: domain_state_accessor_t
  end type domain_state_accessor_t

  !> Domain iterator
  type, abstract, extends(iterator_t) :: domain_iterator_t
  end type domain_iterator_t

  !> Pointer types for building arrays of abstract objects
  !! @{

  !> Domain pointer
  type domain_ptr
    class(domain_t), pointer :: val_ => null( )
  contains
    final :: domain_ptr_finalize
  end type domain_ptr

  !> State pointer
  type domain_state_ptr
    class(domain_state_t), pointer :: val_ => null( )
  contains
    final :: domain_state_ptr_finalize
  end type domain_state_ptr

  !> Mutator pointer
  type domain_state_mutator_ptr
    class(domain_state_mutator_t), pointer :: val_ => null( )
  contains
    final :: domain_state_mutator_ptr_finalize
  end type domain_state_mutator_ptr

  !> Accessor pointer
  type domain_state_accessor_ptr
    class(domain_state_accessor_t), pointer :: val_ => null( )
  contains
    final :: domain_state_accessor_ptr_finalize
  end type domain_state_accessor_ptr

  !> Iterator pointer
  type domain_iterator_ptr
    class(domain_iterator_t), pointer :: val_ => null( )
  contains
    final :: domain_iterator_ptr_finalize
  end type domain_iterator_ptr

  !> @}

interface
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Creates a new domain state object
  function new_state( this )
    import domain_t
    import domain_state_t
    !> New domain state
    class(domain_state_t), pointer :: new_state
    !> Domain
    class(domain_t), intent(inout) :: this
  end function new_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Registers a state variable for each cell in the domain
  subroutine register_cell_state_variable( this, variable_name, units,        &
      default_value, requestor )
    use musica_constants,              only : musica_dk
    import domain_t
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the state variable to create
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Default value for the variable
    real(kind=musica_dk), intent(in) :: default_value
    !> Name of the model component requesting the variable
    character(len=*), intent(in) :: requestor
  end subroutine register_cell_state_variable

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Registers a named collection of state variables for each cell in the
  !! domain
  subroutine register_cell_state_variable_set( this, variable_name, units,    &
      default_value, component_names, requestor )
    use musica_constants,              only : musica_dk
    use musica_string,                 only : string_t
    import domain_t
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the state variable to create
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Default value for the variable
    real(kind=musica_dk), intent(in) :: default_value
    !> Names for each component of the new variable set
    type(string_t), intent(in) :: component_names(:)
    !> Name of the model component requesting the variable
    character(len=*), intent(in) :: requestor
  end subroutine register_cell_state_variable_set

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Registers a flag property for each cell in the domain
  subroutine register_cell_flag( this, flag_name, default_value, requestor )
    import domain_t
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the state variable to create
    character(len=*), intent(in) :: flag_name
    !> Default flag value
    logical, intent(in) :: default_value
    !> Name of the model component requesting the variable
    character(len=*), intent(in) :: requestor
  end subroutine register_cell_flag

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets a mutator for a registered state variable for each cell in the
  !! domain
  function cell_state_mutator( this, variable_name, units, requestor )  &
      result( new_mutator )
    import domain_t
    import domain_state_mutator_t
    !> Accessor for the requested state variable
    class(domain_state_mutator_t), pointer :: new_mutator
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the variable to find
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Name of the model component requesting the mutator
    character(len=*), intent(in) :: requestor
  end function cell_state_mutator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets a mutator for a registered named set of state variables for each
  !! cell in the domain
  function cell_state_set_mutator( this, variable_name, units,          &
      component_names, requestor ) result( new_mutators )
    use musica_string,                 only : string_t
    import domain_t
    import domain_state_mutator_ptr
    !> Accessors for the requested state variable set
    class(domain_state_mutator_ptr), pointer :: new_mutators(:)
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the variable to find
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Names of each component of the variable set
    !!
    !! The names are in the same order as the returned mutators
    type(string_t), allocatable, intent(out) :: component_names(:)
    !> Name of the model component requesting the mutator
    character(len=*), intent(in) :: requestor
  end function cell_state_set_mutator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets a mutator for a registered flag for each cell in the domain
  function cell_flag_mutator( this, flag_name, requestor )                    &
      result( new_mutator )
    import domain_t
    import domain_state_mutator_t
    !> Accessor for the requested flag
    class(domain_state_mutator_t), pointer :: new_mutator
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the flag to find
    character(len=*), intent(in) :: flag_name
    !> Name of the model component requesting the mutator
    character(len=*), intent(in) :: requestor
  end function cell_flag_mutator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets an accessor for a registered state variable for each cell in the
  !! domain
  function cell_state_accessor( this, variable_name, units, requestor )  &
      result( new_accessor )
    import domain_t
    import domain_state_accessor_t
    !> Accessor for the requested state variable
    class(domain_state_accessor_t), pointer :: new_accessor
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the variable to find
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Name of the model component requesting the accessor
    character(len=*), intent(in) :: requestor
  end function cell_state_accessor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets accessors for a registered named set of state variables for each
  !! cell in the domain
  function cell_state_set_accessor( this, variable_name, units,          &
      component_names, requestor ) result( new_accessors )
    use musica_string,                 only : string_t
    import domain_t
    import domain_state_accessor_ptr
    !> Accessors for the requested state variable set
    class(domain_state_accessor_ptr), pointer :: new_accessors(:)
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the variable to find
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Names of each component of the variable set
    !!
    !! The names are in the same order as the returned accessors
    type(string_t), allocatable, intent(out) :: component_names(:)
    !> Name of the model component requesting the accessor
    character(len=*), intent(in) :: requestor
  end function cell_state_set_accessor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets an accessor for a registered flag for each cell in the domain
  function cell_flag_accessor( this, flag_name, requestor )                   &
      result( new_accessor )
    import domain_t
    import domain_state_accessor_t
    !> Accessor for the requested flag
    class(domain_state_accessor_t), pointer :: new_accessor
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the flag to find
    character(len=*), intent(in) :: flag_name
    !> Name of the model component requesting the accessor
    character(len=*), intent(in) :: requestor
  end function cell_flag_accessor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns whether a state variable has been registered for all cells
  logical function is_cell_state_variable( this, variable_name )
    use musica_string,                 only : string_t
    import domain_t
    !> Domain
    class(domain_t), intent(in) :: this
    !> Name of the variable to look for
    character(len=*), intent(in) :: variable_name
  end function is_cell_state_variable

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Returns whether a flag has been registered for all cells
  logical function is_cell_flag( this, flag_name )
    use musica_string,                 only : string_t
    import domain_t
    !> Domain
    class(domain_t), intent(in) :: this
    !> Name of the flag to look for
    character(len=*), intent(in) :: flag_name
  end function is_cell_flag

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets the units for a registered state variable for all cells
  function cell_state_units( this, variable_name )
    use musica_string,                 only : string_t
    import domain_t
    !> Units for the state variable
    type(string_t) :: cell_state_units
    !> Domain
    class(domain_t), intent(in) :: this
    !> Name of the registered state variable
    character(len=*), intent(in) :: variable_name
  end function cell_state_units

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets an iterator for all cells in associated domain_state_t objects
  function cell_iterator( this )
    import domain_t
    import domain_iterator_t
    !> New iterator
    class(domain_iterator_t), pointer :: cell_iterator
    !> Domain
    class(domain_t), intent(in) :: this
  end function cell_iterator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Outputs the registered mutators and accessors
  subroutine output_registry( this, file_unit )
    import domain_t
    !> Domain
    class(domain_t), intent(in) :: this
    !> File unit to output to
    integer, intent(in), optional :: file_unit
  end subroutine output_registry

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Gets the value of a registered property or state variable
  !!
  !! The value returned will be in the units specified when the accessor was
  !! created.
  subroutine state_get( this, iterator, accessor, state_value )
    import domain_state_accessor_t
    import domain_iterator_t
    import domain_state_t
    !> Domain state
    class(domain_state_t), intent(in) :: this
    !> Domain iterator
    class(domain_iterator_t), intent(in) :: iterator
    !> Accessor for the registered property or state variable
    class(domain_state_accessor_t), intent(in) :: accessor
    !> Value of the property or state variable
    class(*), intent(out) :: state_value
  end subroutine state_get

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Updates the value of a registered property or state variable
  !!
  !! The units for the value passed to this function must be the same as
  !! those specified when the mutator was created.
  subroutine state_update( this, iterator, mutator, state_value )
    import domain_state_mutator_t
    import domain_state_t
    import domain_iterator_t
    !> Domain state
    class(domain_state_t), intent(inout) :: this
    !> Domain iterator
    class(domain_iterator_t), intent(in) :: iterator
    !> Mutator for registered property or state variable
    class(domain_state_mutator_t), intent(in) :: mutator
    !> New value
    class(*), intent(in) :: state_value
  end subroutine state_update

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end interface

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalize pointer
  subroutine domain_ptr_finalize( this )

    !> Domain pointer
    type(domain_ptr), intent(inout) :: this

    if( associated( this%val_ ) ) deallocate( this%val_ )

  end subroutine domain_ptr_finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalize pointer
  subroutine domain_state_ptr_finalize( this )

    !> Domain pointer
    type(domain_state_ptr), intent(inout) :: this

    if( associated( this%val_ ) ) deallocate( this%val_ )

  end subroutine domain_state_ptr_finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalize pointer
  subroutine domain_state_mutator_ptr_finalize( this )

    !> Domain pointer
    type(domain_state_mutator_ptr), intent(inout) :: this

    if( associated( this%val_ ) ) deallocate( this%val_ )

  end subroutine domain_state_mutator_ptr_finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalize pointer
  subroutine domain_state_accessor_ptr_finalize( this )

    !> Domain pointer
    type(domain_state_accessor_ptr), intent(inout) :: this

    if( associated( this%val_ ) ) deallocate( this%val_ )

  end subroutine domain_state_accessor_ptr_finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalize pointer
  subroutine domain_iterator_ptr_finalize( this )

    !> Domain pointer
    type(domain_iterator_ptr), intent(inout) :: this

    if( associated( this%val_ ) ) deallocate( this%val_ )

  end subroutine domain_iterator_ptr_finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_domain
