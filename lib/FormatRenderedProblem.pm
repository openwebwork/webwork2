
=head1 NAME

FormatRenderedProblem.pm

=cut

package FormatRenderedProblem;
use Mojo::Base -signatures;

use Digest::SHA qw(sha1_base64);
use Mojo::Util  qw(xml_escape);
use Mojo::JSON  qw(encode_json);
use Mojo::DOM;

use WeBWorK::Utils                       qw(getAssetURL);
use WeBWorK::Utils::LanguageAndDirection qw(get_lang_and_dir get_problem_lang_and_dir);

sub formatRenderedProblem ($c, $renderedProblem) {
	my $ce = $c->ce;

	my $inputsRef = $c->req->params->to_hash;

	my $forbidGradePassback = 1;    # Default is to forbid, due to the security issue

	if (defined($ce->{renderRPCAllowGradePassback})
		&& $ce->{renderRPCAllowGradePassback} eq
		'This course intentionally enables the insecure LTI grade pass-back feature of render_rpc.')
	{
		# It is strongly recommended that you clarify the security risks of enabling the current version of this feature
		# before using it.
		$forbidGradePassback = 0;
	}

	my $renderErrorOccurred = 0;

	my $problemText = $renderedProblem->{text} // '';
	if ($renderedProblem->{flags}{error_flag}) {
		$renderedProblem->{problem_result}{score} = 0;    # force score to 0 for such errors.
		$renderErrorOccurred                      = 1;
		$forbidGradePassback                      = 1;    # due to render error
	}

	my $SITE_URL = $c->server_root_url;

	my $displayMode = $inputsRef->{displayMode} // 'MathJax';

	# HTML document language setting
	my $formLanguage = $inputsRef->{language} // 'en';

	# Third party CSS
	# The second element of each array in the following is whether or not the file is a theme file.
	my @third_party_css = map { getAssetURL($ce, $_->[0], $_->[1]) } (
		[ 'bootstrap.css',                                              1 ],
		[ 'node_modules/jquery-ui-dist/jquery-ui.min.css',              0 ],
		[ 'node_modules/@fortawesome/fontawesome-free/css/all.min.css', 0 ],
		[ 'js/System/system.css',                                       0 ],
		[ 'math4-overrides.css',                                        1 ],
	);

	# Add CSS files requested by problems via ADD_CSS_FILE() in the PG file
	# or via a setting of $ce->{pg}{specialPGEnvironmentVars}{extra_css_files}
	# which can be set in course.conf (the value should be an anonymous array).
	my @cssFiles;
	if (ref($ce->{pg}{specialPGEnvironmentVars}{extra_css_files}) eq 'ARRAY') {
		push(@cssFiles, { file => $_, external => 0 }) for @{ $ce->{pg}{specialPGEnvironmentVars}{extra_css_files} };
	}
	if (ref($renderedProblem->{flags}{extra_css_files}) eq 'ARRAY') {
		push @cssFiles, @{ $renderedProblem->{flags}{extra_css_files} };
	}
	my %cssFilesAdded;    # Used to avoid duplicates
	my @extra_css_files;
	for (@cssFiles) {
		next if $cssFilesAdded{ $_->{file} };
		$cssFilesAdded{ $_->{file} } = 1;
		if ($_->{external}) {
			push(@extra_css_files, $_);
		} else {
			push(@extra_css_files, { file => getAssetURL($ce, $_->{file}), external => 0 });
		}
	}

	# Third party JavaScript
	# The second element of each array in the following is whether or not the file is a theme file.
	# The third element is a hash containing the necessary attributes for the script tag.
	my @third_party_js = map { [ getAssetURL($ce, $_->[0], $_->[1]), $_->[2] ] } (
		[ 'node_modules/jquery/dist/jquery.min.js',                            0, {} ],
		[ 'node_modules/jquery-ui-dist/jquery-ui.min.js',                      0, {} ],
		[ 'node_modules/iframe-resizer/js/iframeResizer.contentWindow.min.js', 0, {} ],
		[ 'js/MathJaxConfig/mathjax-config.js',                                0, { defer => undef } ],
		[ 'node_modules/mathjax/tex-svg.js',                                   0, { defer => undef } ],
		[ 'node_modules/bootstrap/dist/js/bootstrap.bundle.min.js',            0, { defer => undef } ],
		[ 'js/Problem/problem.js',                                             0, { defer => undef } ],
		[ 'js/System/system.js',                                               0, { defer => undef } ],
		[ 'math4-overrides.js',                                                1, { defer => undef } ]
	);

	# Get the requested format.
	my $formatName = $inputsRef->{outputformat} // 'simple';

	# Add JS files requested by problems via ADD_JS_FILE() in the PG file.
	my @extra_js_files;
	if (ref($renderedProblem->{flags}{extra_js_files}) eq 'ARRAY') {
		my %jsFiles;
		for (@{ $renderedProblem->{flags}{extra_js_files} }) {
			next if $jsFiles{ $_->{file} };
			$jsFiles{ $_->{file} } = 1;
			my %attributes = ref($_->{attributes}) eq 'HASH' ? %{ $_->{attributes} } : ();
			if ($_->{external}) {
				push(@extra_js_files, $_);
			} else {
				push(@extra_js_files,
					{ file => getAssetURL($ce, $_->{file}), external => 0, attributes => $_->{attributes} });
			}
		}
	}

	# Set up the problem language and direction
	# PG files can request their language and text direction be set.  If we do not have access to a default course
	# language, fall back to the $formLanguage instead.
	my %PROBLEM_LANG_AND_DIR =
		get_problem_lang_and_dir($renderedProblem->{flags}, $ce->{perProblemLangAndDirSettingMode}, $formLanguage);
	my $PROBLEM_LANG_AND_DIR = join(' ', map {qq{$_="$PROBLEM_LANG_AND_DIR{$_}"}} keys %PROBLEM_LANG_AND_DIR);

	my $previewMode     = defined($inputsRef->{previewAnswers}) || 0;
	my $submitMode      = defined($inputsRef->{WWsubmit})       || 0;
	my $showCorrectMode = defined($inputsRef->{WWcorrectAns})   || 0;
	# A problemUUID should be added to the request as a parameter.  It is used by PG to create a proper UUID for use in
	# aliases for resources.  It should be unique for a course, user, set, problem, and version.
	my $problemUUID   = $inputsRef->{problemUUID}          // '';
	my $problemResult = $renderedProblem->{problem_result} // {};
	my $showSummary   = $inputsRef->{showSummary}          // 1;

	# Result summary
	my $resultSummary = '';

	my $lh = WeBWorK::Localize::getLangHandle($formLanguage);

	# Do not produce a result summary when we had a rendering error.
	if (!$renderErrorOccurred
		&& $showSummary
		&& !$previewMode
		&& ($submitMode || $showCorrectMode)
		&& $problemResult->{summary})
	{
		$resultSummary = $c->c(
			$c->tag(
				'h2',
				class => 'fs-3 mb-2',
				$c->maketext('Results for this submission')
				)
				. $c->tag('div', role => 'alert', $c->b($problemResult->{summary}))
		)->join('');
	}

	# Answer hash in XML format used by the PTX format.
	my $answerhashXML = '';
	if ($formatName eq 'ptx') {
		my $dom = Mojo::DOM->new->xml(1);
		for my $answer (sort keys %{ $renderedProblem->{answers} }) {
			$dom->append_content($dom->new_tag(
				$answer,
				map { $_ => ($renderedProblem->{answers}{$answer}{$_} // '') }
					keys %{ $renderedProblem->{answers}{$answer} }
			));
		}
		$dom->wrap_content('<answerhashes></answerhashes>');
		$answerhashXML = $dom->to_string;

		$c->res->headers->content_type('text/xml; charset=utf-8')
			if $c->current_route eq 'render_rpc' && ($inputsRef->{displayMode} // '') eq 'PTX';
	}

	# Make sure $renderedProblem->{debug_messages} an array reference as saveGradeToLTI might add to it.
	$renderedProblem->{debug_messages} = [] unless ref $renderedProblem->{debug_messages} eq 'ARRAY';

	$forbidGradePassback = 1 if !$forbidGradePassback && !$submitMode;

	# Try to save the grade to an LTI if one provided us data (depending on $forbidGradePassback)
	my $LTIGradeMessage = saveGradeToLTI($c, $ce, $renderedProblem, $forbidGradePassback);

	# Execute and return the interpolated problem template

	# Raw format
	# This format returns javascript object notation corresponding to the perl hash
	# with everything that a client-side application could use to work with the problem.
	# There is no wrapping HTML "_format" template.
	if ($formatName eq 'raw') {
		my $output = {};

		# Everything that ships out with other formats can be constructed from these
		$output->{rh_result}  = $renderedProblem;
		$output->{inputs_ref} = $inputsRef;
		$output->{input}      = $c->{input};        # FIXME: What is this?

		# The following could be constructed from the above, but this is a convenience
		$output->{resultSummary}     = $resultSummary->to_string if $resultSummary;
		$output->{lang}              = $PROBLEM_LANG_AND_DIR{lang};
		$output->{dir}               = $PROBLEM_LANG_AND_DIR{dir};
		$output->{extra_css_files}   = \@extra_css_files;
		$output->{extra_js_files}    = \@extra_js_files;
		$output->{webwork_js_config} = $c->webwork_js_config($inputsRef->{showMathJaxErrors} // 0);

		# Include third party css and javascript files.  Only jquery, jquery-ui, mathjax, and bootstrap are needed for
		# PG.  See the comments before the subroutine definitions for load_css and load_js in pg/macros/PG.pl.
		# The other files included are only needed to make themes work in the webwork2 formats.
		$output->{third_party_css} = \@third_party_css;
		$output->{third_party_js}  = \@third_party_js;

		# Say what version of WeBWorK this is
		$output->{ww_version} = $ce->{WW_VERSION};
		$output->{pg_version} = $ce->{PG_VERSION};

		# Convert to JSON and render.
		return $c->render(data => encode_json($output));
	}

	# Setup arnd render the appropriate template in the templates/RPCRenderFormats folder depending on the outputformat.
	# "ptx" has a special template.  "json" uses the default json template.  All others use the default html template.
	my %template_params = (
		template => $formatName eq 'ptx' ? 'RPCRenderFormats/ptx' : 'RPCRenderFormats/default',
		$formatName eq 'json' ? (format => 'json') : (),
		formatName                   => $formatName,
		ce                           => $ce,
		lh                           => $lh,
		rh_result                    => $renderedProblem,
		SITE_URL                     => $SITE_URL,
		FORM_ACTION_URL              => $SITE_URL . $c->webwork_url . '/' . $c->current_route,
		COURSE_LANG_AND_DIR          => get_lang_and_dir($formLanguage),
		theme                        => $inputsRef->{theme} || $ce->{defaultTheme},
		courseID                     => $inputsRef->{courseID}       // '',
		user                         => $inputsRef->{user}           // '',
		passwd                       => $inputsRef->{passwd}         // '',
		disableCookies               => $inputsRef->{disableCookies} // '',
		key                          => $c->authen->{session_key},
		PROBLEM_LANG_AND_DIR         => $PROBLEM_LANG_AND_DIR,
		problemSeed                  => $renderedProblem->{problem_seed} // $inputsRef->{problemSeed} // 6666,
		psvn                         => $renderedProblem->{psvn}         // $inputsRef->{psvn}        // 54321,
		problemUUID                  => $problemUUID,
		displayMode                  => $displayMode,
		third_party_css              => \@third_party_css,
		extra_css_files              => \@extra_css_files,
		third_party_js               => \@third_party_js,
		extra_js_files               => \@extra_js_files,
		problemText                  => $problemText,
		extra_header_text            => $inputsRef->{extra_header_text} // '',
		resultSummary                => $resultSummary,
		showScoreSummary             => $submitMode && !$renderErrorOccurred && $problemResult,
		answerhashXML                => $answerhashXML,
		LTIGradeMessage              => $LTIGradeMessage,
		sourceFilePath               => $inputsRef->{sourceFilePath}          // '',
		problemSource                => $inputsRef->{problemSource}           // '',
		rawProblemSource             => $inputsRef->{rawProblemSource}        // '',
		uriEncodedProblemSource      => $inputsRef->{uriEncodedProblemSource} // '',
		fileName                     => $inputsRef->{fileName}                // '',
		formLanguage                 => $formLanguage,
		isInstructor                 => $inputsRef->{isInstructor}       // '',
		forceScaffoldsOpen           => $inputsRef->{forceScaffoldsOpen} // '',
		showSummary                  => $showSummary,
		showHints                    => $inputsRef->{showHints}                    // '',
		showSolutions                => $inputsRef->{showSolutions}                // '',
		showPreviewButton            => $inputsRef->{showPreviewButton}            // '',
		showCheckAnswersButton       => $inputsRef->{showCheckAnswersButton}       // '',
		showCorrectAnswersButton     => $inputsRef->{showCorrectAnswersButton}     // '',
		showCorrectAnswersOnlyButton => $inputsRef->{showCorrectAnswersOnlyButton} // 0,
		showFooter                   => $inputsRef->{showFooter}                   // '',
		problem_data                 => encode_json($renderedProblem->{PERSISTENCE_HASH}),
		showMathJaxErrors            => $inputsRef->{showMathJaxErrors} // 0,
	);

	return $c->render(%template_params) if $formatName eq 'json' || !$inputsRef->{send_pg_flags};
	return $c->render(json =>
			{ html => $c->render_to_string(%template_params)->to_string, pg_flags => $renderedProblem->{flags} });
}

sub saveGradeToLTI ($c, $ce, $renderedProblem, $forbidGradePassback) {
	# When $forbidGradePassback is set, we will block the actual submission,
	# but we still provide the LTI data in the hidden fields.

	my $inputsRef = $c->req->params->to_hash;

	return ''
		if !(defined($inputsRef->{lis_outcome_service_url})
			&& defined($inputsRef->{'oauth_consumer_key'})
			&& defined($inputsRef->{'oauth_signature_method'})
			&& defined($inputsRef->{'lis_result_sourcedid'})
			&& defined($ce->{'LISConsumerKeyHash'}{ $inputsRef->{'oauth_consumer_key'} }));

	my $request_url      = $inputsRef->{lis_outcome_service_url};
	my $consumer_key     = $inputsRef->{'oauth_consumer_key'};
	my $signature_method = $inputsRef->{'oauth_signature_method'};
	my $sourcedid        = $inputsRef->{'lis_result_sourcedid'};
	my $consumer_secret  = $ce->{'LISConsumerKeyHash'}{$consumer_key};
	my $score            = $renderedProblem->{problem_result} ? $renderedProblem->{problem_result}{score} : 0;

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
				$LTIGradeMessage = $c->tag('p', "Unable to update LMS grade. Error: $message")->to_string;
				push(@{ $renderedProblem->{debug_messages} }, xml_escape($response->content));
			} else {
				$LTIGradeMessage = $c->tag('p', 'Grade successfully saved.')->to_string;
			}
		} else {
			$LTIGradeMessage = $c->tag('p', 'Unable to update LMS grade. Error: ' . $response->message)->to_string;
			push(@{ $renderedProblem->{debug_messages} }, xml_escape($response->content));
		}
	}

	# save parameters for next time
	$LTIGradeMessage .= $c->hidden_field(lis_outcome_service_url => $request_url)->to_string;
	$LTIGradeMessage .= $c->hidden_field(oauth_consumer_key      => $consumer_key)->to_string;
	$LTIGradeMessage .= $c->hidden_field(oauth_signature_method  => $signature_method)->to_string;
	$LTIGradeMessage .= $c->hidden_field(lis_result_sourcedid    => $sourcedid)->to_string;

	return $LTIGradeMessage;
}

1;
