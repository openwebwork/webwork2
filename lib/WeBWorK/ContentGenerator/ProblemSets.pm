package WeBWorK::ContentGenerator::ProblemSets;
our @ISA = qw(WeBWorK::ContentGenerator);

use strict;
use warnings;
use Apache::Constants qw(:common);
use CGI qw();
use WeBWorK::ContentGenerator;
use WeBWorK::DB::WW;
use WeBWorK::Utils qw(formatDateTime);

sub initialize {
	my $self = shift;
	my $courseEnvironment = $self->{courseEnvironment};
	
	# Open a database connection that we can use for the rest of
	# the content generation.
	
	my $wwdb = new WeBWorK::DB::WW $courseEnvironment;
	$self->{wwdb} = $wwdb;
}

sub title {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');

	return "Problem Sets for $user";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');
	my $wwdb = $self->{wwdb};
	
#	if (!defined $wwdb->getSets($user)) {
#		print "undefined".CGI::br();
#	}
	
	print CGI::startform(-method=>"POST", -action=>$r->uri);
	print CGI::start_table();
	print CGI::Tr(
		CGI::th(""),
		CGI::th("Name"),
		CGI::th("Status"),
		CGI::th({-colspan=>2}, "Actions"),
	);
	
	my @setNames = $wwdb->getSets($user);
	foreach my $setName (sort @setNames) {
		my $set = $wwdb->getSet($user, $setName);
		print setListRow($set);
	}
	
	print CGI::end_table();
	print CGI::endform();
	
	return "";
	
#	print "Set Names", CGI::br(), "\n";
#	print join(CGI::br()."\n", sort @setNames);
#	print CGI::p();
#	
#	print CGI::startform({-method=>"POST", -action=>$r->uri."set0/"});
#	print $self->hidden_authen_fields;
#	print CGI::input({-type=>"submit", -value=>"Do Set 0"});
#	print CGI::endform();
#	"";
}

sub setListRow($) {
	my $set = shift;
	
	my $name = $set->id;
	
	my $openDate = formatDateTime($set->open_date);
	my $dueDate = formatDateTime($set->due_date);
	my $answerDate = formatDateTime($set->answer_date);
	
	my $checkbox = CGI::checkbox(-name=>"set", -value=>$set->id, -label=>"");
	my $interactive = CGI::submit("", "do problem set");
	my $hardcopy = CGI::submit("", "get hard copy");
	
	my $status;
	if (time < $set->open_date) {
		$status = "opens at $openDate";
		$checkbox = "";
		$interactive = "";
		$hardcopy = "";
	} elsif (time < $set->due_date) {
		$status = "open, due at $dueDate";
	} elsif (time < $set->answer_date) {
		$status = "closed, answers at $answerDate";
	} else {
		$status = "closed, answers available";
	}
	
	return CGI::Tr(CGI::td([
		$checkbox,
		$name,
		$status,
		$interactive,
		$hardcopy,
	]));
}

1;
