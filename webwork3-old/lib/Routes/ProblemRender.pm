### Course routes
##
#  These are the routes for all /course URLs in the RESTful webservice
#
##

package Routes::ProblemRender;

use strict;
use warnings;
use Dancer ':syntax';
use Routes qw/convertObjectToHash/;
use WeBWorK::Utils::Tasks qw(fake_user fake_set fake_problem);
use WeBWorK::PG::Local;


prefix '/problems';


###
#
#  General problem renderer.  (Adapted from WeBWorK::Utils::Tasks::RenderProblem)
#
###

get '/:problem_id' => sub {

	if( ! session 'logged_in'){
		return { error=>"You need to login in again."};
	}

	if (0+(session 'permission') < 10) {
		return {error=>"You don't have the necessary permission"};
	}

	my $displayMode = param('displayMode') || vars->{ce}->{pg}{options}{displayMode};
	my $user = param('user') || fake_user(vars->{db});
	my $set = param('set_id') || fake_set(vars->{db});
	my $problem_seed = param('problem_seed') || 0;
	my $showHints = param('showHints') || 0;
	my $showSolutions = param('showSolutions') || 0;
	my $problemNumber = param('problem_number') || 1;
	my $key = param('key');

	# remove any pretty garbage around the problem
	local vars->{ce}->{pg}{specialPGEnvironmentVars}{problemPreamble} = {TeX=>'',HTML=>''};
	local vars->{ce}->{pg}{specialPGEnvironmentVars}{problemPostamble} = {TeX=>'',HTML=>''};
	
	my $problem = fake_problem(vars->{db}, 'problem_seed'=>$problem_seed);
	$problem->{value} = 0.5;
	$problem->problem_id($problemNumber++);
	$problem->source_file('test');
	
	#$problem->{source_file} = 'test';

	


	my $translationOptions = {
		displayMode     => $displayMode,
		showHints       => $showHints,
		showSolutions   => $showSolutions,
		refreshMath2img => 0,
		processAnswers  => 0,
	};
	
	
	my $pg = WeBWorK::PG::Local->new(
		vars->{ce},
		$user,
		$key,
		$set,
		$problem,
		123, # PSVN (practically unused in PG)
		0,
		$translationOptions,
    );	
};


1;
