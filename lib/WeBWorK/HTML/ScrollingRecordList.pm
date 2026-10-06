package WeBWorK::HTML::ScrollingRecordList;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::HTML::ScrollingRecordList - HTML widget for a scrolling list of
records.

=head1 DESCRIPTION

This module compiles the data for a list of user or set records and renders the
scrolling record list widget. Sorting, formatting, and filtering of the records
is done client side by F<htdocs/js/ScrollingRecordList/scrollingrecordlist.js>.

=cut

use Carp;
use Mojo::JSON qw(to_json);

use WeBWorK::Utils                                          qw(sortByName);
use WeBWorK::Utils::Sets                                    qw(format_set_name_display);
use WeBWorK::ContentGenerator::Instructor::ProblemSetDetail qw(FIELD_PROPERTIES);

our @EXPORT_OK = qw(scrollingRecordList);

=head1 FUNCTIONS

=over

=item scrollingRecordList($options, @records)

Returns the rendered HTML for a scrolling list of the given C<@records>. All
records must be C<WeBWorK::DB::Record::User> objects, or all must be
C<WeBWorK::DB::Record::Set> or C<WeBWorK::DB::Record::SetVersion> objects.

C<$options> is a reference to a hash that must contain:

    name       - name of scrolling list
    controller - the WeBWorK::Controller object for the current route

and may contain:

    default_sort    - name of sort to use by default
    default_format  - name of format to use by default
    default_filters - a reference to a list of names of filters to apply by default
    attrs           - a reference to a hash of attributes for the record select

=back

=cut

sub scrollingRecordList ($options, @records) {
	my %options = (default_filters => [], %$options);

	my $name = $options{name};
	my $c    = $options{controller};

	croak 'name not found in options'       unless defined $name;
	croak 'controller not found in options' unless defined $c;

	my $class = @records ? (ref $records[0]) =~ s/Version$//r : '';
	my ($type, $recordData, $filters) =
		$class eq 'WeBWorK::DB::Record::User'  ? ('user', userData($c, @records))
		: $class eq 'WeBWorK::DB::Record::Set' ? ('set',  setData($c, @records))
		: @records                             ? croak "records of class $class are not supported"
		:                                        ('', [], []);

	my %defaultFilters = map { $_ => 1 } @{ $options{default_filters} };
	$defaultFilters{all} = 1 unless %defaultFilters;

	return $c->include(
		'HTML/ScrollingRecordList/scrollingRecordList',
		name    => $name,
		options => \%options,
		filters => [
			map { [ @$_, $defaultFilters{ $_->[1] } ? (selected => undef) : () ] }
				[ "\x{27E8}" . $c->maketext('Display all possible records') . "\x{27E9}" => 'all' ],
			@$filters
		],
		listData => {
			type     => $type,
			records  => to_json($recordData),
			sort     => $c->param("$name!sort")   || $options{default_sort}   // '',
			format   => $c->param("$name!format") || $options{default_format} // '',
			selected => to_json($c->every_param($name))
		}
	);
}

# Each record is sent to the client as a hash containing the value of the record option, the raw field values used for
# sorting and filtering, and the field values used for display when those differ from the raw values.

sub userData ($c, @users) {
	my %permissionName = reverse %{ $c->ce->{userRoles} };
	my %permissions    = map { $_->user_id => $permissionName{ $_->permission } }
		$c->db->getPermissionLevelsWhere({ user_id => { not_like => 'set_id:%' } });

	my @records = map { {
		value  => $_->user_id,
		fields => {
			user_id       => $_->user_id,
			first_name    => $_->first_name,
			last_name     => $_->last_name,
			email_address => $_->email_address,
			section       => $_->section,
			recitation    => $_->recitation,
			status        => statusName($c->ce, $_->status),
			permission    => $permissions{ $_->user_id }
		}
	} } @users;

	my $blankName = "\x{27E8}" . $c->maketext('blank') . "\x{27E9}";
	my (%sections, %recitations, %statuses, %permissionLevels);
	for (@records) {
		++$sections{ $_->{fields}{section}       // '' };
		++$recitations{ $_->{fields}{recitation} // '' };
		++$statuses{ $_->{fields}{status}        // '' };
		++$permissionLevels{ $_->{fields}{permission} } if defined $_->{fields}{permission};
	}

	my @filters;
	if (keys %sections > 1) {
		push(@filters, [ $c->maketext('Section: [_1]', $_ ne '' ? $_ : $blankName) => "section:$_" ])
			for sortByName(undef, keys %sections);
	}
	if (keys %recitations > 1) {
		push(@filters, [ $c->maketext('Recitation: [_1]', $_ ne '' ? $_ : $blankName) => "recitation:$_" ])
			for sortByName(undef, keys %recitations);
	}
	if (keys %statuses > 1) {
		push(@filters, [ $c->maketext('Enrollment Status: [_1]', $_ ne '' ? $_ : $blankName) => "status:$_" ])
			for sortByName(undef, keys %statuses);
	}
	if (keys %permissionLevels > 1) {
		push(@filters, [ $c->maketext('Permission Level: [_1]', $_) => "permission:$_" ])
			for sortByName(undef, keys %permissionLevels);
	}

	return (\@records, \@filters);
}

# A status may have multiple abbreviations, so filter by the status name.
# An abbreviation that is not in the course configuration is used as is.
sub statusName ($ce, $abbrev) {
	return '' if !defined $abbrev || $abbrev eq '';
	return $ce->status_abbrev_to_name($abbrev) // $abbrev;
}

sub setData ($c, @sets) {
	my $typeLabels = FIELD_PROPERTIES()->{assignment_type}{labels};

	my @records = map { {
		# Hardcopy sets the set_id of set versions to "set_id,vN" so that this distinguishes them from global sets.
		value  => $_->set_id,
		fields => {
			set_id          => $_->set_id,
			due_date        => $_->due_date,
			assignment_type => $_->assignment_type,
			# Set versions can only exist for sets that are visible, so they are always considered visible.
			visible => $_->isa('WeBWorK::DB::Record::SetVersion') || $_->visible ? 1 : 0
		},
		display => {
			set_id          => format_set_name_display($_->set_id),
			due_date        => $c->formatDateTime($_->due_date),
			assignment_type => $c->maketext($typeLabels->{ $_->assignment_type } // $_->assignment_type)
		}
	} } @sets;

	my (%assignmentTypes, %visible);
	for (@records) {
		++$assignmentTypes{ $_->{fields}{assignment_type} };
		++$visible{ $_->{fields}{visible} };
	}

	my @filters;
	if (keys %assignmentTypes > 1) {
		push(@filters, [ $c->maketext($typeLabels->{$_} // $_) => "assignment_type:$_" ])
			for sortByName(undef, keys %assignmentTypes);
	}
	if (keys %visible > 1) {
		push(@filters, [ $c->maketext('Visible') => 'visible:1' ], [ $c->maketext('Not Visible') => 'visible:0' ]);
	}

	return (\@records, \@filters);
}

1;
