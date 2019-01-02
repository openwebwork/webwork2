################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/NewSQL/VersionedMerge.pm,v 1.1 2007/03/01 22:09:51 glarose Exp $
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

package WeBWorK::DB::Schema::NewSQL::VersionedMerge;
use base qw(WeBWorK::DB::Schema::NewSQL::Merge);

=head1 NAME

WeBWorK::DB::Schema::NewSQL::VersionedMerge - hack to get merged records 
from multiple tables in the SQL database, for versioned sets and problems

=cut

use strict;
use warnings;
use Carp qw(croak);
use Iterator;
use Iterator::Util;
use WeBWorK::DB::Utils::SQLAbstractIdentTrans;
use WeBWorK::Debug;
use WeBWorK::DB::Utils qw/make_vsetID/;

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item merge

A reference to an array listing the tables to merge, from highest priority to
lowest priority.

=back

=cut

################################################################################
# constructor for merge-specific behavior, and methods fundamental 
# to the merge, are inherited from Merge.pm
################################################################################

################################################################################
# lowlevel get
################################################################################

sub get_fields_where {
	my ( $self, $fields, $where, $order ) = @_;

	# note: this is ugly because we've got two different table models 
        #   that we're combining: {}_user and {}_version.  $self is inheriting
	#   from Merge.pm, and so is using the first model; thus it doesn't
        #   know how to deal with where clauses that include version_ids, 
        #   and calling $self->conv_where() will therefore bail when we have
        #   a restriction on the version_id.  if we use 
	#   $db->{*_version}->conv_where(), there's no error, and the set_id
	#   gets converted to the form we need to find the record in the 
	#   *_user table.
        # however, to make things more interesting, if we're entering here 
        #   from a call of $db->{set_version_merged}->gets(), there's no 
	#   trouble, because we're using $self->keyparts_to_where(), which 
	#   has no trouble returning a %$where hash including a version_id key.
	# the result is that we have to check for what $where is saying
	#   here, even though we'd like to suppress that for the different
	#   _get_fields_where_prepex() routines, because we have to be sure 
	#   that we don't hand a @$where clause including version_id 
	#   information to $self->conv_where().  yuck!

	if ( ref($where) eq 'ARRAY' ) {
	    my ( $nvtable ) = ( $self->table =~ /(.+)_merged/ );
	    my $newWhere = $self->{db}->{$nvtable}->conv_where( $where );
	    if ( defined( $newWhere->{set_id} ) && 
		 $newWhere->{set_id} =~ /,v(\d+)$/ ) {
		$newWhere->{version_id} = $1;
		$newWhere->{set_id} =~ s/,v(\d+)$//; 
	    }
	    $where = $newWhere;
	}

	# get merged {}_user and {} records; to do this we have to be 
	# careful that we don't get fooled by references to versions
	my %nvWhere = %$where;
	for my $key ( keys %nvWhere ) {
		delete( $nvWhere{$key} ) if $key eq 'version_id';
	}
	my @nvFields = grep { $_ ne 'version_id' } @$fields;

	my $sth = $self->_get_fields_where_prepex(\@nvFields, \%nvWhere, $order);
	my @results = @{ $sth->fetchall_arrayref };
	$sth->finish;

	# then get data for this version
	$sth = $self->_get_fields_where_prepex_extra( $fields, $where, $order );
	my @vresults = @{ $sth->fetchall_arrayref };
	$sth->finish;

	# build a set of results hashes to facilitate merging the two sets
	# of data, which will have different fields
	my @res = ();
	foreach my $r ( @results ) {
		push(@res, { map {$nvFields[$_]=>$r->[$_]} (0..$#nvFields) });
	}
	my @vres = ();
	foreach my $r ( @vresults ) {
		push(@vres, {map {$fields->[$_]=>$r->[$_]} (0..$#{@$fields})});
	}

# 	my $rstr = "( ";
# 	foreach (@results) { $rstr .= "[" . join(',', @{$_}) . "]\n"; }
# 	warn("$rstr )\n");
# 	my $vstr = "( ";
# 	foreach (@vresults) { $vstr .= "[" . join(',', @{$_}) . "]\n"; }
# 	warn("$vstr )\n");

	# finally, brutally merge these
	my @mergedResults = ();
	for ( my $i=0; $i<@vres; $i++ ) {
		my @mres = ();
		foreach my $f ( @$fields ) {
		    # there should be a more elegant way of doing this
			if ( defined( $vres[$i]->{$f} ) ) {
				push( @mres, $vres[$i]->{$f} );
			} elsif ( defined( $res[$i]->{$f} ) ) {
				push( @mres, $res[$i]->{$f} );
			} else {
				push( @mres, undef );
			}
		}
		push( @mergedResults, [ @mres ] );
	}

# 	$rstr = "( ";
# 	foreach (@mergedResults) { $rstr .= "[" . join(',', @{$_}) . "]\n"; }
# 	warn("$rstr )\n");

	return @mergedResults;
}

sub _get_fields_where_prepex_extra { 
	my ( $self, $fields, $where, $order ) = @_;

	# we have a problem with the $where parameters, because they 
	# haven't been sent through the Versioned where clause generators
	# manually fix those to deal with the set_id and version_id keys
	my %vWhere = %$where;
	if ( defined($vWhere{'set_id'}) && defined($vWhere{'version_id'}) ) {
		$vWhere{'set_id'} = make_vsetID($vWhere{'set_id'}, $vWhere{'version_id'});
		delete( $vWhere{'version_id'} );
	} elsif ( defined($vWhere{'set_id'}) || defined($vWhere{'version_id'}) ) {
		if ( defined($vWhere{'version_id'}) ) {
			warn("Error: where clause includes version_id and not a set_id.\n");
			delete( $vWhere{'version_id'} );
		}
		if ( defined($vWhere{'set_id'}) ) {
			warn("Error: where clause includes set_id and not a version_id ($vWhere{set_id}).\n");
			delete( $vWhere{'set_id'} );
		}
	}
# 	warn("fields = ", "@$fields", "\n");
# 	warn("vWhere = ", join("; ", map{"$_=>$vWhere{$_}"} keys %vWhere), "\n");

	my $db = $self->{db};

	my ($table) = ($self->table =~ /(.+)_merged/);
	return $db->{$table}->_get_fields_where_prepex( $fields, \%vWhere, $order );
}

################################################################################
# getting keyfields (a.k.a. listing)
################################################################################

*list_where = *WeBWorK::DB::Schema::NewSQL::Versioned::list_where;
*list_where_i = *WeBWorK::DB::Schema::NewSQL::Versioned::list_where_i;

################################################################################
# getting records
################################################################################

*get_records_where = *WeBWorK::DB::Schema::NewSQL::Versioned::get_records_where;
*get_records_where_i = *WeBWorK::DB::Schema::NewSQL::Versioned::get_records_where_i;

################################################################################
# compatibility methods for old API
################################################################################

*get = *WeBWorK::DB::Schema::NewSQL::Versioned::get;
*gets = *WeBWorK::DB::Schema::NewSQL::Versioned::gets;

################################################################################
# utility methods
################################################################################

*sql = *WeBWorK::DB::Schema::NewSQL::Versioned::sql;

1;
