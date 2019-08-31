################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Record/User.pm,v 1.12 2006/10/02 15:04:27 sh002i Exp $
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
use Encode qw(encode);

BEGIN {
	__PACKAGE__->_fields(
		user_id       => { type=>"TINYBLOB NOT NULL", key=>1 },
		first_name    => { type=>"TEXT" },
		last_name     => { type=>"TEXT" },
		email_address => { type=>"TEXT" },
		student_id    => { type=>"TEXT" },
		status        => { type=>"TEXT" },
		section       => { type=>"TEXT" },
		recitation    => { type=>"TEXT" },
		comment       => { type=>"TEXT" },
		displayMode   => { type=>"TEXT" },
		showOldAnswers => { type=>"INT" },
		useMathView   => { type=>"INT"  },
		useWirisEditor   => { type=>"INT"  },
		useMathQuill   => { type=>"INT"  },
		lis_source_did  => { type=>"BLOB" },
	);
}

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

# phrase      =  1*word                       ; Sequence of words
# word        =  atom / quoted-string
# atom        =  1*<any CHAR except specials, SPACE and CTLs>
# specials    =  "(" / ")" / "<" / ">" / "@"  ; Must be in quoted-
#             /  "," / ";" / ":" / "\" / <">  ;  string, to use
#             /  "." / "[" / "]"              ;  within a word.
# SPACE       =  <ASCII SP, space>            ; (     40,      32.)
# CTL         =  <any ASCII control           ; (  0- 37,  0.- 31.)
#                 character and DEL>          ; (    177,     127.)
# quoted-string = <"> *(qtext/quoted-pair) <">; Regular qtext or
#                                             ;   quoted chars.
# qtext       =  <any CHAR excepting <">,     ; => may be folded
#                "\" & CR, and including
#                linear-white-space>
# CR          =  <ASCII CR, carriage return>  ; (     15,      13.)
# quoted-pair =  "\" CHAR                     ; may quote any char

# 2019 rfc822_mailbox was modified for UTF-8 support:
#   If the full_name is set it will use the RFC 2047 "MIME-Header" encoding
#   for the full_name, so that UTF-8 characters can be "sent" via the
#   permitted ASCII encoding.
# When "international emails" (RFC 6532 and RFC 6531) which allow Unicode in
#   the address become widely accepted, and are well supported by the public
#   SMTP mail infrastructure - a different approach will be needed, and
#   WW will need to validate email addresses when they are set/saved to the
#   DB based on the new standards.
# References:
#	https://tools.ietf.org/html/rfc822
#	https://tools.ietf.org/html/rfc2047
#	https://tools.ietf.org/html/rfc6531
#	https://tools.ietf.org/html/rfc6532
#	https://en.wikipedia.org/wiki/International_email#UTF-8_headers

sub rfc822_mailbox {
	my ($self) = @_;
	
	my $full_name = $self->full_name;
	my $address = $self->email_address;
	
	if (defined $address and $address ne "") {
		if (defined $full_name and $full_name ne "") {
			# Encode the user name using "MIME-Header" encoding,
			# which allows UTF-8 encoded names.
			return encode("MIME-Header", $full_name) . " <$address>";
		} else {
			return $address;
		}
	} else {
		return "";
	}
}

1;
