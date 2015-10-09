## This is a number of common subroutines needed when processing the Courses


package Utils::CourseUtils;
use base qw(Exporter);
#use Dancer ':syntax';
#use Dancer::Plugin::Database;
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use Utils::ProblemSets qw/getGlobalSet/;
our @EXPORT    = ();
our @EXPORT_OK = qw(getCourseSettings getAllSets getAllUsers);


# get the course settings

## get all of the user information to send to the client via a script tag in the output_JS subroutine below

sub getAllSets {
    my ($db,$ce) = @_; 

	my @setNames = $db->listGlobalSets;
  	my @sets = map { getGlobalSet($db,$ce,$_) } @setNames;
	return \@sets;
}

# get all users (except login proctors) for the course

sub getAllUsers {
    my ($db,$ce) = @_; 

    my @userIDs = $db->listUsers;
    my @userInfo = $db->getUsers(@userIDs);
    my $numGlobalSets = $db->countGlobalSets;
    
    my @allUsers = ();

    my %permissionsHash = reverse %{$ce->{userRoles}};
    foreach my $u (@userInfo)
    {
        my $PermissionLevel = $db->getPermissionLevel($u->{'user_id'});
        $u->{permission} = $PermissionLevel->{permission};

		my $studid= $u->{student_id};
		my $key = $db->getKey($u->{'user_id'});

		$u->{student_id} = "$studid";  # make sure that the student_id is returned as a string. 
        $u->{num_user_sets} = $db->listUserSets($studid) . "/" . $numGlobalSets;
		$u->{logged_in} = ($key and time <= $key->timestamp()+$ce->{sessionKeyTimeout}) ? JSON::true : JSON::false;
		

		# convert the user $u to a hash
        
        ## NOTE:  I think we can call convertObjectToHash here instead. 
		my $s = {};
		for my $key (keys %{$u}) {
			$s->{$key} = $u->{$key}
		}
        
        my $showOldAnswers = ($u->{showOldAnswers}  eq '') ? $ce->{pg}{options}{showOldAnswers}: $u->{showOldAnswers};
        $s->{showOldAnswers} = $showOldAnswers ? JSON::true : JSON::false;
        
        my $useMathView = ($u->{useMathView} eq '')? $ce->{pg}{options}{useMathView} : $u->{useMathView};
        $s->{useMathView} = $useMathView ? JSON::true : JSON::false;
        
        $s->{_id} = $s->{user_id};

        if(! ($s->{user_id} =~ /^set_id:/)){  # filter out login proctors. 
            push(@allUsers,$s);
        }
        
    }
    
    return \@allUsers;
}

# get the course settings

sub getCourseSettings {

    my $ce = shift; 

	my $ConfigValues = $ce->{ConfigValues};
	my @settings = ();

	# get the list of theme folders in the theme directory and remove . and ..
	my $themeDir = $ce->{webworkDirs}{themes};
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
				$setting->{value} = eval('$ce->' . $string);
				if ($hash->{var} eq 'defaultTheme'){
					$setting->{value} = $themes;	
				}
				$setting->{category} = $category;

				## turn a 0/1 boolean into a false/true one.
				if($setting->{type} eq 'boolean'){
					$setting->{value} = $setting->{value} ? JSON::true : JSON::false;
				}
                
				push(@settings,$setting);
			}
		}
	}

	return \@settings;
}

1;