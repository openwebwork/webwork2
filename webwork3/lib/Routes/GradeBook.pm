### ProblemSet routes
##
#  These are the routes for related GradeBook functions in the RESTful webservice
#
##

package Routes::GradeBook;

use strict;
use warnings;
use Dancer ':syntax';
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash convertBooleans/;
use Utils::ProblemSets qw/reorderProblems addGlobalProblems addUserSet addUserProblems deleteProblems createNewUserProblem/;
use WeBWorK::Utils qw/parseDateTime decodeAnswers/;
use Array::Utils qw(array_minus); 
use Routes::Authentication qw/checkPermissions setCourseEnvironment/;
use Utils::CourseUtils qw/getCourseSettings/;
use Dancer::Plugin::Database;
use Dancer::Plugin::Ajax;
use List::Util qw/first max/;

our @set_props = qw/set_id set_header hardcopy_header open_date reduced_scoring_date due_date answer_date visible enable_reduced_scoring assignment_type attempts_per_version time_interval versions_per_interval version_time_limit version_creation_time version_last_attempt_time problem_randorder hide_score hide_score_by_problem hide_work time_limit_cap restrict_ip relax_restrict_ip restricted_login_proctor/;
our @user_set_props = qw/user_id set_id psvn set_header hardcopy_header open_date reduced_scoring_date due_date answer_date visible enable_reduced_scoring assignment_type description restricted_release restricted_status attempts_per_version time_interval versions_per_interval version_time_limit version_creation_time problem_randorder version_last_attempt_time problems_per_page hide_score hide_score_by_problem hide_work time_limit_cap restrict_ip relax_restrict_ip restricted_login_proctor hide_hint/;
our @user_props = qw/first_name last_name student_id user_id email_address permission status section recitation comment/;
our @problem_props = qw/problem_id flags value max_attempts source_file/;
our @boolean_set_props = qw/visible enable_reduced_scoring/;

###
#  return all problem sets (as objects) for course *course_id* 
#
#  User user must have at least permissions>=10
#
##

get '/courses/:course_id/gradebook' => sub {

    checkPermissions(10,session->{user});

    my $result1={};
    
    my @userIDs = vars->{db}->listUsers();
    for my $userID (@userIDs){
        $result1->{$userID}{user_id} = $userID;
        my @userSets = vars->{db}->listUserSets($userID);
        for my $userSet (@userSets){
            my @problems = vars->{db}->getAllMergedUserProblems($userID,$userSet);
            my $score = 0;
            for my $problem (@problems){
                $score = $score + $problem -> {status};
            }        
            $result1->{$userID}{$userSet.'_score'} = $score; #here we set the score
        }
    }

    #Reformat $result1 into an anonymous array of hashes
    my @result2;
    foreach my $key (keys $result1){
        push(@result2, $result1->{$key});
    }
    return convertArrayOfObjectsToHash(\@result2);
};


return 1;