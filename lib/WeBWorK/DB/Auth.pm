################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::DB::Auth;

# there should be a `use' line for each database type
use WeBWorK::DB::GDBM;

# new($invocant, $courseEnv)
# $invocant	implicitly set by caller
# $courseEnv	an instance of CourseEnvironment
sub new($$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $courseEnv = shift;
	my $dbModule = fullyQualifiedPackageName($courseEnv->{dbInfo}->{auth_type});
	my $self = {
		password_file    => $courseEnv->{dbInfo}->{auth_passwd_file},
		permissions_file => $courseEnv->{dbInfo}->{auth_perm_file},
		keys_file        => $courseEnv->{dbInfo}->{auth_keys_file},
		key_timeout      => $courseEnv->{sessionKeyTimeout},
	};
	$self->{password_db}    = $dbModule->new($self->{password_file});
	$self->{permissions_db} = $dbModule->new($self->{permissions_file});
	$self->{keys_db}        = $dbModule->new($self->{keys_file});
	bless $self, $class;
	return $self;
}

sub fullyQualifiedPackageName($) {
	my $n = shift;
	my $package = __PACKAGE__;
	$package =~ s/([^:]*)$/$n/;
	return $package;
}

# -----

sub getUsers($) {
	my $self = shift;
	my @password_users, @permissions_users, @keys_users;
	if ($self->{password_db}->connect("ro")) {
		@password_users = keys %{$self->{password_db}->hashRef};
		$self->{password_db}->disconnect;
	}
	if ($self->{permissions_db}->connect("ro")) {
		@permissions_users = keys %{$self->{permissions_db}->hashRef};
		$self->{permissions_db}->disconnect;
	}
	if ($self->{keys_db}->connect("ro")) {
		@keys_users = keys %{$self->{keys_db}->hashRef};
		$self->{keys_db}->disconnect;
	}
	my %all_users;
	foreach (@password_users, @permissions_users, @keys_users) {
		$all_users{$_}++;
	}
	return keys %all_users;
}

# -----

sub getPassword($$) {
	my $self = shift;
	my $user = shift;
	return unless $self->{password_db}->connect("ro");
	my $result = $self->{password_db}->hashRef->{$user};
	$self->{password_db}->disconnect;
	return $result;
}

sub setPassword($$$) {
	my $self = shift;
	my $user = shift;
	my $password = crypt shift, join "", ('.','/','0'..'9','A'..'Z','a'..'z')[rand 64, rand 64];
	$self->{password_db}->connect("rw");
	$self->{password_db}->hashRef->{$user} = $password;
	$self->{password_db}->disconnect;
}

sub verifyPassword($$$) {
	my $self = shift;
	my $user = shift;
	my $password = shift;
	my $real_password = $self->getPassword($user);
	return unless defined $real_password;
	$password = crypt $password, $real_password;
	return $password eq $real_password;
}

sub deletePassword($$) {
	my $self = shift;
	my $user = shift;
	$self->{password_db}->connect("rw");
	delete $self->{password_db}->hashRef->{$user};
	$self->{password_db}->disconnect;
}

# -----

sub getKey($$) {
	my $self = shift;
	my $user = shift;
	return unless $self->{keys_db}->connect("ro");
	my $result = $self->{keys_db}->hashRef->{$user};
	$self->{keys_db}->disconnect;
	my ($key, $timestamp) = defined $result ? split /\s+/, $result : (undef, undef);
	if (time <= $timestamp+$self->{key_timeout}) {
		return $key;
	} else {
		$self->deleteKey($user);
		return 0;
	}
}

sub setKey($$$) {
	my $self = shift;
	my $user = shift;
	my $key = shift;
	$self->{keys_db}->connect("rw");
	$self->{keys_db}->hashRef->{$user} = "$key " . time;
	$self->{keys_db}->disconnect;
}

sub verifyKey($$$) {
	my $self = shift;
	my $user = shift;
	my $key = shift;
	my $real_key = $self->getKey($user);
	return unless defined $real_key;
	if ($key eq $real_key) {
		# update timestamp
		$self->setKey($user, $real_key);
		return 1;
	} else {
		return 0;
	}
}

sub deleteKey($$) {
	my $self = shift;
	my $user = shift;
	$self->{keys_db}->connect("rw");
	delete $self->{keys_db}->hashRef->{$user};
	$self->{keys_db}->disconnect;
}

# -----

sub getPermissions($$) {
	my $self = shift;
	my $user = shift;
	return unless $self->{permissions_db}->connect("ro");
	my $result = $self->{permissions_db}->hashRef->{$user};
	$self->{permissions_db}->disconnect;
	return $result;
}

sub setPermissions($$$) {
	my $self = shift;
	my $user = shift;
	my $permissions = shift;
	$self->{permissions_db}->connect("rw");
	$self->{permissions_db}->hashRef->{$user} = $permissions;
	$self->{permissions_db}->disconnect;
}

sub deletePermissions($$) {
	my $self = shift;
	my $user = shift;
	$self->{permissions_db}->connect("rw");
	delete $self->{permissions_db}->hashRef->{$user};
	$self->{permissions_db}->disconnect;
}

# ----- ghetto for stupid functions -----

sub change_user_in_password_file($$$) {
	my $self = shift;
	my $user = shift;
	my $new_user = shift;
	$self->{password_db}->connect("rw");
	my $pwhash = $self->{password_db}->hashRef; # make things easier
	if (exists $pwhash->{$user}) {
		$pwhash->{$new_user} = $pwhash->{$user};
		delete $pwhash->{$user};
	}
	$self->{password_db}->disconnect;
}

sub change_user_in_permissions_file($$$) {
	my $self = shift;
	my $user = shift;
	my $new_user = shift;
	$self->{permissions_db}->connect("rw");
	my $permhash = $self->{permissions_db}->hashRef; # make things easier
	if (exists $permhash->{$user}) {
		$permhash->{$new_user} = $permhash->{$user};
		delete $permhash->{$user};
	}
	$self->{permissions_db}->disconnect;
}

1;
