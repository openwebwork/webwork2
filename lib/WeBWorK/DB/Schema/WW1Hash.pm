################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/DB/Schema/WW1Hash.pm,v 1.24 2004/03/25 00:28:04 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::DB::Schema::WW1Hash;
use base qw(WeBWorK::DB::Schema);

=head1 NAME

WeBWorK::DB::Schema::WW1Hash - support access to the set_user and problem_user
tables with a WWDBv1 hash-style backend.

=cut

use strict;
use warnings;
use Carp;
use WeBWorK::DB::Utils qw(hash2string string2hash);
use WeBWorK::Timing;

use constant TABLES => qw(set_user problem_user);
use constant STYLE  => "hash";

use constant LOGIN_PREFIX => "login<>";
use constant SET_PREFIX   => "set<>";
use constant MAX_PSVN_GENERATION_ATTEMPTS => 200;

################################################################################
# table access functions
################################################################################

=head1 ADDITIONAL METHODS

=over

=cut

sub count {
	my ($self, @keyparts) = @_;
	my ($matchUserID, $matchSetID) = @keyparts[0 .. 1];
	
	# connect
	return unless $self->{driver}->connect("ro");
	
	# get a list of PSVNs that match the userID and setID given
	my @matchingPSVNs;
	if (defined $matchUserID and not defined $matchSetID) {
		@matchingPSVNs = $self->getPSVNsForUser($matchUserID);
	} elsif (defined $matchSetID and not defined $matchUserID) {
		@matchingPSVNs = $self->getPSVNsForSet($matchSetID);
	} elsif (defined $matchUserID and defined $matchSetID) {
		@matchingPSVNs = $self->getPSVN($matchUserID, $matchSetID);
	} else {
		# we need all PSVNs, so we have to do this ourselves.
		@matchingPSVNs =
			grep { m/^\d+$/ }
				keys %{ $self->{driver}->hash() };
	}
	
	my $result = 0;
	if ($self->{table} eq "set_user") {
		$result = @matchingPSVNs;
	} elsif ($self->{table} eq "problem_user") {
		my $matchProblemID = $keyparts[2];
		foreach (@matchingPSVNs) {
			my $string = $self->fetchString($_);
			next unless defined $string;
			my %hash = string2hash($string);
			my $userID = $hash{stlg};
			my $setID = $hash{stnm};
			if (defined $matchProblemID) {
				# we only want one 
				if (exists $hash{"pfn$matchProblemID"}) {
					$result++;
				}
			} else {
				my (undef, undef, @problemIDs) = $self->hash2IDs(%hash);
				$result += @problemIDs;
			}
		}
	}
	
	# disconnect
	$self->{driver}->disconnect();
	
	return $result;
}

sub list {
	my ($self, @keyparts) = @_;
	my ($matchUserID, $matchSetID) = @keyparts[0 .. 1];
	
	# connect
	return unless $self->{driver}->connect("ro");
	
	# get a list of PSVNs that match the userID and setID given
	my @matchingPSVNs;
	if (defined $matchUserID and not defined $matchSetID) {
		@matchingPSVNs = $self->getPSVNsForUser($matchUserID);
	} elsif (defined $matchSetID and not defined $matchUserID) {
		@matchingPSVNs = $self->getPSVNsForSet($matchSetID);
	} elsif (defined $matchUserID and defined $matchSetID) {
		@matchingPSVNs = $self->getPSVN($matchUserID, $matchSetID);
	} else {
		# we need all PSVNs, so we have to do this ourselves.
		@matchingPSVNs =
			grep { m/^\d+$/ }
				keys %{ $self->{driver}->hash() };
	}
	
	# retrieve the strings associated with those PSVNs and retrieve the
	# desired parts of that record
	my @result;
	if ($self->{table} eq "set_user") {
		foreach (@matchingPSVNs) {
			my $string = $self->fetchString($_);
			next unless defined $string;
			my %hash = string2hash($string);
			push @result, [$hash{stlg}, $hash{stnm}];
		}
	} elsif ($self->{table} eq "problem_user") {
		my $matchProblemID = $keyparts[2];
		foreach (@matchingPSVNs) {
			my $string = $self->fetchString($_);
			next unless defined $string;
			my %hash = string2hash($string);
			my $userID = $hash{stlg};
			my $setID = $hash{stnm};
			if (defined $matchProblemID) {
				# we only want one 
				if (exists $hash{"pfn$matchProblemID"}) {
					push @result, [$userID, $setID, $matchProblemID];
				}
			} else {
				my (undef, undef, @problemIDs) = $self->hash2IDs(%hash);
				foreach my $n (@problemIDs) {
					if (exists $hash{"pfn$n"}) {
						push @result, [$userID, $setID, $n];
					}
				}
			}
		}
	}
	
	# disconnect
	$self->{driver}->disconnect();
	
	return @result;
}

sub exists {
	my ($self, @keyparts) = @_;
	my ($userID, $setID) = @keyparts[0 .. 1];
	
	return 0 unless $self->{driver}->connect("ro");
	
	# get a list of PSVNs that match the userID and setID given
	my @matchingPSVNs;
	if (defined $userID and not defined $setID) {
		@matchingPSVNs = $self->getPSVNsForUser($userID);
	} elsif (defined $setID and not defined $userID) {
		@matchingPSVNs = $self->getPSVNsForSet($setID);
	} elsif (defined $userID and defined $setID) {
		@matchingPSVNs = $self->getPSVN($userID, $setID);
	} else {
		# we need all PSVNs, so we have to do this ourselves.
		@matchingPSVNs =
			grep { m/^\d+$/ }
				keys %{ $self->{driver}->hash() };
	}
	
	my $result = 0;
	if (@matchingPSVNs) {
		if ($self->{table} eq "set_user") {
			# at least one set matched
			$result = 1;
		} elsif ($self->{table} eq "problem_user") {
			my $problemID = $keyparts[2];
			if (defined $problemID) {
				# check each set for a matching problem
				foreach my $PSVN (@matchingPSVNs) {
					my $string = $self->fetchString($PSVN);
					next unless defined $string;
					my @problemIDs = $self->string2IDs($string);
					shift @problemIDs; # remove userID
					shift @problemIDs; # remove setID
					if (grep { $_ eq $problemID } @problemIDs) {
						$result = 1;
						last;
					}
				}
			} else {
				# we'll take ANY problem in ANY set
				$result = 1;
			}
		}
	}
	
	$self->{driver}->disconnect();
	return $result;
}

sub add {
	my ($self, $Record) = @_;
	my $userID = $Record->user_id();
	my $setID = $Record->set_id();
	my $db = $self->{db};
	my $table = $self->{table};
	$table =~ m/^(.*)_user$/;
	my $globalSchema = $db->{$1};
	
	return 0 unless $self->{driver}->connect("rw");
	
	my $PSVN = $self->getPSVN($userID, $setID);
	
	my $result;
	if ($self->{table} eq "set_user") {
		$self->{driver}->disconnect();
		my $globalSet = $globalSchema->get($setID);
		$self->{driver}->connect("rw");
		$self->copyOverrides($globalSet, $Record);
		if (defined $PSVN) {
			$self->{driver}->disconnect();
			die "($userID, $setID): UserSet exists.\n";
		}
		my $PSVN = $self->setPSVN($userID, $setID); # create new psvn
		my $string = $self->records2string($Record); # no problems
		$self->storeString($PSVN, $string);
		$result = 1;
	} elsif ($self->{table} eq "problem_user") {
		my $problemID = $Record->problem_id();
		$self->{driver}->disconnect();
		my $globalProblem = $globalSchema->get($setID, $problemID);
		$self->{driver}->connect("rw");
		$self->copyOverrides($globalProblem, $Record);
		unless (defined $PSVN) {
			$self->{driver}->disconnect();
			die "($userID, $setID): UserSet not found.\n";
		}
		my $string = $self->fetchString($PSVN);
		if (defined $string) {
			my ($Set, @Problems) = $self->string2records($string);
			if (grep { $_->problem_id() eq $problemID } @Problems) {
				$self->{driver}->disconnect();
				die "($userID, $setID, $problemID): UserProblem exists.\n"
			}
			push @Problems, $Record;
			$string = $self->records2string($Set, @Problems);
			$self->storeString($PSVN, $string);
			$result = 1;
		} else {
			$result = 0;
		}
	}
	
	$self->{driver}->disconnect();
	return $result;
}

sub get {
	my ($self, @keyparts) = @_;
	
	return ( $self->gets(\@keyparts) )[0];
}

sub gets {
	my ($self, @keypartsRefList) = @_;
	
	my @records;
	$self->{driver}->connect("ro");
	foreach my $keypartsRef (@keypartsRefList) {
		my @keyparts = @$keypartsRef;
		my $UserSet = $self->get1(@keyparts);
		push @records, $UserSet;
	}
	$self->{driver}->disconnect();
	
	return @records;
}

=item get1(@keyparts)

Retrieves one set or problem from the database, packages it into a record
object, and removes values that match global defaults. Assumes that the driver
is already connected to the database. Used by gets().

=cut

sub get1 {
	my ($self, @keyparts) = @_;
	my $db = $self->{db};
	my $table = $self->{table};
	my ($globalTable) = $table =~ m/^(.*)_user$/;
	my $globalSchema = $db->{$globalTable};
	
	my $UserRecord = $self->get1NoFilter(@keyparts);
	
	# filter values that are identical to global values
	if (defined $UserRecord) {
		my $GlobalRecord = $globalSchema->get1(@keyparts[1..$#keyparts]);
		if (defined $GlobalRecord) {
			foreach my $field ($GlobalRecord->NONKEYFIELDS) {
				if ($UserRecord->$field eq $GlobalRecord->$field) {
					$UserRecord->$field(undef);
				}
			}
		} else {
			warn __PACKAGE__, ": keyparts=@keyparts: $table record exists, but $globalTable record does not. returning user record unmodified. this could cause problems later.";
		}
	}
	
	return $UserRecord;
}

=item getsNoFilter(@keypartsRefList)

Similar to gets(), but does not remove values that match global defaults.

=cut

sub getsNoFilter {
	my ($self, @keypartsRefList) = @_;
	
	my @records;
	$self->{driver}->connect("ro");
	foreach my $keypartsRef (@keypartsRefList) {
		my @keyparts = @$keypartsRef;
		my $UserSet = $self->get1NoFilter(@keyparts);
		push @records, $UserSet;
	}
	$self->{driver}->disconnect();
	
	return @records;
}

# helper used by get1
# also used by GlobalTableEmulator when it needs "real" records

=item get1NoFilter(@keyparts)

Similar to get1(), but does not remove values that match global defaults. Used
by getsNoFilter() and several methods in GlobalTableEmulator.

=cut

sub get1NoFilter {
	my ($self, @keyparts) = @_;
	
	my ($userID, $setID) = @keyparts[0 .. 1];
	# FIXME: move these checks up to DB
	die "userID not specified." unless defined $userID;
	die "setID not specified." unless defined $setID;
	
	my $PSVN = $self->getPSVN($userID, $setID);
	
	unless (defined $PSVN) {
		return;
	}
	my $string = $self->fetchString($PSVN);
	
	if ($self->{table} eq "set_user") {
		my $UserSet = $self->string2set($string);
		$UserSet->psvn($PSVN);
		return $UserSet;
	} elsif ($self->{table} eq "problem_user") {
		my ($problemID) = $keyparts[2];
		die "problemID not specified." unless defined $problemID;
		my $UserProblem = $self->string2problem($string, $problemID);
		return $UserProblem;
	}
}

=item getAll($userID, $setID)

Returns all problems in a given set. Only supported for the problem_user table.

=cut

sub getAll {
	my ($self, @keyparts) = @_;
	my $db = $self->{db};
	my $table = $self->{table};
	my ($globalTable) = $table =~ m/^(.*)_user$/;
	my $globalSchema = $db->{$globalTable};
	
	croak "getAll: only supported for the problem_user table"
		unless $table eq "problem_user";
	
	my @UnsortedUserProblems = $self->getAllNoFilter(@keyparts);
	my @UnsortedGlobalProblems = $globalSchema->getAll(@keyparts[1 .. $#keyparts]);
	
	# FIXME FIXME FIXME: Danger! This code assumes that problem IDs are NUMERIC!
	# I don't want to fix it right now, since there is currently no way to
	# specify a non-numeric problem ID. However, it should be fixed at some
	# point!

	my (@UserProblems, @GlobalProblems);
	foreach my $UserProblem (@UnsortedUserProblems) {
		@UserProblems[$UserProblem->problem_id] = $UserProblem;
	}
	foreach my $GlobalProblem (@UnsortedGlobalProblems) {
		@GlobalProblems[$GlobalProblem->problem_id] = $GlobalProblem;
	}
	
	foreach my $problemID (0 .. $#GlobalProblems) {
		my $GlobalProblem = $GlobalProblems[$problemID];
		my $UserProblem = $UserProblems[$problemID];
		
		next unless defined $UserProblem;
		
		if (defined $GlobalProblem) {
			foreach my $field ($GlobalProblem->NONKEYFIELDS) {
				if ($UserProblem->$field eq $GlobalProblem->$field) {
					$UserProblem->$field(undef);
				}
			}
		} else {
			warn __PACKAGE__, ": keyparts=@keyparts: $table record exists, but $globalTable record does not. returning user record unmodified. this could cause problems later.";
		}
	}
	
	return @UnsortedUserProblems;
}

=item getAllNoFilter($userID, $setID)

Similar to getAll(), but does not remove values that match global defaults.
Used by getAll() and the getAll() method in GlobalTableEmulator.

=cut

sub getAllNoFilter {
	my ($self, $userID, $setID) = @_;
	
	croak "getAll: only supported for the problem_user table"
		unless $self->{table} eq "problem_user";
	
	$self->{driver}->connect("ro");
	
	my $PSVN = $self->getPSVN($userID, $setID);
	return unless defined $PSVN;
	
	my $string = $self->fetchString($PSVN);
	my @UserProblems = $self->string2problems($string);
	
	$self->{driver}->disconnect;
	
	return @UserProblems;
}

sub put {
	my ($self, $Record) = @_;
	my $userID = $Record->user_id();
	my $setID = $Record->set_id();
	my $db = $self->{db};
	my $table = $self->{table};
	$table =~ m/^(.*)_user$/;
	my $globalSchema = $db->{$1};
	
	return 0 unless $self->{driver}->connect("rw");
	
	my $PSVN = $self->getPSVN($userID, $setID);
	
	unless (defined $PSVN) {
		$self->{driver}->disconnect();
		die "($userID, $setID): UserSet not found.\n";
	}
	
	my $string = $self->fetchString($PSVN);
	
	my $result;
	if (defined $string) {
		my ($Set, @Problems) = $self->string2records($string);
		if ($self->{table} eq "set_user") {
			$self->{driver}->disconnect();
			# This call makes database connections, so we
			# have to release our control on it.
			my $globalSet = $globalSchema->get($setID);
			$self->{driver}->connect("rw");
	 		$self->copyOverrides($globalSet, $Record);
			$string = $self->records2string($Record, @Problems);
		} elsif ($self->{table} eq "problem_user") {
			my $problemID = $Record->problem_id();
			$self->{driver}->disconnect();
			my $globalProblem = $globalSchema->get($setID, $problemID);
			$self->{driver}->connect("rw");
			$self->copyOverrides($globalProblem, $Record);
			my $found = 0;
			foreach (@Problems) {
				if ($_->problem_id() eq $problemID) {
					$found = 1;
					$_ = $Record;
				}
			}
			unless ($found) {
				$self->{driver}->disconnect();
				die "($userID, $setID, $problemID): UserProblem not found.\n";
			}
			$string = $self->records2string($Set, @Problems);
		}
		$self->storeString($PSVN, $string);
		$result = 1;
	} else {
		$result = 0;
	}
	
	$self->{driver}->disconnect();
	return $result;
}

sub delete {
	my ($self, $userID, $setID, $problemID) = @_;
	
	return 0 unless $self->{driver}->connect("rw");
	
	# get a list of PSVNs that match the userID and setID given
	my @matchingPSVNs;
	if (defined $userID and not defined $setID) {
		@matchingPSVNs = $self->getPSVNsForUser($userID);
	} elsif (defined $setID and not defined $userID) {
		@matchingPSVNs = $self->getPSVNsForSet($setID);
	} elsif (defined $userID and defined $setID) {
		@matchingPSVNs = $self->getPSVN($userID, $setID);
	} else {
		# we need all PSVNs, so we have to do this ourselves.
		@matchingPSVNs =
			grep { m/^\d+$/ }
				keys %{ $self->{driver}->hash() };
	}
	
	if (@matchingPSVNs) {
		foreach my $PSVN (@matchingPSVNs) {
			$self->delete1($PSVN, $problemID);
		}
	}
	
	$self->{driver}->disconnect();
	return 1;
}

=item delete1($PSVN, $problemID)

for the set_user table,  ignore $problemID and deletes the set with the
matching $PSVN. for the problem_user table, deletes the problem matching
$problemID from the set matching $PSVN, or all problems if $problemID is not
defined. Assumes that the driver is already connected to the database. Used by
delete().

=cut

sub delete1 {
	my ($self, $PSVN, $problemID) = @_;
	
	my $string = $self->fetchString($PSVN);
	return 0 unless defined $string;
	my ($userID, $setID) = $self->string2IDs($string);
	
	my $result = 1;
	if ($self->{table} eq "set_user") {
		$self->deletePSVN($userID, $setID);
		$self->deleteString($PSVN);
		$result = 1;
	} elsif ($self->{table} eq "problem_user") {
		my ($Set, @Problems) = $self->string2records($string);
		my $length = @Problems;
		if (defined $problemID) {
			@Problems = grep { not $_->problem_id() eq $problemID } @Problems;
		} else {
			@Problems = (); # delete all problems
		}
		if ($length != @Problems) {
			# removed one, store the new version
			$string = $self->records2string($Set, @Problems);
			$self->storeString($PSVN, $string);
		}
		$result = 1;
	}
	
	return $result;
}

=back

=cut

################################################################################
# add/put override copy helper
################################################################################

sub copyOverrides {
	my ($self, $globalRecord, $userRecord) = @_;
	
	# This could happen if a Null schema is being used.
	unless (defined $globalRecord and defined $userRecord) {
		return $userRecord;
	}
	
	foreach my $field ($globalRecord->FIELDS) {
		unless (defined $userRecord->$field) {
			$userRecord->$field($globalRecord->$field);
		}
	}
	
	return $userRecord; # The edit happens in place, so this is unneccesary.
	                    # Nevertheless, it is common courtesy.
}

################################################################################
# string <-> data conversion functions
################################################################################

sub string2IDs {
	my ($self, $string) = @_;
	return $self->hash2IDs(string2hash($string));
}
 
sub string2set {
	my ($self, $string) = @_;
	return $self->hash2set(string2hash($string));
}

sub string2problem {
	my ($self, $string, $problemID) = @_;
	return $self->hash2problem($problemID, string2hash($string));
}

sub string2problems {
	my ($self, $string) = @_;
	my %hash = string2hash($string);
	my @Problems;
	foreach my $problemID (grep { s/^pfn// } keys %hash) {
		push @Problems, $self->hash2problem($problemID, %hash);
	}
	return @Problems;
}

sub string2records {
	my ($self, $string) = @_;
	my %hash = string2hash($string);
	my @Records = $self->hash2set(%hash);
	if (wantarray) {
		foreach my $problemID (grep { s/^pfn// } keys %hash) {
			push @Records, $self->hash2problem($problemID, %hash);
		}
	}
	return @Records;
}

sub records2string {
	my ($self, $Set, @Problems) = @_;
	my @hashArray = $self->set2hash($Set);
	foreach my $Problem (@Problems) {
		push @hashArray, $self->problem2hash($Problem);
	}
	my %hash = @hashArray;
	return hash2string(%hash);
}

################################################################################
# table multiplexing functions
#  both the set_user and problem_user tables are stored in one hash, keyed by
#  PSVN. we need to be able to split a hash value into two records, and combine
#  two records into a single hash value.
################################################################################

sub hash2IDs {
	my ($self, %hash) = @_;
	my $userID = $hash{stlg};
	my $setID = $hash{stnm};
	my @problemIDs = grep { s/^pfn// } keys %hash;
	return $userID, $setID, @problemIDs;
}

sub hash2set {
	my ($self, %hash) = @_;
	return $self->{db}->{set_user}->{record}->new(
		user_id        => defined $hash{stlg} ? $hash{stlg} : "",
		set_id         => defined $hash{stnm} ? $hash{stnm} : "",
		set_header     => defined $hash{shfn} ? $hash{shfn} : "",
		problem_header => defined $hash{phfn} ? $hash{phfn} : "",
		open_date      => defined $hash{opdt} ? $hash{opdt} : "",
		due_date       => defined $hash{dudt} ? $hash{dudt} : "",
		answer_date    => defined $hash{andt} ? $hash{andt} : "",
		published      => defined $hash{publ} ? $hash{publ} : "",
	);
}

sub hash2problem {
	my ($self, $n, %hash) = @_;
	return $self->{db}->{problem_user}->{record}->new(
		user_id       => defined $hash{"stlg"}   ? $hash{"stlg"}   : "",
		set_id        => defined $hash{"stlg"}   ? $hash{"stnm"}   : "",
		problem_id    => $n,
		source_file   => defined $hash{"pfn$n"}  ? $hash{"pfn$n"}  : "",
		value         => defined $hash{"pva$n"}  ? $hash{"pva$n"}  : "",
		max_attempts  => defined $hash{"pmia$n"} ? $hash{"pmia$n"} : "",
		problem_seed  => defined $hash{"pse$n"}  ? $hash{"pse$n"}  : "",
		status        => defined $hash{"pst$n"}  ? $hash{"pst$n"}  : "",
		attempted     => defined $hash{"pat$n"}  ? $hash{"pat$n"}  : "",
		last_answer   => defined $hash{"pan$n"}  ? $hash{"pan$n"}  : "",
		num_correct   => defined $hash{"pca$n"}  ? $hash{"pca$n"}  : "",
		num_incorrect => defined $hash{"pia$n"}  ? $hash{"pia$n"}  : "",
	);
}

sub set2hash {
	my ($self, $Set) = @_;
	return (
		stlg => $Set->user_id,
		stnm => $Set->set_id,
		shfn => $Set->set_header,
		phfn => $Set->problem_header,
		opdt => $Set->open_date,
		dudt => $Set->due_date,
		andt => $Set->answer_date,
		publ => $Set->published,
	);
}

sub problem2hash {
	my ($self, $Problem) = @_;
	my $n = $Problem->problem_id;
	return (
		"stlg"   => $Problem->user_id,
		"stnm"   => $Problem->set_id,
		"pfn$n"  => $Problem->source_file,
		"pva$n"  => $Problem->value,
		"pmia$n" => $Problem->max_attempts,
		"pse$n"  => $Problem->problem_seed,
		"pst$n"  => $Problem->status,
		"pat$n"  => $Problem->attempted,
		"pan$n"  => $Problem->last_answer,
		"pca$n"  => $Problem->num_correct,
		"pia$n"  => $Problem->num_incorrect,
	);
}

################################################################################
# PSVN and index functions
#  the PSVN pseudo-table and the set and user indexes are not visible to the
#  API, but we need to be able to update them to remain compatible with WWDBv1.
################################################################################

# retrieves a list of existing PSVNs from the user PSVN index
sub getPSVNsForUser {
	my ($self, $userID) = @_;
	my $setsForUser = $self->fetchString(LOGIN_PREFIX.$userID);
	return unless defined $setsForUser;
	my %sets = string2hash($setsForUser);
	return values %sets;
}

# retrieves a list of existing PSVNs from the set PSVN index
sub getPSVNsForSet {
	my ($self, $setID) = @_;
	my $usersForSet = $self->fetchString(SET_PREFIX.$setID);
	return unless defined $usersForSet;
	my %users = string2hash($usersForSet);
	return values %users;
}

# retrieves a list of existing PSVNs from the set PSVN index
sub getAllPSVNs {
	my ($self) = @_;
	return grep { m/^\d+$/ } keys %{ $self->{driver}->hash() };
}

# retrieves an existing PSVN from the PSVN indexes
sub getPSVN {
	my ($self, $userID, $setID) = @_;
	my $setsForUser = $self->{driver}->hash()->{LOGIN_PREFIX.$userID};
	my $usersForSet = $self->{driver}->hash()->{SET_PREFIX.$setID};
	# * if setsForUser is non-empty, then there are sets built for this
	#   user.
	# * if usersForSet is non-empty, then this set has been built for at
	#   least one user.
	# * if either are empty, it is guaranteed that this set has not been
	#   built for this user.
	return unless defined $setsForUser and defined $usersForSet; #shut up, shut up, shut up!
	return unless $setsForUser and $usersForSet;
	my %sets = string2hash($setsForUser);
	my %users = string2hash($usersForSet);
	return unless exists $sets{$setID} and exists $users{$userID};
	# more sanity checks: the following should never happen.
	# if they do, run screaming for the hills.
	if (defined $sets{$setID} and not defined $users{$userID}) {
		die "PSVN indexes inconsistent: set exists in user index ",
		    "but user does not exist in set index.";
	} elsif (not defined $sets{$setID} and defined $users{$userID}) {
		die "PSVN indexes inconsistent: user exists in set index ",
		    "but set does not exist in user index.";
	} elsif ($sets{$setID} != $users{$userID}) {
		die "PSVN indexes inconsistent: user index and set index ",
		    "gave different PSVN values.";
	}
	return $sets{$setID};
}

# generates a new PSVN, updates the PSVN indexes, returns the PSVN
# if there is already a PSVN for this pair, reuse it
sub setPSVN {
	my ($self, $userID, $setID) = @_;
	my $PSVN = $self->getPSVN($userID, $setID);
	unless ($PSVN) {
		# yeah, create a new PSVN here
		my $min_psvn = 10**($self->{params}->{psvnLength} - 1);
		my $max_psvn = 10**$self->{params}->{psvnLength} - 1;
		my $attempts = 0;
		do {
			if (++$attempts > MAX_PSVN_GENERATION_ATTEMPTS) {
				die "failed to find an unused PSVN within ",
				    MAX_PSVN_GENERATION_ATTEMPTS, " attempts.";
			}
			$PSVN = int(rand($max_psvn-$min_psvn+1)) + $min_psvn;
		} while ($self->fetchString($PSVN));
		# get current PSVN indexes
		my $setsForUser = $self->{driver}->hash()->{LOGIN_PREFIX.$userID};
		my $usersForSet = $self->{driver}->hash()->{SET_PREFIX.$setID};
		my %sets = string2hash($setsForUser);  # sets built for user $userID
		my %users = string2hash($usersForSet); # users for which set $setID has been built
		# insert new PSVN into each hash
		$sets{$setID} = $PSVN;
		$users{$userID} = $PSVN;
		# re-encode the hashes
		$setsForUser = hash2string(%sets);
		$usersForSet = hash2string(%users);
		# store 'em in the database
		$self->{driver}->hash()->{LOGIN_PREFIX.$userID} = $setsForUser;
		$self->{driver}->hash()->{SET_PREFIX.$setID} = $usersForSet;
	};
	return $PSVN;
}

# remove an existing PSVN from the PSVN indexes
sub deletePSVN {
	my ($self, $userID, $setID) = @_;
	my $PSVN = $self->getPSVN($userID, $setID);
	return unless $PSVN;
	my $setsForUser = $self->{driver}->hash()->{LOGIN_PREFIX.$userID};
	my $usersForSet = $self->{driver}->hash()->{SET_PREFIX.$setID};
	my %sets = string2hash($setsForUser);  # sets built for user $userID
	my %users = string2hash($usersForSet); # users for which set $setID has been built
	delete $sets{$setID};
	delete $users{$userID};
	$setsForUser = hash2string(%sets);
	$usersForSet = hash2string(%users);
	if ($setsForUser) {
		$self->{driver}->hash()->{LOGIN_PREFIX.$userID} = $setsForUser;
	} else {
		delete $self->{driver}->hash()->{LOGIN_PREFIX.$userID};
	}
	if ($usersForSet) {
		$self->{driver}->hash()->{SET_PREFIX.$setID} = $usersForSet;
	} else {
		delete $self->{driver}->hash()->{SET_PREFIX.$setID};
	}
	return 1;
}

################################################################################
# hash string interface
################################################################################

sub fetchString {
	my ($self, $PSVN) = @_;
	my $string = $self->{driver}->hash()->{$PSVN};
	return $string;
}


sub storeString {
	my ($self, $PSVN, $string) = @_;
	$self->{driver}->hash()->{$PSVN} = $string;
}

sub deleteString {
	my ($self, $PSVN) = @_;
	delete $self->{driver}->hash()->{$PSVN};
}

1;
