################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/ProblemList.pm,v 1.14 2003/12/09 01:12:31 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor::ProblemList;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemList - List and edit problems in a set

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readDirectory list2hash max);
use WeBWorK::DB::Record::Set;

use constant PROBLEM_FIELDS =>[qw(source_file value max_attempts)];
use constant PROBLEM_USER_FIELDS => [qw(problem_seed status num_correct num_incorrect)];

sub problemElementHTML {
	my ($fieldName, $fieldValue, $size, $override, $overrideValue) = @_;
	my $attributeHash = {type=>"text",name=>$fieldName,value=>$fieldValue};
	$attributeHash->{size} = $size if defined $size;
	my $html;
#	my $html = CGI::input($attributeHash);
	
	unless (defined $override) {
		$html = CGI::input($attributeHash);
	} else {
		$html = $fieldValue;
		$attributeHash->{name} = "${fieldName}.override";
		$attributeHash->{value} = ($override ? $overrideValue : "");
		$html = "default:".CGI::br().$html.CGI::br()
			. CGI::checkbox({
				type => "checkbox",
				name => "override",
				label => "override:",
				value => $fieldName,
				checked => ($override ? 1 : 0)
			})
			. CGI::br()
			. CGI::input($attributeHash);
	}
	
	return $html;
}

# pay no attention to the argument list.  Here's what you pass:
# directoryListHTML($level, $selected, $libraryRoot, @path)
sub directoryListHTML {
	my ($level, $selected, @path) = @_;
	$selected = [$selected] unless ref $selected eq "ARRAY";
	my $dirName = join "/", @path[0..$level];
	my $pathInLibrary = join "/", @path[1..$level];
	my @contents = sort grep {m/\.pg$/ or -d "$dirName/$_" and not m/^\.{1,2}$/} readDirectory($dirName);
	my %contentsPretty = map {$pathInLibrary . "/" . $_ => (-d "$dirName/$_" ? "$_/" : $_)} @contents;
	@contents = map {"$pathInLibrary/$_"} @contents; # Make the full path the actual values, so weird user behavior doesn't hurt.
	@$selected = map {"$pathInLibrary/$_"} @$selected;
	
	my $html = ($level eq "0" ? "problem library" : $path[$level]) . CGI::br();
	$html .= CGI::scrolling_list({
		name=>"directory_level_$level",
		values=>\@contents,
		labels=>\%contentsPretty,
		default=>$selected,
		multiple=>'true',
		size=>"20",
	});
	$html .= CGI::br()
		. CGI::input({type=>"submit", name=>"open_add_$level", value=>"Open/Add"});	
}

sub initialize {
	my ($self, $setName) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $setRecord = $db->getGlobalSet($setName); # checked
	die "global set $setName  not found." unless $setRecord;

	$self->{set}  = $setRecord;
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUsers = scalar(@editForUser);
	my $forOneUser = $forUsers == 1;

	unless ($authz->hasPermissions($user, "modify_problem_sets")) {
		$self->{submitError} = "You are not authorized to modify problem sets";
		return;
	}

	# build a quick lookup table
	my %overrides = list2hash $r->param('override');

	# the Problem form was submitted
	if (defined($r->param('submit_problem_changes'))) {
		my @problemList = $db->listGlobalProblems($setName);
		foreach my $problem (@problemList) {
			my $problemRecord = $db->getGlobalProblem($setName, $problem); # checked
			die "global $problem for set $setName not found." unless $problemRecord;
			foreach my $field (@{PROBLEM_FIELDS()}) {
				my $paramName = "problem.${problem}.${field}";
				if (defined($r->param($paramName))) {
					$problemRecord->$field($r->param($paramName));
				}
			}
			$db->putGlobalProblem($problemRecord);

			if ($forOneUser) {
				my $userProblemRecord = $db->getUserProblem($editForUser[0], $setName, $problem); # checked
				die " problem $problem for set $setName and effective user $editForUser[0] not found" unless $userProblemRecord;
				foreach my $field (@{PROBLEM_USER_FIELDS()}) {
					my $paramName = "problem.${problem}.${field}";
					if (defined($r->param($paramName))) {
						$userProblemRecord->$field($r->param($paramName));
					}
				}
				foreach my $field (@{PROBLEM_FIELDS()}) {
					my $paramName = "problem.${problem}.${field}";
					if (defined($r->param("${paramName}.override"))) {
						if (exists $overrides{$paramName}) {
							$userProblemRecord->$field($r->param("${paramName}.override"));
						} else {
							$userProblemRecord->$field(undef);
						}
						
					}
				}
				$db->putUserProblem($userProblemRecord);
				
			}
		}
		foreach my $problem ($r->param('deleteProblem')) {
			$db->deleteGlobalProblem($setName, $problem);
		}
	# The file list field was submitted
	} elsif (defined $r->param('fileBrowsing')) {
		my $libraryRoot = $ce->{courseDirs}->{templates};
		my $count = 0;
		my $done = 0;
		my @path = ();
		my $freeProblemID = max($db->listGlobalProblems($setName)) + 1;
		
		while (defined $r->param("directory_level_$count") and not $done) {
			if (defined $r->param("open_add_$count")) {
				$done = 1;
				my @selected = $r->param("directory_level_$count");
				my $dirFound = 0;
				foreach my $selected (@selected) {
					if (-d "$libraryRoot/$selected") {
						@path = split "/", $selected;
						shift @path if $path[0] eq ""; # remove the null element from the begining
						$dirFound = 1;
						last;
					}
				}
				# Otherwise, create a new global problem for each of the files selected
				unless ($dirFound) {
					foreach my $selected (@selected) {
						my $file = $selected;
						@path = split "/", $selected;
						pop @path; # Remove the file name from the path
						shift @path if $path[0] eq ""; # remove the null element from the begining
						my $problemRecord = $db->newGlobalProblem();
						$problemRecord->problem_id($freeProblemID++);
						$problemRecord->set_id($setName);
						$problemRecord->source_file($file);
						$problemRecord->value("1");
						$problemRecord->max_attempts("-1");
						$db->addGlobalProblem($problemRecord);
						$self->assignProblemToAllSetUsers($problemRecord);
					}

				}
			}
			$count++;
		}
		$self->{path} = [@path];
	}

}

sub path {
	my $self           = shift;
	my $args           = $_[-1];
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $set_id     = $self->{set}->set_id;
	return $self->pathMacro($args,
		"Home"          => "$root",
		$courseName     => "$root/$courseName",
		'instructor'    => "$root/$courseName/instructor",
		'sets'          => "$root/$courseName/instructor/sets/",
		"set $set_id"   => "$root/$courseName/instructor/sets/$set_id",
		'problems'  => '',    
	);
}

sub title {
	my ($self, $setName) = @_;
	return "Problems in ".$self->{ce}->{courseName}." : ".$setName;
}

sub body {
	my ($self, $setName) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $courseName = $ce->{courseName};
	my $setRecord = $db->getGlobalSet($setName); # checked
	die "Global set $setName not found." unless $setRecord;
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUsers = scalar(@editForUser);
	my $forOneUser = $forUsers == 1;

        return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");
	
	my $userCount = $db->listUsers();
	my $setUserCount = $db->countSetUsers($setName);
	my $userCountMessage = "This set is assigned to " . $self->userCountMessage($setUserCount, $userCount) . ".";

	if (@editForUser) {
		print CGI::p("$userCountMessage  Editing user-specific overrides for ". CGI::b(join ", ", @editForUser));
	} else {
		print CGI::p($userCountMessage);
	}
	
	## Problems Form ##
	my @problemList = $db->listGlobalProblems($setName);
	print CGI::a({name=>"problems"});
	print CGI::h2({}, "Problems");
	if (scalar(@problemList)) {
		print CGI::start_form({method=>"POST", action=>$r->uri.'#problems'});
		print CGI::start_table({border=>1, cellpadding=>4});
		print CGI::Tr({}, CGI::th({}, [
			($forUsers ? () : ("Delete?")), 
			"Problem",
			($forUsers ? ("Status", "Problem Seed") : ()),
			"Source File", "Max. Attempts", "Weight",
			($forUsers ? ("Number Correct", "Number Incorrect") : ())
		]));
		foreach my $problem (sort {$a <=> $b} @problemList) {
			my $problemRecord = $db->getGlobalProblem($setName, $problem); # checked
			die "global problem $problem in set $setName not found." unless $problemRecord;
			my $problemID = $problemRecord->problem_id;
			my $userProblemRecord;
			my %problemOverrideArgs;

			if ($forOneUser) {
				$userProblemRecord = $db->getUserProblem($editForUser[0], $setName, $problem); # checked
				die "problem $problem for set $setName and user $editForUser[0] not found. " unless $userProblemRecord;
				foreach my $field (@{PROBLEM_FIELDS()}) {
					$problemOverrideArgs{$field} = [defined $userProblemRecord->$field, $userProblemRecord->$field];
				}
	#		} elsif ($forUsers) {
	#			foreach my $field (@{PROBLEM_FIELDS()}) {
	#				$problemOverrideArgs{$field} = ["", ""];
	#			}
			} else {
				foreach my $field (@{PROBLEM_FIELDS()}) {
					$problemOverrideArgs{$field} = [undef, undef];
				}
			}

			print CGI::Tr({}, 
				CGI::td({}, [
					($forUsers ? () : (CGI::input({type=>"checkbox", name=>"deleteProblem", value=>$problemID}))),
					CGI::a({href=>$ce->{webworkURLs}->{root}."/$courseName/instructor/pgProblemEditor/".$setName.'/'.$problemID.'?'.$self->url_authen_args}, $problemID),
					($forUsers ? (
						problemElementHTML("problem.${problemID}.status", $userProblemRecord->status, "7"),
						problemElementHTML("problem.${problemID}.problem_seed", $userProblemRecord->problem_seed, "7"),
					) : ()),
					problemElementHTML("problem.${problemID}.source_file", $problemRecord->source_file, "40", @{$problemOverrideArgs{source_file}}),
					problemElementHTML("problem.${problemID}.max_attempts",$problemRecord->max_attempts,"7", @{$problemOverrideArgs{max_attempts}}),
					problemElementHTML("problem.${problemID}.value",$problemRecord->value,"7", @{$problemOverrideArgs{value}}),
					($forUsers ? (
						problemElementHTML("problem.${problemID}.num_correct", $userProblemRecord->num_correct, "7"),
						problemElementHTML("problem.${problemID}.num_incorrect", $userProblemRecord->num_incorrect, "7")
					) : ())
				])

			)
		}
		print CGI::end_table();
		print $self->hiddenEditForUserFields(@editForUser);
		print $self->hidden_authen_fields;
		print CGI::input({type=>"submit", name=>"submit_problem_changes", value=>"Save Problem Changes"});
		print CGI::end_form();
	} else {
		print CGI::p("This set doesn't contain any problems yet.");
	}
	
	unless ($forUsers) {
		my $libraryRoot = $ce->{courseDirs}->{templates};
		my @path = defined $self->{path} ? @{$self->{path}} : ();
		unshift @path, $libraryRoot;
		print CGI::a({name=>"addProblem"});
		print CGI::h3({}, "Add Problem(s)");
		print CGI::start_form({method=>"post", action=>$r->uri.'#addProblem'});
		print CGI::input({type=>"hidden", name=>"fileBrowsing", value=>"Yes"});
		print CGI::start_table();
		my $columns = "";
		for (my $counter = 0; $counter < scalar(@path); $counter++) {
			$columns .= CGI::td(directoryListHTML ($counter, (exists $path[$counter+1] ? $path[$counter+1] : []), @path));
		}
		print CGI::Tr($columns);
		print CGI::end_table();
		print $self->hidden_authen_fields;
		print CGI::end_form();
	}
	
	return "";
}

1;
