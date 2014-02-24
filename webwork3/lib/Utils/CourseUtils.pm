## This is a number of common subroutines needed when processing the Courses


package Utils::CourseUtils;
use base qw(Exporter);
use Dancer;
#use Dancer::Plugin::Database;
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use Data::Dumper;
our @EXPORT    = ();
our @EXPORT_OK = qw(getCourseSettings getAllSets getAllUsers);

# get the course settings

## get all of the user information to send to the client via a script tag in the output_JS subroutine below

sub getAllSets {

	my @found_sets = vars->{db}->listGlobalSets;
  
  	my @all_sets = vars->{db}->getGlobalSets(@found_sets);

  	my @sets = ();
  
  
	foreach my $set (@all_sets){
		my @users = vars->{db}->listSetUsers($set->{set_id});
		$set->{assigned_users} = \@users;

		my @problems = vars->{db}->getAllGlobalProblems($set->{set_id});
		$set->{problems} = convertArrayOfObjectsToHash(\@problems);

		push(@sets,convertObjectToHash($set));
	}
	return \@sets;
}

# get all users for the course

sub getAllUsers {

    my @tempArray = vars->{db}->listUsers;
    my @userInfo = vars->{db}->getUsers(@tempArray);
    my $numGlobalSets = vars->{db}->countGlobalSets;
    
    my @allUsers = ();

    my %permissionsHash = reverse %{vars->{ce}->{userRoles}};
    foreach my $u (@userInfo)
    {
        my $PermissionLevel = vars->{db}->getPermissionLevel($u->{'user_id'});
        $u->{'permission'} = $PermissionLevel->{'permission'};

		my $studid= $u->{'student_id'};
		$u->{'student_id'} = "$studid";  # make sure that the student_id is returned as a string. 
        $u->{'num_user_sets'} = vars->{db}->listUserSets($studid) . "/" . $numGlobalSets;
	
		my $Key = vars->{db}->getKey($u->{'user_id'});
		$u->{'login_status'} =  ($Key and time <= $Key->timestamp()+vars->{ce}->{sessionKeyTimeout}); # cribbed from check_session
		

		# convert the user $u to a hash
		my $s = {};
		for my $key (keys %{$u}) {
			$s->{$key} = $u->{$key}
		}

		push(@allUsers,$s);
    }

    return \@allUsers;
}

# get the course settings

sub getCourseSettings {


	my $ConfigValues = vars->{ce}->{ConfigValues};
	my @settings = ();

	# get the list of theme folders in the theme directory and remove . and ..
	my $themeDir = vars->{ce}->{webworkDirs}{themes};
	opendir(my $dh, $themeDir) || die "can't opendir $themeDir: $!";
	my $themes =[grep {!/^\.{1,2}$/} sort readdir($dh)];
	

	# change the configuration into a form ready to send to the browser. 
	foreach my $oneConfig (@$ConfigValues) {
		my $category = @$oneConfig[0];
		foreach my $hash (@$oneConfig) {
			if (ref($hash) eq "HASH") {
				my $setting ={%$hash};
				my $string = $hash->{var};
				if ($string =~ m/^\w+$/) {
					$string =~ s/^(\w+)$/\{$1\}/;
				} else {
					$string =~ s/^(\w+)/\{$1\}->/;
				}
				$setting->{value} = eval('vars->{ce}->' . $string);
				if ($hash->{var} eq 'defaultTheme'){
					$setting->{value} = $themes;	
				}
				$setting->{category} = $category;
				push(@settings,$setting);
			}
		}
	}

	my $tz = DateTime::TimeZone->new( name => vars->{ce}->{siteDefaults}->{timezone}); 
	my $dt = DateTime->now();
	my $timeZone = {var=>"timezone",value=>$tz->short_name_for_datetime( $dt ), category=>"timezone"};

	push(@settings,$timeZone);

	return \@settings;
}

1;