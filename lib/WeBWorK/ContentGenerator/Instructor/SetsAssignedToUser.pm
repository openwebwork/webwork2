################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SetsAssignedToUsers - List and edit which
sets are assigned to a given user.

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(formatDateTime);

sub initialize {
	my ($self, $userID) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $authz = $self->{authz};
	my $user = $r->param("user");
	
	# check authorization
	unless ($authz->hasPermissions($user, "assign_problem_sets")) {
		$self->{submitError} = "You are not authorized to assign problem sets";
		return;
	}
	
	if (defined $r->param("assignToAll")) {
		$self->assignAllSetsToUser($userID);
	} elsif (defined $r->param("unassignFromAll")) {
		$self->unassignAllSetsFromUser($userID);
	} elsif (defined $r->param('assignToSelected')) {
		# get list of all sets and a hash for checking selectedness
		my @setIDs = $db->listGlobalSets;
		my %selectedSets = map { $_ => 1 } $r->param("selected");
		
		# get current user
		my $User = $db->getUser($userID);
		die "record not found for $userID.\n" unless $User;
		
		# go through each possible set
		foreach my $setID (@setIDs) {
			# does the user want it to be assigned to the selected user
			if (exists $selectedSets{$setID}) {
				# user asked to have the set assigned to the selected user
				my $Set = $db->getGlobalSet($setID);
				if ($Set) {
					$self->assignSetToUser($userID, $Set);
				} else {
					warn "global set $setID appeared in listGlobalSets() but does not exist.\n"
				}
			} else {
				# user asked to NOT have the set assigned to the selected user
				# this will unassign it if it is assigned
				$db->deleteUserSet($userID, $setID);
			}
		}
	}
}

sub getUserName {
	my ($self, $pathUserName) = @_;
	
	if (ref $pathUserName eq "HASH") {
		$pathUserName = undef;
	}
	
	return $pathUserName;
}

sub path {
	my $self          = shift;
    my @components    = @_;
	my $args          = $_[-1];
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $userID = $self->getUserName($components[0]);
	
	return $self->pathMacro($args,
		"Home"             => "$root",
		$courseName        => "$root/$courseName",
		"Instructor Tools" => "$root/$courseName/instructor",
		"Users"            => "$root/$courseName/instructor/users/",
		$userID            => "$root/$courseName/instructor/users/$userID",
		"Assigned Sets"    => "", # "$root/$courseName/instructor/users/$userID/sets"
	);
}

sub title {
	my ($self, @components) = @_;
	my $userID = $self->getUserName($components[0]);
	
	return "Assigned Sets";
}

sub body {
	my ($self, $userID) = @_;
	my $r = $self->{r};
	my $authz = $self->{authz};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $webworkRoot = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $user = $r->param('user');
	
	# check authorization
	return CGI::em("You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	# get list of sets
	my @setIDs = $db->listGlobalSets;
	my @Sets = $db->getGlobalSets(@setIDs);
	
	# sort first by open date and then by name (this should be replaced with a
	# call to a standard sorting routine!)
	@Sets = sort {
		$a->open_date <=> $b->open_date
		|| lc($a->set_id) cmp lc($b->set_id)
	} @Sets;
	
	print CGI::start_form({method=>"post", action=>$r->uri});
	print $self->hidden_authen_fields;
	
	print CGI::p(
		CGI::submit({name=>"assignToAll", value=>"Assign all sets"}),
		CGI::submit({name=>"unassignFromAll", value=>"Unassign all sets"}),
	);
	
	print CGI::start_table({});
	
	foreach my $Set (@Sets) {
		my $setID = $Set->set_id;
		my $prettyName = formatDateTime($Set->open_date);
		
		# this is true if $Set is assigned to the selected user
		my $currentlyAssigned = defined $db->getUserSet($userID, $setID);
		
		# URL to edit user-specific set data
		my $url = $ce->{webworkURLs}->{root}
			. "/$courseName/instructor/sets/$setID/?editForUser=$userID&"
			. $self->url_authen_args();
		
		print CGI::Tr({}, 
			CGI::td({}, [
				CGI::checkbox({
					type=>"checkbox",
					name=>"selected",
					checked=>$currentlyAssigned,
					value=>$setID,
					label=>"",
				}),
				$setID,
				"($prettyName)",
				" ",
				$currentlyAssigned
					? CGI::a({href=>$url}, "Edit user-specific set data")
					: (),
			])
		);
	}
	print CGI::end_table();
	print CGI::submit({name=>"assignToSelected", value=>"Save"});
	print CGI::end_form();
	
	return "";
}

1;
