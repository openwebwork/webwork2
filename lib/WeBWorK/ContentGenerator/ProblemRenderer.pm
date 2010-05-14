################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/ProblemRenderer.pm,v 1.1 2008/04/29 19:27:34 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator::ProblemRenderer;
use base qw(WeBWorK::ContentGenerator);
use MIME::Base64 qw( encode_base64 decode_base64);

=head1 NAME

WeBWorK::ContentGenerator::ProblemRenderer - render a problem with a minimal
amount of UI garbage.

=cut

use strict;
use warnings;
use WeBWorK::CGI;
use WeBWorK::Utils qw(pretty_print_rh);
use WeBWorK::Utils::Tasks qw(renderProblems);

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
    my $db = new WeBWorK::DB($r->ce->{dbLayout});
    $r->db($db);

	my $pg = $r->param('pg');
	$pg = decode_base64($r->param('problemSource'));
	my $file = $r->param('file');
	my $seed = $r->param('seed');
	$seed = $r->param('problemSeed');
	my $mode = $r->param('mode');
	my $hint = $r->param('hint');
	my $sol = $r->param('sol');
	# pretty_print_rh($r);
    # pretty_print_rh($r->{paramcache});
    warn "answers", @{ $r->{paramcache}->{AnSwEr0001}},"answersSubmitted",@{ $r->{paramcache}->{answersSubmitted}};
	warn  "problemSource"  ,  @{ $r->{paramcache}->{problemSource} };
	warn  "request object", ${$r->{r}};
	#die "view warning";
	die "must specify either a PG problems (param 'pg') or a path to a PG file (param 'file') and not both"
		unless defined $pg and length $pg xor defined $file and length $file;
	
	#my $problem = $self->get_problem($pg, $file);
	my @options = (r=>$r, problem_list=>[\$pg]);
	
	#push @options, (problem_seed=>$seed) if defined $seed;
	#push @options, (displayMode=>$mode) if defined $mode;
	#push @options, (showHints=>$hint) if defined $hint;
	#push @options, (showSolutions=>$sol) if defined $sol;
	
	($self->{result}) = renderProblems(@options);
}

# sub get_problem {
# 	my ($self, $pg, $file) = @_;
# 	
# 	if (defined $pg) {
# 		return \$pg;
# 	} else {
# 		return $file;
# 	}
# }

use Data::Dumper;
sub content {
	my ($self) = @_;
	my $result = $self->{result};
	my $dump = Dumper($result);
	
	print <<EOF;
<html>
<head>
<title>Yuck!</title>
</head>
<body>
<pre>$dump</pre>
</body>
</html>
EOF
}

# ideas from renderProblem.pl  

# new version of output:
# my $out2   = {
# 	text 						=> encode_base64( $pg->{body_text}  ),
# 	header_text 				=> encode_base64( $pg->{head_text} ),
# 	answers 					=> $pg->{answers},
# 	errors         				=> $pg->{errors},
# 	WARNINGS	   				=> encode_base64($pg->{warnings} ),
# 	problem_result 				=> $pg->{result},
# 	problem_state				=> $pg->{state},
# 	#PG_flag						=> $pg->{flags},
# 	
# 
# 
# };
sub formatAnswerRow {
	my $rh_answer = shift;
	my $problemNumber = shift;
	my $answerString  = $rh_answer->{original_student_ans}||'&nbsp;';
	my $correctAnswer = $rh_answer->{correct_ans}||'';
	my $score         = ($rh_answer->{score}) ? 'Correct' : 'Incorrect';
	my $row = qq{
		<tr>
		    <td>
				$problemNumber
			</td>
			<td>
				$answerString
			</td>
			<td>
			    $score
			</td>
			<td>
				Correct answer is $correctAnswer
			</td>
			<td>
				<i></i>
			</td>
		</tr>\n
	};
	$row;
}
	
# sub formatRenderedProblem {
# 	my $rh_result         = shift;  # wrap problem in formats
# 	my $problemText       = decode_base64($rh_result->{text});
# 	my $rh_answers        = $rh_result->{answers};
# 	
# 	my $warnings          = '';
# 	if ( defined ($rh_result->{WARNINGS}) and $rh_result->{WARNINGS} ){
# 		$warnings = "<div style=\"background-color:pink\">
# 		             <p >WARNINGS</p><p>".decode_base64($rh_result->{WARNINGS})."</p></div>";
# 	}
# 	
# 	         ;
# 	# collect answers
# 	my $answerTemplate    = q{<hr>ANSWERS <table border="3" align="center">};
# 	my $problemNumber     = 1;
#     foreach my $key (sort  keys %{$rh_answers}) {
#     	$answerTemplate  .= formatAnswerRow($rh_answers->{$key}, $problemNumber++);
#     }
# 	$answerTemplate      .= q{</table> <hr>};
# 
# 	
# 
# 	my $problemTemplate = <<ENDPROBLEMTEMPLATE;
# 		
# 		    $answerTemplate
# 		    $warnings
# 		    <form action="http://webhost.math.rochester.edu/webworkdocs/ww/render" method="post">
# 			$problemText
# 	       <input type="hidden" name="answersSubmitted" value="1"> 
# 	       <input type="hidden" name="problemAddress" value="probSource"> 
# 	       <input type="hidden" name="problemSource" value="$encodedSource"> 
# 	       <input type="hidden" name="problemSeed" value="1234"> 
# 	       <input type="hidden" name="pathToProblemFile" value="foobar">
# 	       <p><input type="submit" name="submit" value="submit answers"></p>
# 	     </form>
# 
# 
# ENDPROBLEMTEMPLATE
# 
# 
# 
# 	$problemTemplate;
# }

1;
