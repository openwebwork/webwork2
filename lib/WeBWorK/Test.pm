package WeBWorK::Test;

# print() the page requested.
# args: form data, course-env
sub gen_page() {
	print<<EOT;
Content-type: text/html

<html>
<head><title>Welcome to Hell.</title></head>
<body>
<h1>There you go.</h1>
</body>
</html>
EOT
}

1;
