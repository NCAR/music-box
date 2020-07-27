!> \page coding_style FORTRAN Style Guide
!!
!! This style guide is based on the [Google C++ Style
!! Guide](google.github.io/styleguide/cppguide.html), which is licensed
!! under the CC-By 3.0 License. See
!! <a href="https://creativecommons.org/licenses/by/3.0/">https://creativecommons.org/licenses/by/3.0/</a>
!! for more details. Portions of the text have been modified to apply to
!! FORTRAN code and reflect style choices made for MusicBox, but many
!! sections are presented unchanged, starting with this:
!!
!! Use common sense and BE CONSISTENT.
!!
!! If you are editing code, take a few minutes to look at the code
!! around you and determine its style. If they use spaces around their if
!! clauses, you should, too. If their comments have little boxes of stars
!! around them, make your comments have little boxes of stars around them
!! too.
!!
!! The point of having style guidelines is to have a common vocabulary of
!! coding so people can concentrate on what you are saying, rather than on
!! how you are saying it. We present global style rules here so people know
!! the vocabulary. But local style is also important. If code you add to a
!! file looks drastically different from the existing code around it, the
!! discontinuity throws readers out of their rhythm when they go to read
!! it. Try to avoid this.
!!
!! \htmlonly
!! <div class="row"><div class="col-sm-4">
!! \endhtmlonly
!!     ### Modules ###
!!     - \ref coding_modules_structure "Module structure"
!!     - \ref coding_modules_abstract "Modules for abstract types"
!!
!!     ### Comments ###
!!     - \ref coding_comments_style "Comment style"
!!     - \ref coding_comments_module "File/Module comments"
!!     - \ref coding_comments_type "Type comments"
!!     - \ref coding_comments_function "Function comments"
!!
!! \htmlonly
!! </div><div class="col-sm-4">
!! \endhtmlonly
!!     ### Naming ###
!!     - \ref coding_naming_general "General naming rules"
!!     - \ref coding_naming_file "File names"
!!     - \ref coding_naming_module "Module names"
!!     - \ref coding_naming_type "Type and type member names"
!!     - \ref coding_naming_function "Function and function argument names"
!!     - \ref coding_naming_variable "Variable names"
!!     - \ref coding_naming_constant "Constant names"
!!
!! \htmlonly
!! </div><div class="col-sm-4">
!! \endhtmlonly
!!     ### Functions ###
!!     - \ref coding_functions_short "Write short functions"
!!     - \ref coding_functions_intent "Argument intents"
!!
!!     ### Formatting ###
!!     - \ref coding_format_case "Pretend FORTRAN is case sensitive"
!!     - \ref coding_format_line_length "Line length"
!!     - \ref coding_format_spaces_tabs "Spaces vs. tabs"
!!     - \ref coding_format_horizontal_whitespace "Horizontal whitespace"
!!     - \ref coding_format_vertical_whitespace "Vertical whitespace"
!!
!! \htmlonly
!! </div></div>
!! \endhtmlonly
!!
!! \anchor coding_modules_structure
!! ### Module structure ###
!!
!! Modules generally define a single derived type with type-bound
!! procedures, however this is not strictly enforced. Utility modules
!! that only include generally useful, short, public functions are
!! allowed. Modules may also define more than one public derived type if
!! the defined types are related and module procedures need access to the
!! types' private data members or type-bound procedures.
!!
!! The general structure of a module that defines the \c foo_t type
!! and is built into the bar library would be included in a file named
!! \c foo.F90 as:
!! \code{f90}
!! ! Copyright (C) 2020 National Center for Atmospheric Research
!! ! SPDX-License-Identifier: Apache-2.0
!! !
!! !> \file
!! !> The bar_foo module
!!
!! !> The foo_t type and related functions
!! module bar_foo
!!
!!   use bar_other,                         only : other_t
!!
!!   implicit none
!!   private
!!
!!   public :: foo_t
!!
!!   !> The foo type
!!   !!
!!   !! [description and examples]
!!   type :: foo_t
!!     private
!!     !> Raw foo value
!!     real(kind=musica_dk) :: foo
!!   contains
!!     !> Do foo
!!     procedure :: do_it
!!   end type foo_t
!!
!! contains
!!
!! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!
!!   !> Do foo
!!   !!
!!   !! [description and examples]
!!   subroutine do_it( this )
!!
!!     !> Foo
!!     class(foo_t), intent(in) :: this
!!
!!     ...
!!
!!   end subroutine do_it
!!
!! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!
!! end module bar_foo
!! \endcode
!!
!! \anchor coding_modules_abstract
!! ### Modules for abstract types ###
!!
!! Modules whose primary derived type is \c abstract are structured
!! similar to the style described \ref coding_modules_structure "above",
!! with extending types in a folder named for the abstract module and an
!! optional factory module. The files for the abstract \c foo_t type would
!! be:
!! \code{bash}
!! src/
!!   |
!!   |--- foo.F90
!!   |
!!   |--- foo_factory.F90
!!   |
!!   |--- foos/
!!          |
!!          |--- one.F90
!!          |
!!          |--- another.F90
!! \endcode
!! where the \c one.F90 file defines the \c foo_one_t extending type and
!! \c another.F90 defines the \c foo_another_t extending type.
!!
!! \anchor coding_comments_style
!! ### Comment style ###
!!
!! MusicBox uses <A HREF="http://www.doxygen.nl"> Doxygen </A>
!! to auto-generate documentation. More information on how to comment your
!! code for use with Doxygen is described \ref adding_documentation "here".
!!
!! \anchor coding_comments_module
!! ### File/Module comments ###
!!
!! Files should contain a single module and begin with the license
!! boilerplate and Doxygen description of the file and module:
!! \code{f90}
!! ! Copyright (C) 2020 National Center for Atmospheric Research
!! ! SPDX-License-Identifier: Apache-2.0
!! !
!! !> \file
!! !> The bar_foo module
!!
!! !> The foo_t type and related functions
!! module bar_foo
!!
!! ...
!!
!! end module bar_foo
!! \endcode
!! A brief general description of the module is ok, with more detailed
!! descriptions with example usage included in the type and function
!! comments. You could also include a more detailed set of instructions
!! for using the module type(s) in this header formatted as a Doxygen
!! \c \\page.
!!
!! \anchor coding_comments_type
!! ### Type comments ###
!!
!! Every non-obvious type declaration should have an accompanying comment
!! that describes what it is for and how it should be used.
!! \code{f90}
!! !> Iterates over the contents of a gargantuan_table_t.
!! !! Example:
!! !!    class(gargantuan_table_iterator_t), pointer :: iter
!! !!    iter => table%new_iterator( )
!! !!    do while( iter%next( ) )
!! !!      process( table, iter )
!! !!    end do
!! !!    deallocate( iter )
!! type :: gargantuan_table_iterator_t
!!  ...
!! end type gargantuan_table_iterator_t
!! \endcode
!! The type comment should provide the reader with enough information to
!! know how and when to use the type, as well as any additional
!! considerations necessary to correctly use the type. If an instance of
!! the type can be accessed by multiple threads, take extra care to document
!! the rules and invariants surrounding multithreaded use.
!!
!! The type comment is often a good place for a small example code snippet
!! demonstrating a simple and focused usage of the type.
!!
!! \anchor coding_comments_function
!! ### Function comments ###
!!
!! Almost every function declaration should have comments immediately
!! preceding it that describe what the function does and how to use it.
!! For functions that are simple and obvious
!! (e.g., simple accessors for obvious properties of the type) a very
!! brief description is sufficient. These
!! comments should open with descriptive verbs in the indicative mood
!! ("Opens the file") rather than verbs in the imperative ("Open the file").
!! The comment describes the function; it does not tell the function what
!! to do. In general, these comments do not describe how the function performs
!! its task. Instead, that should be left to comments in the function
!! definition.
!!
!! Types of things to mention in comments at the function declaration:
!!
!! - What the inputs and outputs are. Each argument should have a
!!   Doxygen-style desciption above its definition. If the argument is
!!   a real number the description must include the units - no
!!   exceptions. Units for integer arguments should be included when
!!   applicable.
!! - If the function allocates memory that the caller must free.
!! - If there are any performance implications of how a function is used.
!!
!! Here is an example:
!! \code{f90}
!! !! Returns an iterator for this table.  It is the client's
!! !! responsibility to delete the iterator when it is done with it,
!! !! and it must not use the iterator once the gargantuan_table_t object
!! !! on which the iterator was created has been deleted.
!! !!
!! !! The iterator is initially positioned at the beginning of the table.
!! !!
!! !! This method is equivalent to:
!! !!    class(iterator_t), pointer :: iter
!! !!    iter => table%new_iterator( )
!! !!    call iter%seek("")
!! !!    return
!! !! If you are going to immediately seek to another place in the
!! !! returned iterator, it will be faster to use new_iterator( )
!! !! and avoid the extra seek.
!! function get_iterator( this )
!!   !> Retruned iterator
!!   class(iterator_t), pointer :: get_iterator
!!   !> Table to get iterator for
!!   class(table_t), intent(in) :: this
!!   ...
!! end function get_iterator
!! \endcode
!!
!! However, do not be unnecessarily verbose or state the completely obvious.
!!
!! \anchor coding_naming_general
!! ### General naming rules ###
!!
!! Optimize for readability using names that would be clear even to people
!! with a science background but no modelling experience.
!!
!! Use names that describe the purpose or intent of the object. Do not worry
!! about saving horizontal space as it is far more important to make your
!! code immediately understandable by a new reader. Minimize the use of
!! abbreviations that would likely be unknown to someone outside your project
!! (especially acronyms and initialisms). Avoid the use of single letter or
!! Greek letter variables (\c alpha can mean many different things in
!! different contexts). If it is not possible to provide a meaningful
!! name for a variable (e.g., if it is an intermediate variable in a long
!! mathematical equation), provide the equation in comments to define the
!! variable. Do not abbreviate by deleting
!! letters within a word. As a rule of thumb, an abbreviation is probably OK
!! if it's listed in Wikipedia. Generally speaking, descriptiveness should be
!! proportional to the name's scope of visibility. For example, \c n may be a
!! fine name within a 5-line function, but within the scope of a type, it's
!! likely too vague.
!!
!! For the purposes of the naming rules below, a "word" is anything that you
!! would write in English without internal spaces. This includes
!! abbreviations, such as acronyms and initialisms. For names written in
!! mixed case (also sometimes referred to as "camel case" or "Pascal case"),
!! in which the first letter of each word is capitalized, prefer to capitalize
!! abbreviations as single words, e.g., \c StartRpc() rather than
!! \c StartRPC().
!!
!! \anchor coding_naming_file
!! ### File names ###
!!
!! Filenames should be all lowercase and include underscores (_).
!!
!! Filenames should be the name of the module they contain without the
!! library prefix. For example, the \c mylib_foo_bar module (which is
!! built as part of the \c mylib library) would be in a file named \c
!! foo_bar.F90.
!!
!! \anchor coding_naming_module
!! ### Module names ###
!!
!! Module names should be all lowercase and include underscores (_).
!!
!! Module names should start with the name of the library or executable
!! they are a part of, followed by an underscore (_) and the name of the
!! the primary derived type they define without the \c _t suffix. For
!! example, if a module defines the \c foo_bar_t type and is built as
!! part of the \c mylib library, the module name would be
!! \c mylib_foo_bar.
!!
!! \anchor coding_naming_type
!! ### Type and type member names ###
!!
!! Type names should be all lowercase, include underscores (_) between
!! words, and end in \c _t : e.g., \c foo_bar_t.
!!
!! Type data member names should be all lowercase, include
!! underscores (_), and end with an underscore (_): e.g.,
!! \c my_member_variable_.
!!
!! \anchor coding_naming_function
!! ### Function and function argument names ###
!!
!! Function and function argument names should be all lowercase and
!! include underscores (_).
!!
!! \anchor coding_naming_variable
!! ### Variable names ###
!!
!! The names of variables (including function parameters) and data members
!! are all lowercase, with underscores between words. Data members of types
!! additionally have trailing underscores. For instance:
!! \c a_local_variable, \c a_type_data_member_.
!!
!! \anchor coding_naming_constant
!! ### Constant names ###
!!
!! Variables declared \c parameter, and whose value is fixed for the
!! duration of the program, are named with a leading "k" followed by mixed
!! case. Underscores can be used as separators in the rare cases where
!! capitalization cannot be used for separation. For example:
!! \code{f90}
!! integer, parameter :: kDaysInAWeek = 7;
!! integer, parameter :: kAndroid8_0_0 = 24;  ! Android 8.0.0
!! \endcode
!!
!! \anchor coding_functions_short
!! ### Write short functions ###
!!
!! Prefer small and focused functions.
!!
!! We recognize that long functions are sometimes appropriate, so no hard
!! limit is placed on functions length. If a function exceeds about 40 lines,
!! think about whether it can be broken up without harming the structure of
!! the program.
!!
!! Even if your long function works perfectly now, someone modifying it in a
!! few months may add new behavior. This could result in bugs that are hard
!! to find. Keeping your functions short and simple makes it easier for other
!! people to read and modify your code. Small functions are also easier to
!! test.
!!
!! You could find long and complicated functions when working with some code.
!! Do not be intimidated by modifying existing code: if working with such a
!! function proves to be difficult, you find that errors are hard to debug,
!! or you want to use a piece of it in several different contexts, consider
!! breaking up the function into smaller and more manageable pieces.
!!
!! \anchor coding_functions_intent
!! ### Function argument intents ###
!!
!! Include an \c intent for every function argument without exception.
!! Prefer functions over subroutines with \c intent(out) arguments.
!! Consider breaking up functions with multiple \c intent(out) arguments.
!!
!! \anchor coding_format_case
!! ### Pretend FORTRAN is case sensitive ###
!!
!! Even though FORTRAN is case insensitive, following naming
!! conventions, including for case, makes the code more readable and
!! searachable.
!!
!! \anchor coding_format_line_length
!! ### Line length ###
!!
!! Wrap code that exceeds 79 characters. For wrapped code, place the
!! \c & at the 79th position
!!
!! \anchor coding_format_spaces_tabs
!! ### Spaces vs. tabs ###
!!
!! Use only spaces, and indent 2 spaces at a time.
!!
!! We use spaces for indentation. Do not use tabs in your code. You should
!! set your editor to emit spaces when you hit the tab key.
!!
!! \anchor coding_format_horizontal_whitespace
!! ### Horizontal whitespace ###
!!
!! Use of horizontal whitespace depends on location. Never put trailing
!! whitespace at the end of a line. Adding trailing whitespace can cause
!! extra work for others editing the same file, when they merge, as can
!! removing existing trailing whitespace. So: Don't introduce trailing
!! whitespace. Remove it if you're already changing that line, or do it in
!! a separate clean-up operation (preferably when no-one else is working on
!! the file).
!! \code{f90}
!! if( condition ) then      ! no space after if, while, select, etc.
!!   do_something( )         ! always space after( and before )
!! end if                    ! space after end (end if, end do, etc.)
!! x = 5 + ( 3 / 12.0 )      ! spaces around operators and () in equations
!!
!! function foo( this, bar ) result( foo_result ) ! spaces after( and before )
!!
!! ! exceptions to spacing rules
!! integer(kind=dk), intent(in) :: foo(12)   ! variable definitions
!! foo(:) = 12                               ! implicit loops over arrays
!! write(file_id,*) "foo"                    ! write statements
!! \endcode
!!
!! \anchor coding_format_vertical_whitespace
!! ### Vertical whitespace ###
!!
!! Try to minimize the use of vertical space while maintaining
!! readability. FORTRAN is a text heavy language and vertical spacing
!! can make code easier to read, but excessive vertical spacing means that
!! less code fits on the screen. Use your judgement, and try to never use
!! more that one blank line at a time.
!!
