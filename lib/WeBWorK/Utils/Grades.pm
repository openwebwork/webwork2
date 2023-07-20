################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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
use parent qw(Exporter);

use strict;
use warnings;

use Carp;

our @EXPORT_OK = qw(list_set_versions);

# FIXME: This module is misnamed.  It doesn't actually do anything related to grades.  The grading methods in
# WeBWorK::Utils should be moved here.

# Construct a list of versioned sets for this student user.  This returns a reference to an array of names of set
# versions and whether or not the user is assigned to the set.  The list of names will be a list of set versions if the
# set is versioned, and a list containing only the original set id otherwise.
sub list_set_versions {
	my ($db, $studentName, $setName, $setIsVersioned) = @_;
	croak 'list_set_versions requires a database reference as the first element' unless ref($db) =~ /DB/;

	my @allSetNames;
	my $notAssignedSet = 0;

	if ($setIsVersioned) {
		my @setVersions = $db->listSetVersions($studentName, $setName);
		@allSetNames = map {"$setName,v$_"} @setVersions;
		# If there are not any set versions, it may be because the user is not assigned the set,
		# or because the user hasn't completed any versions.
		$notAssignedSet = 1 if !@setVersions && !$db->existsUserSet($studentName, $setName);
	} else {
		@allSetNames    = ($setName);
		$notAssignedSet = 1 if !$db->existsUserSet($studentName, $setName);
	}

	return (\@allSetNames, $notAssignedSet);
}

1;
