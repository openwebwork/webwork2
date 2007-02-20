################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/NewSQL/Merge.pm,v 1.7 2006/10/19 17:37:25 sh002i Exp $
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

package WeBWorK::DB::Schema::NewSQL::Versioned;
use base qw(WeBWorK::DB::Schema::NewSQL::Std);

=head1 NAME

WeBWorK::DB::Schema::NewSQL::Versioned - provide access to versioned sets.

=cut

use strict;
use warnings;
use WeBWorK::DB::Utils qw/make_vsetID make_vsetID_sql
	grok_setID_from_vsetID_sql grok_versionID_from_vsetID_sql/;

use constant TABLES => qw/set_version problem_version/;

################################################################################
# where clause
################################################################################

# Override where clause generators that can be used with versioned sets so that
# they only match versioned sets.

sub where_DEFAULT {
	my ($self, $flags) = @_;
	return {set_id=>{LIKE=>make_vsetID("%","%")}};
}

# replaces where_versionedset_user_id_eq in NewSQL
sub where_user_id_eq {
	my ($self, $flags, $user_id) = @_;
	return {user_id=>$user_id,set_id=>{LIKE=>make_vsetID("%","%")}};
}

sub where_user_id_like {
	my ($self, $flags, $user_id) = @_;
	return {user_id=>{LIKE=>$user_id},set_id=>{LIKE=>make_vsetID("%","%")}};
}

sub where_set_id_eq {
	my ($self, $flags, $set_id) = @_;
	return {set_id=>{LIKE=>make_vsetID($set_id,"%")}};
}

# replaces where_versionedset_user_id_eq_set_id_eq in NewSQL
sub where_user_id_eq_set_id_eq {
	my ($self, $flags, $user_id, $set_id) = @_;
	return {user_id=>$user_id,set_id=>{LIKE=>make_vsetID($set_id,"%")}};
}

# replaces where_versionedset_user_id_eq_set_id_eq_version_id_le in NewSQL
sub where_user_id_eq_set_id_eq_version_id_le {
	my ($self, $flags, $user_id, $set_id, $version_id) = @_;
	if ($version_id >= 1) {
		my @vsetIDs = map { make_vsetID($set_id,$_) } 1 .. $version_id;
		return {user_id=>$user_id,set_id=>\@vsetIDs};
	} else {
		# nothing matches an invalid version id
		return {-and=>\("0==1")};
	}
}

################################################################################
# overloads to fake version_id field
################################################################################

# replace the virutal set_id and version_id fields with expressions that extract
# the set and version IDs from the real set_id field
sub _get_fields_where_prepex {
	my ($self, $fields, $where, $order) = @_;
	
	if (ref $fields eq "ARRAY") {
		my @fields = @$fields; # don't want to mess up caller's copy
		foreach my $field (@fields) {
			if (lc $field eq "set_id") {
				$field = grok_setID_from_vsetID_sql("set_id")
					. " AS " . $self->sql->_quote("set_id");
			} elsif (lc $field eq "version_id") {
				$field = grok_versionID_from_vsetID_sql("set_id")
					. " AS " . $self->sql->_quote("version_id");
			} else {
				$field = $self->sql->_quote($field);
			}
		}
		$fields = join(", ", @fields);
	}
	
	return $self->SUPER::_get_fields_where_prepex($fields, $where, $order);
}

# modify the INSERT expression so that it looks like this:
# INSERT ... SET (..., set_id, ...) VALUES (..., CONCAT(?,',v',?), ...)
# this is mostly a copy of Std::_insert_fields_prep
sub _insert_fields_prep {
	my ($self, $fields) = @_;
	
	# we'll use dummy values to determine bind order
	my %values;
	@values{@$fields} = (0..@$fields-1);
	
	# VERSIONING
	if (exists $values{set_id} and exists $values{version_id}) {
		# the array form allows raw SQL and bind values
		$values{set_id} = [make_vsetID_sql("?","?"), @values{qw/set_id version_id/}];
		delete $values{version_id};
	} elsif (exists $values{set_id} or exists $values{version_id}) {
		die "can't re-create versioned set_id field without virtual set_id and version_id fields";
	} else {
		# neither set_id nor version_id present, so that's fine
		# (fine with us that is, mysql will complain that keys are missing)
	}
	
	my ($stmt, @order) = $self->sql->insert($self->table, \%values);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	return $sth, @order;
}

# where clause is already in native format (see where subroutines above)
# fieldvals (a hashref) might contain decomposed set_id/version_id fields
# set_id value:
#   +set_id, +version_id => CONCAT(?, ',v', ?) BIND: set_id, version_id
#   +set_id, -version_id => CONCAT(?, ',v', grok_versionID_from_vsetID_sql("set_id")) BIND: set_id
#   -set_id, +version_id => CONCAT(grok_setID_from_vsetID_sql("set_id", ',v', ?) BIND: version_id
#   -set_id, -version_id => not included
sub update_where {
	my ($self, $fieldvals, $where) = @_;
	
	my %fieldvals = %$fieldvals; # don't want to mess up the caller's version
	
	if (exists $fieldvals{set_id} or exists $fieldvals{version_id}) {
		my ($set_id_part, $version_id_part, @bind);
		if (exists $fieldvals{set_id}) {
			$set_id_part = "?";
			push @bind, $fieldvals{set_id};
		} else {
			$set_id_part = grok_setID_from_vsetID_sql("set_id");
		}
		if (exists $fieldvals{version_id}) {
			$version_id_part = "?";
			push @bind, $fieldvals{version_id};
		} else {
			$version_id_part = grok_versionID_from_vsetID_sql("set_id");
		}
		$fieldvals{set_id} = [make_vsetID_sql($set_id_part, $version_id_part), @bind];
		delete $fieldvals{version_id};
	}
	
	$self->SUPER::update_where(\%fieldvals, $where);
}

# this is mostly a copy of Std::_update_fields_prep
sub _update_fields_prep {
	my ($self, $fields) = @_;
	
	# get hashes to pass to update() and where()
	# (dies if any keyfield is missing from @$fields)
	my ($values, $where) = $self->gen_update_hashes($fields);
	
	# grab bind order for set_id/version_id virtual fields
	my $set_id_index = $where->{set_id};
	my $version_id_index = $where->{version_id};
	delete @$where{qw/set_id version_id/};
	
	# do the where clause separately so we get a separate bind list (cute substr trick, huh?)
	my ($stmt, @val_order) = $self->sql->update($self->table, $values);
	(substr($stmt,length($stmt),0), my @where_order) = $self->sql->where($where);
	
	# append physical set_id match clause
	$stmt .= " AND " . $self->sql->_quote("set_id") . " = " . make_vsetID_sql("?","?");
	push @where_order, $set_id_index, $version_id_index;
	
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	return $sth, \@val_order, \@where_order;
}

# don't need to override delete_where, since it'll get a pre-converted where clause
#sub delete_where;

# pretty much the same modification as _update_fields_prep
# this is mostly a copy of Std::_delete_fields_prep
sub _delete_fields_prep {
	my ($self, $fields) = @_;
	
	# get hashes to pass to update() and where()
	# (dies if any keyfield is missing from @$fields)
	my (undef, $where) = $self->gen_update_hashes($fields);
	
	# grab bind order for set_id/version_id virtual fields
	my $set_id_index = $where->{set_id};
	my $version_id_index = $where->{version_id};
	delete @$where{qw/set_id version_id/};
	
	# do the where clause separately so we get a separate bind list (cute substr trick, huh?)
	my ($stmt, @order) = $self->sql->delete($self->table, $where);
	
	# append physical set_id match clause
	$stmt .= " AND " . $self->sql->_quote("set_id") . " = " . make_vsetID_sql("?","?");
	push @order, $set_id_index, $version_id_index;
	
	print STDERR "stmt=$stmt\norder=@order\n";
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	return $sth, @order;
}

sub keyparts_to_where {
	my ($self, @keyparts) = @_;
	
	my $where = $self->SUPER::keyparts_to_where(@keyparts);
	
	if (exists $where->{set_id} and exists $where->{version_id}) {
		$where->{set_id} = make_vsetID($where->{set_id}, $where->{version_id});
		delete $where->{version_id};
	} elsif (exists $where->{set_id} or exists $where->{version_id}) {
		my $set_id_part = exists $where->{set_id} ? $where->{set_id} : "%";
		my $version_id_part = exists $where->{version_id} ? $where->{version_id} : "%";
		$where->{set_id} = {LIKE => make_vsetID($set_id_part, $version_id_part)};
		delete $where->{version_id};
	}
	
	return $where;
}

1;
