!*******************************************************************************

!> \page adding_documentation Documenting 
!!
!! MusicBox uses <A HREF="http://www.doxygen.nl"> Doxygen </A>
!! to generate documentation.
!! General usage is described in the following sections.
!! More information can be found in the
!! <A HREF="http://www.doxygen.nl/manual/index.html"> Doxygen documentation
!! </A>.
!!
!! \section doc_general_usage General Documentation Style
!!
!! Placing a ``!>`` at the beginning of a
!! comment block and ``!!`` on lines 2+ of a comment block will signal Doxygen
!! to include these comments in the documentation.
!! Comments directly above a
!! function or subroutine can be used to document the purpose, usage and
!! science basis of the code.
!! Comments directly above a dummy variable can be
!! used to describe the variable.
!!
!! \subsection doc_general_formulas Formulas
!!
!! Math formulas can be included in \f$\LaTeX\f$ format between \c \\f$ and \c \\f$
!! flags for in-line formulas or <tt>\\f[</tt> and <tt>\\f]</tt> flags for separate formula
!! blocks.
!! For example, the following text:
!! \code{.f90}
!! !! here, \f$i \in 1...10\f$.
!! \endcode
!! is rendered as :
!!
!! here, \f$i \in 1...10\f$.
!!
!! \subsection doc_gen_markdown_html Markdown and HTML
!!
!! <A HREF="http://www.doxygen.nl/manual/markdown.html">Markdown</A> and
!! <A HREF="http://www.doxygen.nl/manual/htmlcmds.html">HTML commands</A>
!! can be included in the comments and will be rendered by Doxygen when
!! building the documentation.
!!
!! \subsection doc_gen_citations Citations
!!
!! Citations can be included using the \c \\cite flag followed by the name
!! of the citation as specified in \c doc/references.bib. If a url is included
!! for the reference in the BibTeX file, it will be hyperlinked by Doxygen.
!!
!! \subsection doc_gen_example Example
!!
!! Here is an example of a function with Doxygen comments:
!! \code{.f90}
!! !> A brief description of my new function
!! !! More detailed information is included here, including a really
!! !! cool equation
!! !! \f[
!! !!   k = a e^{-k_B T}
!! !! \f]
!! !! and maybe a reference to published work \cite Me2018
!! function get_rate( pre_exp_factor__s, temperature__K )
!!
!!   !> Reaction rate [\f$s^{-1}\f$]
!!   real(kind=mflt) :: get_rate
!!   !> Pre-exponential factor [\f$s^{-1}\f$]
!!   real(kind=mflt), intent(in) :: pre_exp_factor__s
!!   !> Temperature [K]
!!   real(kind=mflt), intent(in) :: temperature__K
!!
!!   !...
!!
!! end function get_rate
!! \endcode
!!
!! \subsection doc_general_bugs_and_todos Bugs and Future Work
!!
!! The \c \\bug and \c \\todo flags can be used to document bugs in the code
!! and suggestions for improvements. The detailed function/subroutine
!! documentation will include \c bug and/or \c todo sections when these
!! flags are used. Additionally, Doxygen assembles a
!! \ref bug and a \ref todo from these flagged comments.
!!
!! \bug Doxygen doesn't compile a bug list without at least one bug
