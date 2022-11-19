################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::Instructor::ScoringDownload;
use parent qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ScoringDownload - Download scoring data files

=cut

use strict;
use warnings;

# FIXME: This should be integrated into scoring.pm, and this file deleted.

use WeBWorK::ContentGenerator::Instructor::FileManager;

async sub pre_header_initialize {
	my ($self)     = @_;
	my $r          = $self->r;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $scoringDir = $ce->{courseDirs}->{scoring};
	my $file       = $r->param('getFile');
	my $user       = $r->param('user');

	# the parameter 'getFile" needs to be sanitized. (see bug #3793 )
	# See checkName in FileManager.pm for a more complete sanitization.
	if ($authz->hasPermissions($user, "score_sets")) {
		unless ($file eq WeBWorK::ContentGenerator::Instructor::FileManager::checkName($file)) {    #
			$self->addbadmessage($r->maketext("Your file name is not valid! "));
			$self->addbadmessage($r->maketext(
				"A file name cannot begin with a dot, it cannot be empty, it cannot contain a "
					. "directory path component and only the characters -_.a-zA-Z0-9 and space are allowed."
			));
		} else {
			$self->reply_with_file("text/comma-separated-values", "$scoringDir/$file", $file, 0);
			# 0==don't delete file after downloading
		}
	} else {
		$self->addbadmessage("You do not have permission to access scoring data.");
	}

	return;
}

1;
