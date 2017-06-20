#!/usr/bin/env perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2017 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/bin/wwdb_upgrade,v 1.17 2007/08/13 22:59:50 sh002i Exp $
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

###
#
#  This script goes through the lib and webwork3/lib directories to determine
#  1) all local modules
#  2) all modules needed from cpan.
#
###

use strict;
use warnings;
use feature 'say';

use Array::Utils qw/array_minus/;
use List::MoreUtils qw/uniq/;
use Data::Dump qw/dump/;

BEGIN {
	die "WEBWORK_ROOT not found in environment.\n"
		unless exists $ENV{WEBWORK_ROOT};
}

our @discards = qw/mod_perl warnings strict sigtrap version/;


sub get_local_packages {
  my @packages = ();
  my $libs = "$ENV{WEBWORK_ROOT}/lib $ENV{WEBWORK_ROOT}/../pg $ENV{WEBWORK_ROOT}/webwork3/lib";
  my $output = qx(grep -r --include \\*.pm '^\\s*package\\s.*;\$' $libs);
  my @lines = split(/\n/,$output);
  for my $line (@lines){
    my @out = split(/pm:/,$line);
    if (scalar(@out)>0 && $out[1] =~ /package\s(.*);/){
      push @packages,$1;
    }
  }
  return @packages;

}

## find everything that includes use ...;  and filter out the local packages.

sub get_cpan_pacakges {

  my @local_packages = get_local_packages;
  my @packages = ();
  my $libs = "$ENV{WEBWORK_ROOT}/lib $ENV{WEBWORK_ROOT}/../pg $ENV{WEBWORK_ROOT}/webwork3/lib";
  my $output = qx(grep -r --include \\*.pm '^\\s*use\\s.*;\$' $libs);
  say $output;
  my @lines = split(/\n/,$output);
  for my $line (@lines){
    my @out = split(/pm:/,$line);
    ## pull out all use ...; lines
    if (scalar(@out)>0 && $out[1] =~ /use\s([\w:]*)\s*(qw)?;/){
      push @packages,$1;
    }
  }
  @packages = sort @packages;
  @packages = uniq @packages;
  @packages = array_minus(@packages,@discards);
  @packages = array_minus(@packages,@local_packages);
  say join "\n", @packages;
}

get_cpan_pacakges;
