package WeBWorK::ContentGenerator::Problem;
use base qw(WeBWorK::ContentGenerator);

use strict;
use warnings;
use Apache::Constants qw(:common);
use WeBWorK::ContentGenerator;
use WeBWorK::PG;

# "Classic" form fields from processProblem8.pl
# 
# user - user ID
# key - session key
# course - course name
# probSetKey - USUALLY known as the PSVN
# probNum - problem number a.k.a. ID a.k.a. name
# 
# Mode - display mode (HTML, HTML_tth, or typeset or whatever it's called)
# show_old_answers - whether or not student's old answers should be filled in
# ShowAns - asks for correct answer to be shown -- only available for instructors
# answer$i - student answers
# showEdit - checks if the ShowEditor button should be shown and clicked
# showSol - checks if the solution button ishould be shown and clicked
# 
# source - contains modified problem source when called from the web-based problem editor
# seed - contains problem seed when called from the web-based problem editor
# readSourceFromHTMLQ - if true, problem is read from 'source' instead of file
# action - submit button clicked to invoke script (alledgedly)
# 	'Save updated version'
# 	'Read problem from disk'
# 	'Submit Answers'
# 	'Preview Answers'
# 	'Preview Again'
# probFileName - name of the PG file being edited
# languageType - afaik, always set to 'pg'

sub title {
	my ($self, $problem_set, $problem) = @_;
	my $r = $self->{r};
	my $user = $r->param('user');
	return "Problem $problem of problem set $problem_set for $user";
}

sub body {
	my ($self, $problem_set, $problem) = @_;
	
	# we have to call init_translator like this:
	my $pt = WeBWorK::PG->new($courseEnv, $userName, $setName, $problemNumber, $formData);
	
	# 
	
	# ----- this is not a place of honor -----
	
	# Run the problem (output the html text) but also store it within the object.
	# The correct answers are also calculated and stored within the object
	$pt ->translate();
	
	# print problem output
	print "Problem goes here<p>\n";
	print "Problem output <br>\n";
	print "<HR>";
	print ${$pt->r_text()};
	print "<HR>";
	print "<p>End of problem output<br>";
	
	
	# print source code
	print "Source code<pre>\n";
	print $SOURCE1;
	print "</pre>End source code<p>";
	
	# The format for the output is described here.  We'll need a local variable
	# to handle the warnings.  From within the problem the warning command
	# has been slaved to the __WARNINGS__  routine which is defined in Global.
	# We'll need to provide an alternate mechanism.
	# The base64 encoding is only needed for xml transmission.
	print "<hr>";
	print "Warnings output<br>";
	my $WARNINGS = "Let this be a warning:";
	
	print $WARNINGS;
	
	# Install the standard problem grader.  See gage/xmlrpc/daemon.pm or processProblem8 for detailed
	# code on how to choose which problem grader to install, depending on courseEnvironment and problem data.
	# See also PG.pl which provides for problem by problem overrides.
	$pt->rf_problem_grader($pt->rf_std_problem_grader);
	
	# creates and stores a hash of answer results inside the object: $rh_answer_results
	$pt -> process_answers($rh->{envir}->{inputs_ref});
	
	
	# THE UPDATE AND GRADING LOGIC COULD USE AN OVERHAUL.  IT WAS SOMEWHAT CONSTRAINED
	# BY LEGACY CONDITIONS IN THE ORIGINAL PROCESSPROBLEM8.  IT'S NOT BAD
	# BUT IT COULD PROBABLY BE MADE A LITTLE MORE STRAIGHT FORWARD.
	# 
	# updates the problem state stored by the translator object from the problemEnvironment data
	
	# $pt->rh_problem_state({ recorded_score 			=> $rh->{problem_state}->{recorded_score},
	# 						num_of_correct_ans		=> $rh->{problem_state}->{num_of_correct_ans} ,
	# 						num_of_incorrect_ans	=> $rh->{problem_state}->{num_of_incorrect_ans}
	# 					} );
	
	# grade the problem (and update the problem state again.)
	# 
	# Define an entry order -- the default is the order they are received from the browser.
	# (Which as I understand it is NOT guaranteed to be the Left->Right Up-> Down order we're
	# used to in the West.
	
	my %PG_FLAGS = $pt->h_flags;
		my $ra_answer_entry_order = ( defined($PG_FLAGS{ANSWER_ENTRY_ORDER}) ) ?
							  $PG_FLAGS{ANSWER_ENTRY_ORDER} : [ keys %{$pt->rh_evaluated_answers} ] ;
	# Decide whether any answers were submitted.
		my  $answers_submitted = 0;
			$answers_submitted = 1 if defined( $rh->{answer_form_submitted} ) and 1 == $rh->{answer_form_submitted};
	# If there are answers, grade them
		my ($rh_problem_result,$rh_problem_state) = $pt->grade_problem( answers_submitted => $answers_submitted,
																	 ANSWER_ENTRY_ORDER => $ra_answer_entry_order
																   );       # grades the problem.
	  
	# Output format expected by Webwork.pm (and I believe processProblem8, but check.)
	my $out = { 	
					text 						=> ${$pt ->r_text()}, #  encode_base64( ${$pt ->r_text()}  ),
					header_text 				=> $pt->r_header,     # encode_base64( ${ $pt->r_header } ),
					answers 					=> $pt->rh_evaluated_answers,
					errors         				=> $pt-> errors(),
					WARNINGS	   				=> $WARNINGS,          #encode_base64($WARNINGS ),
					problem_result 				=> $rh_problem_result,
					problem_state				=> $rh_problem_state,
					PG_flag						=> \%PG_FLAGS
			   };
	
	# Debugging printout of environment tables
	print "<P>Request item<P>\n\n";
	print "<TABLE border=\"3\">";
	print $self->print_form_data('<tr><td>','</td><td>','</td></tr>');
	print "</table>\n";
	print "path info <br>\n";
	print $r->path_info();
	print "<P>\n\ncourseEnvironment<P>\n\n";
	print pretty_print_rh($courseEnvironment);	 
	print "<P>\n\nproblemEnvironment<P>\n\n";
	print pretty_print_rh($problemEnvir_rh);

	"";
}

sub pretty_print_rh {
    my $r_input = shift;
    my $out = '';
    if ( not ref($r_input) ) {
    	$out = $r_input;    # not a reference
    } elsif (is_hash_ref($r_input)) {
	    local($^W) = 0;
		$out .= "<TABLE border = \"2\" cellpadding = \"3\" BGCOLOR = \"#FFFFFF\">";
		foreach my $key (sort keys %$r_input ) {
			$out .= "<tr><TD> $key</TD><TD>=&gt;</td><td>&nbsp;".pretty_print_rh($r_input->{$key}) . "</td></tr>";
		}
		$out .="</table>";
	} elsif (is_array_ref($r_input) ) {
		my @array = @$r_input;
		$out .= "( " ;
		while (@array) {
			$out .= pretty_print_rh(shift @array) . " , ";
		}
		$out .= " )"; 
	} elsif (ref($r_input) eq 'CODE') {
		$out = "$r_input";
	} else {
		$out = $r_input;
	}
		$out;
}

sub is_hash_ref {
	my $in =shift;
	my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__} = sub {CORE::die(@_) };
	my $out = eval{  %{   $in  }  };
	$out = ($@ eq '') ? 1 : 0;
	$@='';
	$SIG{__DIE__} = $save_SIG_die_trap;
	$out;
}
sub is_array_ref {
	my $in =shift;
	my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__} = sub {CORE::die(@_) };
	my $out = eval{  @{   $in  }  };
	$out = ($@ eq '') ? 1 : 0;
	$@='';
	$SIG{__DIE__} = $save_SIG_die_trap;
	$out;
}

1;

__END__

my $foo =0;

# The warning mechanism.  This needs to be turned into an object of its own
###############
## Error message routines cribbed from CGI
###############

BEGIN {    #error message routines cribbed from CGI

	my $CarpLevel = 0;  # How many extra package levels to skip on carp.
	my $MaxEvalLen = 0; # How much eval '...text...' to show. 0 = all.
	
	sub longmess {
		my $error = shift;
		my $mess = "";
		my $i = 1 + $CarpLevel;
		my ($pack,$file,$line,$sub,$eval,$require);

		while (($pack,$file,$line,$sub,undef,undef,$eval,$require) = caller($i++)) {
			if ($error =~ m/\n$/) {
				$mess .= $error;
			}
			else {
				if (defined $eval) {
					if ($require) {
						$sub = "require $eval";
					}
					else {
						$eval =~ s/[\\\']/\\$&/g;
						if ($MaxEvalLen && length($eval) > $MaxEvalLen) {
							substr($eval,$MaxEvalLen) = '...';
						}
						$sub = "eval '$eval'";
					}
				}
				elsif ($sub eq '(eval)') {
					$sub = 'eval {...}';
				}

				$mess .= "\t$sub " if $error eq "called";
				$mess .= "$error at $file line $line\n";
			}

			$error = "called";
		}

		$mess || $error;
	}
}
###############
### Our error messages for giving maximum feedback to the user for errors within problems.
###############
BEGIN {
	sub PG_floating_point_exception_handler {       # 1st argument is signal name
		my($sig) = @_;
		print "Content-type: text/html\n\n<H4>There was a floating point arithmetic error (exception SIG$sig )</H4>--perhaps
		you divided by zero or took the square root of a negative number?
		<BR>\n Use the back button to return to the previous page and recheck your entries.<BR>\n";
		exit(0);
	}
	
	$SIG{'FPE'}  = \&PG_floating_point_exception_handler;
#!/usr/bin/perl  -w
	sub PG_warnings_handler {
		my @input = @_;
		my $msg_string = longmess(@_);
		my @msg_array = split("\n",$msg_string);
		my $out_string = '';
		
		# Extra stack information is provided in this next block
		# If the warning message does NOT end in \n then a line 
		# number is appended (see Perl manual about warn function)
		# The presence of the line number is detected below and extra
		# stack information is added.
		# To suppress the line number and the extra stack information
		# add \n to the end of a warn message (in .pl files.  In .pg
		# files add ~~n instead
		
		if ($input[$#input]=~/line \d*\.\s*$/) {   
			$out_string .= "##More details: <BR>\n----"; 
			foreach my $line (@msg_array) {
				chomp($line);
				next unless $line =~/\w+\:\:/;
				$out_string .= "----" .$line . "<BR>\n";
			}
		}

		$Global::WARNINGS .="*  " . join("<BR>",@input) . "<BR>\n" . $out_string .
		                    "<BR>\n--------------------------------------<BR>\n<BR>\n";
		$Global::background_plain_url = $Global::background_warn_url;
		$Global::bg_color = '#FF99CC';  #for warnings -- this change may come too late
	}

	$SIG{__WARN__}=\&PG_warnings_handler;
	
	$SIG{__DIE__} = sub {
	    my $message = longmess(@_);
	    $message =~ s/\n/<BR>\n/;
	    my ($package, $filename, $line) = caller();
	    # use standard die for errors eminating from XML::Parser::Expat
	    # it uses a trapped eval which sometimes fails -- apparently on purpose
	    # and the error is handled by Expat itself.  We don't want
	    # to interfer with that.
	    
	    if ($package eq 'XML::Parser::Expat') {
	    	die @_;
	    }
	    #print  "$package $filename $line \n";
		print  
		"Content-type: text/html\r\n\r\n <h4>Software error</h4> <p>\n\n$message\n<p>\n
		Please inform the webwork meister.<p>\n
		In addition to the error message above the following warnings were detected:
		<HR>
		$Global::WARNINGS;
		<HR>
		It's sometimes hard to tell exactly what has gone wrong since the
		full error message may have been sent to
		standard error instead of to standard out.
		<p> To debug  you can
		<ul>
		<li> guess what went wrong and try to fix it.
		<li> call the offending script directly from the command line
		of unix
		<li> enable the debugging features by redefining
		\$cgiURL in Global.pm and checking the redirection scripts in
		system/cgi. This will force the standard error to be placed
		in the standard out pipe as well.
		<li> Run tail -f error_log <br>
		from the unix command line to see error messages from the webserver.
		The standard error output is being placed in the error_log file for the apache
		web server.  To run this command you have to be in the directory containing the
		error_log or enter the full path name of the error_log. <p>
		In a standard apache installation, this file is at /usr/local/apache/logs/error_log<p>
		In a RedHat Linux installation, this file is at /var/log/httpd/error_log<p>
		At Rochester this file is at /ww/logs/error_log.
		</ul>
		Good luck.<p>\n" ;
	};



}
