################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::ProblemSet;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::ProblemSet - display an index of the problems in a 
problem set.

=cut

use strict;
use warnings;
use CGI qw();

sub initialize {
	my ($self, $setName) = @_;
	my $courseEnvironment = $self->{ce};
	my $r = $self->{r};
	my $db = $self->{db};
	my $userName = $r->param("user");
	my $effectiveUserName = $r->param("effectiveUser");
	
	my $user            = $db->getUser($userName);
	my $effectiveUser   = $db->getUser($effectiveUserName);
	my $set             = $db->getGlobalUserSet($effectiveUserName, $setName);
	my $permissionLevel = $db->getPermissionLevel($userName)->permission();
	
	$self->{userName}        = $userName;
	$self->{user}            = $user;
	$self->{effectiveUser}   = $effectiveUser;
	$self->{set}             = $set;
	$self->{permissionLevel} = $permissionLevel;
	
	##### permissions #####
	
	$self->{isOpen} = time >= $set->open_date || $permissionLevel > 0;
}

sub path {
	my ($self, $setName, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		$setName => "",
	);
}

sub nav {
	my ($self, $setName, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my @links = ("Problem Sets" , "$root/$courseName", "navUp");
	my $tail = "";
	
	return $self->navMacro($args, $tail, @links);
}
	

sub siblings {
	my ($self, $setName) = @_;
	
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	print CGI::strong("Problem Sets"), CGI::br();
	
	my $effectiveUser = $self->{r}->param("effectiveUser");
	my @sets;
	push @sets, $db->getGlobalUserSet($effectiveUser, $_)
		foreach ($db->listUserSets($effectiveUser));
	foreach my $set (sort { $a->open_date <=> $b->open_date } @sets) {
		if (time >= $set->open_date) {
			print CGI::a({-href=>"$root/$courseName/".$set->set_id."/?"
				. $self->url_authen_args}, $set->set_id), CGI::br();
		} else {
			print $set->set_id, CGI::br();
		}
	}
}

sub title {
	my ($self, $setName) = @_;
	
	return $setName;
}

sub info {
	my ($self, $setName) = @_;
	
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	
	return "" unless $self->{isOpen};
	
	my $effectiveUser = $db->getUser($r->param("effectiveUser"));
	my $set  = $db->getGlobalUserSet($effectiveUser->user_id, $setName);
	my $psvn = $set->psvn();
	
	my $screenSetHeader = $set->problem_header || $ce->{webworkFiles}->{screenSnippets}->{setHeader};
	my $displayMode     = $ce->{pg}->{options}->{displayMode};
	
	return "" unless defined $screenSetHeader and $screenSetHeader;
	
	# decide what to do about problem number
	my $problem = WeBWorK::DB::Record::UserProblem->new(
		problem_id => 0,
		set_id => $set->set_id,
		login_id => $effectiveUser->user_id,
		source_file => $screenSetHeader,
		# the rest of Problem's fields are not needed, i think
	);
	
	my $pg = WeBWorK::PG->new(
		$ce,
		$effectiveUser,
		$r->param('key'),
		$set,
		$problem,
		$psvn,
		{}, # no form fields!
		{ # translation options
			displayMode     => $displayMode,
			showHints       => 0,
			showSolutions   => 0,
			processAnswers  => 0,
		},
	);
	
	# handle translation errors
	if ($pg->{flags}->{error_flag}) {
		return $self->errorOutput($pg->{errors}, $pg->{body_text});
	} else {
		return $pg->{body_text};
	}
}

sub body {
	my ($self, $setName) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{ce};
	my $db = $self->{db};
	my $effectiveUser = $r->param('effectiveUser');
	
	return CGI::p(CGI::font({-color=>"red"}, "This problem set is not available because it is not yet open."))
		unless ($self->{isOpen});
	
	my $hardcopyURL =
		$courseEnvironment->{webworkURLs}->{root} . "/"
		. $courseEnvironment->{courseName} . "/"
		. "hardcopy/$setName/?" . $self->url_authen_args;
	print CGI::p(CGI::a({-href=>$hardcopyURL}, "Download a hardcopy"),
		"of this problem set.");
	
	print CGI::start_table();
	print CGI::Tr(
		CGI::th("Name"),
		CGI::th("Attempts"),
		CGI::th("Remaining"),
		CGI::th("Status"),
	);
	
	my $set = $db->getGlobalUserSet($effectiveUser, $setName);
	my @problemNumbers = $db->listUserProblems($effectiveUser, $setName);
	foreach my $problemNumber (sort { $a <=> $b } @problemNumbers) {
		my $problem = $db->getGlobalUserProblem($effectiveUser, $setName, $problemNumber);
		print $self->problemListRow($set, $problem);
	}
	
	print CGI::end_table();
	
	# feedback form
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $feedbackURL = "$root/$courseName/feedback/";
	print
		CGI::startform("POST", $feedbackURL),
		$self->hidden_authen_fields,
		CGI::hidden("module", __PACKAGE__),
		CGI::hidden("set",    $set->set_id),
		CGI::p({-align=>"right"},
			CGI::submit(-name=>"feedbackForm", -label=>"Send Feedback")
		),
		CGI::endform();
	
	return "";
}

sub problemListRow($$$) {
	my $self = shift;
	my $set = shift;
	my $problem = shift;
	
	my $name = $problem->problem_id;
	my $interactiveURL = "$name/?" . $self->url_authen_args;
	my $interactive = CGI::a({-href=>$interactiveURL}, "Problem $name");
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	my $remaining = $problem->max_attempts < 0
		? "unlimited"
		: $problem->max_attempts - $attempts;
	my $status = sprintf("%.0f%%", $problem->status * 100); # round to whole number
	
	return CGI::Tr(CGI::td({-nowrap=>1}, [
		$interactive,
		$attempts,
		$remaining,
		$status,
	]));
}

1;
