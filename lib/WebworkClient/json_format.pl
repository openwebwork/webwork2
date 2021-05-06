# The json output format needs to collect the data differently than the other
# formats. It will return a hash, and each relevant value will later undergo
# variable interpolation.

# Most parts which need variable interpolation end in "_VI".
# Other parts which need variable interpolation are:
#	hidden_input_field_*
#	real_webwork_*

$json_output = { head_part001_VI => '<!DOCTYPE html><html $COURSE_LANG_AND_DIR>' };

$json_output->{head_part010} = <<'ENDPROBLEMTEMPLATE';
<head>
<meta charset='utf-8'>
<base href="TO_SET_LATER_SITE_URL">
<link rel="shortcut icon" href="/webwork2_files/images/favicon.ico"/>
ENDPROBLEMTEMPLATE

$json_output->{head_part100_VI} = <<'ENDPROBLEMTEMPLATE';
<!-- CSS Loads -->
<link rel="stylesheet" type="text/css" href="/webwork2_files/js/vendor/bootstrap/css/bootstrap.css"/>
<link rel="stylesheet" type="text/css" href="/webwork2_files/js/vendor/bootstrap/css/bootstrap-responsive.css"/>
<link rel="stylesheet" type="text/css" href="/webwork2_files/node_modules/jquery-ui-dist/jquery-ui.min.css"/>
<link rel="stylesheet" type="text/css" href="/webwork2_files/node_modules/@fortawesome/fontawesome-free/css/all.min.css"/>
<link rel="stylesheet" type="text/css" href="/webwork2_files/css/knowlstyle.css"/>
<link rel="stylesheet" type="text/css" href="/webwork2_files/js/apps/ImageView/imageview.css"/>
<link rel="stylesheet" href="$themeDir/math4.css"/>
<link rel="stylesheet" href="$themeDir/math4-coloring.css"/>
<link rel="stylesheet" href="$themeDir/math4-overrides.css"/>
ENDPROBLEMTEMPLATE

$json_ouput{head_part200_VI} = <<'ENDPROBLEMTEMPLATE';
<!-- JS Loads -->
<script src="https://polyfill.io/v3/polyfill.min.js?features=es6" defer></script>
<script type="text/javascript" src="/webwork2_files/js/apps/MathJaxConfig/mathjax-config.js" defer></script>
<script type="text/javascript" src="/webwork2_files/mathjax/es5/tex-chtml.js" id="MathJax-script" defer></script>
<script type="text/javascript" src="/webwork2_files/node_modules/jquery/dist/jquery.min.js"></script>
<script type="text/javascript" src="/webwork2_files/node_modules/jquery-ui-dist/jquery-ui.min.js"></script>
<script type="text/javascript" src="/webwork2_files/js/vendor/bootstrap/js/bootstrap.js"></script>
<script type="text/javascript" src="/webwork2_files/js/apps/InputColor/color.js"></script>
<script type="text/javascript" src="/webwork2_files/js/apps/Base64/Base64.js"></script>
<script type="text/javascript" src="/webwork2_files/js/vendor/underscore/underscore.js"></script>
<script type="text/javascript" src="/webwork2_files/js/legacy/vendor/knowl.js"></script>
<script type="text/javascript" src="/webwork2_files/js/apps/Problem/problem.js"></script>
<script type="text/javascript" src="/webwork2_files/js/apps/ImageView/imageview.js"></script>
<script type="text/javascript" src="/webwork2_files/node_modules/iframe-resizer/js/iframeResizer.contentWindow.min.js"></script>
<script src="$themeDir/math4/math4.js" defer></script>
ENDPROBLEMTEMPLATE

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

$json_output->{hidden_input_field_answersSubmitted} = '1';
$json_output->{hidden_input_field_sourceFilePath} = '$sourceFilePath';
$json_output->{hidden_input_field_problemSource} = '$encoded_source';
$json_output->{hidden_input_field_problemSeed} = '$problemSeed';
$json_output->{hidden_input_field_problemUUID} = '$problemUUID';
$json_output->{hidden_input_field_psvn} = '$psvn';
$json_output->{hidden_input_field_pathToProblemFile} = '$fileName';
$json_output->{hidden_input_field_courseName} = '$courseID';
$json_output->{hidden_input_field_courseID} = '$courseID';
$json_output->{hidden_input_field_userID} = '$userID';
$json_output->{hidden_input_field_course_password} = '$course_password';
$json_output->{hidden_input_field_displayMode} = '$displayMode';
$json_output->{hidden_input_field_session_key} = '$session_key';
$json_output->{hidden_input_field_outputformat} = 'json';
$json_output->{hidden_input_field_theme} = '$theme';
$json_output->{hidden_input_field_language} = '$formLanguage';
$json_output->{hidden_input_field_showSummary} = '$showSummary';
$json_output->{hidden_input_field_showAnswerNumbers} = '$showAnswerNumbers';
$json_output->{hidden_input_field_showPreviewButton} = '$showPreviewButton';
$json_output->{hidden_input_field_showCheckAnswersButton} = '$showCheckAnswersButton';
$json_output->{hidden_input_field_showCorrectAnswersButton} = '$showCorrectAnswersButton';
$json_output->{hidden_input_field_showFooter} = '$showFooter';
$json_output->{hidden_input_field_forcePortNumber} = '$forcePortNumber';
$json_output->{hidden_input_field_extraHeaderText} = '$extra_header_text';

# These are the real WeBWorK server URLs which the intermediate needs to use
# to communicate with WW, while the distant client must use URLs of the
# intermediate server (the man in the middle).

$json_output->{real_webwork_SITE_URL} = '$SITE_URL';
$json_output->{real_webwork_FORM_ACTION_URL} = '$FORM_ACTION_URL';
$json_output->{internal_problem_lang_and_dir} = '$PROBLEM_LANG_AND_DIR';

# Output back to WebworkClient.pm is the reference to the hash:
$json_output;
