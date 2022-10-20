$simple_format = <<'ENDPROBLEMTEMPLATE';
<!DOCTYPE html>
<html $COURSE_LANG_AND_DIR>
<head>
<meta charset='utf-8'>
<base href="$SITE_URL">
$favicon

$problemHeadText

<title>WeBWorK using host: $SITE_URL, format: simple seed: $problemSeed</title>
</head>
<body>
<div class="container-fluid">
<div class="row g-0">
<div class="col-12 problem">
$answerTemplate
$color_input_blanks_script
<form id="problemMainForm" class="problem-main-form" name="problemMainForm" action="$FORM_ACTION_URL" method="post">
<div id="problem_body" class="problem-content" $PROBLEM_LANG_AND_DIR>
$problemText
</div>
$scoreSummary
$LTIGradeMessage

<input type="hidden" name="answersSubmitted" value="1">
<input type="hidden" name="sourceFilePath" value = "$sourceFilePath">
<input type="hidden" name="problemSource" value="$encoded_source">
<input type="hidden" name="problemSeed" value="$problemSeed">
<input type="hidden" name="problemUUID" value="$problemUUID">
<input type="hidden" name="psvn" value="$psvn">
<input type="hidden" name="pathToProblemFile" value="$fileName">
<input type="hidden" name="courseID" value="$courseID">
<input type="hidden" name="user" value="$user">
<input type="hidden" name="passwd" value="$passwd">
<input type="hidden" name="displayMode" value="$displayMode">
<input type="hidden" name="key" value="$key">
<input type="hidden" name="outputformat" value="simple">
<input type="hidden" name="theme" value="$theme">
<input type="hidden" name="language" value="$formLanguage">
<input type="hidden" name="showSummary" value="$showSummary">
<input type="hidden" name="showHints" value="$showHints">
<input type="hidden" name="showSolutions" value="$showSolutions">
<input type="hidden" name="showAnswerNumbers" value="$showAnswerNumbers">
<input type="hidden" name="showPreviewButton" value="$showPreviewButton">
<input type="hidden" name="showCheckAnswersButton" value="$showCheckAnswersButton">
<input type="hidden" name="showCorrectAnswersButton" value="$showCorrectAnswersButton">
<input type="hidden" name="showFooter" value="$showFooter">
<input type="hidden" name="extra_header_text" value="$extra_header_text">
<div class="submit-buttons-container col-12 mb-2"><!--
-->$previewButton<!-- -->$checkAnswersButton<!-- -->$correctAnswersButton</div>
</form>
</div>
</div></div>
$footer
</body>
</html>
ENDPROBLEMTEMPLATE

$simple_format;
