################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DBv3.pm,v 1.2 2004/11/25 05:50:01 sh002i Exp $
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

package WeBWorK::DBv3;
use base 'Class::DBI';
use WeBWorK::DBv3::NormalizerMixin;
use Class::DBI::Plugin::AbstractCount;

=head1 NAME

WeBWorK::DBv3 - Class::DBI interface to WWDBv3.

=head1 SYNOPSIS

 use WeBWorK::DBv3;
 
 my $wwdbv3_settings = {
 	dsn          => "dbi:mysql:wwdbv3",
 	user         => "wwdbv3",
 	pass         => "SeCrEt",
 	attr         => {  }, # optional
 	upgrade_lock => "/path/to/wwdbv3_upgrade.lock", # prevent concurrent schema upgrades
 };
 
 WeBWorK::DBv3::init($wwdbv3_settings);
 
 # --- any time after init() as been called... ---
 
 my $course = WeBWorK::DBv3::Course->find({name => "Sam's course"})
 	or die "course not found!";
 
 my @participants = $course->participants;
 
 my $participant = WeBWorK::DBv3::Participant->find({login_name => "sam.hathaway"});
 $participant->first_name("Sam");
 $participant->last_name("Hathaway");
 $participant->update;
 
 my @set_assignments = $participant->set_assignments;

=head1 DESCRIPTION

WeBWorK::DBv3 provides a Class::DBI-based interface to the third-generation
WeBWorK database. (WeBWorK::DB provided an interface to the second-generation
database, the first-generation database was that used by WeBWorK 1.x.)

The database schema is described at
<http://devel.webwork.rochester.edu/twiki/bin/view/Webwork/DatabaseSchemaV3>.

WeBWorK::DBv3 supports automatic schema upgrades by checking the value of the
C<db_version> record in the C<setting> table and applying SQL deltas to the
database.

=cut

use strict;
use warnings;
use vars qw/$dbh $dt_format/;
use DateTime::Format::DBI;
use WeBWorK::DBv3::Utils;

=head1 INITIALIZATION

The init($wwdbv3_settings) function allows the user to set up the details of the
database connection at runtime rather than at compile time. This lets us use
values from the WeBWorK::CourseEnvironment (loaded at runtime) in specifying the
database connection.

$wwdbv3_settings is a reference to a hash containing the following values:

 dsn          => The DBI data source, e.g. "dbi:mysql:wwdbv3"
 user         => The user name with which to connect.
 pass         => The password to supply to connect.
 attr         => A reference to a hash containing DBI attributes.
                 See L<DBI> for more information.
 upgrade_lock => Path to a file which is flock()'d while performing
                 database upgrades.

=cut

sub init {
	my ($wwdbv3_settings) = @_;
	
	my $dsn  = $wwdbv3_settings->{dsn};
	my $user = $wwdbv3_settings->{user};
	my $pass = $wwdbv3_settings->{pass};
	my %attr = (
		RootClass => "DBIx::ContextualFetch", # this is supposedly important to Class::DBI
		RaiseError => 1, # we don't want to have to test return values
		%{ $wwdbv3_settings->{attr} }, # allow user-specified attributes to override
	);
	
	$dbh = DBI->connect_cached($dsn, $user, $pass, \%attr);
	
	$dt_format = new DateTime::Format::DBI($dbh);
	
	my $lockfile = $wwdbv3_settings->{upgrade_lock};
	upgrade_schema($dbh, $lockfile);
}

# override db_Main to get database handle initialized in init() above. note that
# Class::DBI->connection() is never called.
sub db_Main {
	return $dbh;
}

################################################################################

=head1 PUBLIC CLASS::DBI EXTENSIONS

WeBWorK::DBv3 extends Class::DBI to provide several features useful to users to
the WWDBv3 system.

=head2 TABLE LOCKING

When using a table type that doesn't support transactions, we need to be able to
do table-level locks. The currently implementations are from
Class::DBI::Extension and are MySQL-specific.

=over

=item lock_table()

Write-lock the current table.

=cut

__PACKAGE__->set_sql(LockTable => "LOCK TABLES %s WRITE");

sub lock_table {
    my $class = shift;
    $class->sql_LockTable($class->table)->execute;
}

=item unlock_table()

Unlock I<all> locked tables.

=cut

__PACKAGE__->set_sql(UnlockTable => "UNLOCK TABLES");

sub unlock_table {
    my $class = shift;
    $class->sql_UnlockTable->execute;
}

=back

=cut

################################################################################

=head1 INTERNAL IMPROVEMENTS

WeBWorK::DBv3 extends Class::DBI to provide several features useful in the
definition of table classes.

=head2 DATETIME SUPPORT

The method has_a_datetime() has been defined as a shortcut to specifying that a
DATETIME column should be inflated to and deflated from a DateTime.pm object.

 __PACKAGE__->has_a_datetime("open_date");

=cut

sub _datetime_inflate {
	my $dt = $dt_format->parse_datetime($_[0]) or _croak("invalid date: '$_[0]'");
	return $dt->set_time_zone("UTC");
}

sub _datetime_deflate {
	my $dt = $_[0]->clone->set_time_zone("UTC"); # clone to avoid changing timezone of original object
	return $dt_format->format_datetime($dt);
}

# this declares a column to be of type DateTime and defines inflation/deflation
# subroutines for it
sub has_a_datetime {
	my ($class, $field) = @_;
	return unless $field;
	
	$class->has_a(
		$field  => "DateTime",
		inflate => \&_datetime_inflate,
		deflate => \&_datetime_deflate,
	);
}

=head2 PER-COLUMN NORMALIZATION SUPPORT

WeBWorK::DBv3 adds per-column normalization support to Class::DBI via
WeBWorK::DBv3::NormalizerMixin. The interface and implementation are similar to
that of Class::DBI triggers (via Class::Trigger).

To add a normalizer to a field:

 __PACKAGE__->add_normalizer(field => \&normalizer_sub);

&normalizer_sub takes one argument, the value to be normalized. It should return
the normalized value. For example:

 sub _bool_normalizer { $_[0] ? 1 : 0 }
 WeBWorK::DBv3::Course->add_normalizer(visible => \&_bool_normalizer);

Like triggers, multiple normalizers can be added for a single field. However,
you cannot specify the order in which they will be run.

=cut

sub normalize_column_values {
	my ($self, $column_values) = @_;
	
	my @errors;
	
	foreach my $column (keys %$column_values) {
		#warn "callig normalizers for column '$column'.\n";
		eval { $self->call_normalizer($column_values, $column) };
		push @errors, $column => $@ if $@;
	}
	
	return unless @errors;
	$self->_croak(
		"normalize_column_values error: " . join(" ", @errors),
		method => "normalize_column_values",
		data => { @errors },
	);
}

=head3 PREDEFINED NORMALIZERS

Several normalizers are conveniently predefined using a syntax similar to that
of has_a() relationship declarations.

=over

=item has_a_boolean($field)

True values will be normalized to C<1>, false values to C<0>.

=cut

sub _bool_normalizer { $_[0] ? 1 : 0 }
sub has_a_boolean {
	my ($class, $field) = @_;
	return unless $field;
	
	$class->add_normalizer($field => \&_bool_normalizer);
}

=back

=head2 MACROS FOR UNIQUENESS CONSTRAINTS

has_unique_columns() allows you do define uniqueness constraints by listing the
fields that must be unique:

 __PACKAGE__->has_unique_columns($name => qw/field1 field2 field3/);

$name gives a name to this constraint, which is included in the error message
given when the conditions of the constraint are not met.

=cut

# FIXME this is broken -- it doesn't allow multiple NULL values! I'd rather just
# catch the DBI uniqneness violation errors and munge them in some way to get a
# useful error message out. Is there some way to do that? Would it me MySQL
# specific?
# 
# <NULL> and <NULL> - OK
# <NULL, foo> and <NULL, foo> - not OK

sub has_unique_columns {
	my ($class, $name, @columns) = @_;
	
	$class->_invalid_object_method('has_unique_columns()') if ref $class;
	$name or $class->_croak("has_unique_columns needs a name");
	
	foreach my $column (@columns) {
		# normalize columns, and croak on any invalid columns
		my $normalized_column = $class->find_column($column)
			or $class->_croak("has_unique_columns: '$column' is not a valid column");
		$column = $normalized_column;
	}
	
	# closure over @columns, $name
	my $unique_columns = sub {
		my ($self) = @_;
		my %search_spec = map { $_ => $self->$_ } @columns;
		$search_spec{id} = { '!=', $self->id };
		unless ($self->count_search_where(%search_spec) == 0) {
			my $columns = join(",", @columns);
			my $values = join(",", map "'$search_spec{$_}'", @columns);
			my $fail = @columns == 1 ? "fails" : "fail";
			return $self->_croak("$class ($columns) $fail uniqueness constraint '$name' with ($values)");
		}
	};
	
	$class->add_trigger(before_create => $unique_columns);
	$class->add_trigger(before_update => $unique_columns);
}

=head2 COMMA-SEPARATED LIST HANDLING

has_cs_list() allows you to define a column as containing a comma-separated list
of values. It will add an accessor/modifier to the invocant's class with the
suffix C<_list>.

Note that this handling is pretty dumb, and cannot deal with embedded commas.
This is typically OK, since cs_list fields are usually used to store list of
record IDs or strings that are valid identifiers. (If you really need to store
strings with embedded commas, you may URL-encode them or whatever you like. Just
make sure you decode them on the way out.)

 __PACKAGE__->has_cs_list("problem_order");
 
 # results in this method being added to __PACKAGE__
 sub problem_order_list {
 		my ($self, @list) = @_;
 		if (@list) {
 			return $self->problem_order(join(",", @list));
 		} else {
 			return split(",", $self->problem_order);
 		}
 }

=cut

sub has_cs_list {
	my ($class, $field) = @_;
	return unless $field;
	
	my $method_name = "${class}::${field}_list";
	
	# closure over $field
	my $cs_list = sub {
		my ($self, @list) = @_;
		if (@list) {
			return $self->$field(join(",", @list));
		} else {
			return split(",", $self->$field);
		}
	};
	
	no strict 'refs';
	*$method_name = $cs_list;
}

################################################################################
# Table classes: each table in the database is a subclass of WeBWorK::DBv3.
# (http://devel.webwork.rochester.edu/twiki/bin/view/Webwork/DatabaseSchemaV3)
# 
# These are in the reverse order from the order in DatabaseSchemaV3, to ensure
# that the has_a() part of a relationship occurs before the has_many() part.
# 
# From C<Class::DBI/has_many>:
# 
# When setting up the relationship we examine the foreign class's has_a()
# declarations to discover which of its columns reference our class. (Note that
# because this happens at compile time, if the foreign class is defined in the
# same file, the class with the has_a() must be defined earlier than the class
# with the has_many(). If the classes are in different files, Class::DBI should
# be able to do the right thing).
################################################################################

package WeBWorK::DBv3::ProblemAttempt;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("problem_attempt");
__PACKAGE__->columns(All => qw/id problem_version creation_date score data/);

__PACKAGE__->has_a(problem_version => "WeBWorK::DBv3::ProblemVersion");
__PACKAGE__->has_a_datetime("creation_date");

# FIXME need trigger to set creation_date

################################################################################

package WeBWorK::DBv3::ProblemVersion;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("problem_version");
__PACKAGE__->columns(All => qw/id set_version problem_assignment creation_date
source_file seed/);

__PACKAGE__->has_a(set_version => "WeBWorK::DBv3::SetVersion");
__PACKAGE__->has_a(problem_assignment => "WeBWorK::DBv3::ProblemAssignment");
__PACKAGE__->has_a_datetime("creation_date");

__PACKAGE__->has_many(problem_attempts => "WeBWorK::DBv3::ProblemAttempt");

# FIXME need trigger to set creation_date

################################################################################

package WeBWorK::DBv3::SetVersion;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("set_version");
__PACKAGE__->columns(All => qw/id set_assignment problem_order creation_date/);

__PACKAGE__->has_a(set_assignment => "WeBWorK::DBv3::SetAssignment");
__PACKAGE__->has_a_datetime("creation_date");

__PACKAGE__->has_many(problem_versions => "WeBWorK::DBv3::ProblemVersion");

# FIXME need trigger to set creation_date

#sub problem_order_list {
#	my ($self, @problem_order) = @_;
#	if (@problem_order) {
#		return $self->problem_order(join(",", @problem_order));
#	} else {
#		return split(",", $self->problem_order);
#	}
#}

__PACKAGE__->has_cs_list("problem_order");

################################################################################

package WeBWorK::DBv3::ProblemOverride;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("problem_override");
__PACKAGE__->columns(All => qw/id abstract_problem section recitation
participant source_type source_file source_group_set_id weight
max_attempts_per_version version_creation_interval versions_per_interval
version_due_date_offset version_answer_date_offset/);

__PACKAGE__->has_a(abstract_problem => "WeBWorK::DBv3::AbstractProblem");
__PACKAGE__->has_a(section => "WeBWorK::DBv3::Section");
__PACKAGE__->has_a(recitation => "WeBWorK::DBv3::Recitation");
__PACKAGE__->has_a(participant => "WeBWorK::DBv3::Participant");

# FIXME need to make version_due_date_offset/version_answer_date_offset
# DateTime::Offset objects

__PACKAGE__->has_unique_columns('override_scope_unique_for_abstract_problem'
	=> qw/section recitation participant abstract_problem/);

################################################################################

package WeBWorK::DBv3::SetOverride;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("set_override");
__PACKAGE__->columns(All => qw/id abstract_set section recitation participant
set_header hardcopy_header open_date due_date answer_date published
problem_order reorder_type reorder_subset_size atomicity
max_attempts_per_version version_creation_interval versions_per_interval
version_due_date_offset version_answer_date_offset/);

__PACKAGE__->has_a(abstract_set => "WeBWorK::DBv3::AbstractSet");
__PACKAGE__->has_a(section => "WeBWorK::DBv3::Section");
__PACKAGE__->has_a(recitation => "WeBWorK::DBv3::Recitation");
__PACKAGE__->has_a(participant => "WeBWorK::DBv3::Participant");

__PACKAGE__->has_a_datetime("open_date");
__PACKAGE__->has_a_datetime("due_date");
__PACKAGE__->has_a_datetime("answer_date");

# FIXME need to make version_due_date_offset/version_answer_date_offset
# DateTime::Offset objects

#sub problem_order_list {
#	my ($self, @problem_order) = @_;
#	if (@problem_order) {
#		return $self->problem_order(join(",", @problem_order));
#	} else {
#		return split(",", $self->problem_order);
#	}
#}

__PACKAGE__->has_cs_list("problem_order");

__PACKAGE__->has_unique_columns('override_scope_unique_for_abstract_set'
	=> qw/section recitation participant abstract_set/);

################################################################################

package WeBWorK::DBv3::ProblemAssignment;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("problem_assignment");
__PACKAGE__->columns(All => qw/id set_assignment abstract_problem source_file/);

__PACKAGE__->has_a(set_assignment => "WeBWorK::DBv3::SetAssignment");
__PACKAGE__->has_a(abstract_problem => "WeBWorK::DBv3::AbstractProblem");

__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");
__PACKAGE__->has_many(problem_versions => "WeBWorK::DBv3::ProblemVersion");

__PACKAGE__->has_unique_columns('set_assignment_unique_for_abstract_problem'
	=> qw/set_assignment abstract_problem/);

################################################################################

package WeBWorK::DBv3::SetAssignment;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("set_assignment");
__PACKAGE__->columns(All => qw/id abstract_set participant problem_order/);

__PACKAGE__->has_a(abstract_set => "WeBWorK::DBv3::AbstractSet");
__PACKAGE__->has_a(participant => "WeBWorK::DBv3::Participant");

__PACKAGE__->has_many(problem_assignments => "WeBWorK::DBv3::ProblemAssignment");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(set_versions => "WeBWorK::DBv3::SetVersion");

#sub problem_order_list {
#	my ($self, @problem_order) = @_;
#	if (@problem_order) {
#		return $self->problem_order(join(",", @problem_order));
#	} else {
#		return split(",", $self->problem_order);
#	}
#}

__PACKAGE__->has_cs_list("problem_order");

__PACKAGE__->has_unique_columns('abstract_set_unique_for_participant'
	=> qw/abstract_set participant/);

################################################################################

package WeBWorK::DBv3::AbstractProblem;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("abstract_problem");
__PACKAGE__->columns(All => qw/id abstract_set name source_type source_file
source_group_set_id source_group_select_time weight max_attempts_per_version
version_creation_interval versions_per_interval version_due_date_offset
version_answer_date_offset/);

__PACKAGE__->has_a(abstract_set => "WeBWorK::DBv3::AbstractSet");

__PACKAGE__->has_many(problem_assignments => "WeBWorK::DBv3::ProblemAssignment");

__PACKAGE__->has_unique_columns('name_unique_for_abstract_set'
	=> qw/name abstract_set/);

# FIXME need to make version_due_date_offset/version_answer_date_offset
# DateTime::Offset objects

################################################################################

package WeBWorK::DBv3::AbstractSet;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("abstract_set");
__PACKAGE__->columns(All => qw/id course name set_header hardcopy_header
open_date due_date answer_date published problem_order reorder_type
reorder_subset_size reorder_time atomicity max_attempts_per_version
version_creation_interval versions_per_interval version_due_date_offset
version_answer_date_offset/);

__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_a_datetime("open_date");
__PACKAGE__->has_a_datetime("due_date");
__PACKAGE__->has_a_datetime("answer_date");
__PACKAGE__->has_a_boolean("published");

__PACKAGE__->has_many(abstract_problems => "WeBWorK::DBv3::AbstractProblem");
__PACKAGE__->has_many(set_assignments => "WeBWorK::DBv3::SetAssignment");

# FIXME need to make version_due_date_offset/version_answer_date_offset
# DateTime::Offset objects

#sub problem_order_list {
#	my ($self, @problem_order) = @_;
#	if (@problem_order) {
#		return $self->problem_order(join(",", @problem_order));
#	} else {
#		return split(",", $self->problem_order);
#	}
#}

__PACKAGE__->has_cs_list("problem_order");

__PACKAGE__->has_unique_columns('name_unique_for_course' => qw/name course/);

################################################################################

package WeBWorK::DBv3::Participant;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("participant");
__PACKAGE__->columns(All => qw/id course user status role section recitation
last_access comment/);

__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_a(user => "WeBWorK::DBv3::User");
__PACKAGE__->has_a(status => "WeBWorK::DBv3::Status");
__PACKAGE__->has_a(role => "WeBWorK::DBv3::Role");
__PACKAGE__->has_a(section => "WeBWorK::DBv3::Section");
__PACKAGE__->has_a(recitation => "WeBWorK::DBv3::Recitation");

__PACKAGE__->has_many(set_assignments => "WeBWorK::DBv3::SetAssignment");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");

__PACKAGE__->has_unique_columns('user_unique_for_course' => qw/user course/);

################################################################################

package WeBWorK::DBv3::Recitation;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("recitation");
__PACKAGE__->columns(All => qw/id course name/);

__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");

__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");

__PACKAGE__->has_unique_columns('name_unique_for_course' => qw/name course/);

################################################################################

package WeBWorK::DBv3::Section;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("section");
__PACKAGE__->columns(All => qw/id course name/);

__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");

__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");

__PACKAGE__->has_unique_columns('name_unique_for_course' => qw/name course/);

################################################################################

package WeBWorK::DBv3::Role;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("role");
__PACKAGE__->columns(All => qw/id course name privs/);

__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");

__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");

#sub priv_list {
#	my ($self, @privs) = @_;
#	if (@privs) {
#		return $self->privs(join(",", @privs));
#	} else {
#		return split(",", $self->privs);
#	}
#}

__PACKAGE__->has_cs_list("privs");

__PACKAGE__->has_unique_columns('name_unique' => qw/name/);

################################################################################

package WeBWorK::DBv3::Status;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("status");
__PACKAGE__->columns(All => qw/id course name allow_course_access
include_in_assignment include_in_stats include_in_scoring/);

__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_a_boolean("allow_course_access");
__PACKAGE__->has_a_boolean("include_in_assignment");
__PACKAGE__->has_a_boolean("include_in_stats");
__PACKAGE__->has_a_boolean("include_in_scoring");

__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");

__PACKAGE__->has_unique_columns('name_unique' => qw/name/);

################################################################################

package WeBWorK::DBv3::User;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("user");
__PACKAGE__->columns(All => qw/id first_name last_name email_address student_id
login_id password display_mode show_old_answers/);

__PACKAGE__->has_a_boolean("show_old_answers");

__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");

__PACKAGE__->has_unique_columns('student_id_unique' => qw/student_id/);
__PACKAGE__->has_unique_columns('login_id_unique' => qw/login_id/);

################################################################################

package WeBWorK::DBv3::Course;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("course");
__PACKAGE__->columns(All => qw/id name visible locked archived/);

__PACKAGE__->has_a_boolean("visible");
__PACKAGE__->has_a_boolean("locked");
__PACKAGE__->has_a_boolean("archived");

__PACKAGE__->has_many(statuses => "WeBWorK::DBv3::Status");
__PACKAGE__->has_many(roles => "WeBWorK::DBv3::Role");
__PACKAGE__->has_many(sections => "WeBWorK::DBv3::Section");
__PACKAGE__->has_many(recitations => "WeBWorK::DBv3::Recitation");
__PACKAGE__->has_many(participants  => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(abstract_sets => "WeBWorK::DBv3::AbstractSet");

__PACKAGE__->has_unique_columns('name_unique' => qw/name/);

################################################################################

package WeBWorK::DBv3::EquationCache;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("equation_cache");
__PACKAGE__->columns(All => qw/id tex width height depth/);

################################################################################

package WeBWorK::DBv3::Setting;
use base 'WeBWorK::DBv3';

__PACKAGE__->table("setting");
__PACKAGE__->columns(All => qw/name val/);

################################################################################

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=cut

1;

__END__

