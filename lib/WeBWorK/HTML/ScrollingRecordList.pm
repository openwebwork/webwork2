################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Utils/SortRecords.pm,v 1.1 2004/03/01 00:49:25 sh002i Exp $
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

package WeBWorK::HTML::ScrollingRecordList;
use base qw(Exporter);

=head1 NAME

WeBWorK::HTML::ScrollingRecordList - HTML widget for a scrolling list of
records.

=cut

use strict;
use warnings;
use Carp;
use WeBWorK::Utils::FormatRecords qw/getFormatsForClass formatRecords/;
use WeBWorK::Utils::SortRecords qw/getSortsForClass sortRecords/;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	scrollingRecordList
);

sub scrollingRecordList {
	my ($options, @Records) = @_;
	
	my %options = %$options;
	
	croak "name not found in options" unless exists $options{name};
	croak "request not found in options" unless exists $options{request};
	my $name = $options{name};
	my $r = $options{request};
	
	my $default_sort = $options{default_sort} || "";
	my $default_format = $options{default_format} || "";
	warn "default_format=$default_format\n";
	
	my $size = $options{size};
	my $multiple = $options{multiple};
	
	my $sorts = [];
	my $sort_labels = {};
	my $selected_sort = "";
	
	my $formats = [];
	my $format_labels = {};
	my $selected_format = "";
	
	my @ids = ();
	my %labels = ();
	
	my @selected_records = $r->param("$name");
	
	if (@Records) {
		my $class = ref $Records[0];
		
		($sorts, $sort_labels) = getSortsForClass($class);
		$selected_sort = $r->param("$name!sort")
			|| $default_sort
			|| (@$sorts ? $sorts->[0] : "");
		
		($formats, $format_labels) = getFormatsForClass($class);
		$selected_format = $r->param("$name!format")
			|| $default_format
			|| (@$formats ? $formats->[0] : "");
		warn "selected_format=$selected_format";
		
		@Records = sortRecords({preset=>$selected_sort}, @Records);
		
		# generate IDs from keyfields
		my @keyfields = $class->KEYFIELDS;
		foreach my $Record (@Records) {
			push @ids, join("!", map { $Record->$_ } @keyfields);
		}
		
		# generate labels hash
		@labels{@ids} = @Records;
		%labels = formatRecords({preset=>$selected_format}, %labels);
	}
	
	my %sort_popup_options = (
		-name => "$name!sort",
		-values => $sorts,
		-default => $selected_sort,
		-labels => $sort_labels,
	);
	
	my %format_popup_options = (
		-name => "$name!format",
		-values => $formats,
		-default => $selected_format,
		-labels => $format_labels,
	);
	
	my %list_options = (
		-name => "$name",
		-values => \@ids,
		-default => \@selected_records,
		-labels => \%labels,
	);
	$list_options{-size} = $size if $size;
	$list_options{-multiple} = $multiple if $multiple;
	
	return CGI::div({-class=>"ScrollingRecordList"},
		"Sort: ", CGI::popup_menu(%sort_popup_options), CGI::br(),
		"Format: ", CGI::popup_menu(%format_popup_options), CGI::br(),
		CGI::submit("$name!refresh", "Change Display Settings"), CGI::br(),
		CGI::scrolling_list(%list_options)
	);
}

1;
