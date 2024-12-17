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
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ConfigObject::lms_context_id;
use Mojo::Base 'WeBWorK::ConfigObject', -signatures;

# This is only for setting a course's lms_context_id in the lti_course_map table.

sub get_value ($self, $ce) {
	my @courseMap = $self->{c}->db->getLTICourseMapsWhere({ course_id => $ce->{courseName} });
	return $courseMap[0] ? $courseMap[0]->lms_context_id : '';
}

# This actually changes a database value, and so must return the empty string
# so that it is not represented in the course's simple.conf file.
sub save_string ($self, $oldval, $use_current = 0) {
	return '' if $use_current;

	my $c  = $self->{c};
	my $ce = $c->ce;

	# Unlike all other configuration settings, this one needs to be validated. It must be ensured that this course does
	# not have the same context id as any other course on the server that has the same LTI configuration.
	if (defined $c->param($self->{name}) && $c->param($self->{name}) ne '') {
		my @courseMaps = $c->db->getLTICourseMapsWhere;

		# If a context id is going to be set and the course is configured for LTI 1.3, then make sure it has all of the
		# valid LTI 1.3 authentication parameters. Note that it is not neccessary to check that the LTIVersion is set.
		# If it were not, then this configuration setting would not be listed.
		if ($ce->{LTIVersion} eq 'v1p3'
			&& !($ce->{LTI}{v1p3}{PlatformID} && $ce->{LTI}{v1p3}{ClientID} && $ce->{LTI}{v1p3}{DeploymentID}))
		{
			$c->addbadmessage($c->maketext(
				'An LMS context id is requested to be assigned to this course which is set to use LTI 1.3, but '
					. 'this course is missing LTI 1.3 authentication parameters. This is not allowed, and so this '
					. 'setting was not saved.'
			));
			return '';
		}

		for my $courseMap (@courseMaps) {
			next
				if $courseMap->course_id eq $c->ce->{courseName}
				|| $c->param($self->{name}) ne $courseMap->lms_context_id;

			my $other_ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $courseMap->course_id }) };

			if ($ce->{LTIVersion} eq $other_ce->{LTIVersion}) {
				if (
					$ce->{LTIVersion} eq 'v1p1'
					&& (!$ce->{LTI}{v1p1}{ConsumerKey}
						|| !$other_ce->{LTI}{v1p1}{ConsumerKey}
						|| $ce->{LTI}{v1p1}{ConsumerKey} eq $other_ce->{LTI}{v1p1}{ConsumerKey})
					)
				{
					$c->addbadmessage($c->maketext(
						'The requested LMS Context ID is the same as that of another course that is also configured '
							. 'to use LTI 1.1, but the consumer keys for both this course and that course are either '
							. 'both not set or are the same. This is not allowed, and so this setting was not saved.',
						$_
					));
					return '';
				}

				if ($ce->{LTIVersion} eq 'v1p3'
					&& $ce->{LTI}{v1p3}{PlatformID} eq $other_ce->{LTI}{v1p3}{PlatformID}
					&& $ce->{LTI}{v1p3}{ClientID} eq $other_ce->{LTI}{v1p3}{ClientID}
					&& $ce->{LTI}{v1p3}{DeploymentID} eq $other_ce->{LTI}{v1p3}{DeploymentID})
				{
					$c->addbadmessage($c->maketext(
						'The requested LMS Context ID is the same as that of another course that is also configured '
							. 'to use LTI 1.3, but this course and that course have the same LTI 1.3 authentication '
							. 'parameters. This is not allowed, and so this setting was not saved.'
					));
					return '';
				}
			}
		}

		eval { $c->db->setLTICourseMap($c->ce->{courseName}, $c->param($self->{name})) };
		$c->addbadmessage($c->maketext('An error occurred saving the lms_context_id: [_1]', $@)) if $@;
	} else {
		eval { $c->db->deleteLTICourseMapWhere({ course_id => $c->ce->{courseName} }) };
		$c->addbadmessage($c->maketext('An error occurred deletinglms_context_id: [_1]', $@)) if $@;
	}

	return '';
}

# This ensures that the input for this setting always shows what is in the database. If the form is submitted, and the
# requested context id is rejected above, then that rejected value should not be shown when the page reloads.
sub entry_widget ($self, $default, $is_secret = 0) {
	$self->{c}->param($self->{name}, $default);
	return $self->SUPER::entry_widget($default);
}

sub help_title           ($self) { return $self->{c}->maketext('Setting Documentation') }
sub help_name            ($self) { return $self->{c}->maketext('[_1] setting',                   $self->{var}) }
sub help_link_aria_label ($self) { return $self->{c}->maketext('Setting documentation for [_1]', $self->{var}) }

1;
