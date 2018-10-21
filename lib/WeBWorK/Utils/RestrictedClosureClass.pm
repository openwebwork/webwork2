################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/RestrictedClosureClass.pm,v 1.4 2007/08/10 00:27:14 sh002i Exp $
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

package WeBWorK::Utils::RestrictedClosureClass;

=head1 NAME

WeBWorK::Utils::RestrictedClosureClass - Protect instance data and only allow
calling of specified methods.

=head1 SYNPOSIS

 package MyScaryClass;
 
 sub new { return bless { @_[1..$#_] }, ref $_[0] || $_[0] }
 sub get_secret { return $_[0]->{secret_data} }
 sub set_secret { $_[0]->{secret_data} = $_[1] }
 sub use_secret { print "Secret length is ".length($_[0]->get_secret) }
 sub call_for_help { print "HELP!!" }
 
 package main;
 use WeBWorK::Utils::RestrictedClosureClass;
 
 my $unlocked = new MyScaryClass(secret_data => "pErL iS gReAt");
 my $locked = new WeBWorK::Utils::RestrictedClosureClass($obj, qw/use_secret call_for_help/);
 
 $unlocked->get_secret;                # OK
 $unlocked->set_secret("fOoBaR");      # OK
 $unlocked->use_secret;                # OK
 $unlocked->call_for_help;             # OK
 print $unlocked->{secret_data};       # OK
 $unlocked->{secret_data} = "WySiWyG"; # OK
 
 $locked->get_secret;                  # NG (not in method list)
 $locked->set_secret("fOoBaR");        # NG (not in method list)
 $locked->use_secret;                  # OK
 $locked->call_for_help;               # OK
 print $locked->{secret_data};         # NG (not a hash reference)
 $locked->{secret_data} = "WySiWyG";   # NG (not a hash reference)

=head1 DESCRIPTION

RestrictedClosureClass generates a wrapper object for a given object that
prevents access to the objects instance data and only allows specified method
calls. The wrapper object is a closure that calls methods of the underlying
object, if permitted.

This is great for exposing a limited API to an untrusted environment, i.e. the
PG Safe compartment.

=head1 CONSTRUCTOR

=over

=item $wrapper_object = CLASS->new($object, @methods)

Generate a wrapper object for the given $object. Only calls to the methods
listed in @methods will be permitted.

=back

=head1 LIMITATIONS

You can't call SUPER methods, or methods with an explicit class given:

 $locked->SUPER::call_for_help         # NG, would be superclass of RestrictedClosureClass

=head1 SEE ALSO

L<perltoot/Closures-as-Objects>

=cut

use strict;
use warnings;
use Carp;
use Scalar::Util qw/blessed/;

sub new {
	my ($invocant, $object, @methods) = @_;
	croak "wrapper class with no methods is dumb" unless @methods;
	my $class = ref $invocant || $invocant;
	croak "object is not a blessed reference" unless blessed $object;
	my %methods; @methods{@methods} = ();
	my $self = sub { # CLOSURE over $object, %methods;
		my $method = shift;
		if (not exists $methods{$method}) {
			croak "Can't locate object method \"$method\" via package \"".ref($object)."\" fnord";
		}
		return $object->$method(@_);
	};
	return bless $self, $class;
}

sub AUTOLOAD {
	my $self = shift;
	my $name = our $AUTOLOAD;
	$name =~ s/.*:://;
	return if $name eq "DESTROY"; # real obj's DESTROY method called when closure goes out of scope
	return $self->($name, @_);
}

1;

