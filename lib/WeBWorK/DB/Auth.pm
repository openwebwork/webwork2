package WeBWorK::DB::Auth;

# there should be a `use' line for each database type
use WeBWorK::DB::GDBM;

# params: class, course environment
sub new($$) {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $courseEnv = shift;
	my $dbModule = fullyQualifiedPackageName($courseEnv->{auth_db_type});
	my $self = {
		password_file => $courseEnv->{something},
		permissions_file => $courseEnv->{something},
		keys_file => $courseEnv->{something},
	};
	$self->{password_db} = $self->{dbModule}->new($self->{password_file});
	$self->{permissions_db} = $self->{dbModule}->new($self->{permissions_file});
	$self->{keys_db} = $self->{dbModule}->new($self->{keys_file});
	bless $self, $class;
	return $self;
}

sub fullyQualifiedPackageName($) {
	my $n = shift;
	my $package = "__PACKAGE__";
	$package =~ s/([^:]*)$/$n/;
	return $package;
}

sub connect($$$) {
	my $self = shift;
	my $db = shift;
	my $mode = shift;
	return if defined $self->{$db."_db"};
	$self->{$db."_db"} = $self->{dbModule}->new($db."_file", $mode);
	$self->{$db."_db"}->connect();
}

sub disconnect($$) {
	my $self = shift;
	my $db = shift;
	return unless defined $self->{$db."_db"};
	$self->{$db."_db"}->disconnect();
}

# -----

sub getPassword($$) {
	my $self = shift;
	my $user = shift;
	$self->{password_db}->connect("ro");
	my $result = $self->{password_db}->hashRef()->{$user};
	$self->{password_db}->disconnect();
	return $result;
}

sub setPassword($$$) {
	my $self = shift;
	my $user = shift;
	my $password = shift;
	$password = crypt $password, join "", ('.','/','0'..'9','A'..'Z','a'..'z')[rand 64, rand 64]
	$self->{password_db}->connect("rw");
	$self->{password_db}->hashRef()->{$user} = $password;
	$self->{password_db}->disconnect();
}

sub verifyPassword($$$) {
	my $self = shift;
	my $user = shift;
	my $password = shift;
	$self->{password_db}->connect("ro");
	my $result = $self->{password_db}->hashRef()->{$user} eq $password;
	$self->{password_db}->disconnect();
	return $result;
}

sub deletePassword($$) {
	my $self = shift;
	my $user = shift;
	$self->{password_db}->connect("rw");
	delete $self->{password_db}->hashRef()->{$user};
	$self->{password_db}->disconnect();
}

# -----

sub getKey($$) {
	my $self = shift;
	my $user = shift;
	$self->{keys_db}->connect("ro");
	my $result = $self->{keys_db}->hashRef()->{$user};
	$self->{keys_db}->disconnect();
	my ($key, $timestamp) = split /\s+/, $result;
	return $key, $timestamp;
}

sub setKey($$$$) {
	my $self = shift;
	my $user = shift;
	my $key = shift;
	my $timestamp = shift;
	my $key_string = "$key $timestamp";
	$self->{keys_db}->connect("rw");
	$self->{keys_db}->hashRef()->{$user} = $key_string;
	$self->{keys_db}->disconnect();
}

sub verifyKey($$$) {
	my $self = shift;
	my $user = shift;
	my $key = shift;
	$self->{keys_db}->connect("ro");
	my $result = $self->{keys_db}->hashRef()->{$user};
	$self->{keys_db}->disconnect();
	my ($real_key, $timestamp) = split /\s+/, $result;
	return $key eq $real_key;
	# DANGER DANGER! this function no longer updates timestamp!
}

sub deleteKey($$) {
	my $self = shift;
	my $user = shift;
	$self->{keys_db}->connect("rw");
	delete $self->{keys_db}->hashRef()->{$user};
	$self->{keys_db}->disconnect();
}

# -----

sub getPermissions($$) {
	my $self = shift;
	my $user = shift;
	$self->{permissions_db}->connect("ro");
	my $result = $self->{permissions_db}->hashRef()->{$user};
	$self->{permissions_db}->disconnect();
	return $result;
}

sub setPermissions($$$) {
	my $self = shift;
	my $user = shift;
	my $permissions = shift;
	$self->{permissions_db}->connect("rw");
	$self->{permissions_db}->hashRef()->{$user} = $key;
	$self->{permissions_db}->disconnect();
}

sub deletePermissions($$) {
	my $self = shift;
	my $user = shift;
	$self->{permissions_db}->connect("rw");
	delete $self->{permissions_db}->hashRef()->{$user};
	$self->{permissions_db}->disconnect();
}

# ----- ghetto for stupid functions -----

sub change_user_in_password_file($$$) {
	my $self = shift;
	my $user = shift;
	my $new_user = shift;
	$self->{password_db}->connect("rw");
	my $pwhash = $self->{password_db}->hashRef(); # make things easier
	if (exists $pwhash->{user}) {
		$pwhash->{new_user} = $pwhash->{user};
		delete $pwhash->{user};
	}
	$self->{password_db}->disconnect();
}

sub change_user_in_permissions_file($$$) {
	my $self = shift;
	my $user = shift;
	my $new_user = shift;
	$self->{permissions_db}->connect("rw");
	my $permhash = $self->{permissions_db}->hashRef(); # make things easier
	if (exists $permhash->{user}) {
		$permhash->{new_user} = $permhash->{user};
		delete $permhash->{user};
	}
	$self->disconnect{permissions_db}->();
}

=pod
sub create_db {
    my ($fileName, $permissions) =@_;
    my %pwhash;
    my $pw_obj;
    &Global::tie_hash('PW_FH',\$pw_obj,\%pwhash, $fileName,'W',$permissions);
    &Global::untie_hash('PW_FH',\$pw_obj,\%pwhash, $fileName);

    chmod($permissions, $fileName) or
                             wwerror($0, "Can't do chmod($permissions, $fileName)");
    chown(-1,$Global::numericalGroupID,$fileName)  or
                             wwerror($0, "Can't do chown(-1,$Global::numericalGroupID,$fileName)");

}
=cut
