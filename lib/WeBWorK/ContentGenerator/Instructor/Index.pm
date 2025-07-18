package WeBWorK::ContentGenerator::Instructor::Index;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Index - Menu interface to the Instructor
pages

=cut

use WeBWorK::Utils        qw(x);
use WeBWorK::Utils::JITAR qw(jitar_id_to_seq);
use WeBWorK::Utils::Sets  qw(format_set_name_internal);

use constant E_MAX_ONE_SET  => x('Please select at most one set.');
use constant E_ONE_USER     => x('Please select exactly one user.');
use constant E_ONE_SET      => x('Please select exactly one set.');
use constant E_MIN_ONE_USER => x('Please select at least one user.');
use constant E_MIN_ONE_SET  => x('Please select at least one set.');
use constant E_SET_NAME     => x('Please specify a homework set name.');
use constant E_BAD_NAME     => x('Please use only letters, digits, dashes, underscores, and periods in your set name.');

sub pre_header_initialize ($c) {
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;

	# Make sure these are defined for the template.
	$c->stash->{users}          = [];
	$c->stash->{globalSets}     = [];
	$c->stash->{setProblemIDs}  = {};
	$c->stash->{E_MAX_ONE_SET}  = E_MAX_ONE_SET;
	$c->stash->{E_ONE_USER}     = E_ONE_USER;
	$c->stash->{E_ONE_SET}      = E_ONE_SET;
	$c->stash->{E_MIN_ONE_USER} = E_MIN_ONE_USER;
	$c->stash->{E_MIN_ONE_SET}  = E_MIN_ONE_SET;
	$c->stash->{E_SET_NAME}     = E_SET_NAME;
	$c->stash->{E_BAD_NAME}     = E_BAD_NAME;
	$c->stash->{courseID}       = $c->stash('courseID');

	my $userID = $c->param('user');

	return unless ($authz->hasPermissions($userID, 'access_instructor_tools'));

	my @selectedUserIDs = $c->param('selected_users');
	my @selectedSetIDs  = $c->param('selected_sets');

	my $nusers = @selectedUserIDs;
	my $nsets  = @selectedSetIDs;

	my $firstUserID = $nusers ? $selectedUserIDs[0] : '';
	my $firstSetID  = $nsets  ? $selectedSetIDs[0]  : '';

	# These will be used to construct the target URL.
	my ($route, %args, %params);

	my @error;

	# Depending on which button was pushed, fill in values for URL construction.
	if (defined $c->param('sets_assigned_to_user')) {
		if ($nusers == 1) {
			$route = 'instructor_user_detail';
			$args{userID} = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	} elsif (defined $c->param('users_assigned_to_set')) {
		if ($nsets == 1) {
			$route = 'instructor_users_assigned_to_set';
			$args{setID} = $firstSetID;
		} else {
			push @error, E_ONE_SET;
		}
	} elsif (defined $c->param('prob_lib')) {
		if ($nsets == 1) {
			$route = 'instructor_set_maker';
			$params{local_sets} = $firstSetID;
		} elsif ($nsets == 0) {
			$route = 'instructor_set_maker';
		} else {
			push @error, E_ONE_SET;
		}
	} elsif (defined $c->param('user_stats')) {
		if ($nusers == 1) {
			$route = 'instructor_user_statistics';
			$args{userID} = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	} elsif (defined $c->param('set_stats')) {
		if ($nsets == 1) {
			$route = 'instructor_set_statistics';
			$args{setID} = $firstSetID;
		} else {
			push @error, E_ONE_SET;
		}
	} elsif (defined $c->param('user_progress')) {
		if ($nusers == 1) {
			$route = 'instructor_user_progress';
			$args{userID} = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	} elsif (defined $c->param('set_progress')) {
		if ($nsets == 1) {
			$route          = 'instructor_set_progress';
			$args{statType} = 'set';
			$args{setID}    = $firstSetID;
		} else {
			push @error, E_ONE_SET;
		}
	} elsif (defined $c->param('user_options')) {
		if ($nusers == 1) {
			$route = 'options';
			$params{effectiveUser} = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	} elsif (defined $c->param('act_as_user')) {
		if ($nusers == 1 && $nsets <= 1) {
			if ($nsets) {
				$route = 'problem_list';
				$args{setID} = $firstSetID;
			} else {
				$route = 'set_list';
			}
			$params{effectiveUser} = $firstUserID;
		} else {
			push @error, E_ONE_USER    unless $nusers == 1;
			push @error, E_MAX_ONE_SET unless $nsets <= 1;
		}
	} elsif (defined $c->param('create_set')) {
		my $setname = format_set_name_internal($c->param('new_set_name') // '');
		if ($setname) {
			if ($setname =~ /^[\w.-]*$/) {
				$route                 = 'instructor_set_maker';
				$params{new_local_set} = 'Create a New Set in this Course';
				$params{new_set_name}  = $setname;
				$params{selfassign}    = 1;
			} else {
				push @error, E_BAD_NAME;
			}
		} else {
			push @error, E_SET_NAME;
		}
	} elsif (defined $c->param('add_users')) {
		$route = 'instructor_add_users';
		$params{number_of_students} = $c->param('number_of_students') // 1;
	}

	push @error, x('You are not allowed to act as a student.')
		if (defined $c->param('act_as_user') && !$authz->hasPermissions($userID, 'become_student'));
	push @error, x('You are not allowed to modify homework sets.')
		if (defined $c->param('edit_set_for_users')
			&& !$authz->hasPermissions($userID, 'modify_problem_sets'));
	push @error, x('You are not allowed to assign homework sets.')
		if ((defined $c->param('sets_assigned_to_user') || defined $c->param('users_assigned_to_set'))
			&& !$authz->hasPermissions($userID, 'assign_problem_sets'));
	push @error, x('You are not allowed to modify student data.')
		if ((defined $c->param('user_options') || defined $c->param('user_options'))
			&& !$authz->hasPermissions($userID, 'modify_student_data'));

	if (@error) {
		# Handle errors
		$c->addbadmessage($c->c(map { $c->maketext($_) } @error)->join($c->tag('br')));
	} elsif ($route) {
		# Redirect to target page
		$c->reply_with_redirect($c->systemLink($c->url_for($route, %args), params => \%params));
		return;
	}

	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for the
	# user if such restrictions are defined.  This list is sorted by last_name, then first_name, then user_id.
	$c->stash->{users} = [
		$db->getUsersWhere(
			{
				user_id => { not_like => 'set_id:%' },
				$ce->{viewable_sections}{$userID} || $ce->{viewable_recitations}{$userID}
				? (
					-or => [
						$ce->{viewable_sections}{$userID} ? (section => $ce->{viewable_sections}{$userID}) : (),
						$ce->{viewable_recitations}{$userID}
						? (recitation => $ce->{viewable_recitations}{$userID})
						: ()
					]
					)
				: ()
			},
			[qw/last_name first_name user_id/]
		)
	];

	$c->stash->{globalSets} = [ $db->getGlobalSetsWhere ];

	# Problem IDs for each set are needed for the "View answer log ..." action.
	for my $globalSet (@{ $c->stash->{globalSets} }) {
		my @problems = $db->listGlobalProblems($globalSet->set_id);
		@problems = map { join('.', jitar_id_to_seq($_)) } @problems
			if $globalSet->assignment_type && $globalSet->assignment_type eq 'jitar';
		$c->stash->{setProblemIDs}{ $globalSet->set_id } = \@problems;
	}

	return;
}

1;
