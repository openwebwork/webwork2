################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/ProblemSetEditor.pm,v 1.63 2004/09/13 19:35:09 sh002i Exp $
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
use File::Copy;
use WeBWorK::DB::Record::Problem;
use WeBWorK::Utils qw(readFile list2hash listFilesRecursive max);

our $rowheight = 20;  #controls the length of the popup menus.  
our $libraryName;  #library directory name

# added gateway fields here: everything after published
use constant SET_FIELDS => [qw(open_date due_date answer_date set_header hardcopy_header published assignment_type attempts_per_version version_time_limit versions_per_interval time_interval problem_randorder)];
use constant PROBLEM_FIELDS =>[qw(source_file value max_attempts)];
use constant PROBLEM_USER_FIELDS => [qw(problem_seed status num_correct num_incorrect)];

# This defines allowed values for the assignment_type field in the set 
# definition.  Ideally we should probably have this imported from some 
# global file (global.conf?)
use constant ASSIGNMENT_TYPES => [ qw(default gateway proctored_gateway) ];

sub getSetName {
	my ($self, $pathSetName) = @_;
	if (ref $pathSetName eq "HASH") {
		$pathSetName = undef;
	}
	return $pathSetName;
}

# One wrinkle here: if $override is undefined, do the global thing, 
# otherwise, it's truth value determines the checkbox and the current fieldValue is not directly editable
sub setRowHTML {
	my ($description, $fieldName, $fieldValue, $size, $override, $overrideValue) = @_;
	
	my $attributeHash = {type=>"text", name=>$fieldName, value=>$fieldValue};
	$attributeHash->{size} = $size if defined $size;
	
	my $input = (defined $override) ? $fieldValue : CGI::input($attributeHash);

	my $html = CGI::td({}, [$description, $input]);
	
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
	
	# Check permissions
	return unless ($authz->hasPermissions($user, "access_instructor_tools"));
	return unless ($authz->hasPermissions($user, "modify_problem_sets"));
	
	###################################################
	# The set form was submitted with the save button pressed
	# Save changes to the set
	###################################################
		
	if (defined($r->param('submit_set_changes'))) {

		if (!$forUsers) {
			foreach (@{SET_FIELDS()}) {
            # this is an unnecessary logical division: we deal with gateway 
	    #   fields separately from the rest, for no particular reason other
            #   than it makes life somewhat easier for those who don't care  
            #   about gateways
			    if ( /(assignment_type)|(attempts_per_version)|(version_time_limit)|(versions_per_interval)|(time_interval)|(problem_randorder)/ ) {
				if (defined($r->param($_))) {
				    if ( /assignment_type/ && 
					 $r->param($_) =~ /default/i ) {
					$setRecord->$_(undef);
				    } else {
					
					if ( m/time/ ) {
                    # times are input as minutes, not seconds, so multiply by 60
					    $setRecord->$_( 60*($r->param($_)) );
					} else {
					    $setRecord->$_( $r->param($_) );
					}
				    }

				} elsif ( m/assignment_type/ ) {
				    $setRecord->$_(undef);
				}

            # we now return you to your regularly scheduled programming
			    } else {
				if (defined($r->param($_))) {
					if (m/_date$/) {
						$setRecord->$_($self->parseDateTime($r->param($_)));
					} else {
						$setRecord->$_($r->param($_)) unless ($_ eq 'set_header' and $r->param($_) eq "Use System Default");

						if($_ eq 'set_header') {
							# be nice and copy the default file here if it doesn't exist yet
							# empty set headers lead to trouble
							my $set_header = ($r->param($_) eq "Use System Default") ? $setRecord->set_header : $r->param($_);
							
							my $newheaderpath = $r->{ce}->{courseDirs}->{templates} . '/'. $set_header;
							unless(($set_header !~ /\S/) or -e $newheaderpath) {
								my $default_header = $ce->{webworkFiles}->{screenSnippets}->{setHeader};
								File::Copy::copy($default_header, $newheaderpath);
							}
						}
					}
				} else {
					if (m/published$/) {
						$setRecord->$_(0);
					}
				}
			  }
		    }
		

		
		
			###################################################
			# Check that the open, due and answer dates are in increasing order.
			# Bail if this is not correct.
			###################################################
			if ($setRecord->open_date > $setRecord->due_date)  {
				$self->addbadmessage('Error: Due date must come after open date');
				return;
			}
			if ($setRecord->due_date > $setRecord->answer_date) {
				$self->addbadmessage('Error: Answer date must come after due date');
				return;
			}
			###################################################
			# End date check section.
			###################################################
			$self->addgoodmessage("Changes to set $setName were successfully saved.");
			$db->putGlobalSet($setRecord);
		} else {
			
			my $userSetRecord = $db->getUserSet($editForUser[0], $setName); #checked
			die "set $setName not found for $editForUser[0]." unless $userSetRecord;
			foreach my $field (@{SET_FIELDS()}) {
				if (defined $r->param("${field}_override")) {
					if (exists $overrides{$field}) {
						if ($field =~ m/_date$/) {
							$userSetRecord->$field($self->parseDateTime($r->param("${field}_override")));
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
			if ( $active_open_date > $active_due_date ) {
				$self->addbadmessage('Error: Due date override must come after open date');
				return;
			}
			if ( $active_due_date > $active_answer_date ) {
				$self->addbadmessage('Error: Answer date override must come after due date');
				return;
			}
			###################################################
			# End date check section.
			###################################################
			$self->addgoodmessage("Changes to set $setName for user ", CGI::b($editForUser[0]), "were successfully saved.");
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
	    my $openDate     = $self->formatDateTime($setRecord->open_date);
	    my $dueDate      = $self->formatDateTime($setRecord->due_date);
	    my $answerDate   = $self->formatDateTime($setRecord->answer_date);
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
	    $self->addgoodmessage(CGI::p("Set definition saved to $filePath"));
	
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

	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($r->param("user"), "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to modify homework sets.")
		unless $authz->hasPermissions($r->param("user"), "modify_problem_sets");


	## Set Form ##
	my $userSetRecord;
	my %overrideArgs;
	if ($forOneUser) {
		$userSetRecord = $db->getUserSet($editForUser[0], $setName); #checked
		die "set $setName not found for user $editForUser[0]." unless $userSetRecord;
		foreach my $field (@{SET_FIELDS()}) {
			$overrideArgs{$field} = [defined $userSetRecord->$field && $userSetRecord->$field ne "", ($field =~ /_date$/ ? $self->formatDateTime($userSetRecord->$field) : $userSetRecord->$field)];
		}
	} else {
		foreach my $field (@{SET_FIELDS()}) {
			$overrideArgs{$field} = [undef, undef];
		}
	}
	print CGI::h2({}, "Set Data"), "\n";
	if (@editForUser) {
		print CGI::p("Editing user-specific overrides for ". CGI::b(join ", ", @editForUser));
	}

	my $templates_dir = $r->ce->{courseDirs}->{templates};
	my %probLibs = %{ $r->ce->{courseFiles}->{problibs} };
	my $exempt_dirs = join("|", keys %probLibs);
	my @headers = listFilesRecursive(
		$templates_dir,
		qr/header.*\.pg$/i, # match these files
		qr/^(?:$exempt_dirs|CVS)$/, # prune these directories
		0, # match against file name only
		1, # prune against path relative to $templates_dir
	);
	
	@headers = sort @headers;
	unshift (@headers, "Use System Default");
	
	print CGI::start_form({method=>"post", action=>$r->uri}), "\n";
	print CGI::table({},
		CGI::Tr({}, [
			setRowHTML( "Open Date:", 
						"open_date", 
						$self->formatDateTime($setRecord->open_date),
						undef,
						@{$overrideArgs{open_date}})."\n",
			setRowHTML( "Due Date:",
						"due_date", 
						$self->formatDateTime($setRecord->due_date), 
						undef, 
						@{$overrideArgs{due_date}})."\n",
			setRowHTML( "Answer Date:",
						"answer_date", 
						$self->formatDateTime($setRecord->answer_date), 
						undef, 
						@{$overrideArgs{answer_date}})."\n",
#			setRowHTML( "Set Header:", "set_header", 
#						$setRecord->set_header, 
#						32, 
#						@{$overrideArgs{set_header}})."\n",
# FIXME  we're not using this right at the moment as far as I know.  There may someday be a use for it, so don't take this out yet.
# 			setRowHTML( "Problem Header:", 
# 						"hardcopy_header", 
# 						$setRecord->hardcopy_header, 
# 						undef, 
# 						@{$overrideArgs{hardcopy_header}})."\n",
			CGI::td({}, [	"Set Header:" , 
					($forOneUser) 
						? $setRecord->set_header || "None selected."
						: CGI::popup_menu(
							-name=>'set_header', 
							-values=>\@headers, 
							-default=>0) .
						"(currently: " . ($setRecord->set_header || "None selected.") . ")" . "\n",
#
# assignment type added for gateway compatibility
                       CGI::td({}, [ "Assignment Type:", 
                                     ($forOneUser) ? 
                                         $setRecord->assignment_type || "Default." :
                                         CGI::popup_menu( -name=>'assignment_type',
                                                          -values=>ASSIGNMENT_TYPES,
                                                          -default=>($setRecord->assignment_type || "default.") ) .
                                         " (currently: " . 
                                         ( $setRecord->assignment_type || "default." ) .
                                         ")\n" ]) . "\n",
				])
		])
	);

# add input fields for gateway tests, if we're dealing with that type of assignment
        if ( defined($setRecord->assignment_type) && 
             $setRecord->assignment_type =~ /gateway/ ) {
            print "Gateway parameters:", CGI::br(), "\n";
            my $versionTimeLimit = ( defined( $setRecord->version_time_limit ) && 
                                     $setRecord->version_time_limit ) ? 
                                     int(($setRecord->version_time_limit() + 0.5)/60) : 
                                     0;
            my $timeInterval = ( defined( $setRecord->time_interval ) && 
                                     $setRecord->time_interval ne '' ) ? 
                                     int(($setRecord->time_interval() + 0.5)/60) : 
                                     720;  # default is 12 hours
            print CGI::table( {}, 
                    CGI::Tr( {}, [ 
                      CGI::td( {}, "&nbsp;&nbsp;", 
                                   setRowHTML( "Attempts per test version",
                                               "attempts_per_version",
                                               $setRecord->attempts_per_version ? 
                                                 $setRecord->attempts_per_version : 1,
                                               3,
                                               @{$overrideArgs{attempts_per_version}}) .
                                      "\n" ),
                      CGI::td( {}, "&nbsp;&nbsp;", 
                                   setRowHTML( "Time limit for test (min)",
                                               "version_time_limit", 
                                               $versionTimeLimit, 3,
                                               @{$overrideArgs{version_time_limit}}) .
                                      "\n" ),
                      CGI::td( {}, "&nbsp;&nbsp;", 
                                   setRowHTML( "Versions per time interval (0=infty)",
                                               "versions_per_interval",
                                               $setRecord->versions_per_interval ne '' ? 
                                                 $setRecord->versions_per_interval : 1,
                                               3,
                                               @{$overrideArgs{versions_per_interval}}).
                                      "\n" ),
                      CGI::td( {}, "&nbsp;&nbsp;", 
                                   setRowHTML( "Time interval (min)",
                                               "time_interval", $timeInterval, 4, 
                                               @{$overrideArgs{time_interval}}) .
                                      "\n" ),
                      CGI::td( {}, "&nbsp;&nbsp;", 
                                   setRowHTML( "Order problems randomly in set (0|1)",
                                               "problem_randorder",
                                               $setRecord->problem_randorder ne '' ? 
                                                 $setRecord->problem_randorder : 1,
                                               3,
                                               @{$overrideArgs{problem_randorder}}) .
                                      "\n" )
                    ] )
                 ), "\n";
        }


	if (@editForUser) {
		my $publishedClass = ($setRecord->published) ? "Published" : "Unpublished";
		my $publishedText = ($setRecord->published) ? "visible to students" : "hidden from students";
		print CGI::p("This set is currently", CGI::font({class=>$publishedClass}, $publishedText),
		CGI::br(), "(You cannot hide or make a set visible for specific users.)");
	} else {
		print CGI::checkbox({type=>"checkbox", name=>"published", label=>"Visible to students", value=>"1", checked=>(($setRecord->published) ? 1 : 0)}), CGI::br();

	}
	
	print $self->hiddenEditForUserFields(@editForUser),
	      $self->hidden_authen_fields,
	      CGI::input({type=>"submit", name=>"submit_set_changes", value=>"Save Set", style=>"{width: 13ex}"}),
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
	      CGI::submit({ name=>"export_set", label=>"Export Set",  style=>"{width: 13ex}"} ),
	      ' as ',
	      CGI::input({type=>'text',name=>'export_file_name',value=>"set$setName.def",size=>32});
	      
	print CGI::br();

	

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
		$self->addbadmessage(CGI::p("Could not open $probFileName for writing. Check that the  permissions for this problem are 660 (-rw-rw----)"));
	print PROBLEM $body;
	close PROBLEM;
	chmod 0660, "$probFileName" ||
		$self->addbadmessage(CGI::p("CAN'T CHANGE PERMISSIONS ON FILE $probFileName"));
}
1;
