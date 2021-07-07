#!/usr/bin/perl -w

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
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

=head1 NAME

FormatRenderedProblem.pm

=cut

package FormatRenderedProblem;

use WeBWorK::Utils::AttemptsTable;
use WeBWorK::Utils qw(wwRound decode_utf8_base64);
use XML::Simple qw(XMLout);
use WeBWorK::Utils::LanguageAndDirection;
use JSON;
use Digest::SHA qw(sha1_base64);

sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
	$self = {
		return_object   => {},
		encoded_source  => {},
		sourceFilePath  => '',
		site_url        => 'https://demo.webwork.rochester.edu',
		form_action_url => '',
		maketext        => sub { return @_ },
		courseID        => 'daemon_course',  # optional?
		userID          => 'daemon',  # optional?
		course_password => 'daemon',
		inputs_ref      => {},
		@_,
	};
	bless $self, $class;
}

sub return_object {   # out
	my $self = shift;
	my $object = shift;
	$self->{return_object} = $object if defined $object and ref($object); # source is non-empty
	$self->{return_object};
}

sub encoded_source {
	my $self = shift;
	my $source = shift;
	$self->{encoded_source} = $source if defined $source and $source =~/\S/; # source is non-empty
	$self->{encoded_source};
}

sub site_url {
	my $self = shift;
	my $new_url = shift;
	$self->{site_url} = $new_url if defined($new_url) and $new_url =~ /\S/;
	$self->{site_url};
}

sub formatRenderedProblem {
	my $self        = shift;
	my $problemText = '';
	my $rh_result   = $self->return_object() || {};  # wrap problem in formats
	$problemText    = "No output from rendered Problem" unless $rh_result;

	my $courseID = $self->{courseID} // "";

	# Create a course environment
	my $ce = WeBWorK::CourseEnvironment->new({
			webwork_dir => $WeBWorK::Constants::WEBWORK_DIRECTORY,
			courseName => $courseID,
			pg_dir => $WeBWorK::Constants::PG_DIRECTORY,
		});

	my $mt = WeBWorK::Localize::getLangHandle($self->{inputs_ref}{language} // 'en');

	my $forbidGradePassback = 1; # Default is to forbid, due to the security issue

	if ( defined( $ce->{html2xmlAllowGradePassback} ) &&
	     $ce->{html2xmlAllowGradePassback} eq "This course intentionally enables the insecure LTI grade pass-back feature of html2xml." ) {
		# It is strongly recommended that you clarify the security risks of enabling the current version of this feature before using it.
		$forbidGradePassback = 0;
	}

	my $renderErrorOccurred = 0;

	if (ref($rh_result) && $rh_result->{text}) {
		$problemText = $rh_result->{text};
	} else {
		$problemText .= "Unable to decode problem text:<br>$self->{error_string}<br>" .
			format_hash_ref($rh_result);
		$rh_result->{problem_result}->{score} = 0; # force score to 0 for such errors.
		$renderErrorOccurred = 1;
		$forbidGradePassback = 1; # due to render error
	}

	my $SITE_URL = $self->site_url // '';
	my $FORM_ACTION_URL = $self->{form_action_url} // '';

	# Local docker usage with a port number sometimes misbehaves if the port number
	# is not forced into $SITE_URL and $FORM_ACTION_URL
	my $forcePortNumber = ($self->{inputs_ref}{forcePortNumber}) // '';
	if ($forcePortNumber =~ /^[0-9]+$/) {
		$forcePortNumber = 0 + $forcePortNumber;
		if (!($SITE_URL =~ /:${forcePortNumber}/)) {
			$SITE_URL .= ":${forcePortNumber}";
		}
		if (!($FORM_ACTION_URL =~ m+:${forcePortNumber}/webwork2/html2xml+)) {
			$FORM_ACTION_URL =~ s+/webwork2/html2xml+:${forcePortNumber}/webwork2/html2xml+; # Ex: "http://localhost:8080/webwork2/html2xml"
		}
	}

	my $userID = $self->{userID} // "";
	my $course_password = $self->{course_password} // "";
	my $problemSeed = $rh_result->{problem_seed} // $self->{inputs_ref}{problemSeed} // 6666;
	my $psvn = $rh_result->{psvn} // $self->{inputs_ref}{psvn} // 54321;
	my $session_key = $rh_result->{session_key} // "";
	my $displayMode = $self->{inputs_ref}{displayMode};
	my $hideWasNotRecordedMessage = $ce->{hideWasNotRecordedMessage} // 0;

	# HTML document language settings
	my $formLanguage = $self->{inputs_ref}{language} // 'en';
	my $COURSE_LANG_AND_DIR = get_lang_and_dir($formLanguage);

	# Problem source
	my $sourceFilePath = $self->{sourceFilePath} // "";
	my $fileName = $self->{input}{envir}{fileName} // "";
	my $encoded_source = $self->encoded_source // "";

	# Select the theme and theme directory
	my $theme = $self->{inputs_ref}{theme} || $ce->{defaultTheme};
	my $themeDir = "$ce->{webworkURLs}{htdocs}/themes/$theme";

	# Set up the header text
	my $problemHeadText = '';

	# Add CSS files requested by problems via ADD_CSS_FILE() in the PG file
	# or via a setting of $ce->{pg}{specialPGEnvironmentVars}{extra_css_files}
	# which can be set in course.conf (the value should be an anonomous array).
	my %cssFiles;
	if (ref($ce->{pg}{specialPGEnvironmentVars}{extra_css_files}) eq "ARRAY") {
		$cssFiles{$_} = 0 for @{$ce->{pg}{specialPGEnvironmentVars}{extra_css_files}};
	}
	if (ref($rh_result->{flags}{extra_css_files}) eq "ARRAY") {
		$cssFiles{$_->{file}} = $_->{external} for @{$rh_result->{flags}{extra_css_files}};
	}
	for (keys(%cssFiles)) {
		if ($cssFiles{$_}) {
			$problemHeadText .= qq{<link rel="stylesheet" type="text/css" href="$_"/>};
		} elsif (!$cssFiles{$_} && -f "$WeBWorK::Constants::WEBWORK_DIRECTORY/htdocs/$_") {
			$problemHeadText .= qq{<link rel="stylesheet" type="text/css" href="$ce->{webworkURLs}{htdocs}/$_"/>};
		} else {
			$problemHeadText .= qq{<!-- $_ is not available in htdocs/ on this server -->};
		}
	}

	# Add JS files requested by problems via ADD_JS_FILE() in the PG file.
	if (ref($rh_result->{flags}{extra_js_files}) eq "ARRAY") {
		my %jsFiles;
		for my $jsFile (@{$rh_result->{flags}{extra_js_files}}) {
			next if $jsFiles{$jsFile->{file}};
			$jsFiles{$jsFile->{file}} = 1;
			my $attributes = ref($jsFile->{attributes}) eq "HASH"
				? join(" ", map { qq!$_="$jsFile->{attributes}{$_}"! } keys %{$jsFile->{attributes}}) : ();
			if ($jsFile->{external}) {
				$problemHeadText .= qq{<script src="$jsFile->{file}" $attributes></script>}
			} elsif (!$jsFile->{external} && -f "$WeBWorK::Constants::WEBWORK_DIRECTORY/htdocs/$jsFile->{file}") {
				$problemHeadText .= qq{<script src="$ce->{webworkURLs}{htdocs}/$jsFile->{file}" $attributes></script>};
			} else {
				$problemHeadText .= qq{<!-- $jsFile->{file} is not available in htdocs/ on this server -->};
			}
		}
	}

	$problemHeadText .= $rh_result->{header_text} // '';
	$problemHeadText .= $rh_result->{post_header_text} // '';
	$extra_header_text = $self->{inputs_ref}{extra_header_text} // '';
	$problemHeadText .= $extra_header_text;

	if ($ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathQuill') {
		$problemHeadText .= qq{<link href="$ce->{webworkURLs}{htdocs}/js/apps/MathQuill/mathquill.css" rel="stylesheet" />} .
			qq{<link href="$ce->{webworkURLs}{htdocs}/js/apps/MathQuill/mqeditor.css" rel="stylesheet" />} .
			qq{<script src="$ce->{webworkURLs}{htdocs}/js/apps/MathQuill/mathquill.min.js" defer></script>} .
			qq{<script src="$ce->{webworkURLs}{htdocs}/js/apps/MathQuill/mqeditor.js" defer></script>};
	}

	# Set up the problem language and direction
	# PG files can request their language and text direction be set.  If we do
	# not have access to a default course language, fall back to the
	# $formLanguage instead.
	my %PROBLEM_LANG_AND_DIR = get_problem_lang_and_dir($rh_result->{flags}, $ce->{perProblemLangAndDirSettingMode}, $formLanguage);
	my $PROBLEM_LANG_AND_DIR = join(" ", map { qq{$_="$PROBLEM_LANG_AND_DIR{$_}"} } keys %PROBLEM_LANG_AND_DIR);

	my $previewMode = defined($self->{inputs_ref}{preview}) || 0;
	my $checkMode = defined($self->{inputs_ref}{WWcheck}) || 0;
	my $submitMode = defined($self->{inputs_ref}{WWsubmit}) || 0;
	my $showCorrectMode = defined($self->{inputs_ref}{WWcorrectAns}) || 0;
	# problemUUID can be added to the request as a parameter.  It adds a prefix
	# to the identifier used by the  format so that several different problems
	# can appear on the same page.
	my $problemUUID = $self->{inputs_ref}{problemUUID} // 1;
	my $problemResult = $rh_result->{problem_result} // '';
	my $problemState = $rh_result->{problem_state} // '';
	my $showSummary = $self->{inputs_ref}{showSummary} // 1;
	my $showAnswerNumbers = $self->{inputs_ref}{showAnswerNumbers} // 1;

	my $color_input_blanks_script = "";

	# Attempts table
	my $answerTemplate = "";

	if ($renderErrorOccurred) {
		# Do not produce an AttemptsTable when we had a rendering error.
		$answerTemplate = '<!-- No AttemptsTable on errors like this. --> ';
	} else {
		my $tbl = WeBWorK::Utils::AttemptsTable->new(
			$rh_result->{answers} // {},
			answersSubmitted    => $self->{inputs_ref}{answersSubmitted} // 0,
			answerOrder         => $rh_result->{flags}{ANSWER_ENTRY_ORDER} // [],
			displayMode         => $displayMode,
			showAnswerNumbers   => $showAnswerNumbers,
			ce                  => $ce,
			showAttemptPreviews => $previewMode || $submitMode || $showCorrectMode,
			showAttemptResults  => $submitMode || $showCorrectMode,
			showCorrectAnswers  => $showCorrectMode,
			showMessages        => $previewMode || $submitMode || $showCorrectMode,
			showSummary         => (($showSummary and ($submitMode or $showCorrectMode)) // 0) ? 1 : 0,
			maketext            => WeBWorK::Localize::getLoc($formLanguage),
			summary             => $problemResult->{summary} // '', # can be set by problem grader
		);
		$answerTemplate = $tbl->answerTemplate;
		$color_input_blanks_script = (!$previewMode && ($checkMode || $submitMode)) ? $tbl->color_answer_blanks : "";
		$tbl->imgGen->render(refresh => 1) if $tbl->displayMode eq 'images';
	}
	# Score summary
	my $scoreSummary = '';

	if ($submitMode) {
		if ($renderErrorOccurred) {
			$scoreSummary  = '<!-- No scoreSummary on errors. -->';
		} elsif ($problemResult) {
			$scoreSummary = CGI::p($mt->maketext("You received a score of [_1] for this attempt.",
				wwRound(0, $problemResult->{score} * 100) . '%'));
			$scoreSummary .= CGI::p($problemResult->{msg}) if ($problemResult->{msg});

			$scoreSummary .= CGI::p($mt->maketext("Your score was not recorded.")) unless $hideWasNotRecordedMessage;
			$scoreSummary .= CGI::hidden({id => 'problem-result-score', name => 'problem-result-score', value => $problemResult->{score}});
		}
	}
	if ( !$forbidGradePassback && !$submitMode ) {
		$forbidGradePassback = 1;
	}

	# Answer hash in XML format used by the PTX format.
	my $answerhashXML = XMLout($rh_result->{answers} // {}, RootName => 'answerhashes')
	if $self->{inputs_ref}{outputformat} // "" eq "ptx";

	# Sticky format local storage messages
	my $localStorageMessages = CGI::start_div({ id => 'local-storage-messages' });
	$localStorageMessages .= CGI::p('Your overall score for this problem is&nbsp;' . CGI::span({ id => 'problem-overall-score' }, ''));
	$localStorageMessages .= CGI::end_div();

	# Submit buttons (all are shown by default)
	my $showPreviewButton = $self->{inputs_ref}{showPreviewButton} // "";
	my $previewButton = $showPreviewButton eq "0" ? '' :
		'<input type="submit" name="preview" id="previewAnswers_id" value="' . $mt->maketext("Preview My Answers") . '">';
	my $showCheckAnswersButton = $self->{inputs_ref}{showCheckAnswersButton} // "";
	my $checkAnswersButton = $showCheckAnswersButton eq "0" ? '' :
		'<input type="submit" name="WWsubmit" value="' . $mt->maketext("Check Answers") . '">';
	my $showCorrectAnswersButton = $self->{inputs_ref}{showCorrectAnswersButton} // "";
	my $correctAnswersButton = $showCorrectAnswersButton eq "0" ? '' :
		'<input type="submit" name="WWcorrectAns" value="' . $mt->maketext("Show Correct Answers") . '">';

	my $showSolutions = $self->{inputs_ref}{showSolutions} // "";
	my $showHints = $self->{inputs_ref}{showHints} // "";

	# Regular Perl warning messages generated with warn.
	my $warnings = '';
	if ($rh_result->{pg_warnings}) {
		$warnings .= qq{<div style="background-color:pink">PG WARNINGS<br>} .
			decode_utf8_base64($rh_result->{pg_warnings}) . "</div>";
	}
	if ($rh_result->{translator_warnings}) {
		$warnings .= qq{<div style="background-color:pink"><p>TRANSLATOR WARNINGS</p><p>} .
			decode_utf8_base64($rh_result->{translator_warnings}) . "</p></div>";
	}

	# PG debug messages generated with DEBUG_message();
	$rh_result->{debug_messages} = join("<br>", @{$rh_result->{debug_messages} || []});

	# PG warning messages generated with WARN_message();
	my $PG_warning_messages = join("<br>", @{$rh_result->{warning_messages} || []});

	# Internal debug messages generated within PG_core.
	# These are sometimes needed if the PG_core warning message system isn't properly set
	# up before the bug occurs.  In general don't use these unless necessary.
	my $internal_debug_messages = join("<br>", @{$rh_result->{internal_debug_messages} || []});

	# Try to save the grade to an LTI if one provided us data (depending on $forbidGradePassback)
	my $LTIGradeMessage = saveGradeToLTI($self, $ce, $rh_result, $forbidGradePassback);

	my $debug_messages = $rh_result->{debug_messages};

	# For debugging purposes (only used in the debug format)
	my $clientDebug = $self->{inputs_ref}{clientDebug} // "";
	my $client_debug_data = $clientDebug ? "<h3>Webwork client data</h3>" . WebworkClient::pretty_print($self) : '';

	# Show the footer unless it is explicity disabled.
	my $showFooter = $self->{inputs_ref}{showFooter} // "";
	my $footer = $showFooter eq "0" ? ''
		: "<div id='footer'>WeBWorK &copy; 2000-2021 | host: $SITE_URL | course: $courseID | format: $self->{inputs_ref}{outputformat} | theme: $theme</div>";

	# Execute and return the interpolated problem template
	my $format_name = $self->{inputs_ref}{outputformat} // 'simple';

	# The json format
	if ($format_name eq "json") {
		my $json_output = do("WebworkClient/json_format.pl");
		for my $key (keys %{$json_output->{hidden_input_field}}) {
			$json_output->{hidden_input_field}{$key} =~ s/(\$\w+)/$1/gee;
		}

		for my $key (keys %$json_output) {
			if (
				($key =~ /^real_webwork/) ||
				($key =~ /^internal/) ||
				($key =~ /_A?VI$/)
			) {
				# Interpolate values
				if ($key =~ /_AVI$/) {
					map { s/(\$\w+)/$1/gee } @{$json_output->{$key}};
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
	if ($format_name eq "raw") {
		my $output = {};

		# Everything that ships out with other formats can be constructed from these
		$output->{rh_result} = $rh_result;
		$output->{inputs_ref} = $self->{inputs_ref};
		$output->{input} = $self->{input};

		# The following could be constructed from the above, but this is a convenience
		$output->{answerTemplate} = $answerTemplate if ($answerTemplate);
		$output->{lang} = $PROBLEM_LANG_AND_DIR{lang};
		$output->{dir} = $PROBLEM_LANG_AND_DIR{dir};

		# Convert to JSON
		return JSON->new->utf8(0)->encode($output);
	}

	# Find and execute the appropriate template in the WebworkClient folder.
	my $template = do("$WeBWorK::Constants::WEBWORK_DIRECTORY/lib/WebworkClient/${format_name}_format.pl");
	return "Unknown format name $format_name<br>" unless $template;

	# Interpolate values into the template
	$template =~ s/(\$\w+)/$1/gee;

	return $template unless $self->{inputs_ref}{send_pg_flags};
	return JSON->new->utf8(0)->encode({ html => $template, pg_flags => $rh_result->{flags} });
}

sub saveGradeToLTI {
	my ($self, $ce, $rh_result, $forbidGradePassback) = @_;
	# When $forbidGradePassback is set, we will block the actual submission,
	# but we still provide the LTI data in the hidden fields.

	return "" if !(defined($self->{inputs_ref}{lis_outcome_service_url}) &&
		defined($self->{inputs_ref}{'oauth_consumer_key'}) &&
		defined($self->{inputs_ref}{'oauth_signature_method'}) &&
		defined($self->{inputs_ref}{'lis_result_sourcedid'}) &&
		defined($ce->{'LISConsumerKeyHash'}{$self->{inputs_ref}{'oauth_consumer_key'}}));

	my $request_url = $self->{inputs_ref}{lis_outcome_service_url};
	my $consumer_key = $self->{inputs_ref}{'oauth_consumer_key'};
	my $signature_method = $self->{inputs_ref}{'oauth_signature_method'};
	my $sourcedid = $self->{inputs_ref}{'lis_result_sourcedid'};
	my $consumer_secret = $ce->{'LISConsumerKeyHash'}{$consumer_key};
	my $score = $rh_result->{problem_result} ? $rh_result->{problem_result}{score} : 0;

	my $LTIGradeMessage = '';

	if ( ! $forbidGradePassback ) {

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

		my $requestGen = Net::OAuth->request("consumer");

		$requestGen->add_required_message_params('body_hash');

		my $gradeRequest = $requestGen->new(
			request_url => $request_url,
			request_method => "POST",
			consumer_secret => $consumer_secret,
			consumer_key => $consumer_key,
			signature_method => $signature_method,
			nonce => int(rand( 2**32)),
			timestamp => time(),
			body_hash => $bodyhash
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
				$LTIGradeMessage = CGI::p("Unable to update LMS grade. Error: ".$message);
				$rh_result->{debug_messages} .= CGI::escapeHTML($response->content);
			} else {
				$LTIGradeMessage = CGI::p("Grade sucessfully saved.");
			}
		} else {
			$LTIGradeMessage = CGI::p("Unable to update LMS grade. Error: ".$response->message);
			$rh_result->{debug_messages} .= CGI::escapeHTML($response->content);
		}
	}

	# save parameters for next time
	$LTIGradeMessage .= CGI::input({type => 'hidden', name => 'lis_outcome_service_url', value => $request_url});
	$LTIGradeMessage .= CGI::input({type => 'hidden', name => 'oauth_consumer_key', value => $consumer_key});
	$LTIGradeMessage .= CGI::input({type => 'hidden', name => 'oauth_signature_method', value => $signature_method});
	$LTIGradeMessage .= CGI::input({type => 'hidden', name => 'lis_result_sourcedid', value => $sourcedid});

	return $LTIGradeMessage;
}

# error formatting
sub format_hash_ref {
	my $hash = shift;
	warn "Use a hash reference" unless ref($hash) =~ /HASH/;
	return join(" ", map { $_= "--" unless defined($_); $_ } %$hash) . "\n";
}

1;
