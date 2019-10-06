$debug_format = 
q{

	<html $COURSE_LANG_AND_DIR>
	<head>
	<meta charset='utf-8'>
	<base href="$SITE_URL">
	<title>$SITE_URL WeBWorK using host: $SITE_URL, course: $courseID format: debug</title>
	</head>
	<body>
			
	<h2> WeBWorK using host: $SITE_URL,  course: $courseID format: debug</h2>
$pretty_print_self	   
</body>
</html>
};

$debug_format;
