package WeBWorK::ContentGenerator::Problem;
our @ISA = qw(WeBWorK::ContentGenerator);
use lib '/Users/gage/webwork/xmlrpc/daemon';
use lib '/Users/gage/webwork-modperl/lib';
use PGtranslator5;
use WeBWorK::ContentGenerator;
use Apache::Constants qw(:common);

sub title {
	my ($self, $problem_set, $problem) = @_;
	my $r = $self->{r};
	my $user = $r->param('user');
	return "Problem $problem of problem set $problem_set for $user";
}

sub body {
	my ($self, $problem_set, $problem) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');
	
	print "Problem goes here<p>\n";
	
	print "<P>Request item<P>\n\n";
	print "<TABLE border=\"3\">";
	print $self->print_form_data('<tr><td>','</td><td>','</td></tr>');
	print "</table>\n";
	print "<P>\n\ncourseEnvironment<P>\n\n";
	print pretty_print_rh($courseEnvironment);
	
	###########################################################################
	#  The pg problem class should have a method for installing it's problemEnvironment
	###########################################################################
	
	$problemEnvir_rh = defineProblemEnvir($self);
	
	print "<P>\n\nproblemEnvironment<P>\n\n";
	print pretty_print_rh($problemEnvir_rh);
#	my $sig = do "pgGenerator.pl" ;
#	 print "File not found $1" unless defined(sig);
#	 print "Errors $@";
#	print pgHTML(); 
	 
	"";
}


########################################################################################
# This is the structure that needs to be filled out in order to call PGtranslator;
########################################################################################

sub defineProblemEnvir {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
    my %envir=();
#    $envir{'refSubmittedAnswers'}  =   $refSubmittedAnswers if defined($refSubmittedAnswers);
     $envir{'psvnNumber'}	   		=   123456789;
  	$envir{'psvn'}		   			=	123456789;
 	 $envir{'studentName'}	   		=   'Jane Doe';
	$envir{'studentLogin'}	    	=	'jd001m';
	$envir{'studentID'}	    		=	'xxx-xx-4321';
	$envir{'sectionName'}	    	=	'gage';
	$envir{'sectionNumber'}	    	=	'111foobar';
	$envir{'recitationName'}	    =	'gage_recitation';
	$envir{'recitationNumber'}	    =	'11_foobar recitation';
	$envir{'setNumber'}	    		=	'setAlgebraicGeometry';
	$envir{'questionNumber'}      	=	43;
	$envir{'probNum'} 	    		=	43;
	$envir{'openDate'}	    		=	3014438528;
	$envir{'formattedOpenDate'}    	=	'3/4/02';
	$envir{'dueDate'} 	    		=	4014438528;
	$envir{'formattedDueDate'}     	=	'10/4/04';
	$envir{'answerDate'}	    	=	4014438528;
	$envir{'formattedAnswerDate'}  	=	'10/4/04';
	$envir{'problemValue'}	    	=	1;
	$envir{'fileName'}	    		=	'problem1';
	$envir{'probFileName'}	    	=	'problem1';
	$envir{'languageMode'}	    	=	'HTML_tth';
	$envir{'displayMode'}	    	=	'HTML_tth';
	$envir{'outputMode'}	    	=	'HTML_tth';
 	$envir{'courseName'}	    	=	$courseEnvironment ->{courseName};
	$envir{'sessionKey'}	    	=	'asdf';

#	initialize constants for PGanswermacros.pl
	$envir{'numRelPercentTolDefault'} 	=     .1;
	$envir{'numZeroLevelDefault'}		=     1E-14;
	$envir{'numZeroLevelTolDefault'} 	=     1E-12;
	$envir{'numAbsTolDefault'} 			=     .001;
	$envir{'numFormatDefault'}			=     '';
	$envir{'functRelPercentTolDefault'} =     .1;
	$envir{'functZeroLevelDefault'} 	=     1E-14;
	$envir{'functZeroLevelTolDefault'} 	=     1E-12;
	$envir{'functAbsTolDefault'} 		=     .001;
	$envir{'functNumOfPoints'} 			=     3;
	$envir{'functVarDefault'} 			=     'x';
	$envir{'functLLimitDefault'} 		=     .0000001;
	$envir{'functULimitDefault'} 		=     .9999999;
	$envir{'functMaxConstantOfIntegration'} = 1E8;
#	kludge check definition of number of attempts again. The +1 is because this is used before the current answer is evaluated.
	$envir{'numOfAttempts'}             =    2; #&getProblemNumOfCorrectAns($probNum,$psvn)
	                                            # &getProblemNumOfIncorrectAns($probNum,$psvn)+1;

# 
# 
# 	defining directorys and URLs
 	$envir{'templateDirectory'}   		=	$courseEnvironment ->{courseDirs}->{templates};
############	$envir{'classDirectory'}   			=	$Global::classDirectory;
#	$envir{'cgiDirectory'}   			=	$Global::cgiDirectory;
#	$envir{'cgiURL'}                    =   getWebworkCgiURL();
#	$envir{'macroDirectory'}   			=	getCourseMacroDirectory();
#	$envir{'courseScriptsDirectory'}   	=	getCourseScriptsDirectory();
	$envir{'htmlDirectory'}             =   $courseEnvironment ->{courseDirectory}->{html};
#	$envir{'htmlURL'}   				=	getCourseHtmlURL();
#	$envir{'tempDirectory'}             =   getCourseTempDirectory();
#	$envir{'tempURL'}                   =   getCourseTempURL();
# 	$envir{'scriptDirectory'}   		=	$Global::scriptDirectory;##omit
	$envir{'webworkDocsURL'}   			=	'http://webwork.math.rochester.edu';
	$envir{'externalTTHPath'}   		=	'/usr/local/bin/tth';
	

# 
	$envir{'inputs_ref'}                =   $r->param;
 	$envir{'problemSeed'}	   			=   3245;
 	$envir{'displaySolutionsQ'}			= 	1;
 	$envir{'displayHintsQ'}				= 	1;

	# here is a way to pass environment variables defined in webworkCourse.ph
#	my $k;
#	foreach $k (keys %Global::PG_environment ) {
#		$envir{$k} = $Global::PG_environment{$k};
#	}
	\%envir;
}

########################################################################################
# This recursive pretty_print function will print a hash and its sub hashes.
########################################################################################
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
