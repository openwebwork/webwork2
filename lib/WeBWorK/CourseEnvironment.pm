package WeBWorK::CourseEnvironment;

use strict;
use warnings;
use Safe;

# new($invocant, $webworkRoot, $courseName)
# $invocant	implicitly set by caller
# $webworkRoot	directory that contains the WeBWorK distribution
# $courseName	name of the course being used
sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $webworkRoot = shift;
	my $courseName = shift;
	my $safe = Safe->new;
	
	# set up some defaults that the environment files will need
	$safe->reval("\$webworkRoot = '$webworkRoot'");
	$safe->reval("\$courseName = '$courseName'");
	
	# determine location of globalEnvironmentFile
	my $globalEnvironmentFile = "$webworkRoot/conf/global.conf";
	
	# read and evaluate the global environment file
	my $globalFileContents = readFile($globalEnvironmentFile);
	$safe->reval($globalFileContents);
	
	# if that evaluation failed, we can't really go on...
	# we need a global environment!
	$@ and die "Could not evaluate global environment file $globalEnvironmentFile: $@";
	
	# determine location of courseEnvironmentFile
	# pull it out of $safe's symbol table ad hoc
	# (we don't want to do the hash conversion yet)
	no strict 'refs';
	my $courseEnvironmentFile = ${*{${$safe->root."::"}{courseFiles}}}{environment};
	use strict 'refs';
	
	# read and evaluate the course environment file
	# if readFile failed, we don't bother trying to reval
	my $courseFileContents = eval { readFile($courseEnvironmentFile) }; # catch exceptions
	$@ or $safe->reval($courseFileContents);
	
	# get the safe compartment's namespace as a hash
	no strict 'refs';
	my %symbolHash = %{$safe->root."::"};
	use strict 'refs';
	
	# convert the symbol hash into a hash of regular variables.
	my $self = {};
	foreach my $name (keys %symbolHash) {
		# weed out internal symbols
		next if $name =~ /^(INC|_|__ANON__|main::)$/;
		# pull scalar, array, and hash values for this symbol
		my $scalar = ${*{$symbolHash{$name}}};
		my @array = @{*{$symbolHash{$name}}};
		my %hash = %{*{$symbolHash{$name}}};
		# for multiple variables sharing a symbol, scalar takes precedence
		# over array, which takes precedence over hash.
		if (defined $scalar) {
			$self->{$name} = $scalar;
		} elsif (@array) {
			$self->{$name} = \@array;
		} elsif (%hash) {
			$self->{$name} = \%hash;
		}
	}
	
	bless $self, $class;
	return $self;
}

# ----- utils -----

sub readFile {
	my $fileName = shift;
	open INPUTFILE, "<", $fileName
		or die "Couldn't open environment file $fileName: $!";
	my $result = join "\n", <INPUTFILE>;
	close INPUTFILE;
	return $result;
}

1;
