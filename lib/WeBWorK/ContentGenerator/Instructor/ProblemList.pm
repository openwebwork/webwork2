################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
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
	
	my $html = CGI::input($attributeHash);
	if (defined $override) {
		$attributeHash->{name} = "${fieldName}_override";
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
	my @contents = sort grep {m/\.pg$/ or -d $dirName.'/'.$_ and not m/^\.{1,2}$/} readDirectory($dirName);
	my %contentsPretty = map {$_ => (-d $dirName.'/'.$_ ? $_.'/' : $_)} @contents;
	
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
	my $setRecord = $db->getGlobalSet($setName);
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUsers = scalar(@editForUser);
	my $forOneUser = $forUsers == 1;

	# build a quick lookup table
	my %overrides = list2hash $r->param('override');

	# the Problem form was submitted
	if (defined($r->param('submit_problem_changes'))) {
		foreach my $problem ($r->param('deleteProblem')) {
			$db->deleteGlobalProblem($setName, $problem);
		}
		my @problemList = $db->listGlobalProblems($setName);
		foreach my $problem (@problemList) {
			my $problemRecord = $db->getGlobalProblem($setName, $problem);
			foreach my $field (@{PROBLEM_FIELDS()}) {
				my $paramName = "problem_${problem}_${field}";
				if (defined($r->param($paramName))) {
					$problemRecord->$field($r->param($paramName));
				}
			}
			$db->putGlobalProblem($problemRecord);

			if ($forOneUser) {
				my $userProblemRecord = $db->getUserProblem($editForUser[0], $setName, $problem);
				foreach my $field (@{PROBLEM_USER_FIELDS()}) {
					my $paramName = "problem_${problem}_${field}";
					if (defined($r->param($paramName))) {
						$userProblemRecord->$field($r->param($paramName));
					}
				}
				$userProblemRecord->attempted($userProblemRecord->num_correct + $userProblemRecord->num_incorrect);
				foreach my $field (@{PROBLEM_FIELDS()}) {
					my $paramName = "problem_${problem}_${field}";
					if (defined($r->param("${paramName}_override"))) {
						if (exists $overrides{$paramName}) {
							$userProblemRecord->$field($r->param("${paramName}_override"));
						} else {
							$userProblemRecord->$field(undef);
						}
						
						$db->putUserProblem($userProblemRecord);
					}
				}
				
			}
		}
	# The file list field was submitted
	} elsif (defined $r->param('fileBrowsing')) {
		my $libraryRoot = $ce->{courseDirs}->{templates};
		my $count = 0;
		my $done = 0;
		my @path = ();
		my $freeProblemID = max($db->listGlobalProblems($setName)) + 1;
		while (defined $r->param("directory_level_$count") and not $done) {
			my @selected = $r->param("directory_level_$count");
			my $dirFound = 0;
			# If any directories are selected, "cd" into the first one and stop processing this level.
			foreach my $selected (@selected) {
				if (-d join "/", $libraryRoot, @path, $selected) {
					push @path, $selected;
					$dirFound = 1;
					last;
				}
			}
			# Otherwise, create a new global problem for each of the files selected
			unless ($dirFound) {
				foreach my $selected (@selected) {
					my $file = join "/", @path, $selected;
					my $problemRecord = new WeBWorK::DB::Record::Problem;
					$problemRecord->problem_id($freeProblemID++);
					$problemRecord->set_id($setName);
					$problemRecord->source_file($file);
					$problemRecord->value("1");
					$problemRecord->max_attempts("-1");
					$db->addGlobalProblem($problemRecord);
				}
				$done = 1;
			}
			
			if (defined $r->param("open_add_$count")) {
				$done = 1;
			}
			$count++;
		}
		$self->{path} = [@path];
	}

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
	my $courseName = $ce->{courseName};
	my $setRecord = $db->getGlobalSet($setName);
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUsers = scalar(@editForUser);
	my $forOneUser = $forUsers == 1;

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
			my $problemRecord = $db->getGlobalProblem($setName, $problem);
			my $problemID = $problemRecord->problem_id;
			my $userProblemRecord;
			my %problemOverrideArgs;

			if ($forOneUser) {
				$userProblemRecord = $db->getUserProblem($editForUser[0], $setName, $problem);
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
						problemElementHTML("problem_${problemID}_status", $userProblemRecord->status, "7"),
						problemElementHTML("problem_${problemID}_problem_seed", $userProblemRecord->problem_seed, "7"),
					) : ()),
					problemElementHTML("problem_${problemID}_source_file", $problemRecord->source_file, "40", @{$problemOverrideArgs{source_file}}),
					problemElementHTML("problem_${problemID}_max_attempts",$problemRecord->max_attempts,"7", @{$problemOverrideArgs{max_attempts}}),
					problemElementHTML("problem_${problemID}_value",$problemRecord->value,"7", @{$problemOverrideArgs{value}}),
					($forUsers ? (
						problemElementHTML("problem_${problemID}_num_correct", $userProblemRecord->num_correct, "7"),
						problemElementHTML("problem_${problemID}_num_incorrect", $userProblemRecord->num_incorrect, "7")
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
