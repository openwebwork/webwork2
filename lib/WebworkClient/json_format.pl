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

$json_output->{head_part010_VI} = <<'ENDPROBLEMTEMPLATE';
<head>
<meta charset='utf-8'>
<base href="TO_SET_LATER_SITE_URL">
$favicon
ENDPROBLEMTEMPLATE

# CSS loads - as an array of href values
# This is added in formatRenderedProblem
# $json_output->{head_part100}

# JS loads - as an array of arrays.  The first element of each subarray is the href value, and the second (if present)
# is a hash containing any needed attributes for the script tag.
# This is added in formatRenderedProblem
# $json_output->{head_part200}

$json_output->{head_part300_VI} = '$problemHeadText';

$json_output->{head_part400} = '<title>WeBWorK problem</title>';

$json_output->{head_part999} = "</head>";
$json_output->{body_part001} = "<body>";

$json_output->{body_part100} = <<'ENDPROBLEMTEMPLATE';
<div class="container-fluid">
<div class="row">
<div class="col-12 problem">
ENDPROBLEMTEMPLATE

$json_output->{body_part300_VI} = '$answerTemplate';

$json_output->{body_part500} =
	'<form id="problemMainForm" class="problem-main-form" name="problemMainForm" action="TO_SET_LATER_FORM_ACTION_URL" method="post">';

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

$json_output->{hidden_input_field}{answersSubmitted}         = '1';
$json_output->{hidden_input_field}{sourceFilePath}           = '$sourceFilePath';
$json_output->{hidden_input_field}{problemSource}            = '$encoded_source';
$json_output->{hidden_input_field}{problemSeed}              = '$problemSeed';
$json_output->{hidden_input_field}{problemUUID}              = '$problemUUID';
$json_output->{hidden_input_field}{psvn}                     = '$psvn';
$json_output->{hidden_input_field}{pathToProblemFile}        = '$fileName';
$json_output->{hidden_input_field}{courseName}               = '$courseID';
$json_output->{hidden_input_field}{courseID}                 = '$courseID';
$json_output->{hidden_input_field}{userID}                   = '$userID';
$json_output->{hidden_input_field}{course_password}          = '$course_password';
$json_output->{hidden_input_field}{displayMode}              = '$displayMode';
$json_output->{hidden_input_field}{session_key}              = '$session_key';
$json_output->{hidden_input_field}{outputformat}             = 'json';
$json_output->{hidden_input_field}{theme}                    = '$theme';
$json_output->{hidden_input_field}{language}                 = '$formLanguage';
$json_output->{hidden_input_field}{showSummary}              = '$showSummary';
$json_output->{hidden_input_field}{showHints}                = '$showHints';
$json_output->{hidden_input_field}{showSolution}             = '$showSolution';
$json_output->{hidden_input_field}{showAnswerNumbers}        = '$showAnswerNumbers';
$json_output->{hidden_input_field}{showPreviewButton}        = '$showPreviewButton';
$json_output->{hidden_input_field}{showCheckAnswersButton}   = '$showCheckAnswersButton';
$json_output->{hidden_input_field}{showCorrectAnswersButton} = '$showCorrectAnswersButton';
$json_output->{hidden_input_field}{showFooter}               = '$showFooter';
$json_output->{hidden_input_field}{forcePortNumber}          = '$forcePortNumber';
$json_output->{hidden_input_field}{extraHeaderText}          = '$extra_header_text';

# These are the real WeBWorK server URLs which the intermediate needs to use
# to communicate with WW, while the distant client must use URLs of the
# intermediate server (the man in the middle).

$json_output->{real_webwork_SITE_URL}         = '$SITE_URL';
$json_output->{real_webwork_FORM_ACTION_URL}  = '$FORM_ACTION_URL';
$json_output->{internal_problem_lang_and_dir} = '$PROBLEM_LANG_AND_DIR';

# Output back to WebworkClient.pm is the reference to the hash:
$json_output;
