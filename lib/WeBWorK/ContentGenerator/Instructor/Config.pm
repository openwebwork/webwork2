package WeBWorK::ContentGenerator::Instructor::Config;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Config - Config

=cut

use WeBWorK::ConfigValues qw(getConfigValues);
use WeBWorK::CourseConfig qw(configObject buildSimpleConfig writeSimpleConfig);

# Make a new config object from data
sub objectify ($c, $data) {
	return configObject($c, $data);
}

sub pre_header_initialize ($c) {
	$c->stash->{configValues} = [];

	return unless $c->authz->hasPermissions($c->param('user'), 'modify_problem_sets');

	# Record status messages carried over if this is a redirect
	$c->addmessage($c->authen->flash('status_message') || '');

	my $ce = $c->ce;
	$c->stash->{configValues} = getConfigValues($ce);

	if ($c->param('make_changes')) {
		my ($fileOutput, $errors) = buildSimpleConfig($c);
		$c->addbadmessage($_) for @$errors;

		if (writeSimpleConfig($ce, $fileOutput)) {
			$c->addgoodmessage($c->maketext('Changes saved.'));

			# Redirect back to the instructor config page after saving settings.  After the redirect the now saved
			# changes will take effect.  This gives the appearance that settings take effect immediately after saving.
			$c->authen->flash(status_message => $c->{status_message}->join(''));
			$c->reply_with_redirect($c->systemLink($c->url_for('instructor_config'), params => ['current_tab']));
		} else {
			$c->addbadmessage(
				$c->c(
					$c->tag('div', $c->maketext('Unable to open the "~[COURSEROOT~]/simple.conf" file.')),
					$c->tag(
						'div',
						$c->maketext(
							'Contact the site administrator to ensure that the permissions '
								. 'are set so that the web server can write to this file.'
						)
					)
				)->join('')
			);
		}
	}

	return;
}

1;
