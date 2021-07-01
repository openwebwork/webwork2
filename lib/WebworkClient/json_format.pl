# The json output format needs to collect the data differently than the other
# formats. It will return a hash, and each relevant value will later undergo
# variable interpolation.

# Most parts which need variable interpolation end in "_VI".
# Parts ending in "_AVI" are references to anonymous arrays whose entries need variable interpolation.
# Other parts which need variable interpolation are:
#	hidden_input_field}{*
#	real_webwork_*

# NOTE: When a variable needs to be interpolated later, the string should be in single quotes not in double quotes.

$json_output = { head_part001_VI => '<!DOCTYPE html><html $COURSE_LANG_AND_DIR>' };

$json_output->{head_part010} = <<'ENDPROBLEMTEMPLATE';
<head>
<meta charset='utf-8'>
<base href="TO_SET_LATER_SITE_URL">
<link rel="shortcut icon" href="/webwork2_files/images/favicon.ico"/>
ENDPROBLEMTEMPLATE

# CSS loads - as an array of href values
$json_output->{head_part100_AVI} = [
	"/webwork2_files/js/vendor/bootstrap/css/bootstrap.css",
	"/webwork2_files/js/vendor/bootstrap/css/bootstrap-responsive.css",
	"/webwork2_files/node_modules/jquery-ui-dist/jquery-ui.min.css",
	"/webwork2_files/node_modules/@fortawesome/fontawesome-free/css/all.min.css",
	"/webwork2_files/css/knowlstyle.css",
	"/webwork2_files/js/apps/ImageView/imageview.css",
	'$themeDir/math4.css',
	'$themeDir/math4-coloring.css',
	'$themeDir/math4-overrides.css',
];

# JS loads - as an array of href values - the ones which need defer are in head_part201_AVI
$json_output->{head_part200_AVI} = [
	"/webwork2_files/node_modules/jquery/dist/jquery.min.js",
	"/webwork2_files/node_modules/jquery-ui-dist/jquery-ui.min.js",
	"/webwork2_files/js/vendor/bootstrap/js/bootstrap.js",
	"/webwork2_files/js/apps/InputColor/color.js",
	"/webwork2_files/js/apps/Base64/Base64.js",
	"/webwork2_files/js/vendor/underscore/underscore.js",
	"/webwork2_files/js/legacy/vendor/knowl.js",
	"/webwork2_files/js/apps/Problem/problem.js",
	"/webwork2_files/js/apps/ImageView/imageview.js",
	"/webwork2_files/node_modules/iframe-resizer/js/iframeResizer.contentWindow.min.js",
];

# JS loads - as an array of href values - the ones which need defer are in head_part201_AVI
#     mathjax/es5/tex-chtml.js also needs id="MathJax-script" in the <script> tag
$json_output->{head_part201_AVI} = [
	"https://polyfill.io/v3/polyfill.min.js?features=es6",
	"/webwork2_files/js/apps/MathJaxConfig/mathjax-config.js",
	"/webwork2_files/mathjax/es5/tex-chtml.js",
	'$themeDir/math4/math4.js',
];

$json_output->{head_part300_VI} = '$problemHeadText';

$json_output->{head_part400} = '<title>WeBWorK problem</title>';

$json_output->{head_part999} = "</head>";
$json_output->{body_part001} = "<body>";

$json_output->{body_part100} = <<'ENDPROBLEMTEMPLATE';
<div class="container-fluid">
<div class="row-fluid">
<div class="span12 problem">
ENDPROBLEMTEMPLATE

$json_output->{body_part300_VI} = '$answerTemplate';

$json_output->{body_part500} = '<form id="problemMainForm" class="problem-main-form" name="problemMainForm" action="TO_SET_LATER_FORM_ACTION_URL" method="post">';

$json_output->{body_part530_VI} = '<div id="problem_body" class="problem-content" $PROBLEM_LANG_AND_DIR>';

$json_output->{body_part550_VI} = '$problemText';

$json_output->{body_part590} = "</div>";

$json_output->{body_part650_VI} = '$scoreSummary';

$json_output->{body_part700_VI} = '<p>$previewButton $checkAnswersButton $correctAnswersButton</p>';

$json_output->{body_part999_VI} = <<'ENDPROBLEMTEMPLATE';
</form></div></div></div>
$footer
</body></html>
ENDPROBLEMTEMPLATE

$json_output->{hidden_input_field} = {};


$json_output->{hidden_input_field}{answersSubmitted} = '1';
$json_output->{hidden_input_field}{sourceFilePath} = '$sourceFilePath';
$json_output->{hidden_input_field}{problemSource} = '$encoded_source';
$json_output->{hidden_input_field}{problemSeed} = '$problemSeed';
$json_output->{hidden_input_field}{problemUUID} = '$problemUUID';
$json_output->{hidden_input_field}{psvn} = '$psvn';
$json_output->{hidden_input_field}{pathToProblemFile} = '$fileName';
$json_output->{hidden_input_field}{courseName} = '$courseID';
$json_output->{hidden_input_field}{courseID} = '$courseID';
$json_output->{hidden_input_field}{userID} = '$userID';
$json_output->{hidden_input_field}{course_password} = '$course_password';
$json_output->{hidden_input_field}{displayMode} = '$displayMode';
$json_output->{hidden_input_field}{session_key} = '$session_key';
$json_output->{hidden_input_field}{outputformat} = 'json';
$json_output->{hidden_input_field}{theme} = '$theme';
$json_output->{hidden_input_field}{language} = '$formLanguage';
$json_output->{hidden_input_field}{showSummary} = '$showSummary';
$json_output->{hidden_input_field}{showHints} = '$showHints';
$json_output->{hidden_input_field}{showSolution} = '$showSolution';
$json_output->{hidden_input_field}{showAnswerNumbers} = '$showAnswerNumbers';
$json_output->{hidden_input_field}{showPreviewButton} = '$showPreviewButton';
$json_output->{hidden_input_field}{showCheckAnswersButton} = '$showCheckAnswersButton';
$json_output->{hidden_input_field}{showCorrectAnswersButton} = '$showCorrectAnswersButton';
$json_output->{hidden_input_field}{showFooter} = '$showFooter';
$json_output->{hidden_input_field}{forcePortNumber} = '$forcePortNumber';
$json_output->{hidden_input_field}{extraHeaderText} = '$extra_header_text';

# These are the real WeBWorK server URLs which the intermediate needs to use
# to communicate with WW, while the distant client must use URLs of the
# intermediate server (the man in the middle).

$json_output->{real_webwork_SITE_URL} = '$SITE_URL';
$json_output->{real_webwork_FORM_ACTION_URL} = '$FORM_ACTION_URL';
$json_output->{internal_problem_lang_and_dir} = '$PROBLEM_LANG_AND_DIR';

# Output back to WebworkClient.pm is the reference to the hash:
$json_output;
