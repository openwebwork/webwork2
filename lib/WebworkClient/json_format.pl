# The json output format needs to collect the data differently than
# the other formats. It will return an array which alternates between
# key-names and values, and each relevant value will later undergo
# variable interpolation.

# Most parts which need variable interpolation end in "_VI".
# Other parts which need variable interpolation are:
#	hidden_input_field_*
#	real_webwork_*

@pairs_for_json = (
  "head_part001_VI", "<!DOCTYPE html>\n" . '<html $COURSE_LANG_AND_DIR>' . "\n"
);

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<head>
<meta charset='utf-8'>
<base href="TO_SET_LATER_SITE_URL">
<link rel="shortcut icon" href="/webwork2_files/images/favicon.ico"/>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "head_part010", $nextBlock );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<!-- CSS Loads -->
<link rel="stylesheet" type="text/css" href="/webwork2_files/js/vendor/bootstrap/css/bootstrap.css"/>
<link rel="stylesheet" type="text/css" href="/webwork2_files/js/vendor/bootstrap/css/bootstrap-responsive.css"/>
<link rel="stylesheet" type="text/css" href="/webwork2_files/css/jquery-ui-1.8.18.custom.css"/>
<link rel="stylesheet" type="text/css" href="/webwork2_files/css/vendor/font-awesome/css/font-awesome.min.css"/>
<link rel="stylesheet" type="text/css" href="/webwork2_files/themes/math4/math4.css"/>
<link rel="stylesheet" type="text/css" href="/webwork2_files/css/knowlstyle.css"/>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "head_part100", $nextBlock );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<!-- JS Loads -->
<script type="text/javascript" src="/webwork2_files/js/vendor/jquery/jquery.js"></script>
<script type="text/javascript" src="/webwork2_files/mathjax/MathJax.js?config=TeX-MML-AM_HTMLorMML-full"></script>
<script type="text/javascript" src="/webwork2_files/js/jquery-ui-1.9.0.js"></script>
<script type="text/javascript" src="/webwork2_files/js/vendor/bootstrap/js/bootstrap.js"></script>
<script type="text/javascript" src="/webwork2_files/js/apps/AddOnLoad/addOnLoadEvent.js"></script>
<script type="text/javascript" src="/webwork2_files/js/legacy/java_init.js"></script>
<script type="text/javascript" src="/webwork2_files/js/apps/InputColor/color.js"></script>
<script type="text/javascript" src="/webwork2_files/js/apps/Base64/Base64.js"></script>
<script type="text/javascript" src="/webwork2_files/js/vendor/underscore/underscore.js"></script>
<script type="text/javascript" src="/webwork2_files/js/legacy/vendor/knowl.js"></script>
<script type="text/javascript" src="/webwork2_files/js/apps/Problem/problem.js"></script>
<script type="text/javascript" src="/webwork2_files/themes/math4/math4.js"></script>
<script type="text/javascript" src="/webwork2_files/js/vendor/iframe-resizer/js/iframeResizer.contentWindow.min.js"></script>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "head_part200", $nextBlock );

push( @pairs_for_json, "head_part300_VI", '$problemHeadText' . "\n" );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<title>WeBWorK problem</title>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "head_part400", $nextBlock );

push( @pairs_for_json, "head_part999", "</head>\n" );

push( @pairs_for_json, "body_part001", "<body>\n" );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<div class="container-fluid">
<div class="row-fluid">
<div class="span12 problem">
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part100", $nextBlock );

push( @pairs_for_json, "body_part300_VI", '$answerTemplate' . "\n" );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<form id="problemMainForm" class="problem-main-form" name="problemMainForm" action="TO_SET_LATER_FORM_ACTION_URL" method="post">
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part500", $nextBlock );


$nextBlock = <<'ENDPROBLEMTEMPLATE';
<div id="problem_body" class="problem-content" $PROBLEM_LANG_AND_DIR>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part530_VI", $nextBlock );

push( @pairs_for_json, "body_part550_VI", '$problemText' . "\n" );

push( @pairs_for_json, "body_part590", "</div>\n" );

push( @pairs_for_json, "body_part650_VI", '$scoreSummary' . "\n" );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<p>
<input type="submit" name="preview"  value="$STRING_Preview" />
<input type="submit" name="WWsubmit" value="$STRING_Submit"/>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part710_VI", $nextBlock );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
<input type="submit" name="WWcorrectAns" value="$STRING_ShowCorrect"/>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part780_optional_VI", $nextBlock );

push( @pairs_for_json, "body_part790", "</p>\n" );

$nextBlock = <<'ENDPROBLEMTEMPLATE';
</form>
</div>
</div>
</div>
<div id="footer" lang="en" dir="ltr">
WeBWorK &copy; 1996-2019
</div>
</body>
</html>
ENDPROBLEMTEMPLATE

push( @pairs_for_json, "body_part999", $nextBlock );

push( @pairs_for_json, "hidden_input_field_answersSubmitted", '1' );
push( @pairs_for_json, "hidden_input_field_sourceFilePath", '$sourceFilePath' );
push( @pairs_for_json, "hidden_input_field_problemSource", '$encoded_source' );
push( @pairs_for_json, "hidden_input_field_problemSeed", '$problemSeed' );
push( @pairs_for_json, "hidden_input_field_problemUUID", '$problemUUID' );
push( @pairs_for_json, "hidden_input_field_psvn", '$psvn' );
push( @pairs_for_json, "hidden_input_field_pathToProblemFile", '$fileName' );
push( @pairs_for_json, "hidden_input_field_courseName", '$courseID' );
push( @pairs_for_json, "hidden_input_field_courseID", '$courseID' );
push( @pairs_for_json, "hidden_input_field_userID", '$userID' );
push( @pairs_for_json, "hidden_input_field_course_password", '$course_password' );
push( @pairs_for_json, "hidden_input_field_displayMode", '$displayMode' );
push( @pairs_for_json, "hidden_input_field_session_key", '$session_key' );
push( @pairs_for_json, "hidden_input_field_outputformat", 'json' );
push( @pairs_for_json, "hidden_input_field_language", '$formLanguage' );
push( @pairs_for_json, "hidden_input_field_showSummary", '$showSummary' );
push( @pairs_for_json, "hidden_input_field_forcePortNumber", '$forcePortNumber' );

# These are the real WeBWorK server URLs which the intermediate needs to use
# to communicate with WW, while the distant client must use URLs of the
# intermediate server (the man in the middle).

push( @pairs_for_json, "real_webwork_SITE_URL", '$SITE_URL' );
push( @pairs_for_json, "real_webwork_FORM_ACTION_URL", '$FORM_ACTION_URL' );
push( @pairs_for_json, "internal_problem_lang_and_dir", '$PROBLEM_LANG_AND_DIR');

# Output back to WebworkClient.pm is the reference to the array:
\@pairs_for_json;
