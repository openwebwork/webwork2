################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB.pm,v 1.58 2004/10/22 23:06:44 sh002i Exp $
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
use vars qw/$dbh/;
use WeBWorK::DBv3::Utils;

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
	
	my $lockfile = $wwdbv3_settings->{upgrade_lock};
	upgrade_schema($dbh, $lockfile);
}

sub db_Main {
	my ($self) = @_;
	return $dbh;
}

#__PACKAGE__->set_db(Main => DSN, USER, PASS, ATTR);

################################################################################

package WeBWorK::DBv3::Setting;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("setting");
__PACKAGE__->table("setting");
__PACKAGE__->columns(All => qw/name val/);

=head1 METHODS AVAILABLE TO ALL WWDBv3 CLASSES

=over

=item Class->lock_table(); Class->unlock_table();

(From Class::DBI::Extension.) Without transaction support (like MyISAM), we need
to lock tables in some cases. NOTE: Implemented SQL syntax is specific for
MySQL.

=cut

__PACKAGE__->set_sql('LockTable', <<'SQL');
LOCK TABLES %s WRITE
SQL
    ;

sub lock_table {
    my $class = shift;
    $class->sql_LockTable($class->table)->execute;
}


__PACKAGE__->set_sql('UnlockTable', <<'SQL');
UNLOCK TABLES
SQL
    ;

sub unlock_table {
    my $class = shift;
    $class->sql_UnlockTable->execute;
}

=back

=cut

################################################################################

package WeBWorK::DBv3::EquationCache;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("equation_cache");
__PACKAGE__->table("equation_cache");
__PACKAGE__->columns(All => qw/id tex width height depth/);

################################################################################

package WeBWorK::DBv3::Course;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("course");
__PACKAGE__->table("course");
__PACKAGE__->columns(All => qw/id name visible locked archived/);
__PACKAGE__->has_many(statuses => "WeBWorK::DBv3::Status");
__PACKAGE__->has_many(roles => "WeBWorK::DBv3::Role");
__PACKAGE__->has_many(sections => "WeBWorK::DBv3::Section");
__PACKAGE__->has_many(recitations => "WeBWorK::DBv3::Recitation");
__PACKAGE__->has_many(participants  => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(abstract_sets => "WeBWorK::DBv3::AbstractSet");

################################################################################

package WeBWorK::DBv3::User;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("user");
__PACKAGE__->table("user");
__PACKAGE__->columns(All => qw/id first_name last_name email_address student_id
login_id password display_mode show_old_answers/);
__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");

################################################################################

package WeBWorK::DBv3::Status;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("status");
__PACKAGE__->table("status");
__PACKAGE__->columns(All => qw/id course name allow_course_access
include_in_assignment include_in_stats include_in_scoring/);
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");

################################################################################

package WeBWorK::DBv3::Role;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("role");
__PACKAGE__->table("role");
__PACKAGE__->columns(All => qw/id course name privs/);
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");

sub priv_list {
	my ($self, @privs) = @_;
	if (@privs) {
		return $self->privs(join(",", @privs));
	} else {
		return split(",", $self->privs);
	}
}

################################################################################

package WeBWorK::DBv3::Section;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("section");
__PACKAGE__->table("section");
__PACKAGE__->columns(All => qw/id course name/);
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");

################################################################################

package WeBWorK::DBv3::Recitation;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("recitation");
__PACKAGE__->table("recitation");
__PACKAGE__->columns(All => qw/id course name/);
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_many(participants => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");

################################################################################

package WeBWorK::DBv3::Participant;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("participant");
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

################################################################################

package WeBWorK::DBv3::AbstractSet;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("abstract_set");
__PACKAGE__->table("abstract_set");
__PACKAGE__->columns(All => qw/id course name set_header problem_header
open_date due_date answer_date published problem_order reorder_type
reorder_subset_size reorder_time atomicity max_attempts_per_version
version_creation_interval versions_per_interval version_due_date_offset
version_answer_date_offset/);
__PACKAGE__->has_a(course => "WeBWorK::DBv3::Course");
__PACKAGE__->has_many(abstract_problems => "WeBWorK::DBv3::AbstractProblem");
__PACKAGE__->has_many(set_assignments => "WeBWorK::DBv3::SetAssignment");

################################################################################

package WeBWorK::DBv3::AbstractProblem;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("abstract_problem");
__PACKAGE__->table("abstract_problem");
__PACKAGE__->columns(All => qw/id abstract_set name source_type source_file
source_group_set_id source_group_select_time weight max_attempts_per_version
version_creation_interval versions_per_interval version_due_date_offset
version_answer_date_offset/);
__PACKAGE__->has_a(abstract_set => "WeBWorK::DBv3::AbstractSet");
__PACKAGE__->has_many(problem_assignments => "WeBWorK::DBv3::ProblemAssignment");

################################################################################

package WeBWorK::DBv3::SetAssignment;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("set_assignment");
__PACKAGE__->table("set_assignment");
__PACKAGE__->columns(All => qw/id abstract_set participant problem_order/);
__PACKAGE__->has_a(abstract_set => "WeBWorK::DBv3::AbstractSet");
__PACKAGE__->has_a(participant => "WeBWorK::DBv3::Participant");
__PACKAGE__->has_many(problem_assignments => "WeBWorK::DBv3::ProblemAssignment");
__PACKAGE__->has_many(set_overrides => "WeBWorK::DBv3::SetOverride");
__PACKAGE__->has_many(set_versions => "WeBWorK::DBv3::SetVersion");

################################################################################

package WeBWorK::DBv3::ProblemAssignment;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("problem_assignment");
__PACKAGE__->table("problem_assignment");
__PACKAGE__->columns(All => qw/id set_assignment abstract_problem source_file/);
__PACKAGE__->has_a(set_assignment => "WeBWorK::DBv3::SetAssignment");
__PACKAGE__->has_a(abstract_problem => "WeBWorK::DBv3::AbstractProblem");
__PACKAGE__->has_many(problem_overrides => "WeBWorK::DBv3::ProblemOverride");
__PACKAGE__->has_many(problem_versions => "WeBWorK::DBv3::ProblemVersion");

################################################################################

package WeBWorK::DBv3::SetOverride;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("set_override");
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

################################################################################

package WeBWorK::DBv3::ProblemOverride;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("problem_override");
__PACKAGE__->table("problem_override");
__PACKAGE__->columns(All => qw/id abstract_problem section recitation
participant source_type source_file source_group_set_id weight
max_attempts_per_version version_creation_interval versions_per_interval
version_due_date_offset version_answer_date_offset/);
__PACKAGE__->has_a(abstract_problem => "WeBWorK::DBv3::AbstractProblem");
__PACKAGE__->has_a(section => "WeBWorK::DBv3::Section");
__PACKAGE__->has_a(recitation => "WeBWorK::DBv3::Recitation");
__PACKAGE__->has_a(participant => "WeBWorK::DBv3::Participant");

################################################################################

package WeBWorK::DBv3::SetVersion;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("set_version");
__PACKAGE__->table("set_version");
__PACKAGE__->columns(All => qw/id set_assignment problem_order creation_date/);
__PACKAGE__->has_a(set_assignment => "WeBWorK::DBv3::SetAssignment");
__PACKAGE__->has_many(problem_versions => "WeBWorK::DBv3::ProblemVersion");

################################################################################

package WeBWorK::DBv3::ProblemVersion;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("problem_version");
__PACKAGE__->table("problem_version");
__PACKAGE__->columns(All => qw/id set_version problem_assignment creation_date
source_file seed/);
__PACKAGE__->has_a(set_version => "WeBWorK::DBv3::SetVersion");
__PACKAGE__->has_a(problem_assignment => "WeBWorK::DBv3::ProblemAssignment");
__PACKAGE__->has_many(problem_attempts => "WeBWorK::DBv3::ProblemAttempt");

################################################################################

package WeBWorK::DBv3::ProblemAttempt;
use base 'WeBWorK::DBv3';

#__PACKAGE__->set_up_table("problem_attempt");
__PACKAGE__->table("problem_attempt");
__PACKAGE__->columns(All => qw/id problem_version creation_date score data/);
__PACKAGE__->has_a(problem_version => "WeBWorK::DBv3::ProblemVersion");

################################################################################

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=cut

1;

__END__

