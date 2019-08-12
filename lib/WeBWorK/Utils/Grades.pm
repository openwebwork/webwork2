################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/ListingDB.pm,v 1.19 2007/08/13 22:59:59 sh002i Exp $
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

package WeBWorK::Utils::Grades;
use base qw(Exporter);

use strict;
use warnings;
use Carp;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	list_set_versions
);

###########################
# Utils::Grades
#
# Provides common grading methods for grading a set  or a versioned set
###########################

######################################################
# build list of versioned sets for this student user
# inputs:  $studentID, $setID
# returns;    ref to array of names of set versions OR (if not versioned) the $setID
#              notAssignedSet
######################################################

sub list_set_versions {
	my ($db, $studentName, $setName, $setIsVersioned) = @_;
	return ("list_set_versions requires a database reference as the first element") unless ref($db)=~/DB/;
	my @allSetNames = ();
	my $notAssignedSet = 0;
	if ( $setIsVersioned ) {
		my @setVersions = $db->listSetVersions($studentName, $setName);
		@allSetNames = map { "$setName,v$_" } @setVersions;
		# if there aren't any set versions, is it because
		#    the user isn't assigned the set (e.g., is a 
		#    proctor), or because the user hasn't completed
		#    any versions?
		if ( ! @setVersions ) {
			$notAssignedSet = 1 if (! $db->existsUserSet($studentName,$setName));
		}

	} else {
		@allSetNames = ( "$setName" );
	}
	(\@allSetNames, $notAssignedSet);
}



1;
