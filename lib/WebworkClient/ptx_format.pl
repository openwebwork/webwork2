$ptx_static_format = <<'ENDPROBLEMTEMPLATE';
<!--$SITE_URL WeBWorK Editor using host: $SITE_URL, course: $courseID format: ptx -->
<!--BEGIN PROBLEM-->
<webwork>
$problemText
$answerhashXML
</webwork>
<!--END PROBLEM-->
ENDPROBLEMTEMPLATE

$ptx_static_format;
