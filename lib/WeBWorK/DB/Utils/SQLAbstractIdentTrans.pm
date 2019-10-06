################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Utils/SQLAbstractIdentTrans.pm,v 1.4 2007/03/02 23:12:28 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::DB::Utils::SQLAbstractIdentTrans;
use base qw(SQL::Abstract);

=head1 NAME

WeBWorK::DB::Utils::SQLAbstractIdentTrans - subclass of SQL::Abstract that
allows custom hooks to transform identifiers.

=cut

use strict;
use warnings;

sub _table	{
	my $self = shift;
	my $tab	 = shift;
	if (ref $tab eq 'ARRAY') {
		return join ', ', map { $self->_quote_table($_) } @$tab;
	} else {
		return $self->_quote_table($tab);
	}
}

sub _quote {
	my $self  = shift;
	my $label = shift;
	
	return $label if $label eq '*';
	
	return $self->_quote_field($label)
		if !defined $self->{name_sep};
	
	if (defined $self->{transform_all}) {
		return $self->{transform_all}->($label);
	} elsif ($label =~ /(.+)\.(.+)/) {
		return $self->_quote_table($1) . $self->{name_sep} . $self->_quote_field($2);
	} else {
		return $self->_quote_field($label);
	}
}

sub _quote_table {
	my $self  = shift;
	my $label = shift;
	
	# if the table name is a scalar reference, leave it alone (but dereference it)
	return $$label if ref $label eq "SCALAR";
	
	# call custom transform function
	$label = $self->{transform_table}->($label)
		if defined $self->{transform_table};
	
	return $self->{quote_char} . $label . $self->{quote_char};
}

sub _quote_field {
	my $self  = shift;
	my $label = shift;
	
	# call custom transform function
	$label = $self->{transform_field}->($label)
		if defined $self->{transform_field};
	
	return $self->{quote_char} . $label . $self->{quote_char};
}

sub _order_by {
    my $self = shift;
    my $ref = ref $_[0];

    my @vals = $ref eq 'ARRAY'  ? @{$_[0]} :
               $ref eq 'SCALAR' ? $_[0]    : # modification: don't dereference scalar refs
               $ref eq ''       ? $_[0]    :
               SQL::Abstract::puke "Unsupported data struct $ref for ORDER BY";

    # modification: if an item is a scalar ref, don't quote it, only dereference it
    my $val = join ', ', map { ref $_ eq "SCALAR" ? $$_ : $self->_quote($_) } @vals;
    return $val ? $self->_sqlcase(' order by')." $val" : '';
}

1;
