! Copyright (C) 2020 National Center for Atmospheric Research
! SPDX-License-Identifier: Apache-2.0
!
!> \file
!> The musica_io_text module

!> The io_text_t type and related functions
module musica_io_text

  use musica_constants,                only : musica_dk, musica_ik
  use musica_convert,                  only : convert_t
  use musica_domain,                   only : domain_state_accessor_t,        &
                                              domain_state_mutator_t,         &
                                              domain_iterator_t
  use musica_string,                   only : string_t
  use musica_io,                       only : io_t

  implicit none
  private

  public :: io_text_t

  !> Maximum length of a text file line
  integer, parameter :: kMaxFileLine = 5000
  !> Flag for rows
  integer, parameter :: kRows = 1
  !> Flag for columns
  integer, parameter :: kColumns = 2

  !> Private input/output variable type
  type :: io_var_t
    !> Mutator for variable
    class(domain_state_mutator_t), pointer :: mutator_ => null( )
    !> Accessor for variable
    class(domain_state_accessor_t), pointer :: accessor_ => null( )
    !> Model domain variable name
    type(string_t) :: domain_variable_name_
    !> File column index
    integer(kind=musica_ik) :: file_column_index_ = -1
    !> Scaling factor in file units
    real(kind=musica_dk) :: scale_factor_ = 1.0_musica_dk
    !> Conversion
    type(convert_t) :: converter_
    !> Offset for data set in standard MUSICA units
    real(kind=musica_dk) :: offset_ = 0.0_musica_dk
  end type io_var_t

  !> Text file input/output
  !!
  !! Sets up a text file for input and/or output.
  !!
  !! \todo if input text files become large, reassess how they are accessed
  !!       at runtime
  !! \todo add example for \c io_test_t usage
  !!
  type, extends(io_t) :: io_text_t
    private
    !> Flag indicating whether file is open
    logical :: is_open_ = .false.
    !> Flag indicating whether file is for input
    logical :: is_input_ = .false.
    !> Flag indicating whether file is for output
    logical :: is_output_ = .false.
    !> File path
    type(string_t) :: file_path_
    !> File pointer
    integer :: file_unit_ = -1
    !> Delimiter for text file
    type(string_t) :: delimiter_
    !> Indicator of whether the time axis is along rows or columns
    integer :: time_axis_ = kRows
    !> File variable names
    type(string_t), allocatable :: file_variable_names_(:)
    !> File variable units
    type(string_t), allocatable :: file_variable_units_(:)
    !> Whether to shift the data set for each file variable
    logical, allocatable :: file_variable_do_shift_(:)
    !> Value to shift the first entry to for each variable in standard
    !! MUSICA units
    real(kind=musica_dk), allocatable :: shift_first_entry_to_(:)
    !> Domain variable names
    !!
    !! For input files, these are the names that will be searched for in the
    !! domain. If a match is not found, there will be no corresponding
    !! \c io_var_t object, and the input variable data will not be used.
    !!
    !! For output files, these are set to the domain variable name during
    !! output variable registration.
    !!
    type(string_t), allocatable :: domain_variable_names_(:)
    !> Column index for time
    integer(musica_ik) :: time_column_index_ = -1
    !> Converter for time to [s]
    type(convert_t) :: time_converter_
    !> Offset for time [s]
    real(kind=musica_dk) :: time_offset_ = 0.0_musica_dk
    !> Set of registered model variables for input/output
    type(io_var_t), allocatable :: variables_(:)
    !> Iterator over domain cells
    class(domain_iterator_t), pointer :: iterator_ => null( )
    !> File data (time, variable)
    real(kind=musica_dk), allocatable :: file_data_(:,:)
  contains
    !> Load input file variable names, units, and data
    procedure, private :: load_input_file_data
    !> Update the criteria used to match input data to domain variables
    procedure, private :: update_matching_criteria
    !> Auto-maps input/output variables to model state variables
    procedure, private :: auto_map_variables
    !> Set up shifts in the data sets
    procedure, private :: set_shift
    !> Registers a state variable for input/output
    procedure :: register
    !> Get the times corresponding to entries (for input data) [s]
    procedure :: entry_times__s
    !> Updates the model state with input data
    procedure :: update_state
    !> Outputs the current domain state
    procedure :: output
    !> Print the text file configuration information
    procedure :: print => do_print
    !> Closes the file stream
    procedure :: close
    !> Finalizes the output
    final :: finalize
  end type io_text_t

  !> Constructor
  interface io_text_t
    module procedure :: constructor
  end interface io_text_t

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Creates a connection to a text input/output file
  !!
  !! At minimum, \c config must include a top-level key-value pair "intent",
  !! which can be any of: "input", "output", or "input/output".
  !!
  !! A "file name" is also required for files opened for input or
  !! input/output. This is optional for output files, with the default name
  !! being "output.csv".
  !!
  !! Input files require the model domain object for mapping between model
  !! domain and file variables.
  !!
  function constructor( config, domain ) result( new_obj )

    use musica_assert,                 only : die_msg
    use musica_config,                 only : config_t
    use musica_domain,                 only : domain_t

    !> New text file
    type(io_text_t), pointer :: new_obj
    !> Configuration data
    class(config_t), intent(inout) :: config
    !> Model domain
    class(domain_t), intent(inout), optional :: domain

    character(len=*), parameter :: my_name = 'text file constructor'
    type(string_t) :: temp_str
    logical :: found

    allocate( new_obj )

    ! file intent
    call config%get( "intent", temp_str, my_name )
    temp_str = temp_str%to_lower( )
    if( temp_str .eq. "input" ) then
      new_obj%is_input_ = .true.
    else if( temp_str .eq. "output" ) then
      new_obj%is_output_ = .true.
    else if( temp_str .eq. "input/output" ) then
      new_obj%is_input_ = .true.
      new_obj%is_output_ = .true.
      call die_msg( 776288548, "Text input/output files are not supported" )
    else
      call die_msg( 162615120, "Invalid type specified for text file: "//     &
                               temp_str%to_char( ) )
    end if

    ! file name
    call config%get( "file name", new_obj%file_path_, my_name, found = found )
    if( .not. found ) then
      if( new_obj%is_input_ ) then
        call die_msg( 652480899, "A 'file name' must be provided for "//      &
                      "input text files" )
      else
        new_obj%file_path_ = "output.csv"
      end if
    end if

    ! file structure
    call config%get( "delimiter", new_obj%delimiter_, my_name, default = "," )
    call config%get( "time axis", temp_str, my_name, default = "rows" )
    if( temp_str .eq. "rows" ) then
      new_obj%time_axis_ = kRows
    else if( temp_str .eq. "columns" ) then
      new_obj%time_axis_ = kColumns
    else
      call die_msg( 935743676, "Invalid time axis specified for text file "// &
                    new_obj%file_path_%to_char( )//": "//temp_str%to_char( ) )
    end if

    ! initialize io variables
    allocate( new_obj%variables_( 0 ) )

    ! load the variable names, units, and data
    if( new_obj%is_input_ ) then
      call new_obj%load_input_file_data( config )
      if( present( domain ) ) then
        call new_obj%auto_map_variables( domain )
      else
        call die_msg( 304331040, "Input files require the model domain "//    &
                                 "during initialization for mapping." )
      end if
    else
      allocate( new_obj%file_variable_names_(    0 ) )
      allocate( new_obj%file_variable_units_(    0 ) )
      allocate( new_obj%domain_variable_names_(  0 ) )
      allocate( new_obj%file_variable_do_shift_( 0 ) )
      allocate( new_obj%shift_first_entry_to_(   0 ) )
    end if

  end function constructor

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Load input data variable names, units and data
  subroutine load_input_file_data( this, config )

    use musica_assert,                 only : assert, assert_msg, die
    use musica_config,                 only : config_t
    use musica_io,                     only : get_file_unit, free_file_unit

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Input file configuration data
    type(config_t), intent(inout) :: config

    character(len=kMaxFileLine) :: line
    logical :: found
    integer(kind=musica_ik) :: io, i_var, i_time, n_times, n_var
    type(string_t) :: temp_str
    type(string_t), allocatable :: values(:)

    ! read variable names
    this%file_unit_ = get_file_unit( )
    open( unit = this%file_unit_, file = this%file_path_%to_char( ),          &
          action = 'READ', iostat = io )
    call assert_msg( 708186002, io .eq. 0, "Error opening file '"//           &
                     this%file_path_%to_char( ) )
    this%is_open_ = .true.
    if( this%time_axis_ .eq. kRows ) then
      read( this%file_unit_, '(a)', iostat = io ) line
      call assert_msg( 196262051, io .eq. 0, "Error reading header of file '"// &
                     this%file_path_%to_char( ) )
      temp_str = line
      this%file_variable_names_   = temp_str%split( this%delimiter_ )
    else if( this%time_axis_ .eq. kColumns ) then
      n_var = count_lines( this )
      allocate( this%file_variable_names_( n_var ) )
      do i_var = 1, n_var
        read( this%file_unit_, '(a)', iostat = io ) line
        call assert( 242420386, io .eq. 0 )
        temp_str = line
        values = temp_str%split( this%delimiter_ )
        n_times = size( values ) - 1
        this%file_variable_names_( i_var ) = values(1)
      end do
      rewind( this%file_unit_ )
    else
      call die( 727926448 )
    end if
    n_var = size( this%file_variable_names_ )
    do i_var = 1, n_var
      this%file_variable_names_( i_var ) =                                    &
        adjustl( trim( this%file_variable_names_( i_var )%to_char( ) ) )
    end do

    ! update matching criteria (specified names, units, etc.,
    ! standard renaming)
    call this%update_matching_criteria( config )

    ! read the data
    if( this%time_axis_ .eq. kRows ) then
      n_times = count_lines( this ) - 1
      read( this%file_unit_, * )
      allocate( this%file_data_( n_times, n_var ) )
      do i_time = 1, n_times
        read( this%file_unit_, '(a)' ) line
        temp_str = line
        values = temp_str%split( this%delimiter_ )
        call assert_msg( 429572998, size( values ) .eq. n_var, "Bad "//         &
                         "structure in file '"//this%file_path_%to_char( )//    &
                         "'" )
        do i_var = 1, n_var
          this%file_data_( i_time, i_var ) = values( i_var )
        end do
      end do
    else if( this%time_axis_ .eq. kColumns ) then
      allocate( this%file_data_( n_times, n_var ) )
      do i_var = 1, n_var
        read( this%file_unit_, '(a)' ) line
        temp_str = line
        values = temp_str%split( this%delimiter_ )
        call assert_msg( 261145382, size( values ) .eq. n_times + 1,          &
                         "Bad structure in file '"//this%file_path_%to_char( )&
                         //"'" )
        do i_time = 1, n_times
          this%file_data_( i_time, i_var ) = values( i_time + 1 )
        end do
      end do
    else
      call die( 838339259 )
    end if
    close( this%file_unit_ )
    this%is_open_ = .false.
    call free_file_unit( this%file_unit_ )
    this%file_unit_ = -1

  end subroutine load_input_file_data

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Update the matching criteria for input files
  !!
  !! This updates the names that will be searched for in the domain to match
  !! to input file variable names and variable units based on standard
  !! mapping and mapping criteria specified in the configuration data.
  !!
  subroutine update_matching_criteria( this, config )

    use musica_array,                  only : find_string_in_array
    use musica_assert,                 only : assert_msg
    use musica_config,                 only : config_t
    use musica_iterator,               only : iterator_t

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Text file configuration data
    type(config_t), intent(inout) :: config

    character(len=*), parameter :: my_name =                                  &
        "text file update matching criteria"
    class(iterator_t), pointer :: iter
    type(config_t) :: vars, var, shift_data
    type(string_t) :: temp_str, var_name, general_replacement
    type(string_t), allocatable :: var_split(:)
    integer(kind=musica_ik) :: i_var, n_var
    logical :: found, general_match

    ! set the default domain names and units
    n_var = size( this%file_variable_names_ )
    this%domain_variable_names_ = this%file_variable_names_
    allocate( this%file_variable_units_(    n_var ) )
    allocate( this%file_variable_do_shift_( n_var ) )
    allocate( this%shift_first_entry_to_(   n_var ) )
    this%file_variable_do_shift_(:) = .false.
    this%shift_first_entry_to_(:)   = 0.0_musica_dk
    do i_var = 1, n_var
      this%file_variable_units_( i_var ) = "unknown"
    end do

    ! update matching based on specified configuration data
    call config%get( "properties", vars, my_name, found = found )
    if( found ) then
      do i_var = 1, size( this%file_variable_names_ )
        ! look for specific then general entries
        general_match = .false.
        call vars%get( this%file_variable_names_( i_var )%to_char( ), var,    &
                       my_name, found = found )
        if( .not. found ) then
          call vars%get( "*", var, my_name, found = found )
          general_match = .true.
        end if
        if( .not. found ) cycle
        call var%get( "MusicBox name", this%domain_variable_names_( i_var ),  &
                    my_name,                                                  &
                    default = this%domain_variable_names_( i_var )%to_char( ) )
        call var%get( "units", temp_str, my_name, found = found )
        if( found ) this%file_variable_units_( i_var ) = temp_str
        call var%get( "shift first entry to", shift_data, my_name,            &
                      found = found )
        if( found ) then
          call this%set_shift( i_var, shift_data )
          call shift_data%finalize( )
        end if
        call var%finalize( )
        if( general_match ) then
          this%domain_variable_names_( i_var ) =                              &
              this%domain_variable_names_( i_var )%replace( "*",              &
                                this%file_variable_names_( i_var )%to_char( ) )
        end if
      end do
      call vars%finalize( )
    end if

    ! make standard name conversions for text files and get specified units
    do i_var = 1, size( this%domain_variable_names_ )
      this%domain_variable_names_( i_var ) =                                  &
          this%domain_variable_names_( i_var )%replace( "CONC.",              &
                                                        "chemical_species%" )
      this%domain_variable_names_( i_var ) =                                  &
          this%domain_variable_names_( i_var )%replace( "ENV.", "" )
      this%domain_variable_names_( i_var ) =                                  &
          this%domain_variable_names_( i_var )%replace( "EMIS.",              &
                                                        "emission_rates%" )
      this%domain_variable_names_( i_var ) =                                  &
          this%domain_variable_names_( i_var )%replace( "LOSS.",              &
                                                       "loss_rate_constants%" )
      this%domain_variable_names_( i_var ) =                                  &
          this%domain_variable_names_( i_var )%replace( "PHOT.",              &
                                               "photolysis_rate_constants%" )
      var_split = this%domain_variable_names_( i_var )%split( "." )
      if( size( var_split ) .gt. 1 ) then
        this%domain_variable_names_( i_var ) = var_split(1)
        this%file_variable_units_(   i_var ) = var_split(2)
      end if
    end do

  end subroutine update_matching_criteria

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Sets up a shift in the data values
  subroutine set_shift( this, variable_id, config )

    use musica_config,                 only : config_t
    use musica_datetime,               only : datetime_t

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Variable id in file to shift
    integer(kind=musica_ik), intent(in) :: variable_id
    !> Configuration data
    type(config_t) :: config

    type(datetime_t) :: datetime
    real(kind=musica_dk) :: first_value

    datetime = datetime_t( config )
    this%file_variable_do_shift_( variable_id ) = .true.
    this%shift_first_entry_to_(   variable_id ) = datetime%in_seconds( )

  end subroutine set_shift

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Auto-maps input/output variables to model state variables
  subroutine auto_map_variables( this, domain )

    use musica_array,                  only : find_string_in_array,           &
                                              find_string_in_split_array
    use musica_assert,                 only : assert_msg, die_msg
    use musica_domain,                 only : domain_t,                       &
                                              domain_state_mutator_t

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(inout) :: domain

    character(len=*), parameter :: my_name = "auto map text file variables"
    type(string_t) :: var_name
    type(string_t), allocatable :: split_name(:)
    integer :: i_col

    call assert_msg( 974120905, .not. this%is_output_, "Auto-mapping of "//   &
                     "text files is only available for input files." )

    do i_col = 1, size( this%domain_variable_names_ )
      var_name = this%domain_variable_names_( i_col )

      ! create state variables for emissions and loss rates
      if( var_name%substring( 1, 15 ) .eq. "emission_rates%" ) then
        if( this%file_variable_units_( i_col ) .eq. "unknown" ) then
          this%file_variable_units_( i_col ) = "mol m-3 s-1"
        end if
        call domain%register_cell_state_variable( var_name%to_char( ),        & !- state variable name
                                                  "mol m-3 s-1",              & !- MUSICA units
                                                  0.0d0,                      & !- default value
                                                  my_name )
      else if( var_name%substring( 1, 20 ) .eq. "loss_rate_constants%" )  then
        if( this%file_variable_units_( i_col ) .eq. "unknown" ) then
          this%file_variable_units_( i_col ) = "s-1"
        end if
        call domain%register_cell_state_variable( var_name%to_char( ),        & !- state variable name
                                                  "s-1",                      & !- MUSICA units
                                                  0.0d0,                      & !- default value
                                                  my_name )
      end if
      if( domain%is_cell_state_variable( var_name%to_char( ) ) ) then
        ! assume variables are in standard units if not otherwise specified
        if( this%file_variable_units_( i_col ) .eq. "unknown" ) then
          this%file_variable_units_( i_col ) =                                &
              domain%cell_state_units( var_name%to_char( ) )
        end if
        call this%register( domain,                                           &
                            this%domain_variable_names_( i_col )%to_char( ),  &
                            this%file_variable_units_( i_col )%to_char( ),    &
                            this%file_variable_names_( i_col )%to_char( ) )
      end if
    end do

    ! add time index and conversion
    if( find_string_in_array( this%domain_variable_names_, "time", i_col ) )  &
        then
      if( this%file_variable_units_( i_col ) .eq. "unknown" ) then
        call this%register( domain, "time", "s" )
      else
        call this%register( domain, "time",                                   &
                            this%file_variable_units_( i_col )%to_char( ) )
      end if
    end if

  end subroutine auto_map_variables

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Registers a state variable for input/output
  subroutine register( this, domain, domain_variable_name, units,             &
      io_variable_name )

    use musica_array,                  only : add_to_array,                   &
                                              find_string_in_array,           &
                                              find_string_in_split_array
    use musica_assert,                 only : assert_msg
    use musica_domain,                 only : domain_t

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(inout) :: domain
    !> Variable to register
    character(len=*), intent(in) :: domain_variable_name
    !> Units used in the file for the variable
    character(len=*), intent(in) :: units
    !> Optional custom name in file
    character(len=*), intent(in), optional :: io_variable_name

    character(len=*), parameter :: my_name = "register text file variable"
    type(io_var_t), allocatable :: temp_vars(:)
    type(string_t) :: io_var_name, std_units
    integer :: var_id, col_id

    call assert_msg( 812848624, this%is_input_ .neqv. this%is_output_,        &
                     "Input/output text files are not yet supported." )

    if( present( io_variable_name ) ) then
      io_var_name = io_variable_name
    else
      io_var_name = domain_variable_name
    end if

    ! if the variable is time, it does not require accessors or mutators
    ! it just needs to have the column identified
    if( domain_variable_name .eq. "time" ) then
      call assert_msg( 701920734,                                             &
                       find_string_in_array( this%domain_variable_names_,     &
                                             "time", col_id ),                &
                       "Cannot find time column in file '"//                  &
                       this%file_path_%to_char( )//"'" )
      this%time_column_index_ = col_id
      this%time_converter_ = convert_t( "s", units )
      if( this%file_variable_do_shift_( col_id ) ) then
        this%time_offset_ = this%shift_first_entry_to_( col_id ) -           &
            this%time_converter_%to_standard(                                &
                this%file_data_( 1, this%time_column_index_ ) )
      end if
      return
    end if

    ! add a new variable to the set of mapped file variables
    allocate( temp_vars( size( this%variables_ ) ) )
    temp_vars(:) = this%variables_(:)
    deallocate( this%variables_ )
    allocate( this%variables_( size( temp_vars ) + 1 ) )
    this%variables_( 1:size( temp_vars ) ) = temp_vars(:)
    deallocate( temp_vars )
    var_id = size( this%variables_ )

    ! get the standard units and a converter to the file variable units
    std_units = domain%cell_state_units( trim( domain_variable_name ) )
    this%variables_( var_id )%converter_ = convert_t( std_units, units )

    ! register an accessor for output
    if( this%is_output_ ) then
      this%variables_( var_id )%accessor_ =>                                  &
          domain%cell_state_accessor( domain_variable_name,                   & !- state variable name
                                      std_units%to_char( ),                   & !- MUSICA units
                                      my_name )
      col_id = var_id
      call add_to_array( this%file_variable_names_, io_var_name )
      call add_to_array( this%file_variable_units_, units )
      call add_to_array( this%domain_variable_names_, domain_variable_name )
    end if

    ! register a variable for input
    if( this%is_input_ ) then
      call assert_msg( 849368429,                                             &
                       find_string_in_array( this%file_variable_names_,       &
                                             io_var_name, col_id ),           &
                       "Could not find '"//io_var_name%to_char( )//           &
                       "' in input file '"//this%file_path_%to_char( )//"'" )
      this%variables_( var_id )%mutator_ =>                                   &
        domain%cell_state_mutator( domain_variable_name,                      & !- state variable name
                                   std_units%to_char( ),                      & !- MUSICA units
                                   my_name )
      if( this%file_variable_do_shift_( col_id ) ) then
        this%variables_( var_id )%offset_ =                                     &
            this%shift_first_entry_to_( col_id ) -                              &
            this%variables_( var_id )%converter_%to_standard(                   &
                this%file_data_( 1, col_id ) )
      end if
    end if

    this%variables_( var_id )%file_column_index_ = col_id
    this%variables_( var_id )%domain_variable_name_ = domain_variable_name

  end subroutine register

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Get the times corresponding to entries (for input data) [s]
  function entry_times__s( this )

    use musica_assert,                 only : assert
    use musica_constants,              only : musica_dk

    !> Input data entry times [s]
    real(kind=musica_dk), allocatable :: entry_times__s(:)
    !> Text file
    class(io_text_t), intent(inout) :: this

    integer(kind=musica_ik) :: i_time

    call assert( 806233948, this%time_column_index_ .gt. 0 )
    call assert( 180086118, allocated( this%file_data_ ) )

    allocate( entry_times__s( size( this%file_data_, 1 ) ) )

    do i_time = 1, size( entry_times__s )
      entry_times__s( i_time ) =                                              &
          this%time_converter_%to_standard(                                   &
                       this%file_data_( i_time, this%time_column_index_ ) ) + &
          this%time_offset_
    end do

  end function entry_times__s

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Updates the model state with input data
  subroutine update_state( this, domain, domain_state, time__s )

    use musica_assert,                 only : die_msg, assert, assert_msg
    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_t, domain_state_t

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Domain state to update
    class(domain_state_t), intent(inout) :: domain_state
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in), optional :: time__s

    logical :: is_update_time
    integer(kind=musica_ik) :: i_line, i_var, n_rows
    real(kind=musica_dk) :: file_time, new_value

    call assert_msg( 240742292, this%is_input_ .neqv. this%is_output_,        &
                     "Input/output text files are not supported." )

    call assert_msg( 127971652, this%is_input_, "Trying to read data from "// &
                     "output file '"//this%file_path_%to_char( )//"'" )

    if( present( time__s ) ) then
    call assert_msg( 839994341, this%time_column_index_ .gt. 0,               &
                     "No time dimension specified for file '"//               &
                     this%file_path_%to_char( )//"'" )
    end if

    if( .not. associated( this%iterator_ ) ) then
      this%iterator_ => domain%cell_iterator( )
    end if

    ! determine if a new value exists for this time, and find the row index
    ! for the update
    if( present( time__s ) ) then
      i_line = 0
      n_rows = size( this%file_data_, 1 )
      is_update_time = .false.
      do while( .not. is_update_time .and. i_line .lt. n_rows )
        i_line = i_line + 1
        file_time = this%time_converter_%to_standard(                         &
                      this%file_data_( i_line, this%time_column_index_ ) ) +  &
                    this%time_offset_
        if( file_time .eq. time__s ) then
          is_update_time = .true.
        end if
      end do
    else
      i_line = 1
      is_update_time = .true.
    end if

    if( .not. is_update_time ) return

    ! update the state variables
    do i_var = 1, size( this%variables_ )
      call assert( 739231151,                                                 &
                   associated( this%variables_( i_var )%mutator_ ) )
      new_value = this%file_data_( i_line,                                    &
                                 this%variables_( i_var )%file_column_index_ )
      new_value = this%variables_( i_var )%converter_%to_standard( new_value )
      new_value = new_value + this%variables_( i_var )%offset_
      call this%iterator_%reset( )
      do while( this%iterator_%next( ) )
        call domain_state%update( this%iterator_,                             &
                                  this%variables_( i_var )%mutator_,          &
                                  new_value )
      end do
    end do

  end subroutine update_state

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Outputs the current domain state
  subroutine output( this, time__s, domain, domain_state )

    use musica_assert,                 only : assert_msg
    use musica_constants,              only : musica_dk
    use musica_domain,                 only : domain_t, domain_state_t
    use musica_io,                     only : get_file_unit

    !> Text file
    class(io_text_t), intent(inout) :: this
    !> Current simulation time [s]
    real(kind=musica_dk), intent(in) :: time__s
    !> Model domain
    class(domain_t), intent(in) :: domain
    !> Domain state
    class(domain_state_t), intent(in) :: domain_state

    integer :: i_var, i_cell
    real(kind=musica_dk) :: state_value
    logical :: one_cell
    type(string_t) :: col_name

    call assert_msg( 276548276, this%is_input_ .neqv. this%is_output_,        &
                     "Input/output text files are not yet supported." )

    call assert_msg( 383602314, this%is_output_, "Trying to write data to "// &
                     "input file '"//this%file_path_%to_char( )//"'" )

    if( .not. this%is_open_ ) then
      this%iterator_ => domain%cell_iterator( )

      ! check if there is more than one cell for naming
      one_cell = this%iterator_%next( )
      one_cell = .true.
      if( this%iterator_%next( ) ) one_cell = .false.
      call this%iterator_%reset( )

      ! open the cell and write the header
      this%file_unit_ = get_file_unit( )
      open( unit = this%file_unit_, file = this%file_path_%to_char( ) )
      write(this%file_unit_,'(A)',advance="no") "time"
      call this%iterator_%reset( )
      i_cell = 1
      do while( this%iterator_%next( ) )
        do i_var = 1, size( this%variables_ )
          if( one_cell ) then
            col_name = this%file_variable_names_(                             &
                this%variables_( i_var )%file_column_index_ )
          else
            col_name = i_cell
            col_name = trim( col_name%to_char( ) )//'.'//                     &
                this%file_variable_names_(                                    &
                this%variables_( i_var )%file_column_index_ )
          end if
          write(this%file_unit_,'(", ",A)',advance="no") col_name%to_char( )
        end do
        i_cell = i_cell + 1
      end do
      write(this%file_unit_,*) ""
      this%is_open_ = .true.
    end if

    ! output the current state values
    write(this%file_unit_,'(D30.20)',advance="no") time__s
    call this%iterator_%reset( )
    do while( this%iterator_%next( ) )
      do i_var = 1, size( this%variables_ )
        call domain_state%get( this%iterator_,                                &
                               this%variables_(i_var)%accessor_,              &
                               state_value )
        state_value =                                                         &
            this%variables_( i_var )%converter_%to_non_standard( state_value )
        write(this%file_unit_,'(", ",D30.20)',advance="no") state_value
      end do
    end do
    write(this%file_unit_,*) ""

  end subroutine output

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Print the text file configuration information
  subroutine do_print( this )

    !> Text file
    class(io_text_t), intent(in) :: this

    integer(kind=musica_ik) :: i

    write(*,*) "***** Text File Configuration *****"
    write(*,*) ""
    if( this%is_open_ ) then
      write(*,*) "File '"//this%file_path_%to_char( )//"' is open"
    else
      write(*,*) "File '"//this%file_path_%to_char( )//"' is closed"
    end if
    write(*,*) "Delimiter: '"//this%delimiter_%to_char( )//"'"
    write(*,*) "Time column index: ", this%time_column_index_
    write(*,*) "Text file variables:"
    write(*,*) "--------------------"
    if( allocated( this%file_variable_names_ ) ) then
      do i = 1, size( this%file_variable_names_ )
        write(*,*) this%file_variable_names_( i )%to_char( )//" ["//          &
            this%file_variable_units_( i )%to_char( )//"] tried match as '"// &
            this%domain_variable_names_( i )%to_char( )//"'"
      end do
    end if
    write(*,*)
    write(*,*) "Mutators/Accessors"
    write(*,*) "------------------"
    if( allocated( this%variables_ ) ) then
      do i = 1, size( this%variables_ )
        if( associated( this%variables_( i )%mutator_ ) ) then
          write(*,*) "Mutator for '"//                                        &
              this%variables_( i )%domain_variable_name_%to_char( )//"' "//   &
              "attached to column ", this%variables_( i )%file_column_index_, &
              " with scale factor ", this%variables_( i )%scale_factor_
        end if
        if( associated( this%variables_( i )%accessor_ ) ) then
          write(*,*) "Accessor for '"//                                       &
              this%variables_( i )%domain_variable_name_%to_char( )//"' "//   &
              "attached to column ", this%variables_( i )%file_column_index_, &
              " with scale factor ", this%variables_( i )%scale_factor_
        end if
      end do
    end if
    do i = 1, size( this%file_data_, 1 )
      write(*,*) this%file_data_(i,:)
    end do
    write(*,*)
    write(*,*) "*** End Text File Configuration ***"

  end subroutine do_print

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Closes the text file
  subroutine close( this )

    use musica_io,                     only : free_file_unit

    !> Text file
    class(io_text_t), intent(inout) :: this

    if( this%is_open_ ) then
      close( this%file_unit_ )
      call free_file_unit( this%file_unit_ )
      this%is_open_ = .false.
    end if

  end subroutine close

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Finalizes the text file object, including closing the file if needed.
  subroutine finalize( this )

    !> Text file
    type(io_text_t), intent(inout) :: this

    integer(kind=musica_ik) :: i_var

    call this%close( )
    if( associated( this%iterator_ ) ) deallocate( this%iterator_ )
    if( allocated( this%variables_ ) ) then
      do i_var = 1, size( this%variables_ )
        if( associated( this%variables_( i_var )%mutator_ ) ) then
          deallocate( this%variables_( i_var )%mutator_ )
        end if
        if( associated( this%variables_( i_var )%accessor_ ) ) then
          deallocate( this%variables_( i_var )%accessor_ )
        end if
      end do
    end if

  end subroutine finalize

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !> Count the lines in a file
  function count_lines( this ) result( n_lines )

    use musica_assert,                 only : assert

    !> Number of lines in the file
    integer(kind=musica_ik) :: n_lines
    !> Text file
    type(io_text_t), intent(inout) :: this

    integer :: io

    call assert( 776402509, this%is_open_ )
    rewind( this%file_unit_ )
    n_lines = 0
    do
      read( this%file_unit_, *, iostat=io )
      if( io .ne. 0 ) exit
      n_lines = n_lines + 1
    end do
    rewind( this%file_unit_ )

  end function count_lines

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module musica_io_text
