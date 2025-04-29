package WeBWorK::ContentGenerator::Instructor::ScoringDownload;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ScoringDownload - Download scoring data files

=cut

# FIXME: This should be integrated into scoring.pm, and this file deleted.

use WeBWorK::ContentGenerator::Instructor::FileManager;

sub pre_header_initialize ($c) {
	my $ce         = $c->ce;
	my $authz      = $c->authz;
	my $scoringDir = $ce->{courseDirs}->{scoring};
	my $file       = $c->param('getFile');
	my $user       = $c->param('user');

	# the parameter 'getFile" needs to be sanitized. (see bug #3793 )
	# See checkName in FileManager.pm for a more complete sanitization.
	if ($authz->hasPermissions($user, "score_sets")) {
		if ($c->WeBWorK::ContentGenerator::Instructor::FileManager::checkName($file)) {
			$c->addbadmessage($c->maketext("Your file name is not valid! "));
			$c->addbadmessage($c->maketext(
				"A file name cannot begin with a dot, it cannot be empty, it cannot contain a "
					. "directory path component and only the characters -_.a-zA-Z0-9 and space are allowed."
			));
		} else {
			$c->reply_with_file("text/comma-separated-values", "$scoringDir/$file", $file, 0);
			# 0==don't delete file after downloading
		}
	} else {
		$c->addbadmessage("You do not have permission to access scoring data.");
	}

	return;
}

1;
