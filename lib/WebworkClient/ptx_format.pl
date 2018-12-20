$ptx_static_format = <<'ENDPROBLEMTEMPLATE';
<!--$XML_URL WeBWorK Editor using host: $XML_URL, course: $courseID format: ptx -->
<!--BEGIN PROBLEM-->
<webwork>
$problemText
$answerhashXML
</webwork>
<!--END PROBLEM-->
ENDPROBLEMTEMPLATE

$ptx_static_format;
