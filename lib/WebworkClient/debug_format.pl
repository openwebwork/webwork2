$debug_format = 
q{

	<html>
	<head>
	<base href="$XML_URL">
	<title>$XML_URL WeBWorK Editor using host: $XML_URL, course: $courseID format: debug</title>
	</head>
	<body>
			
	<h2> WeBWorK Editor using host: $XML_URL,  course: $courseID format: debug</h2>
$pretty_print_self	   
</body>
</html>
};

$debug_format;