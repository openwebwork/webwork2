## This is a number of common subroutines needed when processing the Courses


package Utils::CourseUtils;
use base qw(Exporter);
use Dancer;
use Dancer::Plugin::Database;
use Data::Dumper;
our @EXPORT    = ();
our @EXPORT_OK = qw(getCourseSettings);

# get the course settings

sub getCourseSettings {

	my $ConfigValues = vars->{ce}->{ConfigValues};

	# get the list of theme folders in the theme directory and remove . and ..
	my $themeDir = vars->{ce}->{webworkDirs}{themes};
	opendir(my $dh, $themeDir) || die "can't opendir $themeDir: $!";
	my $themes =[grep {!/^\.{1,2}$/} sort readdir($dh)];
	

	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			if (ref($hash) eq "HASH") {
				my $string = $hash->{var};
				if ($string =~ m/^\w+$/) {
					$string =~ s/^(\w+)$/\{$1\}/;
				} else {
					$string =~ s/^(\w+)/\{$1\}->/;
				}
				$hash->{value} = eval('vars->{ce}->' . $string);
				
				if ($hash->{var} eq 'defaultTheme'){
					$hash->{values} = $themes;	
				}
			}
		}
	}


	my $tz = DateTime::TimeZone->new( name => vars->{ce}->{siteDefaults}->{timezone}); 
	my $dt = DateTime->now();

	my @tzabbr = ("tz_abbr", $tz->short_name_for_datetime( $dt ));

	push(@$ConfigValues, \@tzabbr);

	return $ConfigValues;
}

1;