################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/ProblemSetEditor.pm,v 1.44 2004/04/03 16:24:42 gage Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator::Instructor::ProblemSetEditor;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetEditor - Edit a set definition list

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::DB::Record::Problem;
use WeBWorK::Utils qw(readFile formatDateTime parseDateTime list2hash readDirectory max);

our $rowheight = 20;  #controls the length of the popup menus.  
our $libraryName;  #library directory name

use constant SET_FIELDS => [qw(open_date due_date answer_date set_header problem_header)];
use constant PROBLEM_FIELDS =>[qw(source_file value max_attempts)];
use constant PROBLEM_USER_FIELDS => [qw(problem_seed status num_correct num_incorrect)];

sub getSetName {
	my ($self, $pathSetName) = @_;
	if (ref $pathSetName eq "HASH") {
		$pathSetName = undef;
	}
	return $pathSetName;
}

# One wrinkle here: if $override is undefined, do the global thing, otherwise, it's truth value determines the checkbox.
sub setRowHTML {
	my ($description, $fieldName, $fieldValue, $size, $override, $overrideValue) = @_;
	
	my $attributeHash = {type=>"text", name=>$fieldName, value=>$fieldValue};
	$attributeHash->{size} = $size if defined $size;
	
	my $html = CGI::td({}, [$description, CGI::input($attributeHash)]);
	
	if (defined $override) {
		$attributeHash->{name}="${fieldName}_override";
		$attributeHash->{value}=($override ? $overrideValue : "" );
	
		$html .= CGI::td({}, [
			CGI::checkbox({
				type=>"checkbox", 
				name=>"override", 
				label=>"override with:",
				value=>$fieldName,
				checked=>($override ? 1 : 0)
			}),
			CGI::input($attributeHash)
		]);
	}
	
	return $html;
			
}



# Initialize does all of the form processing.  It's extensive, and could probably be cleaned up and
# consolidated with a little abstraction.
sub initialize {
	my ($self)      = @_;
	my $r           = $self->r;
	my $db          = $r->db;
	my $ce          = $r->ce;
	my $authz       = $r->authz;
	my $user        = $r->param('user');
	#my $setName    = $self->getSetName(@components);
	my $setName     = $r->urlpath->arg("setID");
	my $setRecord   = $db->getGlobalSet($setName); #checked
	die "global set $setName not found." unless $setRecord;

	$self->{set}    = $setRecord;
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUsers    = scalar(@editForUser);
	my $forOneUser  = $forUsers == 1;

	# build a quick lookup table
	my %overrides = list2hash $r->param('override');
	
	unless ($authz->hasPermissions($user, "modify_problem_sets")) {
		$self->{submitError} = "You are not authorized to modify problem sets";
		return;
	}

	
	###################################################
	# The set form was submitted with the save button pressed
	# Save changes to the set
	###################################################
		$self->{error_message} = undef;
		
		if (defined($r->param('submit_set_changes'))) {
		foreach (@{SET_FIELDS()}) {
			if (defined($r->param($_))) {
				if (m/_date$/) {
					$setRecord->$_(parseDateTime($r->param($_)));
				} else {
					$setRecord->$_($r->param($_));
				}
			}
		}
		###################################################
		# Check that the open, due and answer dates are in increasing order.
		# Bail if this is not correct.
		###################################################

		if ($setRecord->open_date > $setRecord->due_date)  {
			$self->{error_message} .= CGI::div({class=>'ResultsWithError'},'Error: Due date must come after open date');
		}
		if ($setRecord->due_date > $setRecord->answer_date) {
			$self->{error_message} .= CGI::div({class=>'ResultsWithError'},'Error: Answer date must come after due date');
		}
		return if defined($self->{error_message});
		###################################################
		# End date check section.
		###################################################
		$db->putGlobalSet($setRecord);
		
		if ($forOneUser) {
			
			my $userSetRecord = $db->getUserSet($editForUser[0], $setName); #checked
			die "set $setName not found for $editForUser[0]." unless $userSetRecord;
			foreach my $field (@{SET_FIELDS()}) {
				if (defined $r->param("${field}_override")) {
					if (exists $overrides{$field}) {
						if ($field =~ m/_date$/) {
							$userSetRecord->$field(parseDateTime($r->param("${field}_override")));
						} else {
							$userSetRecord->$field($r->param("${field}_override"));
						}
					} else {
						$userSetRecord->$field(undef);
					}
				}
			}
			###################################################
			# Check that the open, due and answer dates are in increasing order.
			# Bail if this is not correct.
			###################################################
			my $active_open_date   = $userSetRecord->open_date   ? $userSetRecord->open_date   : $setRecord->open_date;
			my $active_due_date    = $userSetRecord->due_date    ? $userSetRecord->due_date    : $setRecord->due_date;
			my $active_answer_date = $userSetRecord->answer_date ? $userSetRecord->answer_date : $setRecord->answer_date;
			if ( $active_open_date >$active_due_date ) {
				$self->{error_message} .= CGI::div({class=>'ResultsWithError'},'Error: Due date override must come after open date');
			}
			if ( $active_due_date > $active_answer_date ) {
				$self->{error_message} .= CGI::div({class=>'ResultsWithError'},'Error: Answer date override must come after due date');
			}
			return if defined($self->{error_message});
			###################################################
			# End date check section.
			###################################################
			$db->putUserSet($userSetRecord);
		}

	} 
	
	###################################################
	# The set form was submitted with the export button pressed
	# Export the set structure to a set definition file
	###################################################
	
	if (  defined($r->param('export_set'))  ) {
		my $fileName = $r->param('export_file_name');
		die "Please specify a file name for saving the set definition" unless $fileName;
		$fileName    .= '.def' unless $fileName =~ /\.def$/;
		my $filePath  = $ce->{courseDirs}->{templates}.'/'.$fileName;
		# back up existing file
		if(-e $filePath) {
		    rename($filePath,"$filePath.bak") or 
	    	       die "Can't rename $filePath to $filePath.bak ",
	    	           "Check permissions for webserver on directories. $!";
		}
	    my $openDate     = formatDateTime($setRecord->open_date);
	    my $dueDate      = formatDateTime($setRecord->due_date);
	    my $answerDate   = formatDateTime($setRecord->answer_date);
	    my $setHeader    = $setRecord->set_header;
	    
	    my @problemList = $db->listGlobalProblems($setName);
	    my $problemList  = '';
	    foreach my $prob (sort {$a <=> $b} @problemList) {
	    	my $problemRecord = $db->getGlobalProblem($setName, $prob); # checked
	    	die "global problem $prob for set $setName not found" unless defined($problemRecord);
	    	my $source_file   = $problemRecord->source_file();
			my $value         = $problemRecord->value();
			my $max_attempts  = $problemRecord->max_attempts();
	    	$problemList     .= "$source_file, $value, $max_attempts \n";	    
	    }
	    my $fileContents = <<EOF;

openDate          = $openDate
dueDate           = $dueDate
answerDate        = $answerDate
paperHeaderFile   = $setHeader
screenHeaderFile  = $setHeader
problemList       = 

$problemList



EOF


	    $self->saveProblem($fileContents, $filePath);
	    $self->{message} .= "Set definition saved to $filePath";

	
	
	
	
	}
}


sub body {
	my ($self, @components) = @_;
	my $r                   = $self->r;
	my $urlpath             = $r->urlpath;
	my $db                  = $r->db;
	my $ce                  = $r->ce;
	my $authz               = $r->authz;
	my $user                = $r->param('user');
	my $courseName          = $urlpath->arg("courseID");
	my $setName             = $urlpath->arg("setID");
	my $setRecord           = $db->getGlobalSet($setName);  # checked
	die "global set $setName not found." unless $setRecord;
	my @editForUser         = $r->param('editForUser');
	# some useful booleans
	my $forUsers            = scalar(@editForUser);
	my $forOneUser          = $forUsers == 1;

        return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	## Set Form ##
	my $userSetRecord;
	my %overrideArgs;
	if ($forOneUser) {
		$userSetRecord = $db->getUserSet($editForUser[0], $setName); #checked
		die "set $setName not found for user $editForUser[0]." unless $userSetRecord;
		foreach my $field (@{SET_FIELDS()}) {
			$overrideArgs{$field} = [defined $userSetRecord->$field, ($field =~ /_date$/ ? formatDateTime($userSetRecord->$field) : $userSetRecord->$field)];
		}
	} else {
		foreach my $field (@{SET_FIELDS()}) {
			$overrideArgs{$field} = [undef, undef];
		}
	}
	print $self->{error_message} if defined($self->{error_message}) and $self->{error_message};
	print CGI::h2({}, "Set Data"), "\n";
	if (@editForUser) {
		print CGI::p("Editing user-specific overrides for ". CGI::b(join ", ", @editForUser));
	}
	print CGI::start_form({method=>"post", action=>$r->uri}), "\n";
	print CGI::table({},
		CGI::Tr({}, [
			setRowHTML( "Open Date:", 
						"open_date", 
						formatDateTime($setRecord->open_date),
						undef,
						@{$overrideArgs{open_date}})."\n",
			setRowHTML( "Due Date:",
						"due_date", 
						formatDateTime($setRecord->due_date), 
						undef, 
						@{$overrideArgs{due_date}})."\n",
			setRowHTML( "Answer Date:",
						"answer_date", 
						formatDateTime($setRecord->answer_date), 
						undef, 
						@{$overrideArgs{answer_date}})."\n",
			setRowHTML( "Set Header:", "set_header", 
						$setRecord->set_header, 
						32, 
						@{$overrideArgs{set_header}})."\n",
# FIXME  we're not using this right at the moment as far as I know.  There may someday be a use for it, so don't take this out yet.
# 			setRowHTML( "Problem Header:", 
# 						"problem_header", 
# 						$setRecord->problem_header, 
# 						undef, 
# 						@{$overrideArgs{problem_header}})."\n"
		])
	);
	
	print $self->hiddenEditForUserFields(@editForUser),
	      $self->hidden_authen_fields,
	      CGI::input({type=>"submit", name=>"submit_set_changes", value=>"Save Set"}),
	      '&nbsp;';
	
		#### link to edit setHeader 
    my $PGProblemEditor    = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
                                                     courseID  => $courseName,
                                                     setID     => $setName,
                                                     problemID => '0'
    );
    my $setHeaderEditLink = $self->systemLink($PGProblemEditor);
	if (defined($setRecord) and $setRecord->set_header) {
		print CGI::a({-href=>$setHeaderEditLink},'Edit set header: '.$setRecord->set_header);
	}
	
	print CGI::br(),
	      CGI::submit({ name=>"export_set", label=>"Export Set"} ),
	      ' as ',
	      CGI::input({type=>'text',name=>'export_file_name',value=>"set$setName.def",size=>32});
	      
	print CGI::br(), $self->{message}  if defined $self->{message};

	

	print CGI::end_form();
	
	my $problemCount = $db->listGlobalProblems($setName);
	print CGI::h2({}, "Problems"), "\n";
	print CGI::p({}, "This set contains $problemCount problem" . ($problemCount == 1 ? "" : "s").".");
	#FIXME
	# the code below doesn't work ---
	# get message 
	#no type matches module WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser with args at 
	# /home/gage/webwork/webwork-modperl/lib/WeBWorK/URLPath.pm line 497.
    # error in URLPath.pm??????
 	my $problemSetListPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::ProblemList",
 	                                                  courseID => $courseName,
 	                                                  setID    => $setName
 	);
 
 	my $editProblemsURL        = $self->systemLink($problemSetListPage, 
 	                                               params => ['editForUser']   # include all editForUser parameters
 	);
 	my $usersAssignedToSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet",
 	                                                  courseID => $courseName,
 	                                                  setID    => $setName
 	);
 
 	my $editUsersAssignedToSetURL        = $self->systemLink($usersAssignedToSetPage, 
 	                                             
 	);
 	print CGI::a({href=>$editProblemsURL},
	 (@editForUser) ? "Edit the list of problems in this set for ". CGI::b(join ", ", @editForUser) :
	                  "Edit the list of problems in this set");

	unless (@editForUser) {      # this is not needed when we are editing details for a user
		my $userCount = $db->listUsers;
		my $usersOfSet = $db->countSetUsers($setName);
		print CGI::h2({}, "Users"), "\n";
		print CGI::p({}, "This set is assigned to ".$self->userCountMessage($usersOfSet, $userCount).".");
		print CGI::a({href=>$editUsersAssignedToSetURL}, "Determine who this set is assigned to");
	}
	
	return "";
}
###########################################################################
# utility
###########################################################################
sub saveProblem {     
    my $self      = shift;
	my ($body, $probFileName)= @_;
	local(*PROBLEM);
	open (PROBLEM, ">$probFileName") ||
		$self->submission_error("Could not open $probFileName for writing.
		Check that the  permissions for this problem are 660 (-rw-rw----)");
	print PROBLEM $body;
	close PROBLEM;
	chmod 0660, "$probFileName" ||
	             $self->submission_error("
	                    CAN'T CHANGE PERMISSIONS ON FILE $probFileName");
}
1;
