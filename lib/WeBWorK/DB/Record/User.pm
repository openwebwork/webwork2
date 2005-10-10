################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/User.pm,v 1.6 2005/03/29 21:23:34 jj Exp $
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

package WeBWorK::DB::Record::User;
use base WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record::User - represent a record from the user table.

=cut

use strict;
use warnings;

sub KEYFIELDS {qw(
	user_id
)}

sub NONKEYFIELDS {qw(
	first_name
	last_name
	email_address
	student_id
	status
	section
	recitation
	comment
)}

sub FIELDS {qw(
	user_id
	first_name
	last_name
	email_address
	student_id
	status
	section
	recitation
	comment
)}

sub SQL_TYPES {qw(
	BLOB
	TEXT
	TEXT
	TEXT
	TEXT
	TEXT
	TEXT
	TEXT
	TEXT
)}

sub full_name {
	my ($self) = @_;
	
	my $first = $self->first_name;
	my $last = $self->last_name;
	
	if (defined $first and $first ne "" and defined $last and $last ne "") {
		return "$first $last";
	} elsif (defined $first and $first ne "") {
		return $first;
	} elsif (defined $last and $last ne "") {
		return $last;
	} else {
		return "";
	}
}

sub rfc822_mailbox {
	my ($self) = @_;
	
	my $full_name = $self->full_name;
	my $address = $self->email_address;
	
	if (defined $address and $address ne "") {
		if (defined $full_name and $full_name ne "") {
			return "$full_name <$address>";
		} else {
			return $address;
		}
	} else {
		return "";
	}
}

1;
