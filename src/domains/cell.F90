!> \file
!> This musica_domain_cell module

!> The domain_cell_t type and related functions
module musica_domain_cell

  use musica_constants,                only : musica_ik, musica_dk
  use musica_domain,                   only : domain_t, domain_state_t,       &
                                              domain_iterator_t,              &
                                              domain_state_mutator_t,         &
                                              domain_state_accessor_t
  use musica_string,                   only : string_t

  implicit none
  private

  public :: domain_cell_t, domain_cell_state_t

  !> @defgroup private_domain_cell_types Private types and parameters for cell
  !! domains
  !! @{

  !> Invalid property type
  integer(kind=musica_ik), parameter :: INVALID = 0
  !> Properties for all cells
  integer(kind=musica_ik), parameter :: ALL_CELL_PROPERTY = 1
  !> Flags for all cells
  integer(kind=musica_ik), parameter :: ALL_CELL_FLAG = 2

  !> Registered pairs
  type :: registered_pair_t
    !> Name of the registering model component
    type(string_t) :: owner_
    !> Name of the registered property or state variable
    type(string_t) :: property_
    !> Property type
    integer(kind=musica_ik) :: type_ = INVALID
  end type registered_pair_t

  !> @}

  !> Model domain for a collection of unrelated cells or boxes
  type, extends(domain_t) :: domain_cell_t
    private
    !> Number of cells in the domain
    integer(kind=musica_ik) :: number_of_cells_ = 1
    !> Names of the registered cell properties
    type(string_t), allocatable :: properties_(:)
    !> Units for the properties
    type(string_t), allocatable :: property_units_(:)
    !> Names of the registered cell flags
    type(string_t), allocatable :: flags_(:)
    !> Registered mutators
    type(registered_pair_t), allocatable :: mutators_(:)
    !> Registered accessors
    type(registered_pair_t), allocatable :: accessors_(:)
  contains
    !> Create a new state for the domain
    procedure :: new_state

    !> @name Registration of domain properities and state variables
    !! @{

    !> Register a state variable for all cells
    procedure :: register_cell_state_variable
    !> Register a named collection of state variables for all cells
    procedure :: register_cell_state_variable_set
    !> Register a flag for all cells
    procedure :: register_cell_flag

    !> @}

    !> @name Get mutators for registered domain properties and state
    !! variables
    !! @{

    !> Get an mutator for a state variable for all cells
    procedure :: cell_state_mutator
    !> Get mutators for a named collection of state variables for all cells
    procedure :: cell_state_set_mutator
    !> Get an mutator for a flag for all cells
    procedure :: cell_flag_mutator
    !> @}

    !> @name Get accessors for registered domain properties and state
    !! variables
    !! @{

    !> Get an accessor for a state variable for all cells
    procedure :: cell_state_accessor
    !> Get accessors for a named collection of state variables for all cells
    procedure :: cell_state_set_accessor
    !> Get an accessor for a flag for all cells
    procedure :: cell_flag_accessor
    !> @}

    !> @name Iterators over the domain
    !! @{

    !> Set up an iterator over all domain cells
    procedure :: cell_iterator

    !! @}

    !> @name Output the domain state
    !! @{

    !> Output the state to a text file
    procedure, private :: output_state_text

    !> @}
  end type domain_cell_t

  !> domain_cell_t constructor
  interface domain_cell_t
    module procedure :: constructor
  end interface domain_cell_t

  !> Cell state
  type, extends(domain_state_t) :: domain_cell_state_t
    !> Cell properties (cell, property)
    real(kind=musica_dk), allocatable :: properties_(:,:)
    !> Cell flags (cell, flag)
    logical, allocatable :: flags_(:,:)
  contains
    !> Get the value of a state variable
    procedure :: get => state_get
    !> Update the value of a state variable
    procedure :: update => state_update
  end type domain_cell_state_t

  !> Cell state property mutator
  type, extends(domain_state_mutator_t) ::                                    &
      domain_cell_state_mutator_property_t
    private
    !> Index of the owner of the mutator in
    !! domain_cell_t%mutators_(:)
    integer(kind=musica_ik) :: i_owner_
    !> Index of the property or state variable in
    !! domain_cell_t%properties_(:)
    integer(kind=musica_ik) :: i_property_
  end type domain_cell_state_mutator_property_t

  !> Cell state property accessor
  type, extends(domain_state_accessor_t) ::                                   &
      domain_cell_state_accessor_property_t
    private
    !> Index of the owner of the accessor in
    !! domain_cell_t%accessors_(:)
    integer(kind=musica_ik) :: i_owner_
    !> Index of the property or state variable in
    !! domain_cell_t%properties_(:)
    integer(kind=musica_ik) :: i_property_
  end type domain_cell_state_accessor_property_t

  !> Cell state flag mutator
  type, extends(domain_state_mutator_t) ::                                    &
      domain_cell_state_mutator_flag_t
    private
    !> Index of the owner of the mutator in
    !! domain_cell_t%mutators_(:)
    integer(kind=musica_ik) :: i_owner_
    !> Index of the flag in domain_cell_t%flags_(:)
    integer(kind=musica_ik) :: i_flag_
  end type domain_cell_state_mutator_flag_t

  !> Cell state accessor
  type, extends(domain_state_accessor_t) ::                                   &
      domain_cell_state_accessor_flag_t
    private
    !> Index of the owner of the accessor in
    !! domain_cell_t%accessors_(:)
    integer(kind=musica_ik) :: i_owner_
    !> Index of the property or state variable in
    !! domain_cell_t%flags_(:)
    integer(kind=musica_ik) :: i_flag_
  end type domain_cell_state_accessor_flag_t

  !> Domain iterator
  type, extends(domain_iterator_t) :: domain_cell_iterator_t
    private
    !> Current cell id
    integer(kind=musica_ik) :: current_cell_ = 0
    !> Last cell id
    integer(kind=musica_ik) :: last_cell_
  contains
    !> Advance the iterator
    procedure :: next => domain_cell_iterator_next
    !> Reset the iterator
    procedure :: reset => domain_cell_iterator_reset
  end type domain_cell_iterator_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Constructor for the cell domain
  function constructor( config ) result( new_domain )

    use musica_config,                 only : config_t

    !> Pointer to the new domain
    type(domain_cell_t), pointer :: new_domain
    !> Domain configuration data
    class(config_t), intent(inout) :: config

    allocate( new_domain )
    allocate( new_domain%properties_(     0 ) )
    allocate( new_domain%property_units_( 0 ) )
    allocate( new_domain%flags_(          0 ) )
    allocate( new_domain%mutators_(       0 ) )
    allocate( new_domain%accessors_(      0 ) )

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Create a new domain state object
  function new_state( this )

    !> New domain state
    class(domain_state_t), pointer :: new_state
    !> Domain
    class(domain_cell_t), intent(in) :: this

    integer :: n_prop, n_flag

    n_prop = size( this%properties_ )
    n_flag = size( this%flags_ )

    allocate( domain_cell_state_t :: new_state )

    select type( new_state )
      class is( domain_cell_state_t )

        allocate( new_state%properties_( this%number_of_cells_, n_prop ) )
        allocate( new_state%flags_(      this%number_of_cells_, n_flag ) )

    end select

  end function new_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register a variable for each cell in the domain
  function register_cell_state_variable( this, variable_name, units,          &
      requestor ) result( new_mutator )

    use musica_assert,                 only : assert, assert_msg

    !> Mutator for the new state variable
    class(domain_state_mutator_t), pointer :: new_mutator
    !> Domain
    class(domain_cell_t), intent(inout) :: this
    !> Name of the state variable to create
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Name of the model component requesting the variable
    character(len=*), intent(in) :: requestor

    integer :: property_id
    type(registered_pair_t) :: new_pair

    call assert( 600322248, len( trim( variable_name ) ) .gt. 0 )

    ! find the property or create it if it doesn't exist
    if( find_string( this%properties_, variable_name, property_id ) ) then
      call assert_msg( 526855940, units .eq.                                &
                                  this%property_units_( property_id ),      &
                       "Unit mismatch for property '"//trim( variable_name )&
                       //"': '"//trim( units )//"' != '"//                  &
                       this%property_units_( property_id )%to_char( ) )
    else
      call add_string_to_array( this%properties_, variable_name )
      call add_string_to_array( this%property_units_, units )
      property_id = size( this%properties_ )
    end if

    ! register the mutator
    new_pair%owner_    = requestor
    new_pair%property_ = this%properties_( property_id )
    new_pair%type_     = ALL_CELL_PROPERTY
    call add_registered_pair_to_array( this%mutators_, new_pair )

    ! create the mutator
    allocate( domain_cell_state_mutator_property_t :: new_mutator )
    select type( new_mutator )
      class is( domain_cell_state_mutator_property_t )
        new_mutator%i_owner_    = size( this%mutators_ )
        new_mutator%i_property_ = property_id
    end select

  end function register_cell_state_variable

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register a named collection of state variables for each cell in the
  !! domain
  function register_cell_state_variable_set( this, variable_name, units,      &
      component_names, requestor ) result( new_mutators )

    use musica_assert,                 only : assert, assert_msg
    use musica_domain,                 only : domain_state_mutator_ptr
    use musica_string,                 only : string_t

    !> Mutators for the new state variable
    !!
    !! The mutators are in the same order as the component names passed to
    !! this function
    class(domain_state_mutator_ptr), allocatable :: new_mutators(:)
    !> Domain
    class(domain_cell_t), intent(inout) :: this
    !> Name of the variable to create
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Names for each component of the new variable set
    type(string_t), intent(in) :: component_names(:)
    !> Name of the model component requesting the variable
    character(len=*), intent(in) :: requestor

    integer :: i_mutator, property_id
    type(registered_pair_t) :: new_pair
    type(string_t) :: full_name

    call assert( 152214984, len( trim( variable_name ) ) .gt. 0 )

    allocate( new_mutators( size( component_names ) ) )

    do i_mutator = 1, size( new_mutators )
      select type( mutator => new_mutators( i_mutator )%val )
        class is( domain_cell_state_mutator_property_t )
          full_name = trim( variable_name )//"%"//component_names( i_mutator )

          ! find the property or create it if it doesn't exist
          if( find_string( this%properties_, full_name%to_char( ),            &
                           property_id ) ) then
            call assert_msg( 526855940, units .eq.                            &
                                        this%property_units_( property_id ),  &
                             "Unit mismatch for property '"//                 &
                             full_name%to_char( )//"': '"//trim( units )//    &
                             "' != '"//                                       &
                             this%property_units_( property_id )%to_char( ) )
          else
            call add_string_to_array( this%properties_, full_name%to_char( ) )
            call add_string_to_array( this%property_units_, units )
            property_id = size( this%properties_ )
          end if

          ! register the mutator
          new_pair%owner_    = requestor
          new_pair%property_ = this%properties_( property_id )
          new_pair%type_     = ALL_CELL_PROPERTY
          call add_registered_pair_to_array( this%mutators_, new_pair )

          ! create the mutator
          mutator%i_owner_    = size( this%mutators_ )
          mutator%i_property_ = property_id
      end select
    end do

  end function register_cell_state_variable_set

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Register a flag property for each cell in the domain
  function register_cell_flag( this, flag_name, requestor )                   &
      result( new_mutator )

    use musica_assert,                 only : assert

    !> Mutator for the new state variable
    class(domain_state_mutator_t), pointer :: new_mutator
    !> Domain
    class(domain_cell_t), intent(inout) :: this
    !> Name of the state variable to create
    character(len=*), intent(in) :: flag_name
    !> Name of the model component requesting the variable
    character(len=*), intent(in) :: requestor

    integer :: flag_id
    type(registered_pair_t) :: new_pair

    call assert( 209339722, len( trim( flag_name ) ) .gt. 0 )

    ! find the flag or create it if it doesn't exist
    if( .not. find_string( this%flags_, flag_name, flag_id ) ) then
      call add_string_to_array( this%flags_, flag_name )
      flag_id = size( this%flags_ )
    end if

    ! register the mutator
    new_pair%owner_    = requestor
    new_pair%property_ = this%flags_( flag_id )
    new_pair%type_     = ALL_CELL_FLAG
    call add_registered_pair_to_array( this%mutators_, new_pair )

    ! create the mutator
    allocate( domain_cell_state_mutator_flag_t :: new_mutator )
    select type( new_mutator )
      class is( domain_cell_state_mutator_flag_t )
        new_mutator%i_owner_ = size( this%mutators_ )
        new_mutator%i_flag_  = flag_id
    end select

  end function register_cell_flag

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an mutator for a registered state variable for each cell in the
  !! domain
  function cell_state_mutator( this, variable_name, units, requestor )        &
      result( new_mutator )

    use musica_assert,                 only : assert, die_msg
    use musica_string,                 only : string_t

    !> Accessor for the requested state variable
    class(domain_state_mutator_t), pointer :: new_mutator
    !> Domain
    class(domain_cell_t), intent(inout) :: this
    !> Name of the variable to find
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Name of the model component requesting the mutator
    character(len=*), intent(in) :: requestor

    integer :: property_id
    type(registered_pair_t) :: new_pair

    call assert( 680476255, len( trim( variable_name ) ) .gt. 0 )

    ! find the property or return an error if not found
    if( .not. find_string( this%properties_, variable_name, property_id ) )   &
      then
      call die_msg( 905112945, "Property '"//trim( variable_name )//          &
                    "' requested by '"//trim( requestor )//"' not found." )
    end if

    ! register the mutator
    new_pair%owner_    = requestor
    new_pair%property_ = this%properties_( property_id )
    new_pair%type_     = ALL_CELL_PROPERTY
    call add_registered_pair_to_array( this%mutators_, new_pair )

    ! create the mutator
    allocate( domain_cell_state_mutator_property_t :: new_mutator )
    select type( new_mutator )
      class is( domain_cell_state_mutator_property_t )
        new_mutator%i_owner_    = size( this%mutators_ )
        new_mutator%i_property_ = property_id
    end select

  end function cell_state_mutator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get mutators for a set of state variables for each cell in the domain
  function cell_state_set_mutator( this, variable_name, units,                &
      component_names, requestor ) result( new_mutators )

    use musica_assert,                 only : assert, die_msg
    use musica_domain,                 only : domain_state_mutator_ptr

    !> Accessors for the requested state variable set
    class(domain_state_mutator_ptr), allocatable :: new_mutators(:)
    !> Domain
    class(domain_cell_t), intent(inout) :: this
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

    type(registered_pair_t) :: new_pair
    type(string_t) :: full_name
    integer :: i_mutator, property_id

    call assert( 899848638, allocated( component_names ) )
    call assert( 394642233, len( trim( variable_name ) ) .gt. 0 )

    allocate( new_mutators( size( component_names ) ) )

    do i_mutator = 1, size( component_names )
      select type( mutator => new_mutators( i_mutator )%val )
        class is( domain_cell_state_mutator_property_t )
          full_name =                                                         &
            trim( variable_name )//"%"//component_names( i_mutator )

          ! find the property or return an error if not found
          if( .not. find_string( this%properties_, full_name%to_char( ),      &
                                 property_id ) )                              &
            call die_msg( 842010079, "Property '"//full_name%to_char( )//     &
                       "' requested by '"//trim( requestor )//"' not found." )

          ! register the mutator
          new_pair%owner_    = requestor
          new_pair%property_ = this%properties_( property_id )
          new_pair%type_     = ALL_CELL_PROPERTY
          call add_registered_pair_to_array( this%mutators_, new_pair )

          ! create the mutator
          mutator%i_owner_    = size( this%mutators_ )
          mutator%i_property_ = property_id
      end select
    end do

  end function cell_state_set_mutator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an mutator for a domain cell flag
  function cell_flag_mutator( this, flag_name, requestor )                    &
      result( new_mutator )

    use musica_assert,                 only : assert, die_msg

    !> Accessor for the requested flag
    class(domain_state_mutator_t), pointer :: new_mutator
    !> Domain
    class(domain_cell_t), intent(inout) :: this
    !> Name of the flag to find
    character(len=*), intent(in) :: flag_name
    !> Name of the model component requesting the mutator
    character(len=*), intent(in) :: requestor

    integer :: flag_id
    type(registered_pair_t) :: new_pair

    call assert( 284229422, len( trim( flag_name ) ) .gt. 0 )

    ! find the flag or return an error if not found
    if( .not. find_string( this%flags_, flag_name, flag_id ) ) then
      call die_msg( 614014616, "Flag '"//trim( flag_name )//                  &
                    "' requested by '"//trim( requestor )//"' not found." )
    end if

    ! register the mutator
    new_pair%owner_    = requestor
    new_pair%property_ = this%flags_( flag_id )
    new_pair%type_     = ALL_CELL_FLAG
    call add_registered_pair_to_array( this%mutators_, new_pair )

    ! create the mutator
    allocate( domain_cell_state_mutator_flag_t :: new_mutator )
    select type( new_mutator )
      class is( domain_cell_state_mutator_flag_t )
        new_mutator%i_owner_ = size( this%mutators_ )
        new_mutator%i_flag_  = flag_id
    end select

  end function cell_flag_mutator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an accessor for a registered state variable for each cell in the
  !! domain
  function cell_state_accessor( this, variable_name, units, requestor )       &
      result( new_accessor )

    use musica_assert,                 only : assert, die_msg
    use musica_string,                 only : string_t

    !> Accessor for the requested state variable
    class(domain_state_accessor_t), pointer :: new_accessor
    !> Domain
    class(domain_cell_t), intent(inout) :: this
    !> Name of the variable to find
    character(len=*), intent(in) :: variable_name
    !> Units for the state variable
    character(len=*), intent(in) :: units
    !> Name of the model component requesting the accessor
    character(len=*), intent(in) :: requestor

    integer :: property_id
    type(registered_pair_t) :: new_pair

    call assert( 245885124, len( trim( variable_name ) ) .gt. 0 )

    ! find the property or return an error if not found
    if( .not. find_string( this%properties_, variable_name, property_id ) )   &
      then
      call die_msg( 458539961, "Property '"//trim( variable_name )//          &
                    "' requested by '"//trim( requestor )//"' not found." )
    end if

    ! register the accessor
    new_pair%owner_    = requestor
    new_pair%property_ = this%properties_( property_id )
    new_pair%type_     = ALL_CELL_PROPERTY
    call add_registered_pair_to_array( this%accessors_, new_pair )

    ! create the accessor
    allocate( domain_cell_state_accessor_property_t :: new_accessor )
    select type( new_accessor )
      class is( domain_cell_state_accessor_property_t )
        new_accessor%i_owner_    = size( this%accessors_ )
        new_accessor%i_property_ = property_id
    end select

  end function cell_state_accessor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get accessors for a set of state variables for each cell in the domain
  function cell_state_set_accessor( this, variable_name, units,               &
      component_names, requestor ) result( new_accessors )

    use musica_assert,                 only : assert, die_msg
    use musica_domain,                 only : domain_state_accessor_ptr

    !> Accessors for the requested state variable set
    class(domain_state_accessor_ptr), allocatable :: new_accessors(:)
    !> Domain
    class(domain_cell_t), intent(inout) :: this
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

    type(registered_pair_t) :: new_pair
    type(string_t) :: full_name
    integer :: i_accessor, property_id

    call assert( 520075610, allocated( component_names ) )
    call assert( 127187550, len( trim( variable_name ) ) .gt. 0 )

    allocate( new_accessors( size( component_names ) ) )

    do i_accessor = 1, size( component_names )
      select type( accessor => new_accessors( i_accessor )%val )
        class is( domain_cell_state_accessor_property_t )
          full_name =                                                         &
            trim( variable_name )//"%"//component_names( i_accessor )

          ! find the property or return an error if not found
          if( .not. find_string( this%properties_, full_name%to_char( ),      &
                                 property_id ) )                              &
            call die_msg( 556955404, "Property '"//full_name%to_char( )//     &
                       "' requested by '"//trim( requestor )//"' not found." )

          ! register the accessor
          new_pair%owner_    = requestor
          new_pair%property_ = this%properties_( property_id )
          new_pair%type_     = ALL_CELL_PROPERTY
          call add_registered_pair_to_array( this%accessors_, new_pair )

          ! create the accessor
          accessor%i_owner_    = size( this%accessors_ )
          accessor%i_property_ = property_id
      end select
    end do

  end function cell_state_set_accessor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an accessor for a domain cell flag
  function cell_flag_accessor( this, flag_name, requestor )                   &
      result( new_accessor )

    use musica_assert,                 only : assert, die_msg

    !> Accessor for the requested flag
    class(domain_state_accessor_t), pointer :: new_accessor
    !> Domain
    class(domain_cell_t), intent(inout) :: this
    !> Name of the flag to find
    character(len=*), intent(in) :: flag_name
    !> Name of the model component requesting the accessor
    character(len=*), intent(in) :: requestor

    integer :: flag_id
    type(registered_pair_t) :: new_pair

    call assert( 539062132, len( trim( flag_name ) ) .gt. 0 )

    ! find the flag or return an error if not found
    if( .not. find_string( this%flags_, flag_name, flag_id ) ) then
      call die_msg( 483129107, "Flag '"//trim( flag_name )//                  &
                    "' requested by '"//trim( requestor )//"' not found." )
    end if

    ! register the accessor
    new_pair%owner_    = requestor
    new_pair%property_ = this%flags_( flag_id )
    new_pair%type_     = ALL_CELL_FLAG
    call add_registered_pair_to_array( this%accessors_, new_pair )

    ! create the accessor
    allocate( domain_cell_state_accessor_flag_t :: new_accessor )
    select type( new_accessor )
      class is( domain_cell_state_accessor_flag_t )
        new_accessor%i_owner_ = size( this%accessors_ )
        new_accessor%i_flag_  = flag_id
    end select

  end function cell_flag_accessor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get an iterator for all cells in domain_cell_state_t objects
  function cell_iterator( this )

    use musica_iterator,               only : iterator_t

    !> New iterator
    class(domain_iterator_t), pointer :: cell_iterator
    !> Domain
    class(domain_cell_t), intent(in) :: this

    allocate( domain_cell_iterator_t :: cell_iterator )
    select type( cell_iterator )
      class is( domain_cell_iterator_t )
        cell_iterator%last_cell_ = this%number_of_cells_
    end select
  end function cell_iterator

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Output the domain state to a text file
  subroutine output_state_text( this, domain_state )

    use musica_assert,                 only : die_msg

    !> Domain
    class(domain_cell_t), intent(inout) :: this
    !> Domain state
    class(domain_state_t), intent(in) :: domain_state

    integer :: i_cell

    select type( domain_state )
      class is( domain_cell_state_t )

        ! just print to the screen for now
        write(*,*) this%properties_, this%flags_
        do i_cell = 1, this%number_of_cells_
          write(*,*) domain_state%properties_( i_cell, : ),                   &
                     domain_state%flags_( i_cell, : )
        end do

      class default
        call die_msg( 621916535, "Wrong domain state sent to domain_cell_t "//&
                      "output function" )
    end select

  end subroutine output_state_text

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> @name Type-bound domain_cell_state_t functions
  !!
  !! @{

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get the value of a registered property or state variable
  subroutine state_get( this, iterator, accessor, state_value )

    use musica_assert,                 only : die, die_msg

    !> Domain state
    class(domain_cell_state_t), intent(in) :: this
    !> Domain iterator
    class(domain_iterator_t), intent(in) :: iterator
    !> Accessor for the registered property or state variable
    class(domain_state_accessor_t), intent(in) :: accessor
    !> Value of the property or state variable
    class(*), intent(out) :: state_value

    select type( iterator )
      class is( domain_cell_iterator_t )
        select type( accessor )
          class is( domain_cell_state_accessor_property_t )
            select type( state_value )
              type is( real(kind=musica_dk) )
                state_value = this%properties_( iterator%current_cell_,       &
                                                accessor%i_property_ )
              class default
                call die_msg( 255104122, "Wrong variable type for accessor" )
            end select
          class is( domain_cell_state_accessor_flag_t )
            select type( state_value )
              type is( logical )
                state_value = this%flags_( iterator%current_cell_,            &
                                           accessor%i_flag_ )
              class default
                call die_msg( 408919456, "Wrong variable type for accessor" )
            end select
          class default
            call die( 507350414 )
        end select
      class default
        call die( 220063153 )
    end select

  end subroutine state_get

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update the value of a registered property or state variable
  subroutine state_update( this, iterator, mutator, state_value )

    use musica_assert,                 only : die_msg, die

    !> Domain state
    class(domain_cell_state_t), intent(inout) :: this
    !> Domain iterator
    class(domain_iterator_t), intent(in) :: iterator
    !> Mutator for registered property or state variable
    class(domain_state_mutator_t), intent(in) :: mutator
    !> New value
    class(*), intent(in) :: state_value

    select type( iterator )
      class is( domain_cell_iterator_t )
        select type( mutator )
          class is( domain_cell_state_mutator_property_t )
            select type( state_value )
              type is( real(kind=musica_dk) )
                this%properties_( iterator%current_cell_,                     &
                                  mutator%i_property_     ) = state_value
              class default
                call die_msg( 506636593, "Wrong variable type for mutator" )
            end select
          class is( domain_cell_state_mutator_flag_t )
            select type( state_value )
              type is( logical )
                this%flags_( iterator%current_cell_,                          &
                             mutator%i_flag_         ) = state_value
              class default
                call die_msg( 663358405, "Wrong variable type for mutator" )
            end select
          class default
            call die( 147623386 )
        end select
      class default
        call die( 884636322 )
    end select

  end subroutine state_update

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> @}

  !> @name Functions of domain_cell_iterator_t types
  !!
  !! @{

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Advance the iterator
  !!
  !! Returns false if the end of the collection has been reached
  logical function domain_cell_iterator_next( this )

    !> Iterator
    class(domain_cell_iterator_t), intent(inout) :: this

    this%current_cell_ = this%current_cell_ + 1

    if( this%current_cell_ .gt. this%last_cell_ ) then
      domain_cell_iterator_next = .false.
    else
      domain_cell_iterator_next = .true.
    end if

  end function domain_cell_iterator_next

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Reset the iterator
  subroutine domain_cell_iterator_reset( this )

    !> Iterator
    class(domain_cell_iterator_t), intent(inout) :: this

    this%current_cell_ = 0

  end subroutine domain_cell_iterator_reset

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> @}

  !> @name Private functions of the musica_domain_cell module
  !!
  !! @{

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add a registered pair to an array of registered pairs
  subroutine add_registered_pair_to_array( array, new_pair )

    use musica_assert,                 only : assert

    !> Array to add to
    type(registered_pair_t), allocatable, intent(inout)  :: array(:)
    !> Pair to add to array
    type(registered_pair_t), intent(in) :: new_pair

    type(registered_pair_t), allocatable :: temp_pairs(:)

    ! this could be made more efficient, if necessary

    call assert( 454015072, allocated( array ) )
    allocate( temp_pairs( size( array ) ) )
    temp_pairs(:) = array(:)
    deallocate( array )
    allocate( array( size( temp_pairs ) + 1 ) )
    array( :size( temp_pairs ) ) = temp_pairs(:)
    array( size( array ) )       = new_pair

  end subroutine add_registered_pair_to_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Add a string to an array of string
  subroutine add_string_to_array( array, new_string )

    use musica_assert,                 only : assert

    !> Array to add to
    type(string_t), allocatable, intent(inout) :: array(:)
    !> String to add to array
    character(len=*), intent(in) :: new_string

    type(string_t), allocatable :: temp_strings(:)

    ! this could be made more efficient if necessary

    call assert( 229830677, allocated( array ) )
    allocate( temp_strings( size( array ) ) )
    temp_strings(:) = array(:)
    deallocate( array )
    allocate( array( size( temp_strings ) + 1 ) )
    array( :size( temp_strings ) ) = temp_strings(:)
    array( size( array ) ) = trim( new_string )

  end subroutine add_string_to_array

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Find a string in a string array (case insensitive)
  logical function find_string( array, string, id )

    !> Array to search
    type(string_t), intent(in) :: array(:)
    !> String to search for
    character(len=*), intent(in) :: string
    !> Index of located string
    integer(kind=musica_ik), intent(out) :: id

    type(string_t) :: temp_string
    integer :: i_str

    id = 0
    find_string = .false.
    temp_string = trim( string )
    temp_string = temp_string%to_lower( )
    do i_str = 1, size( array )
      if( temp_string .eq. array( i_str )%to_lower( ) ) then
        id = i_str
        find_string = .true.
        exit
      end if
    end do

  end function find_string

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> @}

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_domain_cell
