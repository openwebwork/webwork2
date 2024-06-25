###############################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::LTIAdvanced;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

use Net::OAuth;
use UUID::Tiny ':std';
use Mojo::JSON qw(encode_json);

use WeBWorK::Utils::Sets qw(format_set_name_display);
use WeBWorK::Utils::CourseManagement qw(listCourses);
use WeBWorK::DB;

$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;

sub initializeRoute ($c, $routeCaptures) {
	# If this is an LTI 1.1 content item request from an LMS course, then find the courseID of the course that that has
	# this LMS course name set in its course environment.  If this is a submission of the content selection form, then
	# get it from the form parameter.
	if ($c->current_route eq 'ltiadvanced_content_selection') {
		$c->stash->{isContentSelection} = 1;

		my $courseID = $c->param('courseID');
		if (!$courseID && $c->param('context_id')) {
			# The database object used here is not associated to any course,
			# and so the only has access to non-native tables.
			my @matchingCourses = WeBWorK::DB->new(WeBWorK::CourseEnvironment->new->{dbLayout})
				->getLTICourseMapsWhere({ lms_context_id => $c->param('context_id') });

			if (@matchingCourses == 1) {
				$courseID = $matchingCourses[0]->course_id;
			} elsif ($c->param('oauth_consumer_key')) {
				for (@matchingCourses) {
					my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $_->course_id }) };
					if ($@) { warn "Failed to initialize course environment for $_: $@\n"; next; }
					if (($ce->{LTIVersion} // '') eq 'v1p1'
						&& $ce->{LTI}{v1p1}{ConsumerKey}
						&& $ce->{LTI}{v1p1}{ConsumerKey} eq $c->param('oauth_consumer_key'))
					{
						$courseID = $_->course_id;
						last;
					}
				}
			}
		}
		$routeCaptures->{courseID} = $c->stash->{courseID} = $courseID if $courseID;
	}

	return;
}

sub content_selection ($c) {
	return $c->render(
		'ContentGenerator/LTI/content_item_selection_error',
		errorMessage => $c->maketext(
			'No WeBWorK course was found associated to this LMS course. '
				. 'If this is an error, please contact the WeBWorK system administrator.'
		),
		contextData => [
			[ $c->maketext('LTI Version'),   '1.1' ],
			[ $c->maketext('Context Title'), $c->param('context_title') ],
			[ $c->maketext('Context ID'),    $c->param('context_id') ]
		]
	) unless $c->stash->{courseID};

	return $c->render('ContentGenerator/LTI/content_item_selection_error',
		errorMessage => $c->maketext('You are not authorized to access instructor tools.'))
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render('ContentGenerator/LTI/content_item_selection_error',
		errorMessage => $c->maketext('You are not authorized to modify sets.'))
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_problem_sets');

	if (($c->param('lti_message_type') // '') eq 'ContentItemSelectionRequest') {
		return $c->render(
			'ContentGenerator/LTI/content_item_selection',
			visibleSets    => [ $c->db->getGlobalSetsWhere({ visible => 1 }, [qw(due_date set_id)]) ],
			acceptMultiple => $c->param('accept_multiple') && $c->param('accept_multiple') eq 'true',
			forwardParams  => {
				content_item_return_url => $c->param('content_item_return_url'),
				lti_version             => $c->param('lti_version'),
				oauth_consumer_key      => $c->param('oauth_consumer_key'),
				$c->param('data') ? (data => $c->param('data')) : ()
			}
		);
	}

	my @selectedSets = $c->db->getGlobalSetsWhere({ set_id => [ $c->param('selected_sets') ] }, [qw(due_date set_id)]);

	my @problems =
		$c->db->getGlobalProblemsWhere({ set_id => [ $c->param('selected_sets') ] }, [qw(set_id problem_id)]);
	my %setMaxScores = map {
		my $setId = $_->set_id;
		my $max   = 0;
		$max += $_->value for (grep { $_->set_id eq $setId } @problems);
		$setId => $max;
	} @selectedSets;

	my $request = Net::OAuth->request('request token')->from_hash(
		{
			lti_message_type       => 'ContentItemSelection',
			lti_version            => $c->param('lti_version'),
			oauth_version          => '1.0',
			oauth_consumer_key     => $c->param('oauth_consumer_key') // 'webwork',
			oauth_callback         => 'about:blank',
			oauth_signature_method => 'HMAC-SHA1',
			oauth_timestamp        => time,
			oauth_nonce            => create_uuid_as_string(UUID_SHA1, UUID_NS_URL, $c->authen->{user_id}) . '_'
				. create_uuid_as_string(UUID_TIME),
			@selectedSets || $c->param('course_home_link')
			? (
				content_items => encode_json({
					'@context' => 'http://purl.imsglobal.org/ctx/lti/v1/ContentItem',
					'@graph'   => [
						$c->param('course_home_link')
						? {
							'@type'   => 'LtiLinkItem',
							mediaType => 'application/vnd.ims.lti.v1.ltilink',
							title     => $c->maketext('Assignments'),
							url       => $c->url_for('set_list', courseID => $c->stash->{courseID})->to_abs->to_string
							}
						: (),
						map { {
							'@type'   => 'LtiLinkItem',
							mediaType => 'application/vnd.ims.lti.v1.ltilink',
							title     => format_set_name_display($_->set_id),
							$_->description ? (text => $_->description) : (),
							url =>
								$c->url_for('problem_list', courseID => $c->stash->{courseID}, setID => $_->set_id)
								->to_abs->to_string,
							lineItem => {
								'@type'          => 'LineItem',
								scoreConstraints => {
									'@type'       => 'NumericLimits',
									normalMaximum => $setMaxScores{ $_->set_id }
								}
							}
						} } @selectedSets
					]
				})
				)
			: (lti_errormsg => $c->maketext('No content was selected.')),
			$c->param('data') ? (data => $c->param('data')) : ()
		},
		request_method  => 'POST',
		request_url     => $c->param('content_item_return_url'),
		consumer_secret => $c->ce->{LTI}{v1p1}{BasicConsumerSecret},
	);
	$request->sign;

	return $c->render(
		'ContentGenerator/LTI/self_posting_form',
		form_target => $c->param('content_item_return_url'),
		form_params => $request->to_hash
	);
}

1;
