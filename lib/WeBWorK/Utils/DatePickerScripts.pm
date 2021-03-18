################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/DatePickerScripts.pm,v 1.48 2009/10/01 21:28:46 gage Exp $
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

package WeBWorK::Utils::DatePickerScripts;
use base qw(Exporter);
use WeBWorK::Utils qw(formatDateTime);
use POSIX;

sub date_scripts {
	my $ce = shift;
	my $set = shift;
	my $bareName = 'set.' . $set->set_id;
	my $reduced = $ce->{pg}{ansEvalDefaults}{enableReducedScoring} ? 1 : 0;
	return qq{\$(function() { new WWDatePicker("$bareName", $reduced); });};
}

1;
