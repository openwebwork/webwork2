################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/NewSQL.pm,v 1.25 2008/06/21 16:38:49 gage Exp $
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

package WeBWorK::DB::Schema::NewSQL;
use base qw(WeBWorK::DB::Schema);

=head1 NAME

WeBWorK::DB::Schema::NewSQL - base class for SQL access.

=cut

use strict;
use warnings;
use Carp qw(croak);
use WeBWorK::Utils qw/undefstr/;

use constant TABLES => qw(*);
use constant STYLE  => "dbi";

################################################################################
# where clauses (not sure if this is where these belong...)
################################################################################

# default where clause (does nothing)
sub where_DEFAULT {
	return {};
}

# can be used for user,password,permission,key,set_user,problem_user,vset_user
sub where_user_id_eq {
	my ($self, $flags, $user_id) = @_;
	return {user_id=>$user_id};
}

# can be used for achievement_user
sub where_achievement_id_eq {
    my ($self, $flags, $achievement_id) = @_;
    return {achievement_id=>$achievement_id};
}

#can be used for past answers
sub where_answer_id_eq {
    my ($self, $flags, $answer_id) = @_;
    return {answer_id=>$answer_id};
}

# can be used for past_answers
sub where_course_id_eq_user_id_eq_set_id_eq_problem_id_eq {
    my ($self, $flags, $course_id, $user_id, $set_id, $problem_id) = @_;
    return {course_id=>$course_id, user_id=>$user_id, set_id=>$set_id, problem_id=>$problem_id};
}

sub where_user_id_eq_set_id_eq_problem_id_eq {
    my ($self, $flags, $user_id, $set_id, $problem_id) = @_;
    return {user_id=>$user_id, set_id=>$set_id, problem_id=>$problem_id};
}

# can be used for user,password,permission,key,set_user,problem_user
sub where_user_id_like {
	my ($self, $flags, $user_id) = @_;
	return {user_id=>{LIKE=>$user_id}};
}

# can be used for user
sub where_email_address_nonempty {
	my ($self, $flags) = @_;
	return {email_address=>{'!=',[undef,""]}};
}

# can be used for user
sub where_status_eq {
	my ($self, $flags, $status) = @_;
	return {status=>$status};
}

# can be used for user
sub where_section_eq {
	my ($self, $flags, $section) = @_;
	return {section=>$section};
}

# can be used for user
sub where_recitation_eq {
	my ($self, $flags, $recitation) = @_;
	return {recitation=>$recitation};
}

# can be used for user
sub where_section_eq_recitation_eq {
	my ($self, $flags, $section, $recitation) = @_;
	return {section=>$section,recitation=>$recitation};
}

# can be used for user
sub where_student_id_eq {
        my ($self, $flags, $student_id) = @_;
        return {student_id=>$student_id};
}

# can be used for password
sub where_password_eq {
	my ($self, $flags, $password) = @_;
	return {password=>$password};
}

# can be used for permission
sub where_permission_eq {
	my ($self, $flags, $permission) = @_;
	return {permission=>$permission};
}

# can be used for permission
sub where_permission_in_range {
	my ($self, $flags, $min, $max) = @_;
	if (defined $min and defined $max) {
		return {-and=>[ {permission=>{">=",$min}}, {permission=>{"<=",$max}} ]};
	} elsif (defined $min) {
		return {permission=>{">=",$min}};
	} elsif (defined $max) {
		return {permission=>{"<=",$max}};
	} else {
		return {};
	}
}

# can be used for set,set_user,problem,problem_user
sub where_set_id_eq {
	my ($self, $flags, $set_id) = @_;
	return {set_id=>$set_id};
}

# can be used for problem,problem_user
sub where_set_id_eq_problem_id_eq {
	my ($self, $flags, $set_id, $problem_id) = @_;
	return {set_id=>$set_id,problem_id=>$problem_id};
}

# can be used for set_user,problem_user
sub where_user_id_eq_set_id_eq {
	my ($self, $flags, $user_id, $set_id) = @_;
	return {user_id=>$user_id,set_id=>$set_id};
}

# added where clauses for locations and set_locations

sub where_location_id_eq { 
	my ($self, $flags, $location_id) = @_;
	return {location_id=>$location_id};
}

sub where_set_id_eq_location_id_eq {
	my ($self, $flags, $set_id, $location_id) = @_;
	return {set_id=>$set_id,location_id=>$location_id};
}

sub where_ip_mask_eq {
	my ($self, $flags, $ip_mask) = @_;
	return {ip_mask=>$ip_mask};
}

sub where_name_eq {
	my ($self, $flags, $name) = @_;
	return {name=>$name};
} # gotta get rid of this stupid way of specifying where clauses...

################################################################################
# utility methods
################################################################################

sub table {
	return shift->{table};
}

sub dbh {
	return shift->{driver}->dbi;
}

sub keyfields {
	return shift->{record}->KEYFIELDS;
}

sub nonkeyfields {
	return shift->{record}->NONKEYFIELDS;
}

sub fields {
	return shift->{record}->FIELDS;
}

sub field_data {
	return shift->{record}->FIELD_DATA;
}

sub initial_records {
	my ($self) = @_;
	if ($self->{record}->can("INITIAL_RECORDS")) {
		return $self->{record}->INITIAL_RECORDS;
	} else {
		return ();
	}
}

sub box {
	my ($self, $values) = @_;
	# promote undef values to empty strings. eventually we'd like to stop doing this (FIXME)
	map { $_ = "" if not defined $_ } @$values;
	return $self->{record}->new($values);
}

sub unbox {
	my ($self, $Record) = @_;
	my @values = $Record->toArray;
	# demote empty strings to undef. eventually we'd like to stop doing this (FIXME)
	map { $_ = undef if defined $_ and $_ eq "" } @values;
	return \@values;
}

sub conv_where {
	my ($self, $where) = @_;
	my $flags = {};
	if (not defined $where) {
		# allow schema module to specify a default where clause
		$where = $self->where_DEFAULT($flags);
	} elsif (ref $where eq "ARRAY") {
		my ($clause, @args) = @$where;
		my $func = "where_$clause";
		croak "Unrecognized where clause '$clause'" unless $self->can($func);
		$where = $self->$func($flags, @args);
	}
	if (wantarray) {
		return $where, $flags;
	} else {
		return $where;
	}
}

sub keyparts_to_where {
	my ($self, @keyparts) = @_;
	
	my $table = $self->{table};
	my @keynames = $self->keyfields;
	croak "got ", scalar @keyparts, " keyparts, expected at most ", scalar @keynames, " (@keynames) for table $table"
		if @keyparts > @keynames;
	
	# generate a where clause for the keyparts spec
	my %where;
	
	foreach my $i (0 .. $#keyparts) {
		next if not defined $keyparts[$i]; # undefined keypart == not restrained
		$where{$keynames[$i]} = $keyparts[$i];
	}
	
	return \%where;
}

sub keyparts_list_to_where {
	my ($self, @keyparts_list) = @_;
	
	map { $_ = $self->keyparts_to_where(@$_) } @keyparts_list;
	return \@keyparts_list;
}

sub gen_update_hashes {
	my ($self, $fields) = @_;
	
	# the values for the values hash are the index of each field in the fields list
	my %values;
	@values{@$fields} = (0..@$fields-1);
	
	# the values for the where hash are the index of each keyfield in the fields list
	my @keyfields = $self->keyfields;
	my %where;
	@where{@keyfields} = map { exists $values{$_} ? $values{$_} : die "missing keypart '$_'" } @keyfields;
	
	# don't need to update keyfields, so take them out of the values hash
	delete @values{@keyfields};
	
	return \%values, \%where;
}

our $__PACKAGE__ = __PACKAGE__;
sub debug_stmt {
	my ($self, $sth, @bind_vals) = @_;
	return unless $self->{params}{debug};
	my ($subroutine) = (caller(1))[3];
	$subroutine =~ s/^${__PACKAGE__}:://;
	my $stmt = $sth->{Statement};
	@bind_vals = undefstr("#UNDEF#", @bind_vals);
	#print STDERR "$subroutine: |$stmt| => |@bind_vals|\n";
	print STDERR "$subroutine: ", $self->bind($stmt, @bind_vals), "\n";
}

sub bind {
	my ($self, $stmt, @bind_vals) = @_;
	$stmt =~ s/\?/@bind_vals ? "?[".$self->dbh->quote(shift @bind_vals)."]" : "###NO BIND VALS###"/eg;
	$stmt .= " ###EXTRA BIND VALS |@bind_vals|###" if @bind_vals;
	return $stmt;
}

####################################################
# checking Tables
####################################################
sub tableExists {
	my $self = shift;
	my $stmt = $self->_exists_table_stmt;
	my $result = eval { $self->dbh->do($stmt); };
	( caught WeBWorK::DB::Ex::TableMissing ) ? 0:1;
}

sub _exists_table_stmt {
	my $self = shift;	
	my $sql_table_name = $self->sql_table_name;
	return "Describe `$sql_table_name` ";
}

################################################################################
# null implementations (to provide slightly nicer error messages)
################################################################################

our %API;
@API{qw/
	create_table
	rename_table
	delete_table
	count_where
	exists_where
	get_fields_where
	get_fields_where_i
	list_where
	list_where_i
	get_records_where
	get_records_where_i
	insert_fields
	insert_fields_i
	insert_records
	insert_records_i
	update_where
	update_fields
	update_fields_i
	update_records
	update_records_i
	delete_where
	delete_fields
	delete_fields_i
	delete_records
	delete_records_i
	count
	list
	exists
	get
	gets
	add
	put
	delete
/} = ();

sub AUTOLOAD {
	our $AUTOLOAD =~ /(.*)::(.*)/;
	if (exists $API{$2}) {
		croak sprintf("%s does not implement &%s", $1, $2);
	} else {
		croak sprintf("Undefined subroutine &%s called ", $AUTOLOAD," stack trace: ", caller());
	}
}

1;
