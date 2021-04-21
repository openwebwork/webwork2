################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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




use strict;
use warnings;

package WeBWorK::ContentGenerator::PGtoTexRenderer;
use base qw(WeBWorK::ContentGenerator);

use WeBWorK::DB;
use Data::Dumper;
use Parser;
use AlgParser;
use HTML::Entities;


#use encodeURI to send code

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $PGcode = "";
	$self->{result} = "";

	$PGcode = $r->param('pgcode') if $r->param('pgcode');

	$self->translate($PGcode) if $PGcode;
}

sub content {
   #######################################################################
   # Return content of rendered problem to the browser that requested it #
   #######################################################################
	my $self = shift;
	print $self->{result};
}

sub translate {
	my $self = shift;
	my $PGcode = shift;
	my $mathObject = "*" . $PGcode;
	eval{$mathObject = AlgParser->new->parse($PGcode)->tolatex};
	$self->{result} = $mathObject;
}

#sub translate { #Old version
#	my $self = shift;
#	my $PGcode = shift;
#	my $mathObject = "*" . $PGcode;
#	eval{$mathObject = Parser->new($PGcode)->TeX};
#	$self->{result} = $mathObject;
#}

1;
