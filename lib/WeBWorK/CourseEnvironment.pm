package WeBWorK::CourseEnvironment;

use Safe;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $webworkRoot = shift;
	my $courseName = shift;
	
	# determine location of globalEnvironmentFile
	my $globalEnvironmentFile = "$webworkRoot/conf/global.conf";

	# read and evaluate the global environment file
	my $globalFileContents = readFile($globalEnvironmentFile);
	my %globalConf = Safe->new->reval($globalFileContents);

	# if that evaluation failed, we can't really go on -- we need a global environment!
	$@ and die "Could not evaluate global environment file $globalEnvironmentFile: $@";
	
	# determine location of courseEnvironmentFile
	my $courseEnvironmentFile = $globalConf{coursesDirectory}
		. "/$courseName/"
		. $globalConf{courseEnvironmentFilename};

	# read and evaluate the course environment file
	my $courseFileContents = readFile($courseEnvironmentFile);
	my %courseConf = Safe->new->reval($courseFileContents);

	# if that evaluation failed, we can't really go on -- we need a course environment!
	$@ and die "Could not evaluate course environment file $courseEnvironmentFile: $@";

	my $self = { %globalConf, %courseConf };
	
	# This comes in as a parameter to new(), not from any file.
	$self->{courseName} = $courseName;
	bless $self, $class;
	return $self;
}

sub get {
	my $self = shift;
	my $var = shift;
	return $self->{$var};
}

# ----- utils -----

sub readFile {
	my $fileName = shift;
	open INPUTFILE, "<", $fileName or die "Couldn't open environment file $fileName: $!";
	my $result = join "\n", <INPUTFILE>;
	close INPUTFILE;
	return $result;
}

1;
