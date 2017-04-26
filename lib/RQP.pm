#!/usr/local/bin/perl   -w


use SOAP::Lite +trace; 
#+trace =>
#[parameters,trace=>sub{ local($|=1); print LOG "start>>", 
#WebworkWebservice::pretty_print_rh(\@_ ),"<<stop\n\n"; }];



use WebworkWebservice;
package RQP;
@ISA =   (SOAP::Server::Parameters);
local(*MYLOG);

use WeBWorK::Utils::Tasks qw(fake_set fake_problem);
use RQP::Render;

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

#print MYLOG "restarting server\n\n";
sub test {
	open MYLOG, ">>/home/gage/debug_info.txt" ;
	local($|=1);
	my $som = pop;
	my $self = shift;
	my $rh_parameter = $som->method;
	#$som->match('/');
	#print MYLOG "headers\n", WebworkWebservice::pretty_print_rh($rh_parameter),"\n";
	#warn "parameters ", WebworkWebservice::pretty_print_rh($rh_parameter);
	#my $params = $som->paramsall();
	#warn "params ", join(" ", @{$params});
	print MYLOG "body ", WebworkWebservice::pretty_print_rh($som->body);
	close(MYLOG);
	return "test hi bye";
}

sub RQP_ServerInformation {
	my $class = shift;
	my $soap_som = pop;
	my $rh_params= $soap_som->method;
	local(*DEBUGLOG);
    open DEBUGLOG, ">>/home/gage/debug_info.txt" || die "can't open debug file";
	print DEBUGLOG "--RQP_ServerInformation\n";

	$rh_out = { 'identifier'       => 'http://www.openwebwork.org',
                 'name'            => 'WeBWorK',
                 'description'     => 'WeBWorK server.  See http://webwork.math.rochester.edu',
                 'cloning'         => 0,
                 'implicitCloning' => 1,
                 'rendering'       => 1,
                 'itemFormats'     => ['pg'],
                 'renderFormats'   => ['xml'],
                 input            => '<hr>'.WebworkWebservice::pretty_print_rh($rh_params).'<hr>',
	};
	return $rh_out;
}

sub RQP_ItemInformation {
	my $class = shift;
	my $soap_som = pop;
	my $rh_params= $soap_som->method;
	local(*DEBUGLOG);
    open DEBUGLOG, ">>/home/gage/debug_info.txt" || die "can't open debug file";
    print DEBUGLOG "--RQP_ItemInformation\n";
	my $format = 'HTML';
	my $sourceErrors = ''; 
	$rh_out = {
	    'format'            => $format,
       'sourceErrors'       => $sourceErrors,
       'template'           => 1,
       'adaptive'           => 1,
       'timeDependent'      => 0,
       'canComputeScore'   => 1,
       'solutionAvailable'  => 0,
       'hintAvailable'      => 0,
       'validationPossible' => 1,
       'maxScore'           => 1,
       'length'             => 1,
       input                => '<hr>'.WebworkWebservice::pretty_print_rh($rh_params).'<hr>',
	};
	close(DEBUGLOG);
	return $rh_out;
}

sub RQP_ProcessTemplate {


}

sub RQP_Clone  {

}
sub RQP_SessionInformation {
	my $class = shift;
	my $soap_som = pop;
	my $rh_params= $soap_som->method;
	local(*DEBUGLOG);
    open DEBUGLOG, ">>/home/gage/debug_info.txt" || die "can't open debug file";
	print DEBUGLOG "--RQP_SessionInformation\n";
	my $templatevars = $rh_params->{templatevars};
	$templatevars->{seed}=4321;
	my $correctResponses = [];
	$rh_out = {
		'outcomevars'      => {id=>45},
		'templatevars'     => $templatevars,
		'correctResponses' => $correctResponses,
		input              => '<hr>'.WebworkWebservice::pretty_print_rh($rh_params).'<hr>',
	};
	close(DEBUGLOG);
	return $rh_out;
}


sub RQP_Render  {
	RQP::Render::RQP_Render(@_);

}


1;
