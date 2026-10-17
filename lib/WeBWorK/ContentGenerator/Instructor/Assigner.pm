package WeBWorK::ContentGenerator::Instructor::Assigner;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Assigner - Assign homework sets to users.

=cut

use WeBWorK::Utils::Instructor qw(assignSetsToUsers unassignSetsFromUsers);

sub pre_header_initialize ($c) {
	my $db    = $c->db;
	my $authz = $c->authz;
	my $ce    = $c->ce;
	my $user  = $c->param('user');

	# Make sure these are defined for the template.
	$c->stash->{users}      = [];
	$c->stash->{globalSets} = [];

	return
		unless $authz->hasPermissions($user, 'access_instructor_tools')
		&& $authz->hasPermissions($user, 'assign_problem_sets');

	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for the
	# user if such restrictions are defined.
	$c->stash->{users} = [
		$db->getUsersWhere({
			user_id => { not_like => 'set_id:%' },
			$ce->{viewable_sections}{$user} || $ce->{viewable_recitations}{$user}
			? (
				-or => [
					$ce->{viewable_sections}{$user}    ? (section    => $ce->{viewable_sections}{$user})    : (),
					$ce->{viewable_recitations}{$user} ? (recitation => $ce->{viewable_recitations}{$user}) : ()
				]
				)
			: ()
		})
	];
	$c->stash->{globalSets} = [ $db->getGlobalSetsWhere ];

	if (defined $c->param('assign') || defined $c->param('unassign')) {
		# Get inputted users and sets filtered based on available users and sets.
		my %available_users = map  { $_->user_id => 1 } @{ $c->stash->{users} };
		my %available_sets  = map  { $_->set_id  => 1 } @{ $c->stash->{globalSets} };
		my @selected_users  = grep { $available_users{$_} } $c->param('selected_users');
		my @selected_sets   = grep { $available_sets{$_} } $c->param('selected_sets');

		if (@selected_users && @selected_sets) {
			if (defined $c->param('assign')) {
				assignSetsToUsers($db, $ce, \@selected_sets, \@selected_users);
				$c->addgoodmessage($c->maketext('All assignments were made successfully.'));
			}
			if (defined $c->param('unassign') && $c->param('confirm_unassign')) {
				unassignSetsFromUsers($db, \@selected_sets, \@selected_users) if (defined $c->param('unassign'));
				$c->addgoodmessage($c->maketext('All unassignments were made successfully.'));
			}
		} else {
			$c->addbadmessage('You must select one or more users below.')
				unless @selected_users;
			$c->addbadmessage('You must select one or more sets below.')
				unless @selected_sets;
		}
	}

	return;
}

1;
