### PastAnswer routes
##
#  These are the routes for related problem set functions in the RESTful webservice
#
##

package PastAnswers;

use strict;
use warnings;
use Dancer ':syntax';
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;

our $PERMISSION_ERROR = "You don't have the necessary permissions.";

##
#  use this to fill the _past_answer database from answer_log
#
#  pstaab: this isn't robust right now.  

get '/courses/:course_id/pastanswers/database' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}

	my $answerLog = vars->{ce}->{webworkDirs}{courses} ."/" . params->{course_id} . "/logs/answer_log";

	return $answerLog;

	my $i =0; 
	open (LOG, $answerLog);
	while (<LOG>) {
		chomp;
	 	my @line = split(/\|/,$_);
	 	my $userID = $line[1];
	 	my $setID = $line[2];
	 	my $problemID = $line[3];
	 	my @tmp = split(/\t/,$line[4]); 
	 	my $scores = shift(@tmp);
	 	my $timestamp = shift(@tmp);
	 	my $answerString = join("\t",@tmp);

	 	my $globalProblem = vars->{db}->getGlobalProblem($setID,$problemID);

	 	my $pastAnswer = vars->{db}->newPastAnswer;

	    $pastAnswer->{course_id} = params->{course_id};
	    $pastAnswer->{user_id} = $userID;
	    $pastAnswer->{set_id} = $setID;
	    $pastAnswer->{problem_id} = $problemID;
	    $pastAnswer->{source_file} = $globalProblem->{source_file};
	    $pastAnswer->{timestamp} = $timestamp;
	    $pastAnswer->{scores} = $scores; 
        $pastAnswer->{answer_string} = $answerString;
	   
	 	vars->{db}->addPastAnswer($pastAnswer);

	}
	close (LOG);

	return $answerLog;


};

get '/courses/:course_id/users/:user_id/sets/:set_id/problems/:problem_id/pastanswers' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}

	my @answerIDs = vars->{db}->listProblemPastAnswers(params->{course_id},params->{user_id},
									params->{set_id},params->{problem_id});

	my @pastAnswers = vars->{db}->getPastAnswers(\@answerIDs);

	return convertArrayOfObjectsToHash(\@pastAnswers);
};
