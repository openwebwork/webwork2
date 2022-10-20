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

=head1 NAME

FormatRenderedProblem.pm

=cut

package FormatRenderedProblem;

use strict;
use warnings;

use XML::Simple qw(XMLout);
use JSON;
use Digest::SHA qw(sha1_base64);

use WeBWorK::Utils::AttemptsTable;
use WeBWorK::Utils qw(wwRound getAssetURL);
use WeBWorK::CGI;
use WeBWorK::Utils::LanguageAndDirection;

sub formatRenderedProblem {
	my $ws = shift;     # $ws is a WebworkWebservice object.
	my $ce = $ws->ce;

	my $problemText = '';
	my $rh_result   = $ws->return_object || {};    # wrap problem in formats
	$problemText = 'No output from rendered Problem' unless $rh_result;

	my $courseID = $ws->{inputs_ref}{courseID} // '';

	my $mt = WeBWorK::Localize::getLangHandle($ws->{inputs_ref}{language} // 'en');

	my $forbidGradePassback = 1;                   # Default is to forbid, due to the security issue

	if (defined($ce->{renderRPCAllowGradePassback})
		&& $ce->{renderRPCAllowGradePassback} eq
		'This course intentionally enables the insecure LTI grade pass-back feature of render_rpc.')
	{
		# It is strongly recommended that you clarify the security risks of enabling the current version of this feature
		# before using it.
		$forbidGradePassback = 0;
	}

	my $renderErrorOccurred = 0;

	if (ref($rh_result) && $rh_result->{text}) {
		$problemText = $rh_result->{text};
	} else {
		$problemText .= "Unable to decode problem text:<br>$ws->{error_string}<br>" . format_hash_ref($rh_result);
		$rh_result->{problem_result}{score} = 0;    # force score to 0 for such errors.
		$renderErrorOccurred                = 1;
		$forbidGradePassback                = 1;    # due to render error
	}

	my $SITE_URL        = $ws->r->server_root_url;
	my $FORM_ACTION_URL = $SITE_URL . $ws->r->webwork_url . '/render_rpc';

	my $user                      = $ws->{inputs_ref}{user}    // '';
	my $passwd                    = $ws->{inputs_ref}{passwd}  // '';
	my $problemSeed               = $rh_result->{problem_seed} // $ws->{inputs_ref}{problemSeed} // 6666;
	my $psvn                      = $rh_result->{psvn}         // $ws->{inputs_ref}{psvn}        // 54321;
	my $key                       = $ws->authen->{session_key};
	my $displayMode               = $ws->{inputs_ref}{displayMode}   // 'MathJax';
	my $hideWasNotRecordedMessage = $ce->{hideWasNotRecordedMessage} // 0;

	# HTML document language settings
	my $formLanguage        = $ws->{inputs_ref}{language} // 'en';
	my $COURSE_LANG_AND_DIR = get_lang_and_dir($formLanguage);

	# Problem source
	my $sourceFilePath = $ws->{inputs_ref}{sourceFilePath} // '';
	my $fileName       = $ws->{inputs_ref}{fileName}       // '';
	my $encoded_source = $ws->{inputs_ref}{problemSource}  // '';

	# Select the theme.
	my $theme = $ws->{inputs_ref}{theme} || $ce->{defaultTheme};

	# Add the favicon.
	my $favicon = CGI::Link({ href => "$ce->{webworkURLs}{htdocs}/images/favicon.ico", rel => 'shortcut icon' });

	# Set up the header text
	my $problemHeadText = '';

	# CSS Loads
	# The second element of each array in the following is whether or not the file is a theme file.
	my @CSSLoads = map { getAssetURL($ce, $_->[0], $_->[1]) } (
		[ 'bootstrap.css',                                              1 ],
		[ 'node_modules/jquery-ui-dist/jquery-ui.min.css',              0 ],
		[ 'node_modules/@fortawesome/fontawesome-free/css/all.min.css', 0 ],
		[ 'math4.css',                                                  1 ],
		[ 'math4-overrides.css',                                        1 ],
	);
	$problemHeadText .= CGI::Link({ href => $_, rel => 'stylesheet' }) for (@CSSLoads);

	# Add CSS files requested by problems via ADD_CSS_FILE() in the PG file
	# or via a setting of $ce->{pg}{specialPGEnvironmentVars}{extra_css_files}
	# which can be set in course.conf (the value should be an anonomous array).
	my @cssFiles;
	if (ref($ce->{pg}{specialPGEnvironmentVars}{extra_css_files}) eq 'ARRAY') {
		push(@cssFiles, { file => $_, external => 0 }) for @{ $ce->{pg}{specialPGEnvironmentVars}{extra_css_files} };
	}
	if (ref($rh_result->{flags}{extra_css_files}) eq 'ARRAY') {
		push @cssFiles, @{ $rh_result->{flags}{extra_css_files} };
	}
	my %cssFilesAdded;    # Used to avoid duplicates
	my @extra_css_files;
	for (@cssFiles) {
		next if $cssFilesAdded{ $_->{file} };
		$cssFilesAdded{ $_->{file} } = 1;
		if ($_->{external}) {
			push(@extra_css_files, $_);
			$problemHeadText .= CGI::Link({ href => $_->{file}, rel => 'stylesheet' });
		} else {
			my $url = getAssetURL($ce, $_->{file});
			push(@extra_css_files, { file => $url, external => 0 });
			$problemHeadText .= CGI::Link({ href => $url, rel => 'stylesheet' });
		}
	}

	# JS Loads
	# The second element of each array in the following is whether or not the file is a theme file.
	# The third element is a hash containing the necessary attributes for the script tag.
	my @JSLoads = map { [ getAssetURL($ce, $_->[0], $_->[1]), $_->[2] ] } (
		[ 'node_modules/jquery/dist/jquery.min.js',                            0, {} ],
		[ 'node_modules/jquery-ui-dist/jquery-ui.min.js',                      0, {} ],
		[ 'node_modules/iframe-resizer/js/iframeResizer.contentWindow.min.js', 0, {} ],
		[ 'js/apps/MathJaxConfig/mathjax-config.js',                0, { defer => undef } ],
		[ 'node_modules/mathjax/es5/tex-svg.js',                    0, { defer => undef, id => 'MathJax-script' } ],
		[ 'node_modules/bootstrap/dist/js/bootstrap.bundle.min.js', 0, { defer => undef } ],
		[ 'js/apps/Problem/problem.js',                             0, { defer => undef } ],
		[ 'math4.js',                                               1, { defer => undef } ],
		[ 'math4-overrides.js',                                     1, { defer => undef } ]
	);
	$problemHeadText .= CGI::script({ src => $_->[0], %{ $_->[1] // {} } }, '') for (@JSLoads);

	# Get the requested format.
	my $formatName = $ws->{inputs_ref}{outputformat} // 'simple';

	# Add the local storage javascript for the sticky format.
	$problemHeadText .=
		CGI::script({ src => getAssetURL($ce, 'js/apps/LocalStorage/localstorage.js'), defer => undef }, '')
		if $formatName eq 'sticky';

	# Add JS files requested by problems via ADD_JS_FILE() in the PG file.
	my @extra_js_files;
	if (ref($rh_result->{flags}{extra_js_files}) eq 'ARRAY') {
		my %jsFiles;
		for (@{ $rh_result->{flags}{extra_js_files} }) {
			next if $jsFiles{ $_->{file} };
			$jsFiles{ $_->{file} } = 1;
			my %attributes = ref($_->{attributes}) eq 'HASH' ? %{ $_->{attributes} } : ();
			if ($_->{external}) {
				push(@extra_js_files, $_);
				$problemHeadText .= CGI::script({ src => $_->{file}, %attributes }, '');
			} else {
				my $url = getAssetURL($ce, $_->{file});
				push(@extra_js_files, { file => $url, external => 0, attributes => $_->{attributes} });
				$problemHeadText .= CGI::script({ src => $url, %attributes }, '');
			}
		}
	}

	$problemHeadText .= $rh_result->{header_text}      // '';
	$problemHeadText .= $rh_result->{post_header_text} // '';
	my $extra_header_text = $ws->{inputs_ref}{extra_header_text} // '';
	$problemHeadText .= $extra_header_text;

	# Set up the problem language and direction
	# PG files can request their language and text direction be set.  If we do
	# not have access to a default course language, fall back to the
	# $formLanguage instead.
	my %PROBLEM_LANG_AND_DIR =
		get_problem_lang_and_dir($rh_result->{flags}, $ce->{perProblemLangAndDirSettingMode}, $formLanguage);
	my $PROBLEM_LANG_AND_DIR = join(' ', map {qq{$_="$PROBLEM_LANG_AND_DIR{$_}"}} keys %PROBLEM_LANG_AND_DIR);

	my $previewMode     = defined($ws->{inputs_ref}{preview})      || 0;
	my $checkMode       = defined($ws->{inputs_ref}{WWcheck})      || 0;
	my $submitMode      = defined($ws->{inputs_ref}{WWsubmit})     || 0;
	my $showCorrectMode = defined($ws->{inputs_ref}{WWcorrectAns}) || 0;
	# A problemUUID should be added to the request as a parameter.  It is used by PG to create a proper UUID for use in
	# aliases for resources.  It should be unique for a course, user, set, problem, and version.
	my $problemUUID       = $ws->{inputs_ref}{problemUUID}       // '';
	my $problemResult     = $rh_result->{problem_result}         // {};
	my $showSummary       = $ws->{inputs_ref}{showSummary}       // 1;
	my $showAnswerNumbers = $ws->{inputs_ref}{showAnswerNumbers} // 1;

	my $color_input_blanks_script = '';

	# Attempts table
	my $answerTemplate = '';

	if ($renderErrorOccurred) {
		# Do not produce an AttemptsTable when we had a rendering error.
		$answerTemplate = '<!-- No AttemptsTable on errors like this. --> ';
	} else {
		my $tbl = WeBWorK::Utils::AttemptsTable->new(
			$rh_result->{answers} // {},
			answersSubmitted    => $ws->{inputs_ref}{answersSubmitted}     // 0,
			answerOrder         => $rh_result->{flags}{ANSWER_ENTRY_ORDER} // [],
			displayMode         => $displayMode,
			showAnswerNumbers   => $showAnswerNumbers,
			ce                  => $ce,
			showAttemptPreviews => $previewMode || $submitMode || $showCorrectMode,
			showAttemptResults  => $submitMode  || $showCorrectMode,
			showCorrectAnswers  => $showCorrectMode,
			showMessages        => $previewMode || $submitMode || $showCorrectMode,
			showSummary         => (($showSummary && ($submitMode || $showCorrectMode)) // 0) ? 1 : 0,
			maketext            => WeBWorK::Localize::getLoc($formLanguage),
			summary             => $problemResult->{summary} // '',    # can be set by problem grader
		);
		$answerTemplate = $tbl->answerTemplate;
		$tbl->imgGen->render(refresh => 1) if $tbl->displayMode eq 'images';
	}
	# Score summary
	my $scoreSummary = '';

	if ($submitMode) {
		if ($renderErrorOccurred) {
			$scoreSummary = '<!-- No scoreSummary on errors. -->';
		} elsif ($problemResult) {
			$scoreSummary = CGI::p($mt->maketext(
				'You received a score of [_1] for this attempt.',
				wwRound(0, $problemResult->{score} * 100) . '%'
			));
			$scoreSummary .= CGI::p($problemResult->{msg}) if ($problemResult->{msg});

			$scoreSummary .= CGI::p($mt->maketext('Your score was not recorded.')) unless $hideWasNotRecordedMessage;
			$scoreSummary .= CGI::hidden(
				{ id => 'problem-result-score', name => 'problem-result-score', value => $problemResult->{score} });
		}
	}
	if (!$forbidGradePassback && !$submitMode) {
		$forbidGradePassback = 1;
	}

	# Answer hash in XML format used by the PTX format.
	my $answerhashXML = $formatName eq 'ptx' ? XMLout($rh_result->{answers} // {}, RootName => 'answerhashes') : '';

	# Sticky format local storage messages
	my $localStorageMessages = CGI::div({ id => 'local-storage-messages' },
		CGI::p('Your overall score for this problem is&nbsp;' . CGI::span({ id => 'problem-overall-score' }, '')));

	# Submit buttons (all are shown by default)
	my $showPreviewButton = $ws->{inputs_ref}{showPreviewButton} // '';
	my $previewButton     = $showPreviewButton eq '0' ? '' : CGI::submit({
		name  => 'preview',
		id    => 'previewAnswers_id',
		class => 'btn btn-primary mb-1',
		value => $mt->maketext('Preview My Answers')
	});
	my $showCheckAnswersButton = $ws->{inputs_ref}{showCheckAnswersButton} // '';
	my $checkAnswersButton =
		$showCheckAnswersButton eq '0'
		? ''
		: CGI::submit({ name => 'WWsubmit', class => 'btn btn-primary mb-1', value => $mt->maketext('Check Answers') });
	my $showCorrectAnswersButton = $ws->{inputs_ref}{showCorrectAnswersButton} // '';
	my $correctAnswersButton =
		$showCorrectAnswersButton eq '0'
		? ''
		: CGI::submit(
			{ name => 'WWcorrectAns', class => 'btn btn-primary mb-1', value => $mt->maketext('Show Correct Answers') }
		);

	my $showSolutions = $ws->{inputs_ref}{showSolutions} // '';
	my $showHints     = $ws->{inputs_ref}{showHints}     // '';

	# PG warning messages (this includes translator warnings).
	my $warnings = '';
	if ($rh_result->{pg_warnings}) {
		$warnings .= CGI::div({ class => 'alert alert-danger mb-2 p-1' },
			CGI::h3('Warning Messages') . join('<br>', split("\n", $rh_result->{pg_warnings})));
	}

	# PG debug messages generated with DEBUG_message();
	$rh_result->{debug_messages} = join('<br>', @{ $rh_result->{debug_messages} || [] });

	# PG warning messages generated with WARN_message();
	my $PG_warning_messages = join('<br>', @{ $rh_result->{warning_messages} || [] });

	# Internal debug messages generated within PG_core.
	# These are sometimes needed if the PG_core warning message system isn't properly set
	# up before the bug occurs.  In general don't use these unless necessary.
	my $internal_debug_messages = join('<br>', @{ $rh_result->{internal_debug_messages} || [] });

	# Try to save the grade to an LTI if one provided us data (depending on $forbidGradePassback)
	my $LTIGradeMessage = saveGradeToLTI($ws, $ce, $rh_result, $forbidGradePassback);

	my $debug_messages = $rh_result->{debug_messages};

	# For debugging purposes (only used in the debug format)
	my $clientDebug       = $ws->{inputs_ref}{clientDebug} // '';
	my $client_debug_data = $clientDebug ? CGI::h3('Webwork client data') . pretty_print($ws) : '';

	# Show the footer unless it is explicity disabled.
	my $showFooter = $ws->{inputs_ref}{showFooter} // '';
	my $footer     = $showFooter eq '0' ? '' : CGI::div({ id => 'footer' },
		"WeBWorK &copy; 2000-2022 | host: $SITE_URL | course: $courseID | format: $formatName | theme: $theme");

	# Execute and return the interpolated problem template

	# The json format
	if ($formatName eq 'json') {
		my $json_output = do('WebworkClient/json_format.pl');
		for my $key (keys %{ $json_output->{hidden_input_field} }) {
			$json_output->{hidden_input_field}{$key} =~ s/(\$\w+)/$1/gee;
		}

		for my $key (keys %$json_output) {
			if (($key =~ /^real_webwork/)
				|| ($key =~ /^internal/)
				|| ($key =~ /_A?VI$/))
			{
				# Interpolate values
				if ($key =~ /_AVI$/) {
					map { $json_output->{$key}{$_} =~ s/(\$\w+)/$1/gee } @{ $json_output->{$key} };
				} else {
					$json_output->{$key} =~ s/(\$\w+)/$1/gee;
				}
				if (($key =~ /_A?VI$/)) {
					my $new_key = $key =~ s/_A?VI$//r;
					$json_output->{$new_key} = $json_output->{$key};
					delete $json_output->{$key};
				}
			}
		}

		# CSS Loads
		$json_output->{head_part100} = \@CSSLoads;

		# JS Loads
		$json_output->{head_part200} = \@JSLoads;

		# Add the current score to the %json_output
		my $json_score = 0;
		if ($submitMode && $problemResult) {
			$json_score = wwRound(0, $problemResult->{score} * 100);
		}
		$json_output->{score} = $json_score;

		return JSON->new->utf8(0)->encode($json_output);
	}

	# Raw format
	# This format returns javascript object notation corresponding to the perl hash
	# with everything that a client-side application could use to work with the problem.
	# There is no wrapping HTML "_format" template.
	if ($formatName eq 'raw') {
		my $output = {};

		# Everything that ships out with other formats can be constructed from these
		$output->{rh_result}  = $rh_result;
		$output->{inputs_ref} = $ws->{inputs_ref};
		$output->{input}      = $ws->{input};

		# The following could be constructed from the above, but this is a convenience
		$output->{answerTemplate}  = $answerTemplate if ($answerTemplate);
		$output->{lang}            = $PROBLEM_LANG_AND_DIR{lang};
		$output->{dir}             = $PROBLEM_LANG_AND_DIR{dir};
		$output->{extra_css_files} = \@extra_css_files;
		$output->{extra_js_files}  = \@extra_js_files;

		# Include third party css and javascript files.  Only jquery, jquery-ui, mathjax, and bootstrap are needed for
		# PG.  See the comments before the subroutine definitions for load_css and load_js in pg/macros/PG.pl.
		# The other files included are only needed to make themes work in the webwork2 formats.
		$output->{third_party_css} = \@CSSLoads;
		$output->{third_party_js}  = \@JSLoads;

		# Say what version of WeBWorK this is
		$output->{ww_version} = $ce->{WW_VERSION};
		$output->{pg_version} = $ce->{PG_VERSION};

		# Convert to JSON
		return JSON->new->utf8(0)->encode($output);
	}

	# Find and execute the appropriate template in the WebworkClient folder.
	my $template = do("$WeBWorK::Constants::WEBWORK_DIRECTORY/lib/WebworkClient/${formatName}_format.pl");
	return "Unknown format name $formatName<br>" unless $template;

	# Interpolate values into the template
	$template =~ s/(\$\w+)/$1/gee;

	return $template unless $ws->{inputs_ref}{send_pg_flags};
	return JSON->new->utf8(0)->encode({ html => $template, pg_flags => $rh_result->{flags}, warnings => $warnings });
}

sub saveGradeToLTI {
	my ($ws, $ce, $rh_result, $forbidGradePassback) = @_;
	# When $forbidGradePassback is set, we will block the actual submission,
	# but we still provide the LTI data in the hidden fields.

	return ''
		if !(defined($ws->{inputs_ref}{lis_outcome_service_url})
			&& defined($ws->{inputs_ref}{'oauth_consumer_key'})
			&& defined($ws->{inputs_ref}{'oauth_signature_method'})
			&& defined($ws->{inputs_ref}{'lis_result_sourcedid'})
			&& defined($ce->{'LISConsumerKeyHash'}{ $ws->{inputs_ref}{'oauth_consumer_key'} }));

	my $request_url      = $ws->{inputs_ref}{lis_outcome_service_url};
	my $consumer_key     = $ws->{inputs_ref}{'oauth_consumer_key'};
	my $signature_method = $ws->{inputs_ref}{'oauth_signature_method'};
	my $sourcedid        = $ws->{inputs_ref}{'lis_result_sourcedid'};
	my $consumer_secret  = $ce->{'LISConsumerKeyHash'}{$consumer_key};
	my $score            = $rh_result->{problem_result} ? $rh_result->{problem_result}{score} : 0;

	my $LTIGradeMessage = '';

	if (!$forbidGradePassback) {

		# This is boilerplate XML used to submit the $score for $sourcedid
		my $replaceResultXML = <<EOS;
<?xml version = "1.0" encoding = "UTF-8"?>
<imsx_POXEnvelopeRequest xmlns = "http://www.imsglobal.org/services/ltiv1p1/xsd/imsoms_v1p0">
  <imsx_POXHeader>
	<imsx_POXRequestHeaderInfo>
	  <imsx_version>V1.0</imsx_version>
	  <imsx_messageIdentifier>999999123</imsx_messageIdentifier>
	</imsx_POXRequestHeaderInfo>
  </imsx_POXHeader>
  <imsx_POXBody>
	<replaceResultRequest>
	  <resultRecord>
	<sourcedGUID>
	  <sourcedId>$sourcedid</sourcedId>
	</sourcedGUID>
	<result>
	  <resultScore>
		<language>en</language>
		<textString>$score</textString>
	  </resultScore>
	</result>
	  </resultRecord>
	</replaceResultRequest>
  </imsx_POXBody>
</imsx_POXEnvelopeRequest>
EOS

		my $bodyhash = sha1_base64($replaceResultXML);

		# since sha1_base64 doesn't pad we have to do so manually
		while (length($bodyhash) % 4) {
			$bodyhash .= '=';
		}

		my $requestGen = Net::OAuth->request('consumer');

		$requestGen->add_required_message_params('body_hash');

		my $gradeRequest = $requestGen->new(
			request_url      => $request_url,
			request_method   => 'POST',
			consumer_secret  => $consumer_secret,
			consumer_key     => $consumer_key,
			signature_method => $signature_method,
			nonce            => int(rand(2**32)),
			timestamp        => time(),
			body_hash        => $bodyhash
		);
		$gradeRequest->sign();

		my $HTTPRequest = HTTP::Request->new(
			$gradeRequest->request_method,
			$gradeRequest->request_url,
			[
				'Authorization' => $gradeRequest->to_authorization_header,
				'Content-Type'  => 'application/xml',
			],
			$replaceResultXML,
		);

		my $response = LWP::UserAgent->new->request($HTTPRequest);

		if ($response->is_success) {
			$response->content =~ /<imsx_codeMajor>\s*(\w+)\s*<\/imsx_codeMajor>/;
			my $message = $1;
			if ($message ne 'success') {
				$LTIGradeMessage = CGI::p("Unable to update LMS grade. Error: $message");
				$rh_result->{debug_messages} .= CGI::escapeHTML($response->content);
			} else {
				$LTIGradeMessage = CGI::p('Grade sucessfully saved.');
			}
		} else {
			$LTIGradeMessage = CGI::p('Unable to update LMS grade. Error: ' . $response->message);
			$rh_result->{debug_messages} .= CGI::escapeHTML($response->content);
		}
	}

	# save parameters for next time
	$LTIGradeMessage .= CGI::input({ type => 'hidden', name => 'lis_outcome_service_url', value => $request_url });
	$LTIGradeMessage .= CGI::input({ type => 'hidden', name => 'oauth_consumer_key',      value => $consumer_key });
	$LTIGradeMessage .= CGI::input({ type => 'hidden', name => 'oauth_signature_method',  value => $signature_method });
	$LTIGradeMessage .= CGI::input({ type => 'hidden', name => 'lis_result_sourcedid',    value => $sourcedid });

	return $LTIGradeMessage;
}

# Error formatting
sub format_hash_ref {
	my $hash = shift;
	warn 'Use a hash reference' unless ref($hash) =~ /HASH/;
	return join(' ', map { $_ // '--' } %$hash) . "\n";
}

# Nice output for debugging
sub pretty_print {
	my ($r_input, $level) = @_;
	$level //= 4;
	$level--;
	return '' unless $level > 0;    # Only print three levels of hashes (safety feature)
	my $out = '';
	if (!ref $r_input) {
		$out = $r_input if defined $r_input;
		$out =~ s/</&lt;/g;         # protect for HTML output
	} elsif ("$r_input" =~ /hash/i) {
		# "$r_input" =~ /hash/i" will pick up objects whose $self is a hash and so works better than "ref $r_input".
		local $^W = 0;
		$out .= qq{$r_input <table border="2" cellpadding="3" bgcolor="#FFFFFF">};

		for my $key (sort keys %$r_input) {
			# Safety feature - we do not want to display the contents of %seed_ce which
			# contains the database password and lots of other things, and explicitly hide
			# certain internals of the CourseEnvironment in case one slips in.
			next
				if (($key =~ /database/)
					|| ($key =~ /dbLayout/)
					|| ($key eq "ConfigValues")
					|| ($key eq "ENV")
					|| ($key eq "externalPrograms")
					|| ($key eq "permissionLevels")
					|| ($key eq "seed_ce"));
			$out .= "<tr><td>$key</td><td>=&gt;</td><td>&nbsp;" . pretty_print($r_input->{$key}) . "</td></tr>";
		}
		$out .= '</table>';
	} elsif (ref $r_input eq 'ARRAY') {
		my @array = @$r_input;
		$out .= '( ';
		while (@array) {
			$out .= pretty_print(shift @array, $level) . ' , ';
		}
		$out .= ' )';
	} elsif (ref $r_input eq 'CODE') {
		$out = "$r_input";
	} else {
		$out = $r_input;
		$out =~ s/</&lt;/g;    # Protect for HTML output
	}

	return $out . ' ';
}

1;
