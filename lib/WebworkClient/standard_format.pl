$standard_format = <<'ENDPROBLEMTEMPLATE';
<html>
<head>
<base href="$XML_URL">
<link rel="shortcut icon" href="/webwork2_files/images/favicon.ico"/>
<!-- CSS Loads -->
<link rel="stylesheet" type="text/css" href="/webwork2_files/js/vendor/bootstrap/css/bootstrap.css"/>
<link href="$XML_URL/webwork2_files/js/vendor/bootstrap/css/bootstrap-responsive.css" rel="stylesheet" />
<link rel="stylesheet" type="text/css" href="$XML_URL/webwork2_files/css/jquery-ui-1.8.18.custom.css"/>
<link rel="stylesheet" type="text/css" href="$XML_URL/webwork2_files/css/vendor/font-awesome/css/font-awesome.min.css"/>
<link rel="stylesheet" type="text/css" href="$XML_URL/webwork2_files/themes/math4/math4.css"/>
<link href="$XML_URL/webwork2_files/css/knowlstyle.css" rel="stylesheet" type="text/css" />

<!-- JS Loads -->
<script type="text/javascript" src="/webwork2_files/js/vendor/jquery/jquery.js"></script>
<script type="text/javascript" src="/webwork2_files/mathjax/MathJax.js?config=TeX-MML-AM_HTMLorMML-full"></script>
<script type="text/javascript" src="/webwork2_files/js/jquery-ui-1.9.0.js"></script>
<script type="text/javascript" src="/webwork2_files/js/vendor/bootstrap/js/bootstrap.js"></script>
<script src="/webwork2_files/js/apps/AddOnLoad/addOnLoadEvent.js" type="text/javascript"></script>
<script src="/webwork2_files/js/legacy/java_init.js" type="tesxt/javascript"></script>
<script src="/webwork2_files/js/apps/InputColor/color.js" type="text/javascript"></script>
<script src="/webwork2_files/js/apps/Base64/Base64.js" type="text/javascript"></script>
<script src="/webwork2_files/mathjax/MathJax.js?config=TeX-MML-AM_HTMLorMML-full" type="text/javascript"></script>
<script type="textx/javascript" src="/webwork2_files/js/vendor/underscore/underscore.js"></script>
<script type="text/javascript" src="/webwork2_files/js/legacy/vendor/knowl.js"></script>
<script src="/webwork2_files/js/apps/Problem/problem.js" type="text/javascript"></script>
<script type="text/javascript" src="/webwork2_files/themes/math4/math4.js"></script>	
<script type="text/javascript" src="/webwork2_files/js/vendor/iframe-resizer/js/iframeResizer.contentWindow.min.js"></script>
$problemHeadText


<title>$XML_URL WeBWorK Editor using host: $XML_URL, course: $courseID format: standard</title>
</head>
<body>

<h2> WeBWorK Editor using host: $XML_URL, course: $courseID format: standard</h2>
		    $answerTemplate
		    $color_input_blanks_script
		    <form action="$FORM_ACTION_URL" method="post">
<div class="problem-content">
			$problemText
</div>
$scoreSummary
$LTIGradeMessage

	       <input type="hidden" name="answersSubmitted" value="1"> 
		   <input type="hidden" name="sourceFilePath" value = "$sourceFilePath">
	       <input type="hidden" name="problemSource" value="$encoded_source"> 
	       <input type="hidden" name="problemSeed" value="$problemSeed"> 
	       <input type="hidden" name="pathToProblemFile" value="$fileName">
	       <input type="hidden" name=courseName value="$courseID">
	       <input type="hidden" name=courseID value="$courseID">
	       <input type="hidden" name="userID" value="$userID">
	       <input type="hidden" name="course_password" value="$course_password">
	       <input type="hidden" name="displayMode" value="$displayMode">
	       <input type="hidden" name="session_key" value="$session_key">
	       <input type="hidden" name="outputformat" value="standard">
	       <input type="hidden" name="language" value="$formLanguage">
	       <input type="hidden" name="showSummary" value="$showSummary">
	
		   <p>
		      <input type="submit" name="preview"  value="Preview" /> 
			  <input type="submit" name="WWsubmit" value="Submit answer"/> 
		      <input type="submit" name="WWcorrectAns" value="Show correct answer"/>
		   </p>
	     </form>
<HR>

<h3> Perl warning section </h3>
$warnings
<h3> PG Warning section </h3>
$PG_warning_messages;
<h3> Debug message section </h3>
$debug_messages
<h3> internal errors </h3>
$internal_debug_messages
<div id="footer">
WeBWorK &copy 1996-2016 | host: $XML_URL | course: $courseID | format: standard | theme: math4
</div>

</body>
</html>

ENDPROBLEMTEMPLATE

$standard_format;
