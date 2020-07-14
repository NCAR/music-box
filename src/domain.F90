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
  !! be used to build domain state objects and related accessors/mutators
  type, abstract :: domain_t
  contains
    !> Create a new state for the domain
    procedure(new_state), deferred :: new_state

    !> @name Registration of domain properities and state variables
    !! @{

    !> Register a state variable for all cells
    procedure(register_cell_state_variable), deferred ::                      &
      register_cell_state_variable
    !> Register a named collection of state variables for all cells
    procedure(register_cell_state_variable_set), deferred ::                  &
      register_cell_state_variable_set
    !> Register a flag for all cells
    procedure(register_cell_flag), deferred :: register_cell_flag

    !> @}

    !> @name Get mutators for registered domain properties and state
    !! variables
    !! @{

    !> Get an mutator for a state variable for all cells
    procedure(cell_state_mutator), deferred :: cell_state_mutator
    !> Get mutators for a named collection of state variables for all
    !! cells
    procedure(cell_state_set_mutator), deferred :: cell_state_set_mutator
    !> Get an mutator for a flag for all cells
    procedure(cell_flag_mutator), deferred :: cell_flag_mutator

    !> @}

    !> @name Get accessors for registered domain properties and state
    !! variables
    !! @{

    !> Get an accessor for a state variable for all cells
    procedure(cell_state_accessor), deferred :: cell_state_accessor
    !> Get accessors for a named collection of state variables for all
    !! cells
    procedure(cell_state_set_accessor), deferred :: cell_state_set_accessor
    !> Get an accessor for a flag for all cells
    procedure(cell_flag_accessor), deferred :: cell_flag_accessor

    !> @}

    !> @name Iterators over the domain
    !! @{

    !> Set up an iterator over all domain cells
    procedure(cell_iterator), deferred :: cell_iterator

    !! @}

    !> @name Output the domain state
    !! @{

    !> Output the state to text file
    procedure(output_state_text), deferred, private :: output_state_text
    generic :: output_state => output_state_text

    !> @}
  end type domain_t

  !> Abstract domain state
  type, abstract :: domain_state_t
  contains
    !> Get the value of a state variable
    procedure(state_get), deferred :: get
    !> Update the value of a state variable
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
    class(domain_t), pointer :: val => null( )
  end type domain_ptr

  !> State pointer
  type domain_state_ptr
    class(domain_state_t), pointer :: val => null( )
  end type domain_state_ptr

  !> Mutator pointer
  type domain_state_mutator_ptr
    class(domain_state_mutator_t), pointer :: val => null( )
  end type domain_state_mutator_ptr

  !> Accessor pointer
  type domain_state_accessor_ptr
    class(domain_state_accessor_t), pointer :: val => null( )
  end type domain_state_accessor_ptr

  !> Iterator pointer
  type domain_iterator_ptr
    class(domain_iterator_t), pointer :: val => null( )
  end type domain_iterator_ptr

  !> @}

interface
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Create a new domain state object
  function new_state( this )
    import domain_t
    import domain_state_t
    !> New domain state
    class(domain_state_t), pointer :: new_state
    !> Domain
    class(domain_t), intent(in) :: this
  end function new_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register a state variable for each cell in the domain
  function register_cell_state_variable( this, variable_name, units,          &
      requestor ) result( new_mutator )
    import domain_t
    import domain_state_mutator_t
    !> Mutator for the new state variable
    class(domain_state_mutator_t), pointer :: new_mutator
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the state variable to create
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Name of the model component requesting the variable
    character(len=*), intent(in) :: requestor
  end function register_cell_state_variable

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register a named collection of state variables for each cell in the
  !! domain
  function register_cell_state_variable_set( this, variable_name, units,      &
      component_names, requestor ) result( new_mutators )
    use musica_string,                 only : string_t
    import domain_t
    import domain_state_mutator_ptr
    !> Mutators for the new state variables
    !!
    !! The mutators are in the same order as the component names passed to
    !! this function
    class(domain_state_mutator_ptr), allocatable :: new_mutators(:)
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the state variable to create
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Names for each component of the new variable set
    type(string_t), intent(in) :: component_names(:)
    !> Name of the model component requesting the variable
    character(len=*), intent(in) :: requestor
  end function register_cell_state_variable_set

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register a flag property for each cell in the domain
  function register_cell_flag( this, flag_name, requestor )                   &
      result( new_mutator )
    import domain_t
    import domain_state_mutator_t
    !> Mutator for the new state variable
    class(domain_state_mutator_t), pointer :: new_mutator
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Name of the state variable to create
    character(len=*), intent(in) :: flag_name
    !> Name of the model component requesting the variable
    character(len=*), intent(in) :: requestor
  end function register_cell_flag

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an mutator for a registered state variable for each cell in the
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

  !> Get an mutator for a registered named set of state variables for each
  !! cell in the domain
  function cell_state_set_mutator( this, variable_name, units,          &
      component_names, requestor ) result( new_mutators )
    use musica_string,                 only : string_t
    import domain_t
    import domain_state_mutator_ptr
    !> Accessors for the requested state variable set
    class(domain_state_mutator_ptr), allocatable :: new_mutators(:)
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

  !> Get an mutator for a registered flag for each cell in the domain
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

  !> Get an accessor for a registered state variable for each cell in the
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

  !> Get an accessor for a registered named set of state variables for each
  !! cell in the domain
  function cell_state_set_accessor( this, variable_name, units,          &
      component_names, requestor ) result( new_accessors )
    use musica_string,                 only : string_t
    import domain_t
    import domain_state_accessor_ptr
    !> Accessors for the requested state variable set
    class(domain_state_accessor_ptr), allocatable :: new_accessors(:)
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

  !> Get an accessor for a registered flag for each cell in the domain
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

  !> Get an iterator for all cells in associated domain_state_t objects
  function cell_iterator( this )
    import domain_t
    import domain_iterator_t
    !> New iterator
    class(domain_iterator_t), pointer :: cell_iterator
    !> Domain
    class(domain_t), intent(in) :: this
  end function cell_iterator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Output the domain state to a text file
  subroutine output_state_text( this, domain_state )
    import domain_t
    import domain_state_t
    !> Domain
    class(domain_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(in) :: domain_state
  end subroutine output_state_text

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get the value of a registered property or state variable
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

  !> Update the value of a registered property or state variable
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

end module musica_domain
