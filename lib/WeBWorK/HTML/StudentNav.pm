package WeBWorK::HTML::StudentNav;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::HTML::StudentNav - student navigation for all users assigned to a set.

=cut

our @EXPORT_OK = qw(studentNav);

sub studentNav ($c, $setID) {
	my $userID = $c->param('user');

	return '' unless $c->authz->hasPermissions($userID, 'become_student');

	# Find all users for the given set (except the current user) sorted by last_name, then first_name, then user_id.
	# If $setID is undefined, list all users except the current user instead.
	my @allUserRecords = $c->db->getUsersWhere(
		{
			user_id => [
				map { $_->[0] } $c->db->listUserSetsWhere(
					{ defined $setID ? (set_id => $setID) : (), user_id => { '!=' => $userID } }
				)
			]
		},
		[qw/last_name first_name user_id/]
	);

	return '' unless @allUserRecords;

	my $eUserID = $c->param('effectiveUser');

	my $filter = $c->param('studentNavFilter');

	# Find the previous, current, and next users, and format the student names for display.
	# Also create a hash of sections and recitations if there are any for the course.
	my @userRecords;
	my $currentUserIndex = 0;
	my %filters;
	for (@allUserRecords) {
		# Add to the sections and recitations if defined.  Also store the first user found in that section or
		# recitation.  This user will be switched to when the filter is selected.
		my $section = $_->section;
		$filters{"section:$section"} = [ $c->maketext('Filter by section [_1]', $section), $_->user_id ]
			if $section && !$filters{"section:$section"};
		my $recitation = $_->recitation;
		$filters{"recitation:$recitation"} = [ $c->maketext('Filter by recitation [_1]', $recitation), $_->user_id ]
			if $recitation && !$filters{"recitation:$recitation"};

		# Only keep this user if it satisfies the selected filter if a filter was selected.
		next
			unless !$filter
			|| ($filter =~ /^section:(.*)$/    && $_->section eq $1)
			|| ($filter =~ /^recitation:(.*)$/ && $_->recitation eq $1);

		my $addRecord = $_;
		$currentUserIndex = @userRecords if $addRecord->user_id eq $eUserID;
		push @userRecords, $addRecord;

		# Construct a display name.
		$addRecord->{displayName} =
			($addRecord->last_name || $addRecord->first_name
				? $addRecord->last_name . ', ' . $addRecord->first_name
				: $addRecord->user_id);
	}
	my $prevUser = $currentUserIndex > 0             ? $userRecords[ $currentUserIndex - 1 ] : 0;
	my $nextUser = $currentUserIndex < $#userRecords ? $userRecords[ $currentUserIndex + 1 ] : 0;

	# Mark the current user.
	$userRecords[$currentUserIndex]{currentUser} = 1;

	# Set up the student nav.
	return $c->include(
		'HTML/StudentNav/student_nav',
		userID           => $userID,
		eUserID          => $eUserID,
		userRecords      => \@userRecords,
		currentUserIndex => $currentUserIndex,
		prevUser         => $prevUser,
		nextUser         => $nextUser,
		filter           => $filter,
		filters          => \%filters
	);
}

1;
