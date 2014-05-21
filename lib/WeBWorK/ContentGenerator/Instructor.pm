################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor.pm,v 1.64 2007/08/13 22:59:55 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor - Abstract superclass for the Instructor
tools, providing useful utility functions.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use File::Find;
use WeBWorK::DB::Utils qw(initializeUserProblem);
use WeBWorK::Debug;
use WeBWorK::Utils;

=head1 METHODS

=cut

################################################################################
# Primary assignment methods
################################################################################

=head2 Primary assignment methods

=over

=item assignSetToUser($userID, $GlobalSet)

Assigns the given set and all problems contained therein to the given user. If
the set (or any problems in the set) are already assigned to the user, a list of
failure messages is returned.

=cut

sub assignSetToUser {
	my ($self, $userID, $GlobalSet) = @_;
	my $setID = $GlobalSet->set_id;
	my $db = $self->{db};
	
	my $UserSet = $db->newUserSet;
	$UserSet->user_id($userID);
	$UserSet->set_id($setID);
	
	my @results;
	my $set_assigned = 0;
	
	eval { $db->addUserSet($UserSet) };
	if ($@) {
		if ($@ =~ m/user set exists/) {
			push @results, "set $setID is already assigned to user $userID.";
			$set_assigned = 1;
		} else {
			die $@;
		}
	}
	
	my @GlobalProblems = grep { defined $_ } $db->getAllGlobalProblems($setID);
	foreach my $GlobalProblem (@GlobalProblems) {
		my @result = $self->assignProblemToUser($userID, $GlobalProblem);
		push @results, @result if @result and not $set_assigned;
	}
	
	return @results;
}

sub assignSetVersionToUser {
    my ( $self, $userID, $GlobalSet ) = @_;
# in:  ($self,) $userID = the userID of the user to which to assign the set,
#      $GlobalSet = the global set object.
# out: a new set version is assigned to the user.
# note: we assume that the global set and user are well defined.  I think this
#    is a safe assumption.  it would be nice to just call assignSetToUser,
#    but we run into trouble doing that because of the distinction between
#    the setID and the setVersionID

    my $setID = $GlobalSet->set_id;
    my $db = $self->{db};

# figure out what version we're on, reset setID, get a new user set
# FIXME: old version; new call follows
#    my $setVersionNum = $db->getUserSetVersionNumber( $userID, $setID );
    my @allVersionIDs = $db->listSetVersions( $userID, $setID );
    my $setVersionNum = ( @allVersionIDs ) ? $allVersionIDs[-1] : 0;
    $setVersionNum++;
    my $userSet = $db->newSetVersion;
    $userSet->user_id( $userID );
    $userSet->set_id( $setID );
    $userSet->version_id( $setVersionNum );

    my @results = ();
    my $set_assigned = 0;

# add the set to the database
    eval { $db->addSetVersion( $userSet ) };
    if ( $@ ) {
	if ( $@ =~ m/user set exists/ ) {
	    push( @results, "set $setID,v$setVersionNum is already assigned" .
		  "to user $userID" );
	    $set_assigned = 1;
	} else {
	    die $@;
	}
    }

# populate set with problems
    my @GlobalProblems = grep { defined $_ } $db->getAllGlobalProblems($setID);

# keep track of problems assigned from groups so that we can have multiple
#    problems from a given group, without duplicates
    my %groupProblems = ();

    foreach my $GlobalProblem ( @GlobalProblems ) {
	$GlobalProblem->set_id( $setID );
# this is getting called from within ContentGenerator, so that $self
#    isn't an Instructor object---therefore, calling $self->assign... 
#    doesn't work.  the following is an ugly workaround that works b/c
#    both Instructor and ContentGenerator objects have $self->{db}
# FIXME  it would be nice to have a better solution to this
	my @result = 
	    assignProblemToUserSetVersion( $self, $userID, $userSet,
	    			           $GlobalProblem, \%groupProblems );
	push( @results, @result ) if ( @result && not $set_assigned );
    }

    return @results;
}


=item unassignSetFromUser($userID, $setID, $problemID)

Unassigns the given set and all problems therein from the given user.

=cut

sub unassignSetFromUser {
	my ($self, $userID, $setID) = @_;
	my $db = $self->{db};
	
	$db->deleteUserSet($userID, $setID);
}

=item assignProblemToUser($userID, $GlobalProblem, $seed)

Assigns the given problem to the given user. If the problem is already assigned
to the user, an error string is returned. If $seed is defined, the UserProblem
will be given that seed.

=cut

sub assignProblemToUser {
	my ($self, $userID, $GlobalProblem, $seed) = @_;
	my $db = $self->{db};
	
	my $UserProblem = $db->newUserProblem;
	$UserProblem->user_id($userID);
	$UserProblem->set_id($GlobalProblem->set_id);
	$UserProblem->problem_id($GlobalProblem->problem_id);
	initializeUserProblem($UserProblem, $seed);
	
	eval { $db->addUserProblem($UserProblem) };
	if ($@) {
		if ($@ =~ m/user problem exists/) {
			return "problem " . $GlobalProblem->problem_id
				. " in set " . $GlobalProblem->set_id
				. " is already assigned to user $userID.";
		} else {
			die $@;
		}
	}
	
	return ();
}

# $seed is optional -- if set, the UserProblem will be given that seed
sub assignProblemToUserSetVersion {
	my ($self, $userID, $userSet, $GlobalProblem, $groupProbRef, $seed) = @_;
	my $db = $self->{db};
	
# conditional to allow selection of problems from a group of problems, 
# defined in a set.  

    # problem groups are indicated by source files "group:problemGroupName"
	if ( $GlobalProblem->source_file() =~ /^group:(.+)$/ ) {
	    my $problemGroupName = $1;  

    # get list of problems in group
	    my @problemList = $db->listGlobalProblems($problemGroupName);
        # sanity check: if the group set hasn't been defined or doesn't
        # actually contain problems (oops), then we can't very well assign 
        # this problem to the user.  we could go on and assign all other 
        # problems, but that results in a partial set.  so we die here if 
        # this happens.  philosophically we're requiring that the instructor
        # set up the sets correctly or have to deal with the carnage after-
        # wards.  I'm not sure that this is the best long-term solution.
        # FIXME: this means that we may have created a set version that
        # doesn't have any problems.  this is bad.  but it's hard to see 
        # where else to deal with it---fixing the problem requires checking
        # at the set version-creation level that all the problems in the 
        # set are well defined.  FIXME
	    die("Error in set version creation: no problems are available " .
		"in problem group $problemGroupName.  Set " . 
		$userSet->set_id . " has been created for $userID, but " .
		"does not contain the right problems.\n") if (! @problemList);

	    my $nProb = @problemList;
	    my $whichProblem = int(rand($nProb));

    # we allow selection of multiple problems from a group, but want them to
    #   be different.  there's probably a better way to do this
	    if ( defined( $groupProbRef->{$problemGroupName} ) &&
		 $groupProbRef->{$problemGroupName} =~ /\b$whichProblem\b/ ) {
		my $nAvail = $nProb - 
		    ( $groupProbRef->{$problemGroupName} =~ tr/,// ) - 1;

		die("Too many problems selected from group.") if ( ! $nAvail );

		$whichProblem = int(rand($nProb));
		while ( $groupProbRef->{$problemGroupName} =~ /\b$whichProblem\b/ ) {
		    $whichProblem = ( $whichProblem + 1 )%$nProb;
		}
	    }
	    if ( defined( $groupProbRef->{$problemGroupName} ) ) {
		$groupProbRef->{$problemGroupName} .= ",$whichProblem";
	    } else {
		$groupProbRef->{$problemGroupName} = "$whichProblem";
	    }

	    my $prob = $db->getGlobalProblem($problemGroupName,
					     $problemList[$whichProblem]);
	    $GlobalProblem->source_file($prob->source_file());
	}
	
# all set; do problem assignment
	my $UserProblem = $db->newProblemVersion;
	$UserProblem->user_id($userID);
	$UserProblem->set_id($userSet->set_id);
	$UserProblem->version_id($userSet->version_id);
	$UserProblem->problem_id($GlobalProblem->problem_id);
	$UserProblem->source_file($GlobalProblem->source_file);
	initializeUserProblem($UserProblem, $seed);
	
	eval { $db->addProblemVersion($UserProblem) };
	if ($@) {
		if ($@ =~ m/user problem exists/) {
			return "problem " . $GlobalProblem->problem_id
				. " in set " . $GlobalProblem->set_id
				. " is already assigned to user $userID.";
		} else {
			die $@;
		}
	}

	return();
}

=item unassignProblemFromUser($userID, $setID, $problemID)

Unassigns the given problem from the given user.

=cut

sub unassignProblemFromUser {
	my ($self, $userID, $setID, $problemID) = @_;
	my $db = $self->{db};
	
	$db->deleteUserProblem($userID, $setID, $problemID);
}

=back

=cut

################################################################################
# Secondary set assignment methods
################################################################################

=head2 Secondary assignment methods

=over

=item assignSetToAllUsers($setID)

Assigns the set specified and all problems contained therein to all users in
the course. This is more efficient than repeatedly calling assignSetToUser().
If any assignments fail, a list of failure messages is returned.

=cut

sub assignSetToAllUsers {
	my ($self, $setID) = @_;
	my $db = $self->{db};
	my @userIDs = $db->listUsers;

	debug("$setID: getting user list");
	# DBFIXME pre-filter with WHERE clause for status abbrevs. that allow assignment (tricky...)
	my @userRecords = $db->getUsers(@userIDs);
	debug("$setID: (done with that)");
	
	debug("$setID: getting problem list");
	my @GlobalProblems = grep { defined $_ } $db->getAllGlobalProblems($setID);
	debug("$setID: (done with that)");
	
	my @results;
	
	foreach my $User (@userRecords) {
		next unless $self->r->ce->status_abbrev_has_behavior($User->status, "include_in_assignment");
		my $UserSet = $db->newUserSet;
		my $userID = $User->user_id;
		$UserSet->user_id($userID);
		$UserSet->set_id($setID);
		debug("$setID: adding UserSet for $userID");
		eval { $db->addUserSet($UserSet) };
		if ($@) {
			next if $@ =~ m/user set exists/;
			die $@;
		}
		debug("$setID: (done with that)");
		
		debug("$setID: adding UserProblems for $userID");
		foreach my $GlobalProblem (@GlobalProblems) {
			my @result = $self->assignProblemToUser($userID, $GlobalProblem);
			push @results, @result if @result;
		}
		debug("$setID: (done with that)");
	}
	
	return @results;
}

=item unassignSetFromAllUsers($setID)

Unassigns the specified sets and all problems contained therein from all users.

=cut

sub unassignSetFromAllUsers {
	my ($self, $setID) = @_;
	my $db = $self->{db};
	
	my @userIDs = $db->listSetUsers($setID);
	
	foreach my $userID (@userIDs) {
		$self->unassignSetFromUser($userID, $setID);
	}
}

=item assignAllSetsToUser($userID)

Assigns all sets in the course and all problems contained therein to the
specified user. This is more efficient than repeatedly calling
assignSetToUser(). If any assignments fail, a list of failure messages is
returned.

=cut

sub assignAllSetsToUser {
	my ($self, $userID) = @_;
	my $db = $self->{db};
	
	# assign only sets that are not already assigned
	#my %userSetIDs = map { $_ => 1 } $db->listUserSets($userID);
	#my @globalSetIDs = grep { not exists $userSetIDs{$_} } $db->listGlobalSets;
	#my @GlobalSets = $db->getGlobalSets(@globalSetIDs);
	# FIXME: i don't think we need to do the above, since asignSetToUser fails
	# silently if a UserSet already exists. instead we do this:
	# DBFIXME shouldn't need to get list of set IDs
	my @globalSetIDs = $db->listGlobalSets;
	my @GlobalSets = $db->getGlobalSets(@globalSetIDs);
	
	my @results;
	
	my $i = 0;
	foreach my $GlobalSet (@GlobalSets) {
		if (not defined $GlobalSet) {
			warn "record not found for global set $globalSetIDs[$i]";
		} else {
			my @result = $self->assignSetToUser($userID, $GlobalSet);
			push @results, @result if @result;
		}
		$i++;
	}
	
	return @results;
}

=item unassignAllSetsFromUser($userID)

Unassigns all sets and all problems contained therein from the specified user.

=cut

sub unassignAllSetsFromUser {
	my ($self, $userID) = @_;
	my $db = $self->{db};
	
	my @setIDs = $db->listUserSets($userID);
	
	foreach my $setID (@setIDs) {
		$self->unassignSetFromUser($userID, $setID);
	}
}

=back

=cut

################################################################################
# Utility assignment methods
################################################################################

=head2 Utility assignment methods

=over

=item assignSetsToUsers($setIDsRef, $userIDsRef)

Assign each of the given sets to each of the given users. If any assignments
fail, a list of failure messages is returned.

=cut

sub assignSetsToUsers {
	my ($self, $setIDsRef, $userIDsRef) = @_;
	my $db = $self->{db};
	
	my @setIDs = @$setIDsRef;
	my @userIDs = @$userIDsRef;
	my @GlobalSets = $db->getGlobalSets(@setIDs);
	
	my @results;
	
	foreach my $GlobalSet (@GlobalSets) {
		foreach my $userID (@userIDs) {
			my @result = $self->assignSetToUser($userID, $GlobalSet);
			push @results, @result if @result;
		}
	}
	
	return @results;
}

=item unassignSetsFromUsers($setIDsRef, $userIDsRef)

Unassign each of the given sets from each of the given users.

=cut

sub unassignSetsFromUsers {
	my ($self, $setIDsRef, $userIDsRef) = @_;
	my @setIDs = @$setIDsRef;
	my @userIDs = @$userIDsRef;
	
	foreach my $setID (@setIDs) {
		foreach my $userID (@userIDs) {
			$self->unassignSetFromUser($userID, $setID);
		}
	}
}

=item assignProblemToAllSetUsers($GlobalProblem)

Assigns the problem specified to all users to whom the problem's set is
assigned. If any assignments fail, a list of failure messages is returned.

=cut

sub assignProblemToAllSetUsers {
	my ($self, $GlobalProblem) = @_;
	my $db = $self->{db};
	my $setID = $GlobalProblem->set_id;
	my @userIDs = $db->listSetUsers($setID);
	
	my @results;
	
	foreach my $userID (@userIDs) {
		my @result = $self->assignProblemToUser($userID, $GlobalProblem);
		push @results, @result if @result;
	}
	
	return @results;
}

=back

=cut

################################################################################
# Utility method for adding problems to a set
################################################################################

=head2 Utility method for adding problems to a set

=over

=cut

sub addProblemToSet {
	my ($self, %args) = @_;
	my $db = $self->r->db;
	my $value_default = $self->{ce}->{problemDefaults}->{value};
	my $max_attempts_default = $self->{ce}->{problemDefaults}->{max_attempts};	
	my $showMeAnother_default = $self->{ce}->{problemDefaults}->{showMeAnother};	
    # showMeAnotherCount is the number of times that showMeAnother has been clicked; initially 0
	my $showMeAnotherCount = 0;	
	

	die "addProblemToSet called without specifying the set name." if $args{setName} eq "";
	my $setName = $args{setName};

	my $sourceFile = $args{sourceFile} or 
		die "addProblemToSet called without specifying the sourceFile.";

	# The rest of the arguments are optional
	
#	my $value = $args{value} || $value_default;
	my $value = $value_default;
	if (defined($args{value})){$value = $args{value};}  # 0 is a valid value for $args{value}  

	my $maxAttempts = $args{maxAttempts} || $max_attempts_default;
	my $showMeAnother = $args{showMeAnother} || $showMeAnother_default;
	my $problemID = $args{problemID};

	unless ($problemID) {
		$problemID = WeBWorK::Utils::max($db->listGlobalProblems($setName)) + 1;
	}

	my $problemRecord = $db->newGlobalProblem;
	$problemRecord->problem_id($problemID);
	$problemRecord->set_id($setName);
	$problemRecord->source_file($sourceFile);
	$problemRecord->value($value);
	$problemRecord->max_attempts($maxAttempts);
	$problemRecord->showMeAnother($showMeAnother);
	$problemRecord->{showMeAnotherCount}=$showMeAnotherCount;
	$db->addGlobalProblem($problemRecord);

	return $problemRecord;
}

=back

=cut

################################################################################
# Utility methods
################################################################################

=head2 Utility methods

=over

=cut

sub hiddenEditForUserFields {
	my ($self, @editForUser) = @_;
	my $return = "";
	foreach my $editUser (@editForUser) {
		$return .= CGI::input({type=>"hidden", name=>"editForUser", value=>$editUser});
	}
	
	return $return;
}

sub userCountMessage {
	my ($self, $count, $numUsers) = @_;
	
	my $message;
	if ($count == 0) {
		$message = CGI::em($self->r->maketext("no students"));
	} elsif ($count == $numUsers) {
		$message = $self->r->maketext("all students");
	} elsif ($count == 1) {
		$message = $self->r->maketext("1 student");
	} elsif ($count > $numUsers || $count < 0) {
		$message = CGI::em("an impossible number of users: $count out of $numUsers");
	} else {
		$message = $self->r->maketext("[_1] students out of [_2]", $count, $numUsers);
	}
	
	return $message;
}

sub setCountMessage {
	my ($self, $count, $numSets) = @_;
	my $r = $self->r;

	my $message;
	if ($count == 0) {
		$message = CGI::em($r->maketext("no sets"));
	} elsif ($count == $numSets) {
		$message = $r->maketext("all sets");
	} elsif ($count == 1) {
		$message = "1 ".$r->maketext("set");
	} elsif ($count > $numSets || $count < 0) {
		$message = CGI::em("an impossible number of sets: $count out of $numSets");
	} else {
		$message = $count." ".$r->maketext("sets");
	}
	
	return $message;
}

sub read_dir {  # read a directory
	my $self      = shift;
	my $directory = shift;
	my $pattern   = shift;
	my @files = grep /$pattern/, WeBWorK::Utils::readDirectory($directory); 
	return sort @files;
}

=back

=cut

################################################################################
# Methods for listing various types of files
################################################################################

=head2 Methods for listing various types of files

=over

=cut

# list classlist files
sub getCSVList {
	my ($self) = @_;
	my $ce = $self->{ce};
	my $dir = $ce->{courseDirs}->{templates};
	return grep { not m/^\./ and m/\.lst$/ and -f "$dir/$_" } WeBWorK::Utils::readDirectory($dir);
}

sub getDefList {
	my ($self) = @_;
	my $ce = $self->{ce};
	my $dir = $ce->{courseDirs}->{templates};
	return $self->read_dir($dir, qr/.*\.def/);
}

sub getScoringFileList {
	my ($self) = @_;
	my $ce = $self->{ce};
	my $dir = $ce->{courseDirs}->{scoring};
	return $self->read_dir($dir, qr/.*\.csv/);
}

sub getTemplateFileList {  # find all .pg files under the template tree (time consuming)
	my ($self) = shift;
	my $subDir = shift;
	my $ce = $self->{ce};
	$subDir = '' unless defined $subDir;
	my $dir = $ce->{courseDirs}->{templates}."/$subDir";
	# FIXME  currently allows one to see most files in the templates directory.  
	# a better facility for handling auxiliary files would be nice.
	return $self->read_dir($dir, qr/\.pg$|.*\.html|\.png|\.gif|\.txt|\.pl/);
}
sub getTemplateDirList {  # find all .pg files under the template tree (time consuming)
	my ($self) = @_;
	my $ce = $self->{ce};
	my $dir = $ce->{courseDirs}->{templates};
	my @list = ();
	my $wanted = sub { if (-d $_ ) { 
	                        my $current = $_;
	                        return if $current =~/CVS/;
	                        return if -l $current;   # don't list links
	                        my $name = $File::Find::name;
	                        $name = " Top" if $current =/^\./; #  top directory
							$name =~ s/^$dir\///;
							push @list, $name
					   }
	};
	File::Find::find($wanted, $dir);
	return sort @list;
}

=back

=cut

1;
