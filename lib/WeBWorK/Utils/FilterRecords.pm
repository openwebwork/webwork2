################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/FilterRecords.pm,v 1.5 2006/09/25 22:14:54 sh002i Exp $
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

package WeBWorK::Utils::FilterRecords;
use base qw(Exporter);

use WeBWorK::Utils qw(sortByName);

=head1 NAME

WeBWorK::Utils::FilterRecords - utilities for sorting database records.

=head1 SYNOPSIS

 use WeBWorK::Utils::FilterRecords qw/getFiltersForClass/;
 
 # get a list of sorts
 my ($FiltersRef, $FilterLabelsRef) = getFiltersForClass(@Users);
 my @filters      = @$filtersRef;      # filter names
 my %FilterLabels = %$FilterLabelsRef; # suitable for CGI's "-labels" parameter

 use WeBWorK::Utils::FilterRecords qw/FilterRecords/;
 
 # start with a list of records
 my @Users = $db->getUsers($db->listUsers);
 
 # sort the records using a preset
 @FilteredUsers = FilterRecords({preset=>"none"}, @Users);
 
 # or provide a custom sort
 @FilteredUsers = FilterRecords({fields=>[qw/section /]}, @Users);

=head1 DESCRIPTION

This module provides record filtering functions, and a collection of preset filters
for the standard WeBWorK record classes. Filters are specified by a list
of field names. Records that match the current user in the specified field will be 
allowed through

=cut

use strict;
use warnings;
use Carp;
our @EXPORT    = ();
our @EXPORT_OK = qw(
	getFiltersForClass
	filterRecords
);

#use constant PRESET_FILTERS => {
#	"WeBWorK::DB::Record::User" => {
#		"all" => {
#			name => "List all available students",
#			fields => [ qw// ],
#		},
#	},
#};


=head1 FUNCTIONS

=over

=item getFiltersForClass($class)

Given the name of a record class, returns the preset filters available for that
class.

The return value consists of a two-element list. The first element is a
reference to a list of filter names. The second element is a reference to a hash
mapping filter names to string descriptions.

Together, these two lists are suitable for passing to the C<-values> and
C<-labels> parameters of several CGI module methods, i.e. popup_menu(),
scrolling_list(), checkbox_group(), and radio_group().

=cut

sub getFiltersForClass {
	my (@Records) = @_;

	my (%sections, %recitations);
	my (@names,%labels);
	push @names, "all";
	$labels{all} = "Display all possible records";
	
	if (ref $Records[0] eq "WeBWorK::DB::Record::User"){
		foreach my $user (@Records){
			$sections{$user->section}++;
			$recitations{$user->recitation}++;
		}
	
		if (scalar(keys %sections) > 1) {
		  foreach my $sec (sortByName(undef, keys %sections)){
			push @names, "section:$sec";
			if ($sec ne ""){
				$labels{"section:$sec"} = "Display section $sec";
			} else {
				$labels{"section:$sec"} = "Display section <blank>";
			}
		  }
		}

		if (scalar(keys %recitations) > 1) {
		  foreach my $rec (sortByName(undef, keys %recitations)){
			push @names, "recitation:$rec";
			if ($rec ne ""){
				$labels{"recitation:$rec"} = "Display recitation $rec";
			} else {
			        $labels{"recitation:$rec"} = "Display recitation <blank>";
			}
		  }
		}
	}
	return ( \@names, \%labels );
}

=item sortRecords(\%options, @Records)

Given a sort specification (or the name of a preset format) and a list of
records, returns a list of the same records in order according to the sort.

%options can consist of either:

 preset => the name of a preset format listed by getFormatsForClass()

or:

 fields => a reference to a list of fields in the records' class

If C<preset> is given, and its value does not match any known preset but I<is>
the name of a field in the record class, the records will be sorted by that
field.

If C<fields> is given, the records are sorted according to the specified fields.
If multiple fields are specified, the second field is is consulted if two
records are found to have identical first fields, and so on.

=cut

# DBFIXME filtering should happen in the database (WHERE clauses)
sub filterRecords {
	my ($options, @Records) = @_;
	
	# nothing to do
	return () unless @Records;
	
	# get class info (we assume that the records are all of the same type)
	
	my %options = %$options;
	
	my @filtersToUse = @{$options{filter}};

	if (grep {$_ eq "all"} @filtersToUse) {return @Records;}
	
	my @GoodRecords = ();
	foreach my $record (@Records){
	foreach my $fil (@filtersToUse){
		my ($name, $value) = split(/:/, $fil);
		#warn "filter = $fil";
		#warn "name = $name";
		#warn "value = $value";
		#warn "section = $record->section";
#		my @data = split(/::/, $record);
		if ($record->$name eq $value) {push @GoodRecords, $record}
	}
	}
	return @GoodRecords;
}

=back

=head1 BUGS

No provision for case-insensitive, descending, or numeric sorting.

No provision for programmatic sorts. While a one-time programmatic sort can be
done easily without using this module, programmatic preset sorts would be
useful, i.e. for intelligent sorting of set IDs.

The fields being compared cannot contain nulls, because of the way packed keys
are being generated.

=cut

1;
