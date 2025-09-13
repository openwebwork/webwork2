
=head1 NAME

FormatRenderedProblem.pm

=cut

package FormatRenderedProblem;

use strict;
use warnings;

use Digest::SHA qw(sha1_base64);
use Mojo::Util  qw(xml_escape);
use Mojo::JSON  qw(encode_json);
use Mojo::DOM;

use WeBWorK::Utils                       qw(getAssetURL);
use WeBWorK::Utils::LanguageAndDirection qw(get_lang_and_dir get_problem_lang_and_dir);

sub formatRenderedProblem {
	my $ws = shift;     # $ws is a WebworkWebservice object.
	my $ce = $ws->ce;

	my $rh_result = $ws->return_object;

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

	my $problemText = $rh_result->{text} // '';
	if ($rh_result->{flags}{error_flag}) {
		$rh_result->{problem_result}{score} = 0;    # force score to 0 for such errors.
		$renderErrorOccurred                = 1;
		$forbidGradePassback                = 1;    # due to render error
	}

	my $SITE_URL = $ws->c->server_root_url;

	my $displayMode = $ws->{inputs_ref}{displayMode} // 'MathJax';

	# HTML document language setting
	my $formLanguage = $ws->{inputs_ref}{language} // 'en';

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
		[ 'js/MathJaxConfig/mathjax-config.js',                     0, { defer => undef } ],
		[ 'node_modules/mathjax/es5/tex-svg.js',                    0, { defer => undef, id => 'MathJax-script' } ],
		[ 'node_modules/bootstrap/dist/js/bootstrap.bundle.min.js', 0, { defer => undef } ],
		[ 'js/Problem/problem.js',                                  0, { defer => undef } ],
		[ 'js/System/system.js',                                    0, { defer => undef } ],
		[ 'math4-overrides.js',                                     1, { defer => undef } ]
	);

	# Get the requested format.
	my $formatName = $ws->{inputs_ref}{outputformat} // 'simple';

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
		get_problem_lang_and_dir($rh_result->{flags}, $ce->{perProblemLangAndDirSettingMode}, $formLanguage);
	my $PROBLEM_LANG_AND_DIR = join(' ', map {qq{$_="$PROBLEM_LANG_AND_DIR{$_}"}} keys %PROBLEM_LANG_AND_DIR);

	my $previewMode     = defined($ws->{inputs_ref}{previewAnswers}) || 0;
	my $submitMode      = defined($ws->{inputs_ref}{WWsubmit})       || 0;
	my $showCorrectMode = defined($ws->{inputs_ref}{WWcorrectAns})   || 0;
	# A problemUUID should be added to the request as a parameter.  It is used by PG to create a proper UUID for use in
	# aliases for resources.  It should be unique for a course, user, set, problem, and version.
	my $problemUUID   = $ws->{inputs_ref}{problemUUID} // '';
	my $problemResult = $rh_result->{problem_result}   // {};
	my $showSummary   = $ws->{inputs_ref}{showSummary} // 1;

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
		$resultSummary = $ws->c->c(
			$ws->c->tag(
				'h2',
				class => 'fs-3 mb-2',
				$ws->c->maketext('Results for this submission')
				)
				. $ws->c->tag('div', role => 'alert', $ws->c->b($problemResult->{summary}))
		)->join('');
	}

	# Answer hash in XML format used by the PTX format.
	my $answerhashXML = '';
	if ($formatName eq 'ptx') {
		my $dom = Mojo::DOM->new->xml(1);
		for my $answer (sort keys %{ $rh_result->{answers} }) {
			$dom->append_content($dom->new_tag(
				$answer,
				map { $_ => ($rh_result->{answers}{$answer}{$_} // '') } keys %{ $rh_result->{answers}{$answer} }
			));
		}
		$dom->wrap_content('<answerhashes></answerhashes>');
		$answerhashXML = $dom->to_string;

		$ws->c->res->headers->content_type('text/xml; charset=utf-8')
			if $ws->c->current_route eq 'render_rpc' && ($ws->c->param('displayMode') // '') eq 'PTX';
	}

	# Make sure $rh_result->{debug_messages} an array reference as saveGradeToLTI might add to it.
	$rh_result->{debug_messages} = [] unless ref $rh_result->{debug_messages} eq 'ARRAY';

	$forbidGradePassback = 1 if !$forbidGradePassback && !$submitMode;

	# Try to save the grade to an LTI if one provided us data (depending on $forbidGradePassback)
	my $LTIGradeMessage = saveGradeToLTI($ws, $ce, $rh_result, $forbidGradePassback);

	# Execute and return the interpolated problem template

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
		$output->{resultSummary}   = $resultSummary->to_string if $resultSummary;
		$output->{lang}            = $PROBLEM_LANG_AND_DIR{lang};
		$output->{dir}             = $PROBLEM_LANG_AND_DIR{dir};
		$output->{extra_css_files} = \@extra_css_files;
		$output->{extra_js_files}  = \@extra_js_files;

		# Include third party css and javascript files.  Only jquery, jquery-ui, mathjax, and bootstrap are needed for
		# PG.  See the comments before the subroutine definitions for load_css and load_js in pg/macros/PG.pl.
		# The other files included are only needed to make themes work in the webwork2 formats.
		$output->{third_party_css} = \@third_party_css;
		$output->{third_party_js}  = \@third_party_js;

		# Say what version of WeBWorK this is
		$output->{ww_version} = $ce->{WW_VERSION};
		$output->{pg_version} = $ce->{PG_VERSION};

		# Convert to JSON and render.
		return $ws->c->render(data => encode_json($output));
	}

	# Setup arnd render the appropriate template in the templates/RPCRenderFormats folder depending on the outputformat.
	# "ptx" has a special template.  "json" uses the default json template.  All others use the default html template.
	my %template_params = (
		template => $formatName eq 'ptx' ? 'RPCRenderFormats/ptx' : 'RPCRenderFormats/default',
		$formatName eq 'json' ? (format => 'json') : (),
		formatName                   => $formatName,
		ws                           => $ws,
		ce                           => $ce,
		lh                           => $lh,
		rh_result                    => $rh_result,
		SITE_URL                     => $SITE_URL,
		FORM_ACTION_URL              => $SITE_URL . $ws->c->webwork_url . '/' . $ws->c->current_route,
		COURSE_LANG_AND_DIR          => get_lang_and_dir($formLanguage),
		theme                        => $ws->{inputs_ref}{theme} || $ce->{defaultTheme},
		courseID                     => $ws->{inputs_ref}{courseID}       // '',
		user                         => $ws->{inputs_ref}{user}           // '',
		passwd                       => $ws->{inputs_ref}{passwd}         // '',
		disableCookies               => $ws->{inputs_ref}{disableCookies} // '',
		key                          => $ws->authen->{session_key},
		PROBLEM_LANG_AND_DIR         => $PROBLEM_LANG_AND_DIR,
		problemSeed                  => $rh_result->{problem_seed} // $ws->{inputs_ref}{problemSeed} // 6666,
		psvn                         => $rh_result->{psvn}         // $ws->{inputs_ref}{psvn}        // 54321,
		problemUUID                  => $problemUUID,
		displayMode                  => $displayMode,
		third_party_css              => \@third_party_css,
		extra_css_files              => \@extra_css_files,
		third_party_js               => \@third_party_js,
		extra_js_files               => \@extra_js_files,
		problemText                  => $problemText,
		extra_header_text            => $ws->{inputs_ref}{extra_header_text} // '',
		resultSummary                => $resultSummary,
		showScoreSummary             => $submitMode && !$renderErrorOccurred && $problemResult,
		answerhashXML                => $answerhashXML,
		LTIGradeMessage              => $LTIGradeMessage,
		sourceFilePath               => $ws->{inputs_ref}{sourceFilePath}          // '',
		problemSource                => $ws->{inputs_ref}{problemSource}           // '',
		rawProblemSource             => $ws->{inputs_ref}{rawProblemSource}        // '',
		uriEncodedProblemSource      => $ws->{inputs_ref}{uriEncodedProblemSource} // '',
		fileName                     => $ws->{inputs_ref}{fileName}                // '',
		formLanguage                 => $formLanguage,
		isInstructor                 => $ws->{inputs_ref}{isInstructor}       // '',
		forceScaffoldsOpen           => $ws->{inputs_ref}{forceScaffoldsOpen} // '',
		showSummary                  => $showSummary,
		showHints                    => $ws->{inputs_ref}{showHints}                    // '',
		showSolutions                => $ws->{inputs_ref}{showSolutions}                // '',
		showPreviewButton            => $ws->{inputs_ref}{showPreviewButton}            // '',
		showCheckAnswersButton       => $ws->{inputs_ref}{showCheckAnswersButton}       // '',
		showCorrectAnswersButton     => $ws->{inputs_ref}{showCorrectAnswersButton}     // '',
		showCorrectAnswersOnlyButton => $ws->{inputs_ref}{showCorrectAnswersOnlyButton} // 0,
		showFooter                   => $ws->{inputs_ref}{showFooter}                   // '',
		problem_data                 => encode_json($rh_result->{PERSISTENCE_HASH}),
		pretty_print                 => \&pretty_print
	);

	return $ws->c->render(%template_params) if $formatName eq 'json' || !$ws->{inputs_ref}{send_pg_flags};
	return $ws->c->render(
		json => {
			html              => $ws->c->render_to_string(%template_params)->to_string,
			pg_flags          => $rh_result->{flags},
			deprecated_macros => $rh_result->{deprecated_macros}
		}
	);
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
				$LTIGradeMessage = $ws->c->tag('p', "Unable to update LMS grade. Error: $message")->to_string;
				push(@{ $rh_result->{debug_messages} }, xml_escape($response->content));
			} else {
				$LTIGradeMessage = $ws->c->tag('p', 'Grade sucessfully saved.')->to_string;
			}
		} else {
			$LTIGradeMessage = $ws->c->tag('p', 'Unable to update LMS grade. Error: ' . $response->message)->to_string;
			push(@{ $rh_result->{debug_messages} }, xml_escape($response->content));
		}
	}

	# save parameters for next time
	$LTIGradeMessage .= $ws->c->hidden_field(lis_outcome_service_url => $request_url)->to_string;
	$LTIGradeMessage .= $ws->c->hidden_field(oauth_consumer_key      => $consumer_key)->to_string;
	$LTIGradeMessage .= $ws->c->hidden_field(oauth_signature_method  => $signature_method)->to_string;
	$LTIGradeMessage .= $ws->c->hidden_field(lis_result_sourcedid    => $sourcedid)->to_string;

	return $LTIGradeMessage;
}

# Nice output for debugging
sub pretty_print {
	my ($r_input, $level) = @_;
	return 'undef' unless defined $r_input;

	$level //= 4;
	$level--;
	return 'too deep' unless $level > 0;

	my $ref = ref($r_input);

	if (!$ref) {
		return xml_escape($r_input);
	} elsif (eval { %$r_input || 1 }) {
		# `eval { %$r_input || 1 }` will pick up all objectes that can be accessed like a hash and so works better than
		# `ref $r_input`.  Do not use `"$r_input" =~ /hash/i` because that will pick up strings containing the word
		# hash, and that will cause an error below.
		my $out =
			'<div style="display:table;border:1px solid black;background-color:#fff;">'
			. ($ref eq 'HASH'
				? ''
				: '<div style="'
				. 'display:table-caption;padding:3px;border:1px solid black;background-color:#fff;text-align:center;">'
				. "$ref</div>")
			. '<div style="display:table-row-group">';
		for my $key (sort keys %$r_input) {
			# Safety feature - we do not want to display the contents of %seed_ce which
			# contains the database password and lots of other things, and explicitly hide
			# certain internals of the CourseEnvironment in case one slips in.
			next
				if (($key =~ /database/)
					|| ($key eq "ConfigValues")
					|| ($key eq "ENV")
					|| ($key eq "externalPrograms")
					|| ($key eq "permissionLevels")
					|| ($key eq "seed_ce"));
			$out .=
				'<div style="display:table-row"><div style="display:table-cell;vertical-align:middle;padding:3px">'
				. xml_escape($key)
				. '</div>'
				. qq{<div style="display:table-cell;vertical-align:middle;padding:3px">=&gt;</div>}
				. qq{<div style="display:table-cell;vertical-align:middle;padding:3px">}
				. pretty_print($r_input->{$key}, $level)
				. '</div></div>';
		}
		$out .= '</div></div>';
		return $out;
	} elsif ($ref eq 'ARRAY') {
		return '[ ' . join(', ', map { pretty_print($_, $level) } @$r_input) . ' ]';
	} elsif ($ref eq 'CODE') {
		return 'CODE';
	} else {
		return xml_escape($r_input);
	}
}

1;
