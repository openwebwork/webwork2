package WeBWorK::ExternalProblem;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::ExternalProblem - Use problems from other online homework systems.

=head1 DESCRIPTION

The source file of a problem in a set is usually the path of a PG file.  It can
instead name a problem from another online homework system, such as

    imathas:1234
    myopenmath:1234

Such a source file starts with the name of the type of external problem
followed by a colon.  What follows the colon depends on the type.  An external
problem does not have a file.  It is obtained from the other system when it is
rendered.  Use L</isExternalSource> anywhere that a source file would otherwise
be treated as a file (to read it, edit it, get its tags, and so on).

The problem is still rendered by PG.  Before PG is called, L</pgOptions> has the
module for the type of the problem get what is needed from the other system, and
then has PG render a short problem.  So answer feedback, hardcopy, the problem
graders, and so on work as they do for other problems.

=head2 Adding a type of external problem

Add the name (in lower case) of each source file prefix to the C<TYPES> hash
below, with a short name for the system that is shown to users, and the module
that handles the type.  Several prefixes can use the same module.  The module
must have a C<pgOptions> function that takes the course environment, the options
for the C<WeBWorK::PG> constructor, and the prefix.  It must change the options
so that PG renders the problem, by setting the C<r_source> option to a PG
problem and putting what that problem needs into an option of its own (PG puts
an option that it does not know into the problem environment).  See
L<WeBWorK::ExternalProblem::IMathAS> for an example.

If the PG problem needs code of its own, then put that in a macro file in a
directory next to the module, and have C<pgOptions> put that directory first
in the C<macrosPath> option.  Such a macro is internal to the module, and is not
for use in problem files.

=cut

our @EXPORT_OK = qw(isExternalSource externalSourceType);

# The types of external problems, by the prefix of the source file.
use constant TYPES => {
	imathas    => { name => 'IMathAS',    module => 'WeBWorK::ExternalProblem::IMathAS' },
	myopenmath => { name => 'MyOpenMath', module => 'WeBWorK::ExternalProblem::IMathAS' },
};

=head1 FUNCTIONS

=head2 externalSourceType

    my $type = externalSourceType($sourceFile);

If C<$sourceFile> is the source file of an external problem, then this returns
a reference to a hash with the keys C<prefix> (the prefix of the source file in
lower case), C<name> (the name of the system that the problem is from), and
C<module> (the module that handles it).  Otherwise this returns undef.

Note that this only looks at the prefix of the source file.  If the rest of
the source file is not valid for the type, then that is reported when the
problem is rendered.

=cut

sub externalSourceType ($sourceFile) {
	return unless defined $sourceFile && $sourceFile =~ /^(\w+):/;
	my $prefix = lc $1;
	my $type   = TYPES->{$prefix};
	return unless $type;
	return { prefix => $prefix, %$type };
}

=head2 isExternalSource

    if (isExternalSource($sourceFile)) { ... }

Returns true if C<$sourceFile> is the source file of a problem from another
online homework system, and so is not a file.

=cut

sub isExternalSource ($sourceFile) { return defined externalSourceType($sourceFile) }

=head2 pgOptions

    WeBWorK::ExternalProblem::pgOptions($ce, \%options);

Takes the course environment and the options for the C<WeBWorK::PG> constructor
(as C<WeBWorK::Utils::Rendering::constructPGOptions> gives them).  If the
C<sourceFilePath> option is the source file of an external problem and no
problem source is given in the C<r_source> option, then the module for the type
of the problem changes the options so that PG renders the problem.

This should be called in the subprocess that the problem is rendered in, since
the module may wait for the other system.

Returns true if the options were changed.

=cut

sub pgOptions ($ce, $options) {
	return 0 if ref $options->{r_source};
	my $type = externalSourceType($options->{sourceFilePath});
	return 0 unless $type;

	# The modules are only loaded when needed, since most uses of this module only need isExternalSource.
	eval "require $type->{module}" or die $@;    ## no critic (ProhibitStringyEval)
	return $type->{module}->can('pgOptions')->($ce, $options, $type->{prefix});
}

1;
