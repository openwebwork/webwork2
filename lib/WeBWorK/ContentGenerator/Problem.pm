package WeBWorK::ContentGenerator::Problem;
use base qw(WeBWorK::ContentGenerator);

use strict;
use warnings;
use CGI qw(:html :form);
use WeBWorK::Utils qw(ref2string);
use WeBWorK::PG;
use WeBWorK::Form;

# NEW form fields
# 
# user
# key
# 
# displayMode
# showOldAnswers
# showCorrectAnswers
# showHints
# showSolutions
# 
# submitAnswers - name of "Submit Answers" button

sub title {
	my ($self, $setName, $problemNumber) = @_;
	my $userName = $self->{r}->param('user');
	return "Problem $problemNumber of problem set $setName for $userName";
}

sub body {
	my ($self, $setName, $problemNumber) = @_;
	my $courseEnv = $self->{courseEnvironment};
	my $r = $self->{r};
	my $userName = $r->param('user');
	
	# fix format of setName and problem
	# (i want dennis to cut "set" and "prob" off before calling me)
	$setName =~ s/^set//;
	$problemNumber =~ s/^prob//;
	
	# get database information
	my $classlist = WeBWorK::DB::Classlist->new($courseEnv);
	my $wwdb = WeBWorK::DB::WW->new($courseEnv);
	my $user = $classlist->getUser($userName);
	my $set = $wwdb->getSet($userName, $setName);
	my $problem = $wwdb->getProblem($userName, $setName, $problemNumber);
	my $psvn = $wwdb->getPSVN($userName, $setName);
	
	# set options from form fields
	my $displayMode        = $r->param("displayMode")        || $courseEnv->{pg}->{options}->{displayMode};
	my $showOldAnswers     = $r->param("showOldAnswers")     || $courseEnv->{pg}->{options}->{showOldAnswers};
	my $showCorrectAnswers = $r->param("showCorrectAnswers") || $courseEnv->{pg}->{options}->{showCorrectAnswers};
	my $showHints          = $r->param("showHints")          || $courseEnv->{pg}->{options}->{showHints};
	my $showSolutions      = $r->param("showSolutions")      || $courseEnv->{pg}->{options}->{showSolutions};
	my $processAnswers     = $r->param("submitAnswers");
	
	# coerce form fields into CGI::Vars format
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	# TODO:
	# 1. enforce privs for showCorrectAnswers and showSolutions
	#    (use $PRIV = $canPRIV && $wantPRIV -- cool syntax!)
	# 2. if answers were not submitted and there are student answers in the DB,
	#    decode them and put them into $formFields for the translator
	# 3. Latex2HTML massaging code
	# 4. store submitted answers hash in database for sticky answers
	# 5. deal with the results of answer evaluation and grading :p
	# 6. introduce a recordAnswers option, which works on the same principle as
	#    the other priv-based options
	
	my $pg = WeBWorK::PG->new(
		$courseEnv,
		$r->param('user'),
		$r->param('key'),
		$setName,
		$problemNumber,
		{ # translation options
			displayMode    => $displayMode,
			showHints      => $showHints,
			showSolutions  => $showSolutions,
			processAnswers => $processAnswers,
		},
		$formFields
	);
	
#	return (
#		h1("Problem.pm"),
#		table(
#			Tr(td("user"),    td($r->param('userName'))),
#			Tr(td("key"),     td($r->param('key'))),
#			Tr(td("set"),     td($setName)),
#			Tr(td("problem"), td($problemNumber)),
#		),
#		#pre(hash2string($pg, 0)),
#		hash2string($pg, 1),
#	);
	
	# View options form
	print startform("POST", $r->uri);
	print $self->hidden_authen_fields;
	print p("View equations as: ",
		radio_group(
			-name    => "displayMode",
			-values  => ['plainText', 'formattedText', 'images'],
			-default => $displayMode,
			-labels  => {
				plainText     => "plain text",
				formattedText => "formatted text",
				images        => "images",
			}
		), br(),
		checkbox(
			-name    => "showOldAnswers",
			-checked => $showOldAnswers,
			-label   => "Show old answers",
		), br(),
		submit(-name=>'redisplay')
	);
	print endform();
	print hr();
	
	# Previous answer results
	
	
	# Problem form
	print startform("POST", $r->uri);
	print $self->hidden_authen_fields;
	print p($pg->{body_text});
	print p(submit(-name=>"submitAnswers", -label=>"Submit Answers"));
	print endform();
	print hr();
	
	# debugging stuff
	print h2("debugging information");
	print h3("form fields");
	print ref2string($formFields);
	print h3("PG object");
	print ref2string($pg, {'WeBWorK::PG::Translator' => 1});
	
	return "";
}

1;
