package WeBWorK::AchievementItems;
use base qw(WeBWorK);

use strict;
use warnings;

use Storable qw(nfreeze thaw);

#have to add any new items to this list, furthermore
# the elements of this list have to match the class name/id of the
# item classes defined below. 
use constant ITEMS => [qw(
ResetIncorrectAttempts
DuplicateProb
DoubleProb
HalfCreditProb
FullCreditProb
ReducedCred
ExtendDueDate
DoubleSet
RessurectHW
Surprise
SuperExtendDueDate
HalfCreditSet
FullCreditSet
)];

=head2 NAME

Item - this is the base class for achievement times.  This defines an 
interface for all of the achievement items.  Each achievement item will have 
a name, a description, a method for creating an html form to get its inputs
called print_form and a method for applying those inputs called use_item.  

Note: the ID has to match the name of the class. 

=cut

sub id { shift->{id} }
sub name { shift->{name} }
sub description { shift->{description} }

# This is a global method that returns all of the provided users items. 
sub UserItems {
    my $userName = shift;
    my $db = shift;
    my $ce = shift;

    # return unless the user has global achievement data
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    
    return unless ($globalUserAchievement->frozen_hash);

    my $globalData = thaw($globalUserAchievement->frozen_hash);
    my @items;

    # ugly eval to get a new item object for each type of item.  
    foreach my $item (@{+ITEMS}) {
	push (@items, eval("WeBWorK::AchievementItems::${item}->new")) if
	    ($globalData->{$item});
    }

    return \@items;
}

#Item to ressurect a homework for 24 hours 

package WeBWorK::AchievementItems::RessurectHW;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "RessurectHW",
	name => "Scroll of Ressurection",
	description => "Opens any homework set for 24 hours.",
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

    #Find all of the closed sets and put them in form

    for (my $i=0; $i<=$#$sets; $i++) {
	if (after($$sets[$i]->due_date()) & $$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	}
    }

    return join("",
	CGI::p("Choose the set which you would like to ressurect."),
	CGI::label("Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"res_set_id", name=>"res_set_id"})));
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #check and see if student really has the item and if the data is valid
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('res_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);


    # Set a new due date and answer time for the student and remove the item
    $set->due_date(time()+86400);
    $set->answer_date(time()+86400);

    $db->putUserSet($set);
	
    my @probIDs = $db->listUserProblems($userName,$setID);

    foreach my $probID (@probIDs) {
	my $problem = $db->getUserProblem($userName,$setID,$probID);
	$problem->problem_seed($problem->problem_seed + 100);
	$db->putUserProblem($problem);
    }

    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
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

    #find all currently open sets and print to a form
    for (my $i=0; $i<=$#$sets; $i++) {
	if (between($$sets[$i]->open_date, $$sets[$i]->answer_date)  && $$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	}
    }

    return join("",
	CGI::p("Choose the set whose due date you would like to extend."),
	CGI::label("Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"ext_set_id", name=>"ext_set_id"})));
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #check and see if the student has the achievement and if the data is valid
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('ext_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);

    #add time to the due date and answer datae and remove item from inventory
    $set->due_date($set->due_date()+86400);
    $set->answer_date($set->answer_date()+86400);

    $db->putUserSet($set);
	
    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to extend a due date by 48 hours. 

package WeBWorK::AchievementItems::SuperExtendDueDate;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "SuperExtendDueDate",
	name => "Robe of Longevity",
	description => "Adds 48 hours to the due date of a homework.",
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

    #find all currently open sets and print to a form
    for (my $i=0; $i<=$#$sets; $i++) {
	if (between($$sets[$i]->open_date, $$sets[$i]->answer_date)  && $$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	}
    }

    return join("",
	CGI::p("Choose the set whose due date you would like to extend."),
	CGI::label("Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"ext_set_id", name=>"ext_set_id"})));
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #check and see if the student has the achievement and if the data is valid
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('ext_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);

    #add time to the due date and answer datae and remove item from inventory
    $set->due_date($set->due_date()+172800);
    $set->answer_date($set->answer_date()+172800);

    $db->putUserSet($set);
	
    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to extend a due date by 24 hours for reduced credit

package WeBWorK::AchievementItems::ReducedCred;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "ReducedCred",
	name => "Ring of Reduction",
	#Reduced credit needs to be set up in course configuration for this
	# item to work,
	description => "Enable reduced scoring for a homework set.  This will allow you to submit answers for partial credit for limited time after the due date.",
	%options,
    };
    
    bless($self, $class);
    return $self;
}
    
sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;
    my $ce = $r->{ce};

    my @openSets;
    my @openSetCount;
    my $maxProblems=0;


    #print names of open sets
    for (my $i=0; $i<=$#$sets; $i++) {
	if (between($$sets[$i]->open_date, $$sets[$i]->answer_date)  && $$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	}
    }

    return join("",
	CGI::p("Choose the set which you would like to enable partial credit for."),
	CGI::label("Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"red_set_id", name=>"red_set_id"})));
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;


    #check variables
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "This item won't work unless your instructor enables the reduced scoring feature.  Let them know that you recieved this message." unless $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod};
	
    
    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('red_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);


    # enable reduced scoring on the set and add the reduced scoring period 
    # to the due date.  
    my $additionalTime = 60*$ce->{pg}{ansEvalDefaults}{reducedScoringPeriod};
    $set->enable_reduced_scoring(1);
    $set->reduced_scoring_date($set->due_date());
    $set->due_date($set->due_date()+$additionalTime);
    $set->answer_date($set->answer_date()+$additionalTime);

    $db->putUserSet($set);
	
    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to make a homework set worth twice as much

package WeBWorK::AchievementItems::DoubleSet;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "DoubleSet",
	name => "Cake of Enlargment",
	description => "Cause the selected homework set to count for twice as many points as it normally would.",
	%options,
    };
    
    bless($self, $class);
    return $self;
}
    
sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;
    my $ce = $r->{ce};

    my @openSets;

    #print open sets

    for (my $i=0; $i<=$#$sets; $i++) {
	if ($$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	}
    }

    return join("",
	CGI::p("Choose the set which you would like to be worth twice as much."),
	CGI::label("Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"dub_set_id", name=>"dub_set_id"})));
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate input data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('dub_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);

    # got through the problems in the set and double the value/weight of each

    my @probIDs = $db->listUserProblems($userName,$setID);

    foreach my $probID (@probIDs) {
	my $globalproblem = $db->getMergedProblem($userName, $setID,$probID);
	my $problem = $db->getUserProblem($userName,$setID,$probID);
	$problem->value($globalproblem->value*2);
	$db->putUserProblem($problem);
    }
	
    $globalData->{$self->{id}} = 0;
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

    #print open sets in a drop down and some javascript which will cause the 
    #second drop down to have the correct number of problems for each set

    for (my $i=0; $i<=$#$sets; $i++) {
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
    foreach (my $i=0; $i<=$#openSets; $i++) {
	$problem_id_script .= "case '".$openSets[$i]."': max =".$openSetCount[$i]."; break; "
    }
    $problem_id_script .= "default: max = $openSetCount[0];} "
	if $#openSetCount >= 0;
    $problem_id_script .= "\$('\#ria_problem_id option').slice(max,$maxProblems).hide(); ";
    $problem_id_script .= "\$('\#ria_problem_id option').slice(0,max).show();";

    return join("",
	CGI::p("Please choose the set name and problem number of the question which should have its incorrect attempt count reset."),
	CGI::label("Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"ria_set_id", name=>"ria_set_id",onchange=>$problem_id_script})),
	" ",
	CGI::label("Problem Number ",
	CGI::popup_menu({values=>\@problemIDs,name=>"ria_problem_id",id=>"ria_problem_id",attributes=>\%attributes})));

}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('ria_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);
    my $problemID = $r->param('ria_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);

    my $problem = $db->getUserProblem($userName, $setID, $problemID);

    return "There was an error accessing that problem." unless $problem;

    #set number of incorrect attempts to zero

    $problem->num_incorrect(0);

    $db->putUserProblem($problem);
	
    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to make a problem worth double.  
package WeBWorK::AchievementItems::DoubleProb;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "DoubleProb",
	name => "Cupcake of Enlargement",
	description => "Causes a single homework problem to be worth twice as much..",
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

    #print open sets and javascript to mach second dropdown to number of
    #problems in each set

    for (my $i=0; $i<=$#$sets; $i++) {
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
	
    my $problem_id_script = "var setid = \$('\#dbp_set_id').val(); var max = null; switch(setid) {";
    foreach (my $i=0; $i<=$#openSets; $i++) {
	$problem_id_script .= "case '".$openSets[$i]."': max =".$openSetCount[$i]."; break; "
    }
    $problem_id_script .= "default: max = $openSetCount[0];} "
	if $#openSetCount >= 0;
    $problem_id_script .= "\$('\#dbp_problem_id option').slice(max,$maxProblems).hide(); ";
    $problem_id_script .= "\$('\#dbp_problem_id option').slice(0,max).show();";

    return join("",
	CGI::p("Please choose the set name and problem number of the question which should have its weight doubled."),
	CGI::label("Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"dbp_set_id", name=>"dbp_set_id",onchange=>$problem_id_script})),
	" ",
	CGI::label("Problem Number ",
	CGI::popup_menu({values=>\@problemIDs,name=>"dbp_problem_id",id=>"dbp_problem_id",attributes=>\%attributes})));

}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('dbp_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);
    my $problemID = $r->param('dbp_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);


    my $globalproblem = $db->getMergedProblem($userName, $setID,$problemID);
    my $problem = $db->getUserProblem($userName, $setID, $problemID);

    return "There was an error accessing that problem." unless $problem;

    #double value of problem

    $problem->value($globalproblem->value*2);
    $db->putUserProblem($problem);

    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to give half credit on a single problem.
package WeBWorK::AchievementItems::HalfCreditProb;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "HalfCreditProb",
	name => "Lesser Rod of Revelation",
	description => "Gives half credit on a single homework problem.",
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

    #print form with open sets and javasscript to have appropriate number 
    # of items in second drop down

    for (my $i=0; $i<=$#$sets; $i++) {
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

    my $problem_id_script = "var setid = \$('\#hcp_set_id').val(); var max = null; switch(setid) {";
    foreach (my $i=0; $i<=$#openSets; $i++) {
	$problem_id_script .= "case '".$openSets[$i]."': max =".$openSetCount[$i]."; break; "
    }
    $problem_id_script .= "default: max = $openSetCount[0];} " 
	if $#openSetCount >= 0;
    $problem_id_script .= "\$('\#hcp_problem_id option').slice(max,$maxProblems).hide(); ";
    $problem_id_script .= "\$('\#hcp_problem_id option').slice(0,max).show();";

    return join("",
	CGI::p("Please choose the set name and problem number of the question which should be given half credit."),
	CGI::label("Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"hcp_set_id", name=>"hcp_set_id",onchange=>$problem_id_script})),
	" ",
	CGI::label("Problem Number ",
	CGI::popup_menu({values=>\@problemIDs,name=>"hcp_problem_id",id=>"hcp_problem_id",attributes=>\%attributes})));

}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('hcp_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);
    my $problemID = $r->param('hcp_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);

    my $problem = $db->getUserProblem($userName, $setID, $problemID);

    return "There was an error accessing that problem." unless $problem;

    #Add .5 to grade with max of 1

    if ($problem->status < .5) {
	$problem->status($problem->status + .5); 
    } else {
	$problem->status(1);
    }

    $db->putUserProblem($problem);
	
    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to give half credit on all problems in a homework set.
package WeBWorK::AchievementItems::HalfCreditSet;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "HalfCreditSet",
	name => "Lesser Tome of Enlightenment",
	description => "Gives half credit on every problem in a set.",
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

    for (my $i=0; $i<=$#$sets; $i++) {
	push(@openSets,$$sets[$i]->set_id);
    }
    
    
    #print form with sets 
    return join("",
		CGI::p("Choose the set which you would like to ressurect."),
		CGI::label("Set Name ",
		CGI::popup_menu({values=>\@openSets,id=>"hcs_set_id", name=>"hcs_set_id"})));
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('hcs_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    # go through the problems in the set
    my @probIDs = $db->listUserProblems($userName,$setID);

    foreach my $probID (@probIDs) {
	my $problem = $db->getUserProblem($userName, $setID, $probID);
	
	return "There was an error accessing that problem." unless $problem;

	#Add .5 to grade with max of 1
	
	if ($problem->status < .5) {
	    $problem->status($problem->status + .5); 
	} else {
	    $problem->status(1);
	}
	
	$db->putUserProblem($problem);
    }
    
    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to give full credit on a single problem
package WeBWorK::AchievementItems::FullCreditProb;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "FullCreditProb",
	name => "Greater Rod of Revelation",
	description => "Gives full credit on a single homework problem.",
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

    #print form getting set and problem number

    for (my $i=0; $i<=$#$sets; $i++) {
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
	
    my $problem_id_script = "var setid = \$('\#fcp_set_id').val(); var max = null; switch(setid) {";
    foreach (my $i=0; $i<=$#openSets; $i++) {
	$problem_id_script .= "case '".$openSets[$i]."': max =".$openSetCount[$i]."; break; "
    }
    $problem_id_script .= "default: max = $openSetCount[0];} "
	if $#openSetCount >= 0;
    $problem_id_script .= "\$('\#fcp_problem_id option').slice(max,$maxProblems).hide(); ";
    $problem_id_script .= "\$('\#fcp_problem_id option').slice(0,max).show();";

    return join("",
	CGI::p("Please choose the set name and problem number of the question which should be given full credit."),
	CGI::label("Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"fcp_set_id", name=>"fcp_set_id",onchange=>$problem_id_script})),
	" ",
	CGI::label("Problem Number ",
	CGI::popup_menu({values=>\@problemIDs,name=>"fcp_problem_id",id=>"fcp_problem_id",attributes=>\%attributes})));

}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('fcp_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);
    my $problemID = $r->param('fcp_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);

    my $problem = $db->getUserProblem($userName, $setID, $problemID);

    return "There was an error accessing that problem." unless $problem;

    #set status of the file to one. 

    $problem->status(1);

    $db->putUserProblem($problem);
	
    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to give half credit on all problems in a homework set.
package WeBWorK::AchievementItems::FullCreditSet;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "FullCreditSet",
	name => "Greater Tome of Enlightenment",
	description => "Gives full credit on every problem in a set.",
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

    for (my $i=0; $i<=$#$sets; $i++) {
	push(@openSets,$$sets[$i]->set_id);
    }
    
    
    #print form with sets 
    return join("",
		CGI::p("Choose the set which you would like to ressurect."),
		CGI::label("Set Name ",
		CGI::popup_menu({values=>\@openSets,id=>"fcs_set_id", name=>"fcs_set_id"})));
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('fcs_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    # go through the problems in the set
    my @probIDs = $db->listUserProblems($userName,$setID);

    foreach my $probID (@probIDs) {
	my $problem = $db->getUserProblem($userName, $setID, $probID);
	
	return "There was an error accessing that problem." unless $problem;

	# set status to 1
	$problem->status(1);

	$db->putUserProblem($problem);
    }
    
    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to turn one problem into another problem
package WeBWorK::AchievementItems::DuplicateProb;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "DuplicateProb",
	name => "Box of Transmogrification",
	description => "Causes a homework problem to become a clone of another problem from the same set.",
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

    # print open sets and allow for a choice of two problems from the set

    for (my $i=0; $i<=$#$sets; $i++) {
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
	
    my $problem_id_script = "var setid = \$('\#tran_set_id').val(); var max = null; switch(setid) {";
    foreach (my $i=0; $i<=$#openSets; $i++) {
	$problem_id_script .= "case '".$openSets[$i]."': max =".$openSetCount[$i]."; break; "
    }
    $problem_id_script .= "default: max = $openSetCount[0];} "
	if $#openSetCount >= 0;
    $problem_id_script .= "\$('\#tran_problem_id option').slice(max,$maxProblems).hide(); ";
    $problem_id_script .= "\$('\#tran_problem_id option').slice(0,max).show();";
    $problem_id_script .= "\$('\#tran_problem_id2 option').slice(max,$maxProblems).hide(); ";
    $problem_id_script .= "\$('\#tran_problem_id2 option').slice(0,max).show();";

    return join("",
	CGI::p("Please choose the set, the problem you would like to copy, and the problem you would like to copy it to."),
	CGI::label("Set Name ",
	CGI::popup_menu({values=>\@openSets,id=>"tran_set_id", name=>"tran_set_id",onchange=>$problem_id_script})),
	" ",
	CGI::label(" Copy this Problem ",
	CGI::popup_menu({values=>\@problemIDs,name=>"tran_problem_id",id=>"tran_problem_id",attributes=>\%attributes})),
	CGI::label(" To this Problem ",
	CGI::popup_menu({values=>\@problemIDs,name=>"tran_problem_id2",id=>"tran_problem_id2",attributes=>\%attributes}))


);

}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!" 
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('tran_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);
    my $problemID = $r->param('tran_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);
    my $problemID2 = $r->param('tran_problem_id2');
    return "You need to input a Problem Number" unless
	($problemID2);

    return "You need to pick 2 different problems!" if
	($problemID == $problemID2);

    my $problem = $db->getMergedProblem($userName, $setID, $problemID);
    my $problem2 = $db->getUserProblem($userName, $setID, $problemID2);

    return "There was an error accessing that problem." unless $problem;

    #set the source of the second problem to that of the first problem. 

    $problem2->source_file($problem->source_file);

    $db->putUserProblem($problem2);
	
    $globalData->{$self->{id}} = 0;
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to print a suprise message
package WeBWorK::AchievementItems::Surprise;
our @ISA = qw(WeBWorK::AchievementItems);
use Storable qw(nfreeze thaw);
use WeBWorK::Utils qw(sortByName before after between);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "Surprise",
	name => "Mysterious Package (with Ribbons)",
	description => "What could be inside?",
	%options,
    };
    
    bless($self, $class);
    return $self;
}
    
sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;

    # the form opens the file "suprise_message.txt" in the achievements 
    # folder and then prints the contetnts of the file.  

    my $sourceFilePath = $r->{ce}->{courseDirs}->{achievements}.'/surprise_message.txt';

    open MESSAGE, $sourceFilePath or return CGI::p("I couldn't find the file [ACHEVDIR]/surprise_message.txt!");

    my @message = <MESSAGE>;

    return CGI::p(@message);

}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #doesn't do anything

    return;
}

1;
