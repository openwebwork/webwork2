################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::DB::Classlist;

use strict;
use warnings;
use WeBWorK::DB::User;

# there should be a `use' line for each database type
use WeBWorK::DB::GDBM;

# new($invocant, $courseEnv)
# $invocant	implicitly set by caller
# $courseEnv	an instance of CourseEnvironment
sub new($$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $courseEnv = shift;
	my $dbModule = fullyQualifiedPackageName($courseEnv->{dbInfo}->{cldb_type});
	my $self = {
		classlist_file => $courseEnv->{dbInfo}->{cldb_file},
	};
	$self->{classlist_db} = $dbModule->new($self->{classlist_file});
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
	return unless $self->{classlist_db}->connect("ro");
	my @result = keys %{$self->{classlist_db}->hashRef};
	$self->{classlist_db}->disconnect;
	@result = grep !/^>>/, @result; # remove keys which start with ">>"
	return @result;
}

# -----

sub getUser($$) {
	my $self = shift;
	my $userID = shift;
	if ($userID =~ /^>>/) {
		warn "Attempt to use the special key $userID as a user!";
		return;
	}
	return unless $self->{classlist_db}->connect("ro");
	my $result = $self->{classlist_db}->hashRef->{$userID};
	$self->{classlist_db}->disconnect;
	return unless defined $result;
	return hash2user($userID, decode($result));
}

sub setUser($$) {
	my $self = shift;
	my $user = shift;
	if ($user->id =~ /^>>/) {
		warn "Attempt to use the special key \"", $user->id, "\" as a user ID!";
		return;
	}
	die "Can't add/modify user ", $user->id, ": classlist database locked" if $self->locked;
	$self->{classlist_db}->connect("rw");
	$self->{classlist_db}->hashRef->{$user->id} = encode(user2hash($user));
	$self->{classlist_db}->disconnect;
}

sub deleteUser($$) {
	my $self = shift;
	my $userID = shift;
	if ($userID =~ /^>>/) {
		warn "Attempt to use the special key \"$userID\" as a user ID!";
		return;
	}
	die "Can't delete user $userID: classlist database locked" if $self->locked;
	return unless $self->{classlist_db}->connect("rw");
	delete $self->{classlist_db}->hashRef->{$userID};
	$self->{classlist_db}->disconnect;
}

# -----

sub lock($) {
	my $self = shift;
	return unless $self->{classlist_db}->connect("rw");
	$self->{classlist_db}->hashRef->{">>lock_status"} = "locked";
	$self->{classlist_db}->disconnect;
}

sub unlock($) {
	my $self = shift;
	return unless $self->{classlist_db}->connect("rw");
	# the old code sets this to "unlocked", but I'm going to remove it.
	delete $self->{classlist_db}->hashRef->{">>lock_status"};
	$self->{classlist_db}->disconnect;
}

sub locked($) {
	my $self = shift;
	return unless $self->{classlist_db}->connect("ro");
	my $result = $self->{classlist_db}->hashRef->{">>lock_status"};
	$self->{classlist_db}->disconnect;
	return defined $result and $result eq "locked";
}

# -----

sub decode($) {
	my $string = shift;
	my %hash = $string =~ /(.*?)(?<!\\)=(.*?)(?:(?<!\\)&|$)/g;
	$hash{$_} =~ s/\\(.)/$1/ foreach (keys %hash); # unescape anything
	return %hash;
}

sub encode(@) {
	my %hash = @_;
	my $string;
	foreach (keys %hash) {
		$hash{$_} =~ s/(=|&)/\\$1/; # escape & and =
		$string .= "$_=$hash{$_}&";
	}
	chop $string; # remove final '&' from string for old code :p
	return $string;
}

# -----

# the classlist_DBglue.pl library from the WeBWorK 1.x series uses four
# character hash keys -- we want to use more descriptive field names, so
# we do some conversion here.
#
# This is a little dangerous, since we hardcode User's schema, but I don't
# think it'll be a problem -- hopefully future backends will use the new
# field names and the old ones will wither away.

sub hash2user($%) {
	my $userID = shift;
	my %hash = @_;
	my $user = WeBWorK::DB::User->new(id => $userID);
	$user->first_name    ( $hash{stfn} ) if defined $hash{stfn};
	$user->last_name     ( $hash{stln} ) if defined $hash{stln};
	$user->email_address ( $hash{stea} ) if defined $hash{stea};
	$user->student_id    ( $hash{stid} ) if defined $hash{stid};
	$user->status        ( $hash{stst} ) if defined $hash{stst};
	$user->section       ( $hash{clsn} ) if defined $hash{clsn};
	$user->recitation    ( $hash{clrc} ) if defined $hash{clrc};
	$user->comment       ( $hash{comt} ) if defined $hash{comt};
	return $user;
}

sub user2hash($) {
	my $user = shift;
	my %hash;
	$hash{stfn} = $user->first_name    if defined $user->first_name;
	$hash{stln} = $user->last_name     if defined $user->last_name;
	$hash{stea} = $user->email_address if defined $user->email_address;
	$hash{stid} = $user->student_id    if defined $user->student_id;
	$hash{stst} = $user->status        if defined $user->status;
	$hash{clsn} = $user->section       if defined $user->section;
	$hash{clrc} = $user->recitation    if defined $user->recitation;
	$hash{comt} = $user->comment       if defined $user->comment;
	return %hash;
}

1;
