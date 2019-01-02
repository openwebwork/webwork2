################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/RestrictedMailer.pm,v 1.2 2006/12/05 20:57:53 sh002i Exp $
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

package WeBWorK::Utils::RestrictedMailer;
use base "Email::Sender";

=for comment

PLEASE NOTE

This class does not impose any restrictions on its own, it simply provides
restricted versions of Email::Sender's Open, OpenMultipart, MailMsg, and
MailFile methods.

The restricted methods prevent the caller from overriding parameters that
have already been specified to the constructor. For example, if the "smtp"
parameter is specified in new(), it cannot be re-specified in Open(). To lock
a parameter without specifying a value, set it to undef.

To avoid having to list all possible parameters to lock them, specify
lock_by_default=>1. To allow a locked parameter to be changed, list it in
allow_change.

To restrict the recipients that are allowed, list those recipients in
allowed_recipients.

By wrapping an instance of this class with RestrictedClosureClass, you can
prevent the user from changing the SMTP server settings and sending mail to
or from unauthorized addresses.

Method summary:
 - new (wrapped) - safe
 - Open (wrapped) - safe
 - OpenMultipart (wrapped) - safe
 - MailMsg (wrapped) - safe
 - MailFile (wrapped) - unsafe, allows read access to filesystem
 - Send - unsafe, can be used to issue SMTP commands
 - SendLine - unsafe, can be used to issue SMTP commands
 - print/SendEnc - safe
 - SendLineEnc - safe
 - SendEx - unsafe, can be used to issue SMTP commands
 - SendLineEx - unsafe, can be used to issue SMTP commands
 - Part - safe, but params cannot be locked
 - Body - safe, but params cannot be locked
 - SendFile/Attach - unsafe, allows read access to filesystem
 - EndPart - safe
 - Close - safe, but allows overriding the keepconnection parameter
 - Cancel - safe
 - QueryAuthProtocols - unsafe, allows connection to arbitrary SMTP server
 - GetHandle - safe

FIXME MailFile needs restriction on what files can be specified.

FIXME There's currently no way to restrict the arguments to Part, Body, or
SendFile/Attach, but the only time this is actually a problem is with the "file"
parameter to SendFile/Attach.

FIXME What about ctype and charset, which appear as params to new and also
appear separately as params to MailFile, Part, Body, and SendFile/Attach?

FIXME Close should check if keepconnection is locked.

FIXME QueryAuthProtocols could be made safe by prohibiting the $smtpserver
argument.

=cut

use strict;
use warnings;
use Carp;
use Scalar::Util qw/refaddr/;
use Storable qw/dclone/;
use WeBWorK::Utils qw/constituency_hash/;

# params that all methods accept
our @COMMON_PARAMS = qw/from fake_from reply replyto to fake_to cc fake_cc bcc
smtp subject headers boundary multipart ctype charset client priority confirm
debug debug_level auth authid authdomain auth_encoded keepconnection
skip_bad_recipients createmessageid onerrors/;

# params accepted by each method we're restricting
our %LEGAL_PARAMS = (
	new => constituency_hash(@COMMON_PARAMS),
	Open => constituency_hash(@COMMON_PARAMS),
	OpenMultipart => constituency_hash(@COMMON_PARAMS),
	MailMsg => constituency_hash(@COMMON_PARAMS, qw/msg/),
	MailFile => constituency_hash(@COMMON_PARAMS, qw/msg file description ctype charset encoding/),
	#Part => constituency_hash(qw/description ctype encoding disposition content_id msg charset/),
	Body => constituency_hash(qw/charset encoding ctype msg/),
	Attach => constituency_hash(qw/description ctype encoding disposition file content_id/),
);

# order of positional params
our %POSITIONAL_PARAMS = (
	new => [qw/from reply to smtp subject headers boundary/],
	Open => [qw/from reply to smtp subject headers/],
	OpenMultipart => [qw/from reply to smtp subject headers boundary/],
	MailMsg => [qw/from reply to smtp subject headers msg/],
	MailFile => [qw/from reply to smtp subject headers msg file description/],
	#Part => [qw/description ctype encoding disposition content_id msg/],
	#Body => [qw/charset encoding ctype/],
	#Attach => [qw/description ctype encoding disposition file/],
);

# legal opts:
#   - params (parameters to pass to SUPER::new, either as an arrayref of positional params or as hashref)
#   - lock_by_default (if true, params not listed in params or allow_change will be locked)
#   - allow_change (params listed here will always be changeable)
#   - allowed_recipients (if non-empty, recipient addresses must be in this list)
#   - fatal_errors (if true, attempts to modify locked params will cause an exception)
# 
sub new {
	my ($invocant, %opts) = @_;
	
	my $params = $opts{params};
	$params = munge_params("new", @$params) if ref $params eq "ARRAY";
	
	# make a deep copy of the params that will be passed to new
	# Email::Sender might delete some elements, and we need the whole thing for later comparison
	my $initial_params = dclone $params;
	
	# create the object, passing the params in
	my $self = $invocant->SUPER::new($params);
	
	# handle errors
	die $Email::Sender::Error unless ref $self;
	
	# store the set of initial params for later perusal
	$self->initial_params = $initial_params;
	
	# lock_by_default states that params listed neither in params nor in allow_change should be locked
	$self->lock_by_default = $opts{lock_by_default};
	
	# allow_change lists params that can be changed even if they appear in params OR lock_by_default is true
	# (this is stored as a HASH with undefined values for easy constituency testing)
	$self->allow_change = constituency_hash(@{$opts{allow_change}});
	
	# allowed_recipients can't be handled by setting an initial param
	$self->allowed_recipients = constituency_hash(@{$opts{allowed_recipients}});
	
	# fatal_errors will generate exceptions when locked params are changed
	# (otherwise, the changes are ignored and a warning is issued)
	$self->fatal_errors = $opts{fatal_errors};
	
	return $self;
}

sub Open {
	my $self = shift;
	my $params = munge_params("Open", @_);
	$self->filter_params("Open", $params);
	warn "this is Open: self=$self ISA=@WeBWorK::Utils::RestrictedMailer::ISA";
	return $self->SUPER::Open($params);
}

sub OpenMultipart {
	my $self = shift;
	my $params = munge_params("OpenMultipart", @_);
	$self->filter_params("OpenMultipart", $params);
	return $self->SUPER::Open($params);
}

sub MailMsg {
	my $self = shift;
	my $params = munge_params("MailMsg", @_);
	$self->filter_params("MailMsg", $params);
	return $self->SUPER::MailMsg($params);
}

sub MailFile {
	my $self = shift;
	my $params = munge_params("MailFile", @_);
	$self->filter_params("MailFile", $params);
	return $self->SUPER::MailFile($params);
}

sub _prepare_addresses {
	my ($self, $type) = @_;
	$self->SUPER::_prepare_addresses($type);
	foreach my $address (@{$self->{'to_list'}}, @{$self->{'cc_list'}}, @{$self->{'bcc_list'}}) {
		$address = $1 if $address =~ /<(.*)>/;
		croak "mail not permitted to '$address'" unless exists $self->allowed_recipients->{$address};
	}
}

################################################################################

# prefix for the keys we're adding to $self
our $PREFIX = "WeBWorK_Utils_RestrictedMailer_";

sub initial_params     : lvalue { shift->{$PREFIX."initial_params"} }
sub lock_by_default    : lvalue { shift->{$PREFIX."lock_by_default"} }
sub allow_change       : lvalue { shift->{$PREFIX."allow_change"} }
sub allowed_recipients : lvalue { shift->{$PREFIX."allowed_recipients"} }
sub fatal_errors       : lvalue { shift->{$PREFIX."fatal_errors"} }

sub skipped_recipients { return shift->{skipped_recipients} }
sub error              { return shift->{error} }
sub error_msg          { return shift->{error_msg} }

sub carp_or_croak { shift->fatal_errors ? croak @_ : carp @_ }

sub munge_params {
	my ($sub, @params) = @_;
	
	my $hash;
	if (@params) {
		if (ref $params[0] eq "HASH") {
			$hash = $params[0];
		} else {
			my @names = @{$POSITIONAL_PARAMS{$sub}};
			my $max = $#names < $#params ? $#names : $#params;
			@$hash{@names[0..$max]} = @params[0..$max];
		}
	}
	return $hash || {};
}

sub filter_params {
	my ($self, $sub, $params) = @_;
	
	foreach my $param (keys %$params) {
		if (exists $LEGAL_PARAMS{$sub}{$param}) {
			next if exists $self->{$PREFIX."allow_change"}{$param};
			if (exists $self->{$PREFIX."initial_params"}{$param}) {
				my $oldval = $self->{$PREFIX."initial_params"}{$param};
				my $newval = $params->{$param};
				next if deq($oldval, $newval);
				$self->carp_or_croak("failed to set param '$param' in method '$sub': param is locked");
				delete $params->{$param};
			} elsif ($self->{$PREFIX."lock_by_default"}) {
				$self->carp_or_croak("failed to change param '$param' in method '$sub': param is locked");
				delete $params->{$param};
			}
		} else {
			$self->carp_or_croak("invalid param '$param' in method '$sub'");
			delete $params->{$param};
		}
	}
}

sub deq {
	my ($oldval, $newval) = @_;
	
	#print "oldval=$oldval newval=$newval\n";
	if (ref $oldval and ref $newval) {
		if (ref $oldval eq ref $newval) {
			my $reftype = ref $oldval;
			if ($reftype eq "HASH") {
				my @oldkeys = sort keys %$oldval;
				my @newkeys = sort keys %$newval;
				#print "oldkeys=@oldkeys\n";
				#print "newkeys=@newkeys\n";
				return 0 unless deq(\@oldkeys, \@newkeys);
				my @oldvals = @$oldval{@oldkeys};
				my @newvals = @$newval{@newkeys};
				#print "oldvals=@oldvals\n";
				#print "newvals=@newvals\n";
				return deq(\@oldvals, \@newvals);
			} elsif ($reftype eq "ARRAY") {
				return 0 unless @$oldval == @$newval;
				for (my $i = 0; $i < @$oldval; $i++) {
					return 0 unless deq($oldval->[$i], $newval->[$i]);
				}
				return 1;
			} elsif ($reftype eq "SCALAR") {
				return deq($$oldval, $$newval);
			} elsif ($reftype eq "CODE") {
				# the best we can do here is compare the addresses
				return refaddr $oldval == refaddr $newval;
			} else {
				warn "unsupported reftype '$reftype' in deq()";
				return 0;
			}
		} else {
			return 0;
		}
	} elsif (ref $oldval) {
		return 0;
	} elsif (ref $newval) {
		return 0;
	} else {
		if (defined $oldval and defined $newval) {
			return $oldval eq $newval;
		} elsif (not defined $oldval and not defined $newval) {
			return 1;
		} else {
			return 0;
		}
	}
}

1;
