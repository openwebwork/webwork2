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

sub title {
	my ($self, @components) = @_;
	return "Problem Set Editor - ".$self->{ce}->{courseName}." : ".$self->getSetName(@components);
}

# Initialize does all of the form processing.  It's extensive, and could probably be cleaned up and
# consolidated with a little abstraction.
sub initialize {
	my ($self, @components) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $setName = $self->getSetName(@components);
	my $setRecord = $db->getGlobalSet($setName);
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUsers = scalar(@editForUser);
	my $forOneUser = $forUsers == 1;

	# build a quick lookup table
	my %overrides = list2hash $r->param('override');
	
	# The set form was submitted
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
		$db->putGlobalSet($setRecord);
		if ($forOneUser) {
			
			my $userSetRecord = $db->getUserSet($editForUser[0], $setName);
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
					
					$db->putUserSet($userSetRecord);
				}
			}
		}
	} 
}


sub body {
	my ($self, @components) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $courseName = $ce->{courseName};
	my $setName = $self->getSetName(@components);
	my $setRecord = $db->getGlobalSet($setName);
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUsers = scalar(@editForUser);
	my $forOneUser = $forUsers == 1;
	
	## Set Form ##
	my $userSetRecord;
	my %overrideArgs;
	if ($forOneUser) {
		$userSetRecord = $db->getUserSet($editForUser[0], $setName);
		foreach my $field (@{SET_FIELDS()}) {
			$overrideArgs{$field} = [defined $userSetRecord->$field, ($field =~ /_date$/ ? formatDateTime($userSetRecord->$field) : $userSetRecord->$field)];
		}
	} else {
		foreach my $field (@{SET_FIELDS()}) {
			$overrideArgs{$field} = [undef, undef];
		}
	}
	
	print CGI::h2({}, "Set Data"), "\n";	
	print CGI::start_form({method=>"post", action=>$r->uri}), "\n";
	print CGI::table({},
		CGI::Tr({}, [
			setRowHTML("Open Date:", "open_date", formatDateTime($setRecord->open_date), undef, @{$overrideArgs{open_date}})."\n",
			setRowHTML("Due Date:", "due_date", formatDateTime($setRecord->due_date), undef, @{$overrideArgs{due_date}})."\n",
			setRowHTML("Answer Date:", "answer_date", formatDateTime($setRecord->answer_date), undef, @{$overrideArgs{answer_date}})."\n",
			setRowHTML("Set Header:", "set_header", $setRecord->set_header, undef, @{$overrideArgs{set_header}})."\n",
			setRowHTML("Problem Header:", "problem_header", $setRecord->problem_header, undef, @{$overrideArgs{problem_header}})."\n"
		])
	);
	
	print $self->hiddenEditForUserFields(@editForUser);
	print $self->hidden_authen_fields;
	print CGI::input({type=>"submit", name=>"submit_set_changes", value=>"Save Set"});
	print CGI::end_form();
	
	my $problemCount = $db->listGlobalProblems($setName);
	print CGI::h2({}, "Problems"), "\n";
	print CGI::p({}, "This set contains $problemCount problem" . ($problemCount == 1 ? "" : "s").".");
	print CGI::a({href=>$r->uri."problems/?".$self->url_authen_args}, "Edit the list of problems in this set");
	
	my $userCount = $db->listUsers;
	my $usersOfSet = $db->listSetUsers($setName);
	print CGI::h2({}, "Users"), "\n";
	print CGI::p({}, "This set is assigned to ".$self->userCountMessage($usersOfSet, $userCount).".");
	print CGI::a({href=>$r->uri."users/?".$self->url_authen_args}, "Determine who this set is assigned to");
	
	return "";
}

1;
