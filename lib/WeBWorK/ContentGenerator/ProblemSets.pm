package WeBWorK::ContentGenerator::ProblemSets;
our @ISA = qw(WeBWorK::ContentGenerator);

use strict;
use warnings;
use WeBWorK::ContentGenerator;
use WeBWorK::DB::WW;
use Apache::Constants qw(:common);
use CGI qw();

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
	
	if (!defined $wwdb->getSets($user)) {
		print "undefined".CGI->br();
	}
	
	my @setNames = $wwdb->getSets($user);
	
	print "Set Names", CGI->br(), "\n";
	print join(CGI->br()."\n", @setNames);
	print CGI->p();
	
	print CGI->startform({-method=>"POST", -action=>$r->uri."set0/"});
	print $self->hidden_authen_fields;
	print CGI->input({-type=>"submit", -value=>"Do Set 0"});
	print CGI->endform();
	"";
}

1;
