################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Schema::GlobalTableEmulator;

=head1 NAME

WeBWorK::DB::Schema::GlobalTableEmulator - emulate the global 'set' and
'problem' tables using access to the 'set_user' and 'problem_user' tables.

=cut

use strict;
use warnings;
use Data::Dumper;
use WeBWorK::DB::Utils qw(global2user user2global findDefaults);

use constant TABLES => qw(set problem);
use constant STYLE  => "dummy";

use constant HIDDEN_LOGIN => "!@#$%^&*()";

################################################################################
# static functions
################################################################################

sub tables() {
	return TABLES;
}

sub style() {
	return STYLE;
}

################################################################################
# constructor
################################################################################

sub new($$$) {
	my ($proto, $db, $driver, $table, $record, $params) = @_;
	my $class = ref($proto) || $proto;
	die "$table: unsupported table"
		unless grep { $_ eq $table } $proto->tables();
	die $driver->style(), ": style mismatch"
		unless $driver->style() eq $proto->style();
	my $self = {
		db     => $db,
		driver => $driver,
		table  => $table,
		record => $record,
		params => $params,
	};
	bless $self, $class;
	return $self;
}

################################################################################
# table access functions
################################################################################

sub list($@) {
	my ($self, @keyparts) = @_;
	# keyparts is (setID) or (setID, problemID), depending on the table.
	# get list of user-specific record IDs with keyparts (undef, @keyparts)
	# (this will match any user id, including an empty user id.)
	# remove duplicates (ignoring userID)
	# return that list, in the form [$setID] or [$setID, $problemID],
	# depending on the table.
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	
	my @userRecordIDs = $userSchema->list(undef, @keyparts);
	
	my @recordIDs;
	if ($self->{table} eq "set") {
		my %setIDs;
		foreach my $userRecordID (@userRecordIDs) {
			my ($userID, $setID) = @$userRecordID;
			$setIDs{$setID}++;
		}
		foreach my $setID (keys %setIDs) {
			push @recordIDs, [$setID];
		}
		# @recordIDs is now ALL SETS MATCHED
	} elsif ($self->{table} eq "problem") {
		my %problemIDs;
		foreach my $userRecordID (@userRecordIDs) {
			my ($userID, $setID, $problemID) = @$userRecordID;
			$problemIDs{$setID}{$problemID}++;
		}
		foreach my $setID (keys %problemIDs) {
			foreach my $problemID (keys %{$problemIDs{$setID}}) {
				push @recordIDs, [$setID, $problemID];
			}
		}
		# @recordIDs is now ALL PROBLEMS MATCHED
	}
	return @recordIDs;
}

sub exists($@) {
	my ($self, @keyparts) = @_;
	# if a user-specific record exists with keyparts (undef, @keyparts)
	# (this will match any user id, including an empty user id.)
		# return true
	# else
		# return false
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	
	my @setList = $userSchema->list(undef, @keyparts);
	warn "setList=@setList\n";
	
	return scalar @setList;
}

sub add($$) {
	my ($self, $Record) = @_;
	# die if $self->exists(@keyparts)
	# create a user-specific record with user_id=HIDDEN_LOGIN
	# return true
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	
	# make sure record doesn't already exist
	my $setID = $Record->set_id();
	if ($self->{table} eq "set") {
		die "($setID): Set exists.\n"
			if $self->exists($setID);
	} elsif ($self->{table} eq "problem") {
		my $problemID = $Record->problem_id();
		die "($setID, $problemID): Problem exists.\n"
			if $self->exists($setID, $problemID);
	}
	
	my $UserRecord = global2user($userSchema->{record}, $Record);
	$UserRecord->user_id(HIDDEN_LOGIN);
	return $userSchema->add($UserRecord);
}

sub get($@) {
	my ($self, @keyparts) = @_;
	# get user-specific records for each user
	# ask WeBWorK::DB::Utils::findDefaults for a consensus
	# if a user-specific record exists with keyparts (HIDDEN_LOGIN, @keyparts)
		# update it with the data from the consensus
	# return the consensus
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	
	# get a consensus of all the user records
	my @userRecordIDs = $userSchema->list(undef, @keyparts);
	my @UserRecords = map { $userSchema->get($_->[0], @keyparts) } @userRecordIDs;
	my $ConsensusRecord = findDefaults($self->{record}, @UserRecords);
		# ConsensusRecord is a GLOBAL record
	
	# get the "hidden" user record (or create one if doesn't exist) and
	# update it with the consensus defaults
	my $HiddenRecord = $userSchema->get(HIDDEN_LOGIN, @keyparts);
	unless (defined $HiddenRecord) {
		$HiddenRecord = $userSchema->{record}->new();
	}
	foreach my $field ($ConsensusRecord->FIELDS()) {
		$HiddenRecord->$field($ConsensusRecord->$field());
	}
	
	# return the consensus record
	return $ConsensusRecord; # which is a GLOBAL record... yay!
}

sub put($$) {
	my ($self, $Record) = @_;
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my @keyparts = map { $Record->$_() } $Record->KEYFIELDS();
	my $result;
	
	# make a user-specific record with user_id=HIDDEN_LOGIN out of $Record
	# i'm calling this a "hidden" record
	my $HiddenRecord = $userSchema->{record}->new();
	foreach my $field ($Record->FIELDS()) {
		$HiddenRecord->$field($Record->$field());
	}
	$HiddenRecord->user_id(HIDDEN_LOGIN);
	
	# add new or store updated hidden record
	if ($userSchema->exists(HIDDEN_LOGIN, @keyparts)) {
		$result = $userSchema->put($HiddenRecord);
	} else {
		$result = $userSchema->add($HiddenRecord);
	}
	
	# get a consensus of all the user records
	my @userRecordIDs = $userSchema->list(undef, @keyparts);
	my @UserRecords = map { $userSchema->get($_->[0], @keyparts) } @userRecordIDs;
	my $ConsensusRecord = findDefaults($self->{record}, @UserRecords);
	
	# distribute the new values to each "real" user record
	foreach my $UserRecord (@UserRecords) {
		my $changed = 0;
		foreach my $field ($ConsensusRecord->FIELDS()) {
			if ($UserRecord->$field() eq $ConsensusRecord->$field()) {
				$changed = 1;
				$UserRecord->$field($Record->$field());
			}
			if ($changed) {
				$result &= $userSchema->put($UserRecord);
			}
		}
	}
	
	return $result;
}

sub delete($@) {
	my ($self, @keyparts) = @_;
	# if a user-specific record exists with keyparts (HIDDEN_LOGIN, @keyparts)
		# delete it
	# return whether it existed
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	
	return $userSchema->delete(HIDDEN_LOGIN, @keyparts);
}

1;
