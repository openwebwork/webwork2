################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::DB::WW;

=head1 NAME

WeBWorK::DB::WW - interface with the WeBWorK problem set database.

=cut

use strict;
use warnings;
use Carp;
use WeBWorK::Problem;
use WeBWorK::Set;
use WeBWorK::Utils qw(dbDecode dbEncode);

use constant LOGIN_PREFIX => "login<>";
use constant SET_PREFIX => "set<>";
use constant MAX_PSVN_GENERATION_ATTEMPTS => 200;

# there should be a `use' line for each database type
use WeBWorK::DB::GDBM;

# new($invocant, $courseEnv)
# $invocant - implicitly set by caller
# $courseEnv - an instance of CourseEnvironment
sub new($$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $courseEnv = shift;
	my $dbModule = fullyQualifiedPackageName($courseEnv->{dbInfo}->{wwdb_type});
	my $self = {
		webwork_file => $courseEnv->{dbInfo}->{wwdb_file},
		psvn_digits => $courseEnv->{dbInfo}->{psvn_digits},
	};
	$self->{webwork_db} = $dbModule->new($self->{webwork_file});
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

#sub fixMyMistakes($) { # ***
#	my $self = shift;
#	my $userID = "practice1";
#	my $setID = "dummy";
#	my $PSVN = 95540;
#	$self->{webwork_db}->connect("rw");
#	delete $self->{webwork_db}->hashRef->{$PSVN};
#	my $setsForUser = $self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID};
#	my $usersForSet = $self->{webwork_db}->hashRef->{SET_PREFIX.$setID};
#	my %sets = dbDecode($setsForUser);  # sets built for user $userID
#	my %users = dbDecode($usersForSet); # users for which set $setID has been built
#	delete $sets{$setID};
#	delete $users{$userID};
#	$setsForUser = dbEncode(%sets);
#	$usersForSet = dbEncode(%users);
#	$self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID} = $setsForUser;
#	$self->{webwork_db}->hashRef->{SET_PREFIX.$setID} = $usersForSet;
#	$self->{webwork_db}->disconnect;
#}

# -----

# getSets($userID) - returns a list of SetIDs in the current database for the
#                    specified user
# $userID - the user ID (a.k.a. login name) of the user to get sets for
sub getSets($$) {
	my $self = shift;
	my $userID = shift;
	return unless $self->{webwork_db}->connect("ro");
	my $result = $self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID};
	$self->{webwork_db}->disconnect;
	return unless defined $result;
	my %record = dbDecode($result);
	return keys %record;
}

# -----

# getSet($userID, $setID) - returns a WeBWorK::Set object containing data
#                           from the specified set.
# $userID - the user ID (a.k.a. login name) of the set to retrieve
# $setID - the ID (a.k.a. name) of the set to retrieve
sub getSet($$$) {
	my $self = shift;
	my $userID = shift;
	my $setID = shift;
	my $PSVN = $self->getPSVN($userID, $setID);
	return unless $PSVN;
	return hash2set($self->fetchRecord($PSVN));
}

# setSet($set) - if a set with the same ID for the specified user
#                exists, it is replaced. If not, a new set is added.
#                returns true on success, undef on failure.
# $set - a WeBWorK::Set object containing the set data
sub setSet($$) {
	my $self = shift;
	my $set = shift;
	my $PSVN = $self->getPSVN($set->login_id, $set->id);
	my %record = (
		$PSVN ? $self->fetchRecord($PSVN) : (),
		set2hash($set),
	);
	$PSVN = $self->setPSVN($set->login_id, $set->id) unless ($PSVN);
	return $self->storeRecord($PSVN, %record);
}

# deleteSet($userID, $setID) - removes the set with the specified userID and
#                              setID. Also removes all problems in set.
#                              Returns true on success, undef on failure.
# $userID - the user ID (a.k.a. login name) of the set to delete
# $setID - the ID (a.k.a. name) of the set to delete
sub deleteSet($$$) {
	my $self = shift;
	my $userID = shift;
	my $setID = shift;
	my $PSVN = $self->getPSVN($userID, $setID);
	$self->{webwork_db}->connect("rw");
	delete $self->{webwork_db}->hashRef->{$PSVN};
	$self->{webwork_db}->disconnect;
	$self->deletePSVN($userID, $setID);
	return 1;
}

# -----

# getSetDefaults($setID) - returns a WeBWorK::Set object containing the default
#                          values for a particular set. (See NOTE)
# setID - id of set to fetch

# setSetDefaults($set) - Replace set defaults with the given set. (See NOTE)
# $set - a WeBWorK::Set object containing set defaults

# deleteSetDefaults($setID) - Remove set defaults with the given ID. (See NOTE)
# $setID - the ID of the set defaults to delete

# -----

# getProblems($userID, $setID) - returns a list of problem IDs in the
#                                specified set for the specified user.
# $userID - the user ID of the user to get problems for
# $setID - the set ID to get problems from
sub getProblems($$$) {
	my $self = shift;
	my $userID = shift;
	my $setID = shift;
	my $PSVN = $self->getPSVN($userID, $setID);
	my %record = $self->fetchRecord($PSVN);
	return unless %record;
	my @result;
	my $i = 1;
	while (exists $record{"pse".$i}) {
		push @result, $i++;
	}
	return @result;
}

# -----

# getProblem($userID, $setID, $problemNumber) - returns a WeBWorK::Problem
#                                               object containing the problem
#                                               requested
# $userID - the user for which to retrieve the problem
# $setID - the set from which to retrieve the problem
# $problemNumber - the number of the problem to retrieve
sub getProblem($$$$) {
	my $self = shift;
	my $userID = shift;
	my $setID = shift;
	my $problemNumber = shift;
	my $PSVN = $self->getPSVN($userID, $setID);
	return unless $PSVN;
	return hash2problem($problemNumber, $self->fetchRecord($PSVN));
}

# setProblem($problem) - if a problem with the same ID for the specified user
#                        exists, it is replaced. If not, a new problem is added.
#                        returns true on success, undef on failure.
# $problem - a WeBWorK::Problem object containing the object data
sub setProblem($$) {
	my $self = shift;
	my $problem = shift;
	my $PSVN = $self->getPSVN($problem->login_id, $problem->set_id);
	die "failed to add problem: set ", $problem->set_id, " does not exist."
		unless $PSVN;
	my %record = (
		$self->fetchRecord($PSVN),
		problem2hash($problem),
	);
	return $self->storeRecord($PSVN, %record);
}

# deleteProblem($userID, $setID, $problemNumber) - removes a problem with the
#                                                  specified parameters.
# $userID - the user ID of the problem to delete
# $setID - the ID of the problem's set
# $problemNumber - the problem number of the problem to delete
sub deleteProblem($$$$) {
	my $self = shift;
	my $userID = shift;
	my $setID = shift;
	my $n = shift;
	my $PSVN = $self->getPSVN($userID, $setID);
	my %record = $self->fetchRecord($PSVN);
	return unless %record;
	delete $record{"pfn$n"}  if exists $record{"pfn$n"};
	delete $record{"pva$n"}  if exists $record{"pva$n"};
	delete $record{"pmia$n"} if exists $record{"pmia$n"};
	delete $record{"pse$n"}  if exists $record{"pse$n"};
	delete $record{"pst$n"}  if exists $record{"pst$n"};
	delete $record{"pat$n"}  if exists $record{"pat$n"};
	delete $record{"pan$n"}  if exists $record{"pan$n"};
	delete $record{"pca$n"}  if exists $record{"pca$n"};
	delete $record{"pia$n"}  if exists $record{"pia$n"};
	return $self->storeRecord($PSVN, %record);
}

# -----

# getProblemDefaults($setID, $problemNumber) - Returns a WeBWorK::Problem object
#                                              containing the default values for
#                                              a particular problem. (See NOTE)
# $setID - set id of problem to retrieve
# $problemNumber - problem number of problem to retrieve

# setProblemDefaults($problem) - Replace or add problem defaults with the given
#                                problem. (See NOTE)
# $problem - a WeBWorK::Problem object containing problem defaults

# deleteProblemDefaults($setID, $problemNumber) - remove problem defaults with
#                                                 the given set and problem ID.
#                                                 (See NOTE)
# $setID - the set ID of the problem defaults to delete
# $problemNumber - the problem number of the problem defaults to delete

# -----

# getPSVNs($userID) - get a list of PSVNs for a user
# $userID - the user
sub getPSVNs($$) {
	my $self = shift;
	my $userID = shift;
	return unless $self->{webwork_db}->connect("ro");
	my $setsForUser = $self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID};
	$self->{webwork_db}->disconnect;
	return unless defined $setsForUser;
	my %sets = dbDecode($setsForUser);
	return values %sets;
}

# -----

# getPSVN($userID, $setID) - look up a PSVN given a user ID and set ID (PSVN
#                            stands for Problem Set Version Number and
#                            uniquely identifies a user's version of a set.)
# $userID - the user ID to lookup
# $serID - the set ID to lookup
sub getPSVN($$$) {
	my $self = shift;
	my $userID = shift;
	my $setID = shift;
	return unless $self->{webwork_db}->connect("ro");
	my $setsForUser = $self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID};
	my $usersForSet = $self->{webwork_db}->hashRef->{SET_PREFIX.$setID};
	$self->{webwork_db}->disconnect;
	# * if setsForUser is non-empty, then there are sets built for
	#   this user.
	# * if usersForSet is non-empty, then this set has been built for
	#   at least one user.
	# * if either are empty, it is guaranteed that this set has not
	#   been built for this user.
	return unless defined $setsForUser and defined $usersForSet;
	return unless $setsForUser and $usersForSet;
	my %sets = dbDecode($setsForUser);
	my %users = dbDecode($usersForSet);
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

# setPSVN($userID, $setID) - adds a new PSVN to the PSVN indexesfor the given
#                            user ID and set ID, if it doesn't exist. Returns
#                            the PSVN.
# $userID - the user ID to use
# $serID - the set ID to use
sub setPSVN($$$) {
	my $self = shift;
	my $userID = shift;
	my $setID = shift;
	my $PSVN = $self->getPSVN($userID, $setID);
	unless ($PSVN) {
		# yeah, create a new PSVN here
		my $min_psvn = 10**($self->{psvn_digits} - 1);
		my $max_psvn = 10**$self->{psvn_digits} - 1;
		my $attempts = 0;
		do {
			if (++$attempts > MAX_PSVN_GENERATION_ATTEMPTS) {
				die "failed to find an unused PSVN.";
			}
			$PSVN = int(rand($max_psvn-$min_psvn+1)) + $min_psvn;
		} while ($self->fetchRecord($PSVN));
		$self->{webwork_db}->connect("rw"); # open "rw" to lock
		# get current PSVN indexes
		my $setsForUser = $self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID};
		my $usersForSet = $self->{webwork_db}->hashRef->{SET_PREFIX.$setID};
		my %sets = dbDecode($setsForUser);  # sets built for user $userID
		my %users = dbDecode($usersForSet); # users for which set $setID has been built
		# insert new PSVN into each hash
		$sets{$setID} = $PSVN;
		$users{$userID} = $PSVN;
		# re-encode the hashes
		$setsForUser = dbEncode(%sets);
		$usersForSet = dbEncode(%users);
		# store 'em in the database
		$self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID} = $setsForUser;
		$self->{webwork_db}->hashRef->{SET_PREFIX.$setID} = $usersForSet;
		$self->{webwork_db}->disconnect;
	};
	return $PSVN;
}

# deletePSVN($userID, $setID) - remove an entry from the PSVN indexes.
# $userID - the user to remove
# $setID - the set to remove
sub deletePSVN($$) {
	my $self = shift;
	my $userID = shift;
	my $setID = shift;
	my $PSVN = $self->getPSVN($userID, $setID);
	return unless $PSVN;
	$self->{webwork_db}->connect("rw"); # open "rw" to lock
	my $setsForUser = $self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID};
	my $usersForSet = $self->{webwork_db}->hashRef->{SET_PREFIX.$setID};
	my %sets = dbDecode($setsForUser);  # sets built for user $userID
	my %users = dbDecode($usersForSet); # users for which set $setID has been built
	delete $sets{$setID};
	delete $users{$userID};
	$setsForUser = dbEncode(%sets);
	$usersForSet = dbEncode(%users);
	$self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID} = $setsForUser;
	$self->{webwork_db}->hashRef->{SET_PREFIX.$setID} = $usersForSet;
	$self->{webwork_db}->disconnect;
	return 1;
}

# -----

# fetchRecord($PSVN) - retrieve the record associated with the given PSVN
# $PSVN - problem set version number
sub fetchRecord($$) {
	my $self = shift;
	my $PSVN = shift;
	return unless $self->{webwork_db}->connect("ro");
	my $result = $self->{webwork_db}->hashRef->{$PSVN};
	$self->{webwork_db}->disconnect;
	return dbDecode($result);
}

# storeRecord($PSVN, %record) - store the given record with the PSVN as a key
# $PSVN - problem set version number
# %record - the record to insert
sub storeRecord($$%) {
	my $self = shift;
	my $PSVN = shift;
	my %record = @_;
	$self->{webwork_db}->connect("rw");
	$self->{webwork_db}->hashRef->{$PSVN} = dbEncode(%record);
	$self->{webwork_db}->disconnect;
	return 1;
}

# -----

# hash2set(%hash) - places selected fields from a webwork database record
#                   in a WeBWorK::Set object, which is then returned.
# %hash - a hash representing a database record
sub hash2set(%) {
	my %hash = @_;
	my $set = WeBWorK::Set->new;
	$set->id             ( $hash{stnm} ) if defined $hash{stnm};
	$set->login_id       ( $hash{stlg} ) if defined $hash{stlg};
	$set->set_header     ( $hash{shfn} ) if defined $hash{shfn};
	$set->problem_header ( $hash{phfn} ) if defined $hash{phfn};
	$set->open_date      ( $hash{opdt} ) if defined $hash{opdt};
	$set->due_date       ( $hash{dudt} ) if defined $hash{dudt};
	$set->answer_date    ( $hash{andt} ) if defined $hash{andt};
	return $set;
}

# set2hash($set) - unpacks a WeBWorK::Set object and returns PART of a hash
#                  suitable for storage in the webwork database.
# $set - a WeBWorK::Set object.
sub set2hash($) {
	my $set = shift;
	return (
		stnm => $set->id,
		stlg => $set->login_id,
		shfn => $set->set_header,
		phfn => $set->problem_header,
		opdt => $set->open_date,
		dudt => $set->due_date,
		andt => $set->answer_date,
	);
}

# hash@problem($n, %hash) - places selected fields from a webwork
#                                       database record in a WeBWorK::Problem
#                                       object, which is then returned.
# $n - the problem number to extract
# %hash - a hash representing a database record
sub hash2problem($%) {
	my $n = shift;
	my %hash = @_;
	my $problem = WeBWorK::Problem->new(id => $n);
	$problem->set_id        ( $hash{stnm}    ) if defined $hash{stnm};
	$problem->login_id      ( $hash{stlg}    ) if defined $hash{stlg};
	$problem->source_file   ( $hash{"pfn$n"} ) if defined $hash{"pfn$n"};
	$problem->value         ( $hash{"pva$n"} ) if defined $hash{"pva$n"};
	$problem->max_attempts  ( $hash{"pmia$n"}) if defined $hash{"pmia$n"};
	$problem->problem_seed  ( $hash{"pse$n"} ) if defined $hash{"pse$n"};
	$problem->status        ( $hash{"pst$n"} ) if defined $hash{"pst$n"};
	$problem->attempted     ( $hash{"pat$n"} ) if defined $hash{"pat$n"};
	$problem->last_answer   ( $hash{"pan$n"} ) if defined $hash{"pan$n"};
	$problem->num_correct   ( $hash{"pca$n"} ) if defined $hash{"pca$n"};
	$problem->num_incorrect ( $hash{"pia$n"} ) if defined $hash{"pia$n"};
	return $problem;
}

# problem2hash($problem) - unpacks a WeBWorK::Problem object and returns PART
#                          of a hash suitable for storage in the webwork
#                          database.
# $problem - a WeBWorK::Problem object
sub problem2hash($) {
	my $problem = shift;
	my $n = $problem->id;
#	my %hash;
#	$hash{stnm}    = $problem->set_id        if defined $problem->set_id;
#	$hash{stlg}    = $problem->login_id      if defined $problem->login_id;
#	$hash{"pfn$n"} = $problem->source_file   if defined $problem->source_file;
#	$hash{"pva$n"} = $problem->value         if defined $problem->value;
#	$hash{"pmia$n"}= $problem->max_attempts  if defined $problem->max_attempts;
#	$hash{"pse$n"} = $problem->problem_seed  if defined $problem->problem_seed;
#	$hash{"pst$n"} = $problem->status        if defined $problem->status;
#	$hash{"pat$n"} = $problem->attempted     if defined $problem->attempted;
#	$hash{"pan$n"} = $problem->last_answer   if defined $problem->last_answer;
#	$hash{"pca$n"} = $problem->num_correct   if defined $problem->num_correct;
#	$hash{"pia$n"} = $problem->num_incorrect if defined $problem->num_incorrect;
#	return %hash;
	return (
		stnm     => $problem->set_id,
		stlg     => $problem->login_id,
		"pfn$n"  => $problem->source_file,
		"pva$n"  => $problem->value,
		"pmia$n" => $problem->max_attempts,
		"pse$n"  => $problem->problem_seed,
		"pst$n"  => $problem->status,
		"pat$n"  => $problem->attempted,
		"pan$n"  => $problem->last_answer,
		"pca$n"  => $problem->num_correct,
		"pia$n"  => $problem->num_incorrect,

	);
}

1;
