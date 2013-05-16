package WeBWorK::AchievementItems;
use base qw(WeBWorK);

use strict;
use warnings;

use Storable qw(nfreeze thaw);

=head2 NAME

Item - this is the base class for achievement times.  This defines an 
interface for all of the achievement items.  Each achievement item will have 
a name, a description, a method for creating an html form to get its inputs
and a method for applying those inputs.  

=cut

sub id { shift->{id} }
sub name { shift->{name} }
sub description { shift->{description} }

# This is a global method that returns all of the provided users items. 
sub UserItems {
    my $userName = shift;
    my $db = shift;
    my $ce = shift;

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    
    return unless ($globalUserAchievement->frozen_hash);

    my $globalData = thaw($globalUserAchievement->frozen_hash);
    my @items;

    push (@items, WeBWorK::AchievementItems::ExtendDueDate->new) if
	($globalData->{ExtendDueDate});

    push (@items, WeBWorK::AchievementItems::ResetIncorrectAttempts->new) if
	($globalData->{ResetIncorrectAttempts});

    return \@items;
}

#Item to extend a due date by 24 hours. 

package WeBWorK::AchievementItems::ExtendDueDate;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "ExtendDueDate",
	name => "Tunic of Extension",
	description => "Adds 24 hours to the due date of a homework.",
	%options,
    };
    
    bless($self, $class);
    return $self;
}
    
sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;

    my @openSets;
    my @openSetCount;
    my $maxProblems=0;

    for (my $i=0; $i<$#$sets; $i++) {
	if (between($$sets[$i]->open_date, $$sets[$i]->due_date)  && $$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	}
    }

    return join("",
	CGI::p("Choose the set whose due date you would like to extend."),
	"Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"ext_set_id", name=>"ext_set_id"}));
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('ext_set_id');
    return "You need to input a Set Name" unless
	($setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);

    $set->due_date($set->due_date()+86400);
    $set->answer_date($set->answer_date()+86400);

    $db->putUserSet($set);
	
#    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to reset number of incorrect attempts.
package WeBWorK::AchievementItems::ResetIncorrectAttempts;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "ResetIncorrectAttempts",
	name => "Potion of Forgetfullness",
	description => "Resets the number of incorrect attempts on a single homework problem.",
	%options,
    };
    
    bless($self, $class);
    return $self;
}
    
sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;

    my @openSets;
    my @openSetCount;
    my $maxProblems=0;

    for (my $i=0; $i<$#$sets; $i++) {
	if (between($$sets[$i]->open_date, $$sets[$i]->due_date) && $$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	    push(@openSetCount,$$setProblemCount[$i]);
	    $maxProblems = $$setProblemCount[$i] if ($$setProblemCount[$i]>$maxProblems);
	}
    }

    my @problemIDs;
    my %attributes;

    for (my $i=1; $i<=$maxProblems; $i++) {
	push(@problemIDs,$i);
	if ($i > $openSetCount[0]) {
	    $attributes{$i}{style} = 'display:none;';
	}
    }
	
    my $problem_id_script = "var setid = \$('\#ria_set_id').val(); var max = null; switch(setid) {";
    foreach (my $i=0; $i<$#openSets; $i++) {
	$problem_id_script .= "case '".$openSets[$i]."': max =".$openSetCount[$i]."; break; "
    }
    $problem_id_script .= "default: max = $openSetCount[0];} ";
    $problem_id_script .= "\$('\#ria_problem_id option').slice(max,$maxProblems).hide(); ";
    $problem_id_script .= "\$('\#ria_problem_id option').slice(0,max).show();";

    return join("",
	CGI::p("Please choose the set name and problem number of the question which should have its incorrect attempt count reset."),
	"Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"ria_set_id", name=>"ria_set_id",onchange=>$problem_id_script}),
	" ",
	"Problem Number ",
	CGI::popup_menu({values=>\@problemIDs,name=>"ria_problem_id",id=>"ria_problem_id",attributes=>\%attributes}));

}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('ria_set_id');
    return "You need to input a Set Name" unless
	($setID);
    my $problemID = $r->param('ria_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);

    my $problem = $db->getUserProblem($userName, $setID, $problemID);

    return "There was an error accessing that problem." unless $problem;

    $problem->num_incorrect(0);

    $db->putUserProblem($problem);
	
    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

