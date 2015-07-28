#!/Volumes/WW_test/opt/local/bin/perl -w
use 5.012;

# Test AttemptsTable.pm
BEGIN {
	require "../../standaloneProblemRenderer/grab_course_environment.pl";
	eval "use lib '$WebworkBase::RootPGDir/lib'"; die $@ if $@;
	eval "use lib '$WebworkBase::RootWebwork2Dir/lib'"; die $@ if $@;
}
use WeBWorK::Utils::AttemptsTable;
use WeBWorK::PG::ImageGenerator;
use HTML::Entities;
my $answers = {
	AnSwEr0001	=>	{
		_filter_name	=>	 "dereference_array_ans",
		ans_label	=>	 "AnSwEr0001",
		ans_message	=>	"", 
		ans_name	=>	 "AnSwEr0001",
		correct_ans	=>	 "8 * e^(2 * (x - 4))",
		correct_ans_latex_string	=>	 "8e^{2\\!\\left(x-4\\right)}",		
		correct_value	=>	 "(8*e^[2*(x-4)])",
		debug	=>	 0,
		diagnostics	=>	"", 
		done	=>	 1,
		error_flag	=>	 "",
		error_message	=>	 "",
		ignoreInfinity	=>	 1,
		ignoreStrings	=>	 1,
		original_student_ans	=> "8 * e^(2 * (x - 4))",	 
		preview_latex_string	=> "8e^{2\\!\\left(x-4\\right)}",	 
		preview_text_string	=>	 "8 * e^(2 * (x - 4))",
		score	=>	 0,
		showDomainErrors	=>	 1,
		showEqualErrors	=>	 1,
		showTypeWarnings	=>	 1,
		showUnionReduceWarnings	=>	 1,
		student_ans	=>	 "",
		studentsMustReduceUnions	=>	 1,
		type	=>	 "essay", #"Value (Formula)",
		upToConstant	=>	 0,
	},
	AnSwEr0002	=>	 {
		_filter_name	=>	 "dereference_array_ans",
		ans_label	=>	 "AnSwEr0002",
		ans_message	=>	 "",
		ans_name	=>	 "AnSwEr0002",
		correct_ans	=>	 16,
		correct_ans_latex_string	=>	 16,
		correct_value	=>	 16,
		debug	=>	 0,
		done	=>	 1,
		error_flag	=>"",	 
		error_message	=>"",	 
		ignoreInfinity	=>	 1,
		ignoreStrings	=>	 1,
		original_student_ans	=>"16",	 
		preview_latex_string	=>	 "16",
		preview_text_string	=>	 "16",
		score	=>	 1,
		showEqualErrors	=>	 1,
		showTypeWarnings	=>	 1,
		showUnionReduceWarnings	=>	 1,
		student_ans	=>	 "",
		studentsMustReduceUnions	=>	 1,
		type	=>	 "Value (Real)",
	},
	AnSwEr0003	=>	 {
		_filter_name	=>	 "dereference_array_ans",
		ans_label	=>	 "AnSwEr0003",
		ans_message	=>	 "",
		ans_name	=>	 "AnSwEr0003",
		correct_ans	=>	 "-0.0625",
		correct_ans_latex_string	=>	 "-0.0625",
		correct_value	=>	 "-0.0625",
		debug	=>	 0,
		done	=>	 1,
		error_flag	=> "",	 
		error_message	=> "",	 
		ignoreInfinity	=>	 1,
		ignoreStrings	=>	 1,
		original_student_ans	=> "-0.0625", 
		preview_latex_string	=> "-0.0625",	 
		preview_text_string	    => "-0.0625",	 
		score	=>	 1,
		showEqualErrors	=>	 1,
		showTypeWarnings	=>	 1,
		showUnionReduceWarnings	=>	 1,
		student_ans	=>	 "",
		studentsMustReduceUnions	=>	 1,
		type	=>	 "Value (Real)",
	},
	AnSwEr0004	=>	 {
		_filter_name	=>	 "dereference_array_ans",
		ans_label	=>	 "AnSwEr0004",
		ans_message	=>	 "answer message",
		ans_name	=>	 "AnSwEr0004",
		correct_ans	=>	 "2 * y",
		correct_ans_latex_string	=>	 "2y",
		correct_value	=>	 "(2*y)",
		debug	=>	 0,
		diagnostics	=> "",	 
		done	=>	 1,
		error_flag	=> "",	 
		error_message	=>	"", 
		ignoreInfinity	=>	 1,
		ignoreStrings	=>	 1,
		original_student_ans	=> "2y",	 
		preview_latex_string	=> "2y",
		preview_text_string	=>	 "2y",
		score	=>	 0,
		showDomainErrors	=>	 1,
		showEqualErrors	=>	 1,
		showTypeWarnings	=>	 1,
		showUnionReduceWarnings	=>	 1,
		student_ans	=>	 "",
		studentsMustReduceUnions	=>	 1,
		type	=>	 "Value (Formula)",
		upToConstant	=>	 0,
	},
	AnSwEr0005	=>	 {
		_filter_name	=>	 "dereference_array_ans",
		ans_label	=>	 "AnSwEr0005",
		ans_message	=>	 "answer message",
		ans_name	=>	 "AnSwEr0005",
		correct_ans	=>	 "4 + (2 /2)*((8 *8 ) - y*y)",
		correct_ans_latex_string	=>	 "4+1\\!\\left(64-yy\\right)",
		correct_value	=>	 "(4+1*(64-y*y))",
		debug	=>	 0,
		diagnostics	=>"",	 
		done	=>	 1,
		error_flag	=>"",	 
		error_message	=> "error message",	 
		ignoreInfinity	=>	 1,
		ignoreStrings	=>	 1,
		original_student_ans	=> "4 + (2 /2)*((8 *8 ) - y*y)",	 
		preview_latex_string	=> "4+1\\!\\left(64-yy\\right)",	 
		preview_text_string	=>	 "",
		score	=>	 0,
		showDomainErrors	=>	 1,
		showEqualErrors	=>	 1,
		showTypeWarnings	=>	 1,
		showUnionReduceWarnings	=>	 1,
		student_ans	=>	 "",
		studentsMustReduceUnions	=>	 1,
		type	=>	 "Value (Formula)",
		upToConstant	=>	 0,
	}
};
my $ce = $WebworkBase::ce;
my $answerOrder = [sort keys %{ $answers }];
my $site_url = "http://localhost";
my $moodle_prefix = "%%";
######################################################
	my %imagesModeOptions = %{$ce->{pg}->{displayModeOptions}->{images}};
	
	my $imgGen = WeBWorK::PG::ImageGenerator->new(
		tempDir         => $ce->{webworkDirs}->{tmp},
		latex	        => $ce->{externalPrograms}->{latex},
		dvipng          => $ce->{externalPrograms}->{dvipng},
		useCache        => 1,
		cacheDir        => $ce->{webworkDirs}->{equationCache},
		cacheURL        => $site_url . $ce->{webworkURLs}->{equationCache},
		cacheDB         => $ce->{webworkFiles}->{equationCacheDB},
		dvipng_align    => $imagesModeOptions{dvipng_align},
		dvipng_depth_db => $imagesModeOptions{dvipng_depth_db},
	);
	



######################################################
#print "add strings to table\n";

my $tbl = WeBWorK::Utils::AttemptsTable->new(
	$answers,
	answersSubmitted       => 1,
	answerOrder            => $answerOrder,
	displayMode            => 'images',
	imgGen                 => $imgGen,	
	showAttemptPreviews    => 1,
	showAttemptResults     => 1,
	showCorrectAnswers     => 1,
	showMessages           => 1,
);
print "answers ", $tbl->answers,"\n";
print "answersSubmitted ", $tbl->answersSubmitted,"\n";
print "displayMode ", $tbl->displayMode,"\n";
print "imgGen ", $tbl->imgGen,"\n";
print "answerOrder ", $tbl->answerOrder,"\n";
print "correct_ids ", $tbl->correct_ids//'',"\n";
print "incorrect_ids ", $tbl->incorrect_ids//'',"\n";

print "showAttemptPreviews ", $tbl->showAttemptPreviews,"\n";
print "showAttemptResults ", $tbl->showAttemptResults,"\n";
print "showCorrectAnswers ", $tbl->showCorrectAnswers,"\n";
print "showMessages ", $tbl->showMessages,"\n";
print "\n\n\n";
# 
# 
# print "processed strings ", join(" ", @{$tbl->imgGen->{strings}}), "\n\n";
# print "next is render\n";


	
# say "tbl is of type ", ref($tbl);
# say $tbl;
# say "displayMode ", $tbl->displayMode;
# say "answers ", $tbl->answers;
# say "answersSubmitted = ", $tbl->answersSubmitted;

my $answerTemplate = $tbl->answerTemplate;
my $color_input_blanks_script = $tbl->color_answer_blanks;

# print "processed strings ", join(" ", @{$tbl->imgGen->{strings}}), "\n\n";
# print "next is render\n";


# render equation images
$tbl->imgGen->render(refresh => 1) if $tbl->displayMode eq 'images';

# say "imgGen cacheURL", $imgGen->{cacheURL};
# say "imgGen cacheDir", $imgGen->{cacheDir};
# say "imgGen cacheDB", $imgGen->{cacheDB};
# say "ce     cacheDB", $ce->{webworkFiles}->{equationCacheDB};
# say "imgGen tempDir", $imgGen->{tempDir};

print <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8" />
	<title>attempts table</title>
	<script src="https://hosted2.webwork.rochester.edu/webwork2_files/js/apps/InputColor/color.js" type="text/javascript"></script>
	<link rel="stylesheet" type="text/css" href="https://hosted2.webwork.rochester.edu/webwork2_files/themes/math4/math4.css"/>
	<script type="text/javascript" src="https://hosted2.webwork.rochester.edu/webwork2_files/mathjax/MathJax.js?config=TeX-MML-AM_HTMLorMML-full"></script>
	<script src="https://hosted2.webwork.rochester.edu/webwork2_files/js/apps/AddOnLoad/addOnLoadEvent.js" type="text/javascript"></script>
	$color_input_blanks_script
	<meta name="generator" content="BBEdit 11.1" />
</head>
<body>
$answerTemplate
<p>
<input type="text" name="AnSwEr0002" id = "AnSwEr0002" size=40 value="16 right answer"><br/>
<input type="text" name="AnSwEr0004" id = "AnSwEr0004" size=40 value="wrong answer">
</p>
</body>
</html>
EOF

