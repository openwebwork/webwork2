################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::ProblemSet;

=head1 NAME

WeBWorK::ContentGenerator::ProblemSet - display an index of the problems in a 
problem set.

=cut

use strict;
use warnings;
use base qw(WeBWorK::ContentGenerator);
use Apache::Constants qw(:common);
use CGI qw();
use WeBWorK::ContentGenerator;
use WeBWorK::DB::WW;
use WeBWorK::DB::Classlist;

sub initialize {
	my ($self, $setName) = @_;
	my $courseEnvironment = $self->{courseEnvironment};
	my $r = $self->{r};
	my $userName = $r->param("user");
	my $effectiveUserName = $r->param("effectiveUser");
	
	##### database setup #####
	
	my $cldb   = WeBWorK::DB::Classlist->new($courseEnvironment);
	my $wwdb   = WeBWorK::DB::WW->new($courseEnvironment);
	my $authdb = WeBWorK::DB::Auth->new($courseEnvironment);
	
	my $user            = $cldb->getUser($userName);
	my $effectiveUser   = $cldb->getUser($effectiveUserName);
	my $set             = $wwdb->getSet($effectiveUserName, $setName);
	my $permissionLevel = $authdb->getPermissions($userName);
	
	$self->{cldb} = $cldb;
	$self->{wwdb} = $wwdb;
	$self->{authdb} = $authdb;
	
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
	
	my $ce = $self->{courseEnvironment};
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
	
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my @links = ("Problem Sets" , "$root/$courseName", "navUp");
	my $tail = "";
	
	return $self->navMacro($args, $tail, @links);
}
	

sub siblings {
	my ($self, $setName) = @_;
	
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	print CGI::strong("Problem Sets"), CGI::br();
	
	my $wwdb = $self->{wwdb};
	my $effectiveUser = $self->{r}->param("effectiveUser");
	my @sets;
	push @sets, $wwdb->getSet($effectiveUser, $_) foreach ($wwdb->getSets($effectiveUser));
	foreach my $set (sort { $a->open_date <=> $b->open_date } @sets) {
		if (time >= $set->open_date) {
			print CGI::a({-href=>"$root/$courseName/".$set->id."/?"
				. $self->url_authen_args}, $set->id), CGI::br();
		} else {
			print $set->id, CGI::br();
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
	my $ce = $self->{courseEnvironment};
	
	return "" unless $self->{isOpen};
	
	my $wwdb = $self->{wwdb};
	my $cldb = $self->{cldb};
	my $effectiveUser = $cldb->getUser($r->param("effectiveUser"));
	my $set  = $wwdb->getSet($effectiveUser->id, $setName);
	my $psvn = $wwdb->getPSVN($effectiveUser->id, $setName);
	
	my $screenSetHeader = $set->problem_header || $ce->{webworkFiles}->{screenSnippets}->{setHeader};
	my $displayMode     = $ce->{pg}->{options}->{displayMode};
	
	return "" unless defined $screenSetHeader and $screenSetHeader;
	
	# decide what to do about problem number
	my $problem = WeBWorK::Problem->new(
		id => 0,
		set_id => $set->id,
		login_id => $effectiveUser->id,
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
	my $courseEnvironment = $self->{courseEnvironment};
	my $effectiveUser = $r->param('effectiveUser');
	my $wwdb = $self->{wwdb};
	
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
	
	my $set = $wwdb->getSet($effectiveUser, $setName);
	my @problemNumbers = $wwdb->getProblems($effectiveUser, $setName);
	foreach my $problemNumber (sort { $a <=> $b } @problemNumbers) {
		my $problem = $wwdb->getProblem($effectiveUser, $setName, $problemNumber);
		print $self->problemListRow($set, $problem);
	}
	
	print CGI::end_table();
	
	# feedback form
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $feedbackURL = "$root/$courseName/feedback/";
	print
		CGI::startform("POST", $feedbackURL),
		$self->hidden_authen_fields,
		CGI::hidden("module", __PACKAGE__),
		CGI::hidden("set",    $set->id),
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
	
	my $name = $problem->id;
	my $interactiveURL = "$name/?" . $self->url_authen_args;
	my $interactive = CGI::a({-href=>$interactiveURL}, "Problem $name");
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	my $remaining = $problem->max_attempts < 0
		? "unlimited"
		: $problem->max_attempts - $attempts;
	my $status = $problem->status * 100 . "%";
	
	return CGI::Tr(CGI::td({-nowrap=>1}, [
		$interactive,
		$attempts,
		$remaining,
		$status,
	]));
}

1;
