#!/usr/local/bin/perl   -w

package RQP::Render;
@ISA = qw( RQP );
use WebworkWebservice;
use WeBWorK::Utils::Tasks qw(fake_set fake_problem);

our $WW_DIRECTORY = $WebworkWebservice::WW_DIRECTORY;
our $PG_DIRECTORY = $WebworkWebservice::PG_DIRECTORY;
our $COURSENAME   = $WebworkWebservice::COURSENAME;
our $HOST_NAME    = $WebworkWebservice::HOST_NAME;
our $HOSTURL      ="http://$HOST_NAME:8002"; #FIXME
our $ce           =$WebworkWebservice::SeedCE;
# create a local course environment for some course
    $ce           = WeBWorK::CourseEnvironment->new($WW_DIRECTORY, "", "", $COURSENAME);
#print "\$ce = \n", WeBWorK::Utils::pretty_print_rh($ce);
our $db = WeBWorK::DB->new($ce->{dbLayout});

sub RQP_Render  {
	my $class = shift;
	my $soap_som = pop;
	my $rh_params= $soap_som->method;

	local(*DEBUGLOG);
    open DEBUGLOG, ">>/home/gage/debug_info.txt" || die "can't open debug file";
	print DEBUGLOG "--RQP_Render\n";
	#my $output = WebworkWebservice::pretty_print_rh(\%parameters);
	my $source = $rh_params->{source};
	$source =~s/</&lt;/g;
	$source =~s/>/&gt;/g;
	my $output = "the first element is ". $self. " and the last ". ref($envelope)."\n\n";
	$output .= WebworkWebservice::pretty_print_rh($rh_params);
	
	my %templatevars = @{$rh_params->{templatevars}};
	my $templatevars =\%templatevars;
	print DEBUGLOG "templateVars (", join("|", @{$rh_params->{templateVars}}),")\n";

	#############
	# Default environment
	#############
	my $userName    = "foobar";
	my $user        = $db->getUser($userName);
	my $key         = "asdfasdfasdf";
	
	my $problemNumber =  (defined($templatevars->{envir}->{probNum})   )    ? $templatevars->{envir}->{probNum}      : 1 ;
	my $problemSeed   =  (defined($templatevars->{envir}->{problemSeed}))   ? $templatevars->{envir}->{problemSeed}  : 1 ;
	my $psvn          =  (defined($templatevars->{envir}->{psvn})      )    ? $templatevars->{envir}->{psvn}         : 1234 ;
	my $problemStatus =  $templatevars->{problem_state}->{recorded_score}|| 0 ;
	my $problemValue  =  (defined($templatevars->{envir}->{problemValue}))   ? $templatevars->{envir}->{problemValue}  : 1 ;
	my $num_correct   =  $templatevars->{problem_state}->{num_correct}   || 0 ;
	my $num_incorrect =  $templatevars->{problem_state}->{num_incorrect} || 0 ;
	my $problemAttempted = ($num_correct && $num_incorrect);
	my $lastAnswer    = '';
	########
	# set
	########
	my $setRecord        = initializeDefaultSet($db);
	
	########
	# problem
	########
	my $problemRecord    = initializeDefaultProblem($db);

	

	my $formFields  = {};
	my $translationOptions = {};
	my $rh_envir = WeBWorK::PG::defineProblemEnvir(
		$class,    
		$ce,
		$user,
		$key,
		$setRecord,
		$problemRecord,
		$setRecord->psvn,
		$formFields,
		$translationOptions,
	);
	
	$templatevars->{envir} = $rh_envir;
	#hack -- root is a restricted term
	$templatevars->{envir}->{__files__} = '';
	$templatevars->{envir}->{problemSeed}++;

	##############
	my @templatevars = %$templatevars;
	my $rh_out = {
		templateVars     => packRQParray($templatevars),
		index            => 'index',
		advanceState     => 0,
		embedPrefix      => 'AnSwErAnSwEr',
		appletBase       => 'unknown',
		mediaBase        => 'unknown url',
		renderFormat     => 'HTML',
		modalFormat      => 'dvipng',
		persistentData   => 'this is a string',
		outcomeVars      => [{identifier=>'id',values=>345}],
		output           => packRQParray($output),
		source           => $source,
		input            => '<hr>'.WebworkWebservice::pretty_print_rh($rh_params).'<hr>',
	
	};
	print DEBUGLOG $output;
	close(DEBUGLOG);
	return $rh_out;

}
sub packRQParray {
	my $rh_hash=shift;
	my @array = ();
	foreach $key (keys %{$rh_hash}) {
		push @array, {identifier => $key, values => $rh_hash->{$key}};
	}
	\@array;
}
sub initializeDefaultSet {
	my $db = shift;

	my $setName       = 'set0';
	my $setRecord   = fake_set($db);
	$setRecord->set_id($setName);
	$setRecord->set_header("defaultHeader");
	$setRecord->hardcopy_header("defaultHeader");
	$setRecord->open_date(time()-60*60*24*7); #  one week ago
	$setRecord->due_date(time()+60*60*24*7*2); # in two weeks
	$setRecord->answer_date(time()+60*60*24*7*3); # in three weeks
	$setRecord->psvn(0);
	$setRecord;
}

sub initializeDefaultProblem {
		my $db                = shift;
		my $userName             = 'foobar';
		my $problemNumber        = 0;
		my $setName              = 'set0';
		my $problemRecord        = fake_problem($db);
		$problemRecord->user_id($userName);
		$problemRecord->problem_id(0);
		$problemRecord->set_id($setName);
		$problemRecord->problem_seed(0);
		$problemRecord->status(0);
		$problemRecord->value(1);
		$problemRecord->attempted(0);
		$problemRecord->last_answer('');
		$problemRecord->num_correct(0);
		$problemRecord->num_incorrect(0);
		$problemRecord;

}
1;