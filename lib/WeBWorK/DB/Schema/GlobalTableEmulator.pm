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
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	my @recordIDs;
	
	if ($globalUserID) {
		my @userRecordIDs = $userSchema->list($globalUserID, @keyparts);
		foreach my $userRecordID (@userRecordIDs) {
			shift @$userRecordID; # take off the userID
			push @recordIDs, $userRecordID;
		}
	} else {
		warn "WARNING: using slow, slow consensus";
		my @userRecordIDs = $userSchema->list(undef, @keyparts);
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
	}
	return @recordIDs;
}

sub exists($@) {
	my ($self, @keyparts) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	my @setList;
	if ($globalUserID) {
		@setList = $userSchema->list($globalUserID, @keyparts);
	} else {
		@setList = $userSchema->list(undef, @keyparts);
	}
	
	return scalar @setList;
}

sub add($$) {
	my ($self, $Record) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
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
	
	if ($globalUserID) {
		$UserRecord->user_id($globalUserID);
	} else {
		$UserRecord->user_id(HIDDEN_LOGIN);
	}
	
	# add it
	return $userSchema->add($UserRecord);
}

sub get($@) {
	my ($self, @keyparts) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	if ($globalUserID) {
		my $UserRecord = $userSchema->get($globalUserID, @keyparts);
		return user2global($self->{record}, $UserRecord);
	} else {
		warn "WARNING: using slow, slow consensus";
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
}

sub put($$) {
	my ($self, $Record) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	my @keyparts = map { $Record->$_() } $Record->KEYFIELDS();
	my $result;
	
	if ($globalUserID) {
		my $NewDefaults = global2user($userSchema->{record}, $Record);
		$NewDefaults->user_id($globalUserID);
		
		my $OldDefaults = $self->get($globalUserID, @keyparts);
		
		# add new or store updated "global" record
		if ($userSchema->exists($globalUserID, @keyparts)) {
			$result = $userSchema->put($NewDefaults);
		} else {
			$result = $userSchema->add($NewDefaults);
		}
		
		my @userIDs = map { $_->[0] } $userSchema->list(undef, @keyparts);
		
		$self->distGlobalValues($OldDefaults, $Record, @userIDs);
	} else {
		warn "WARNING: using slow, slow consensus";
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
		my @userIDs = map { $_->[0] } $userSchema->list(undef, @keyparts);
		my @UserRecords = map { $userSchema->get($_, @keyparts) } @userIDs;
		my $ConsensusRecord = findDefaults($self->{record}, @UserRecords);
		
		$self->distGlobalValues($ConsensusRecord, $Record, @userIDs);
	}
	return $result;
}

sub delete($@) {
	my ($self, @keyparts) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	if ($globalUserID) {
		return $userSchema->delete($globalUserID, @keyparts);
	} else {
		return $userSchema->delete(HIDDEN_LOGIN, @keyparts);
	}
}

################################################################################
# function to distribute new global values to each user-specific record
################################################################################

sub distGlobalValues($$$@) {
	my ($self, $OldGlobalRecord, $NewGlobalRecord, @userIDs) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	
	my @keyparts = map { $NewGlobalRecord->$_() } $NewGlobalRecord->KEYFIELDS();
	
	# figure out which fields (if any) were changed
	my @changedFields;
	if (defined $OldGlobalRecord) {
		foreach my $field ($OldGlobalRecord->FIELDS()) {
			if ($OldGlobalRecord->$field() ne $NewGlobalRecord->$field()) {
				push @changedFields, $field;
			}
		}
	} else {
		@changedFields = $NewGlobalRecord->FIELDS();
	}
	
	# if no fields were changed, we're done
	return unless @changedFields;
	
	# impose the new values for each user
	foreach my $userID (@userIDs) {
		my $UserRecord = $userSchema->get($userID, @keyparts);
		my $changed;
		foreach my $field (@changedFields) {
			if (defined $OldGlobalRecord) {
				if ($UserRecord->$field() eq $OldGlobalRecord->$field()) {
					$changed = 1;
					$UserRecord->$field($NewGlobalRecord->$field());
				}
			} else {
				$UserRecord->$field($NewGlobalRecord->$field());
			}
		}
		if ($changed) {
			$userSchema->put($UserRecord);
		}
	}
}

1;
