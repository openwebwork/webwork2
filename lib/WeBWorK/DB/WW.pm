################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::DB::WW;

use strict;
use warnings;
use WeBWorK::Set;
use WeBWorK::Problem;

use constant LOGIN_PREFIX => "login<>";
use constant SET_PREFIX => "set<>";

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

# getSets($userID) - returns a list of sets in the current database for the
#                    specified user
# $userID - the user ID (a.k.a. login name) of the user to get sets for
sub getSets($$) {
	my $self = shift;
	my $userID = shift;
	return unless $self->{webwork_db}->connect("ro");
	my $result = $self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID};
	$self->{webwork_db}->disconnect;
	return unless defined $result;
	return keys %{decode($result)};
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
	my $PSVN = getPSVN($userID, $setID);
	return unless $PSVN;
	return hash2set($self->fetchRcord($PSVN));
}

# setSet($set) - if a set with the same ID for the specified user
#                exists, it is replaced. If not, a new set is added.
#                returns true on success, undef on failure.
# $set - a WeBWorK::Set object containing the set data
sub setSet($$) {
	my $self = shift;
	my $set = shift;
	my $PSVN = getPSVN($set->login_id, $set->id);
	my %record = (
		$PSVN ? $self->fetchRecord($PSVN) : (),
		set2hash($set),
	);
	return $self->storeRecord($PSVN, %record);
}

# deleteSet($userID, $setID) - removes the set with the specified userID and
#                              setID. Returns true on success, undef on failure.
# $userID - the user ID (a.k.a. login name) of the set to delete
# $setID - the ID (a.k.a. name) of the set to delete
sub deleteSet($$$) {
	my $self = shift;
	my $userID = shift;
	my $setID = shift;
	my $PSVN = getPSVN($userID, $setID);
	$self->{classlist_db}->connect("rw");
	delete $self->{classlist_db}->hashRef->{$userID};
	$self->{classlist_db}->disconnect;
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
	my $PSVN = getPSVN($userID, $setID);
	my %record = $self->fetchRecord($PSVN);
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
	my $PSVN = getPSVN($userID, $setID);
	return unless $PSVN;
	return hash2problem($problemNumber, fetchRecord($PSVN));
}

# setProblem($problem) - if a problem with the same ID for the specified user
#                        exists, it is replaced. If not, a new problem is added.
#                        returns true on success, undef on failure.
# $problem - a WeBWorK::Problem object containing the object data
sub setProblem($$) {
	my $self = shift;
	my $problem = shift;
	my $PSVN = getPSVN($problem->login_id, $problem->set_id);
	my %record = (
		$PSVN ? $self->fetchRecord($PSVN) : (),
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
	my $PSVN = getPSVN($userID, $setID);
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
	my $result = $self->{webwork_db}->hashRef->{LOGIN_PREFIX.$userID};
	$self->{webwork_db}->disconnect;
	return unless $result;
	my %sets = decode($result);
	return $sets{$setID};
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
	return decode($result);
}

# storeRecord($PSVN, %record) - store the given record with the PSVN as a key
# $PSVN - problem set version number
# %record - the record to insert
sub storeRecord($$%) {
	my $self = shift;
	my $PSVN = shift;
	my %record = @_;
	$self->{webwork_db}->connect("rw");
	$self->{webwork_db}->hashRef->{$PSVN} = encode(%record);
	$self->{webwork_db}->disconnect;
	return 1;
}

# -----

# decode($string) - decodes a quasi-URL-encoded hash from a hash-based
#                   webwork database. unescapes \& and \= in VALUES ONLY.
# $string - string to decode
sub decode($) {
	my $string = shift;
	return unless defined $string and $string;
	my %hash = $string =~ /(.*?)(?<!\\)=(.*?)(?:(?<!\\)&|$)/g;
	$hash{$_} =~ s/\\(.)/$1/ foreach (keys %hash); # unescape anything
	return %hash;
}

# encode(%hash) - encodes a hash as a quasi-URL-encoded string for insertion
#                 into a hash-based webwork database. Escapes & and = in
#                 VALUES ONLY.
# %hash - hash to encode
sub encode(%) {
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
	my %hash;
	$hash{stnm} = $set->id             if defined $set->id;
	$hash{stlg} = $set->login_id       if defined $set->login_id;
	$hash{shfn} = $set->set_header     if defined $set->set_header;
	$hash{phfn} = $set->problem_header if defined $set->problem_header;
	$hash{opdt} = $set->open_date      if defined $set->open_date;
	$hash{dudt} = $set->due_date       if defined $set->due_date;
	$hash{andt} = $set->answer_date    if defined $set->answer_date;
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
	
}

# problem2hash($problem) - unpacks a WeBWorK::Problem object and returns PART
#                          of a hash suitable for storage in the webwork
#                          database.
# $problem - a WeBWorK::Problem object
sub problem2hash($) {
	my $problem = shift;
	my $n = $problem->id;
	my %hash;
	$hash{stnm}    = $problem->set_id        if defined $problem->set_id;
	$hash{stlg}    = $problem->login_id      if defined $problem->login_id;
	$hash{"pfn$n"} = $problem->source_file   if defined $problem->source_file;
	$hash{"pva$n"} = $problem->value         if defined $problem->value;
	$hash{"pmia$n"}= $problem->max_attempts  if defined $problem->max_attempts;
	$hash{"pse$n"} = $problem->problem_seed  if defined $problem->problem_seed;
	$hash{"pst$n"} = $problem->status        if defined $problem->status;
	$hash{"pat$n"} = $problem->attempted     if defined $problem->attempted;
	$hash{"pan$n"} = $problem->last_answer   if defined $problem->last_answer;
	$hash{"pca$n"} = $problem->num_correct   if defined $problem->num_correct;
	$hash{"pia$n"} = $problem->num_incorrect if defined $problem->num_incorrect;
	return %hash;
}

1;
