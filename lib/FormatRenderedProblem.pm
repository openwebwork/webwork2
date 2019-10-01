#!/usr/bin/perl -w

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WebworkClient.pm,v 1.1 2010/06/08 11:46:38 gage Exp $
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

=head1 NAME

FormatRenderedProblem.pm

=cut

package FormatRenderedProblem;

use lib "$WeBWorK::Constants::WEBWORK_DIRECTORY/lib";
use lib "$WeBWorK::Constants::PG_DIRECTORY/lib";
use MIME::Base64 qw( encode_base64 decode_base64);
use WeBWorK::Utils::AttemptsTable;
use WeBWorK::PG::ImageGenerator;
use WeBWorK::Utils qw( wwRound encode_utf8_base64 decode_utf8_base64);
use XML::Simple qw(XMLout);
use WeBWorK::Utils::DetermineProblemLangAndDirection;
use Encode qw(encode_utf8 decode_utf8);
use JSON;

our $UNIT_TESTS_ON  = 0; 



# then create imgGen
our $seed_ce;

eval {
	$seed_ce = WeBWorK::CourseEnvironment->new( 
				{webwork_dir		=>		$WeBWorK::Constants::WEBWORK_DIRECTORY, 
				 courseName         =>      '',
				 webworkURL         =>      '',
				 pg_dir             =>      $WeBWorK::Constants::PG_DIRECTORY,
				 });
};
	if ($@ or not ref($seed_ce)){
		warn "Unable to find environment for WebworkClient: 
			 webwork_dir => $WeBWorK::Constants::WEBWORK_DIRECTORY 
			 pg_dir      => $WeBWorK::Constants::PG_DIRECTORY";
	}



our %imagesModeOptions = %{$seed_ce->{pg}->{displayModeOptions}->{images}};
our $site_url = $seed_ce->{server_root_url}//'';
our $imgGen = WeBWorK::PG::ImageGenerator->new(
		tempDir         => $seed_ce->{webworkDirs}->{tmp},
		latex	        => $seed_ce->{externalPrograms}->{latex},
		dvipng          => $seed_ce->{externalPrograms}->{dvipng},
		useCache        => 1,
		cacheDir        => $seed_ce->{webworkDirs}->{equationCache},
		cacheURL        => $site_url . $seed_ce->{webworkURLs}->{equationCache},
		cacheDB         => $seed_ce->{webworkFiles}->{equationCacheDB},
		dvipng_align    => $imagesModeOptions{dvipng_align},
		dvipng_depth_db => $imagesModeOptions{dvipng_depth_db},
);


sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
	$self = {
		return_object   => {},
		encoded_source  => {},
		sourceFilePath  => '',
		site_url        => 'https://demo.webwork.rochester.edu',
		form_action_url =>'',
		maketext        => sub {return @_}, 
		courseID        => 'daemon_course',  # optional?
		userID          => 'daemon',  # optional?
		course_password => 'daemon',
		inputs_ref      => {},	  
		@_,
	};
	bless $self, $class;
}
sub return_object {   # out
	my $self = shift;
	my $object = shift;
	$self->{return_object} = $object if defined $object and ref($object); # source is non-empty
	$self->{return_object};
}
sub encoded_source {
	my $self = shift;
	my $source = shift;
	$self->{encoded_source} =$source if defined $source and $source =~/\S/; # source is non-empty
	$self->{encoded_source};
}
sub site_url {
	my $self = shift;
	my $new_url = shift;
	$self->{site_url} = $new_url if defined($new_url) and $new_url =~ /\S/;
	$self->{site_url};
}
sub formatRenderedProblem {
	my $self 			  = shift;
	my $problemText       ='';
	my $rh_result         = $self->return_object() || {};  # wrap problem in formats
	$problemText       = "No output from rendered Problem" unless $rh_result ;
	#print "formatRenderedProblem text $rh_result = ",%$rh_result,"\n";
	if (ref($rh_result) and $rh_result->{text} ) {
		$problemText       =  $rh_result->{text};
	} else {
		$problemText       .= "Unable to decode problem text<br/>\n".
		$self->{error_string}."\n".
		format_hash_ref($rh_result);
	}
	my $problemHeadText = $rh_result->{header_text}//'';
	my $rh_answers        = $rh_result->{answers}//{};
	my $answerOrder       = $rh_result->{flags}->{ANSWER_ENTRY_ORDER}; #[sort keys %{ $rh_result->{answers} }];
	my $encoded_source     = $self->encoded_source//'';
	my $sourceFilePath    = $self->{sourceFilePath}//'';
	my $warnings          = '';
        my $answerhashXML     = XMLout($rh_answers, RootName => 'answerhashes');

	#################################################
	# Code to get and set problem language and direction based on flags set by the PG problem.
	# This uses the same utility function as used by lib/WeBWorK/ContentGenerator/Problem.pm
	# and various modules in lib/WeBWorK/ContentGenerator/Instructor/ .
	# However, for technical reasons it requires using additional optional arguments
	# which were added for the use here as they are not available via an internal
	# CourseEnvironment where it was available in the other uses.
	#################################################
	# Need to set things like $PROBLEM_LANG_AND_DIR = "lang=\"he\" dir=\"rtl\"";

	my $formLanguage     = ($self->{inputs_ref}->{language})//'en';

	my @PROBLEM_LANG_AND_DIR = ();

	my $mode_for_get_problem_lang_and_dir = "auto:en:ltr"; # Will be used to set the default
	# Setting to force English and LTR always:
	#     $mode_for_get_problem_lang_and_dir = "force:en:ltr";
	# Setting to avoid any setting be used:
	#     $mode_for_get_problem_lang_and_dir = "none";

	my @to_set_lang_dir = get_problem_lang_and_dir( $self, $rh_result, $mode_for_get_problem_lang_and_dir, $formLanguage );
	   # We are calling get_problem_lang_and_dir() when $self does not
	   # have a request hash called "r" inside it, so need to set the requested
	   # and the course-wide language. We request mode $mode_for_get_problem_lang_and_dir
	   # which by default is set above to "auto:en:ltr" so PG files can request their
	   # language and text direction be set, but falls back to English and LTR.
	   # We also do not have access to a default course language in the same sense
	   # so use the $formLanguage instead.

	while ( scalar(@to_set_lang_dir) > 0 ) {
	    push( @PROBLEM_LANG_AND_DIR, shift( @to_set_lang_dir ) ); # HTML tag being set
	    push( @PROBLEM_LANG_AND_DIR, "=\"" );
	    push( @PROBLEM_LANG_AND_DIR, shift( @to_set_lang_dir ) ); # HTML value being set
	    push( @PROBLEM_LANG_AND_DIR, "\" " );
	}
	my $PROBLEM_LANG_AND_DIR = join("",@PROBLEM_LANG_AND_DIR);

	#################################################
	# Code to get and set main language and direction for generated HTML pages.
	# Very similar to the code in output_course_lang_and_dir() of
	# lib/WeBWorK/ContentGenerator.pm with changes for the XMLRPC on the setting.
	# It depends on the $formLanguage and not a course setting.
	#################################################

	my $master_lang_setting = "lang=\"en-US\""; # default setting
	my $master_dir_setting  = "";               # default is NOT set

	if ( $formLanguage ne "en" ) {
	  # Attempt to override the defaults
	  if ( $formLanguage =~ /^he/i ) { # supports also the current "heb" option
	    # Hebrew - requires RTL direction
	    $master_lang_setting = "lang=\"he\""; # Hebrew
	    $master_dir_setting  = " dir=\"rtl\""; # RTL
	  } elsif ( $formLanguage =~ /^ar/i ) {
	    # Arabic - requires RTL direction
	    $master_lang_setting = "lang=\"ar\""; # Arabic
	    $master_dir_setting  = " dir=\"rtl\""; # RTL
	  } else {
	    # Use the $formLanguage without changing the text direction.
	    # Additional RTL languages should be added above, as needed.
	    $master_lang_setting = "lang=\"${formLanguage}\"";
	  }
	}

	my $COURSE_LANG_AND_DIR = "${master_lang_setting}${master_dir_setting}";

	#################################################
	# regular Perl warning messages generated with warn
	#################################################

	if ( defined ($rh_result->{WARNINGS}) and $rh_result->{WARNINGS} ){
		$warnings = "<div style=\"background-color:pink\">
		             <p >WARNINGS</p><p>".decode_utf8_base64($rh_result->{WARNINGS})."</p></div>";
	}
	#warn "keys: ", join(" | ", sort keys %{$rh_result });
	
	#################################################	
	# PG debug messages generated with DEBUG_message();
	#################################################
	
	my $debug_messages = $rh_result->{debug_messages} ||     [];
    $debug_messages = join("<br/>\n", @{  $debug_messages }    );
    
	#################################################    
	# PG warning messages generated with WARN_message();
	#################################################

    my $PG_warning_messages =  $rh_result->{warning_messages} ||     [];
    $PG_warning_messages = join("<br/>\n", @{  $PG_warning_messages }    );
    
	#################################################
	# internal debug messages generated within PG_core
	# these are sometimes needed if the PG_core warning message system
	# isn't properly set up before the bug occurs.
	# In general don't use these unless necessary.
	#################################################

    my $internal_debug_messages = $rh_result->{internal_debug_messages} || [];
    $internal_debug_messages = join("<br/>\n", @{ $internal_debug_messages  } );
    
    my $fileName = $self->{input}->{envir}->{fileName} || "";


    #################################################


	$self->{outputformats}={};
	my $SITE_URL      	 =  $self->site_url//'';
	my $FORM_ACTION_URL  =  $self->{form_action_url}//'';

	#################################################
	# Local docker usage with a port number sometimes misbehaves if the port number
	# is not forced into $SITE_URL and $FORM_ACTION_URL
	#################################################
	my $forcePortNumber = ($self->{inputs_ref}->{forcePortNumber})//'';
	if ( $forcePortNumber =~ /^[0-9]+$/ ) {
	  $forcePortNumber = 0 + $forcePortNumber;
	  if ( ! ( $SITE_URL =~ /:${forcePortNumber}/ ) ) {
	    $SITE_URL .= ":${forcePortNumber}";
	  }
	  if ( ! ( $FORM_ACTION_URL =~ m+:${forcePortNumber}/webwork2/html2xml+ ) ) {
	    $FORM_ACTION_URL =~ s+/webwork2/html2xml+:${forcePortNumber}/webwork2/html2xml+ ; # Ex: "http://localhost:8080/webwork2/html2xml"
	  }
	}

	#################################################


	my $courseID         =  $self->{courseID}//'';
	my $userID           =  $self->{userID}//'';
	my $course_password  =  $self->{course_password}//'';
	my $problemSeed      =  $self->{inputs_ref}->{problemSeed}//6666;
	my $psvn             =  $self->{inputs_ref}->{psvn}//54321;
	my $session_key      =  $rh_result->{session_key}//'';
	my $displayMode      =  $self->{inputs_ref}->{displayMode};
	

	my $previewMode      =  defined($self->{inputs_ref}->{preview})||0;
	my $checkMode        =  defined($self->{inputs_ref}->{WWcheck})||0;
	my $submitMode       =  defined($self->{inputs_ref}->{WWsubmit})||0;
	my $showCorrectMode  =  defined($self->{inputs_ref}->{WWcorrectAns})||0;
	# problemUUID can be added to the request as a parameter.  
	# It adds a prefix to the 
	# identifier used by the  format so that several different problems
	# can appear on the same page.   
	my $problemUUID      =  $self->{inputs_ref}->{problemUUID}//0;
	my $problemResult    =  $rh_result->{problem_result}//'';
	my $problemState     =  $rh_result->{problem_state}//'';
	my $showSummary      = ($self->{inputs_ref}->{showSummary})//1; #default to show summary for the moment

	my $scoreSummary     =  '';


	my $tbl = WeBWorK::Utils::AttemptsTable->new(
		$rh_answers,
		answersSubmitted       => $self->{inputs_ref}->{answersSubmitted}//0,
		answerOrder            => $answerOrder//[],
		displayMode            => $self->{inputs_ref}->{displayMode},
		imgGen                 => $imgGen,
		ce                     => '',	#used only to build the imgGen
		showAttemptPreviews    => ($previewMode or $submitMode or $showCorrectMode),
		showAttemptResults     => ($submitMode or $showCorrectMode),
		showCorrectAnswers     => ($showCorrectMode),
		showMessages           => ($previewMode or $submitMode or $showCorrectMode),
		showSummary            => ( ($showSummary and ($submitMode or $showCorrectMode) )//0 )?1:0,  
		maketext               => WeBWorK::Localize::getLoc($formLanguage//'en'),
		summary                => ($self->{problem_result}->{summary} )//'', # can be set by problem grader
	);


	my $answerTemplate = $tbl->answerTemplate;
	my $color_input_blanks_script = $tbl->color_answer_blanks;
	$tbl->imgGen->render(refresh => 1) if $tbl->displayMode eq 'images';

	# warn "imgGen is ", $tbl->imgGen;
	#warn "answerOrder ", $tbl->answerOrder;
	#warn "answersSubmitted ", $tbl->answersSubmitted;
	# render equation images

	my $mt = WeBWorK::Localize::getLangHandle($formLanguage//'en');

	if ($submitMode && $problemResult) {
		my $ScoreMsg = $mt->maketext("You received a score of [_1] for this attempt.",wwRound(0, $problemResult->{score} * 100).'%');
		$scoreSummary = CGI::p($ScoreMsg);
		if ($problemResult->{msg}) {
			 $scoreSummary .= CGI::p($problemResult->{msg});
		}

		my $notRecorded = $mt->maketext("Your score was not recorded.");
		$scoreSummary .= CGI::p($notRecorded);
		$scoreSummary .= CGI::hidden({id=>'problem-result-score', name=>'problem-result-score',value=>$problemResult->{score}});
	}

	##########################################################
	#  Try to save the grade to an LTI if one provided us data
	##########################################################

	my $LTIGradeMessage = '';
	if (defined($self->{inputs_ref}->{lis_outcome_service_url}) &&
	    defined($self->{inputs_ref}->{'oauth_consumer_key'}) &&
	    defined($self->{inputs_ref}->{'oauth_signature_method'}) &&
	    defined($self->{inputs_ref}->{'lis_result_sourcedid'}) &&
	    defined($self->{seed_ce}->{'LISConsumerKeyHash'}->{$self->{inputs_ref}->{'oauth_consumer_key'}}) ) {
	  
	  my $request_url = $self->{inputs_ref}->{lis_outcome_service_url};
	  my $consumer_key = $self->{inputs_ref}->{'oauth_consumer_key'}; 
	  my $signature_method = $self->{inputs_ref}->{'oauth_signature_method'};
	  my $sourcedid = $self->{inputs_ref}->{'lis_result_sourcedid'};
	  my $consumer_secret = $self->{seed_ce}->{'LISConsumerKeyHash'}->{$consumer_key};
	  my $score = $problemResult ? $problemResult->{score} : 0;
	  
	  # This is boilerplate XML used to submit the $score for $sourcedid
  my $replaceResultXML = <<EOS;
<?xml version = "1.0" encoding = "UTF-8"?>
<imsx_POXEnvelopeRequest xmlns = "http://www.imsglobal.org/services/ltiv1p1/xsd/imsoms_v1p0">
  <imsx_POXHeader>
    <imsx_POXRequestHeaderInfo>
      <imsx_version>V1.0</imsx_version>
      <imsx_messageIdentifier>999999123</imsx_messageIdentifier>
    </imsx_POXRequestHeaderInfo>
  </imsx_POXHeader>
  <imsx_POXBody>
    <replaceResultRequest>
      <resultRecord>
	<sourcedGUID>
	  <sourcedId>$sourcedid</sourcedId>
	</sourcedGUID>
	<result>
	  <resultScore>
	    <language>en</language>
	    <textString>$score</textString>
	  </resultScore>
	</result>
      </resultRecord>
    </replaceResultRequest>
  </imsx_POXBody>
</imsx_POXEnvelopeRequest>
EOS

	  my $bodyhash = sha1_base64($replaceResultXML);

	  # since sha1_base64 doesn't pad we have to do so manually 
	  while (length($bodyhash) % 4) {
	    $bodyhash .= '=';
	  }

	  my $requestGen = Net::OAuth->request("consumer");
  
	  $requestGen->add_required_message_params('body_hash');
  
	  my $gradeRequest = $requestGen->new(
		  request_url => $request_url,
		  request_method => "POST",
		  consumer_secret => $consumer_secret,
		  consumer_key => $consumer_key,
		  signature_method => $signature_method,
		  nonce => int(rand( 2**32)),
		  timestamp => time(),
		  body_hash => $bodyhash
							 );
	  $gradeRequest->sign();

	  my $HTTPRequest = HTTP::Request->new(
					       $gradeRequest->request_method,
					       $gradeRequest->request_url,
					       [
						'Authorization' => $gradeRequest->to_authorization_header,
						'Content-Type'  => 'application/xml',
					       ],
					       $replaceResultXML,
					      );
	  
	  my $response = LWP::UserAgent->new->request($HTTPRequest);
	  
	  if ($response->is_success) {
	    $response->content =~ /<imsx_codeMajor>\s*(\w+)\s*<\/imsx_codeMajor>/;
	    my $message = $1;
	    if ($message ne 'success') {
	      $LTIGradeMessage = CGI::p("Unable to update LMS grade. Error: ".$message);
	      $debug_messages .= CGI::escapeHTML($response->content);
	    } else {
	      $LTIGradeMessage = CGI::p("Grade sucessfully saved.");
	    }
	  } else {
	    $LTIGradeMessage = CGI::p("Unable to update LMS grade. Error: ".$response->message);
	    $debug_messages .= CGI::escapeHTML($response->content);
	  }

	  # save parameters for next time
	  $LTIGradeMessage .= CGI::input({type=>'hidden', name=>'lis_outcome_service_url', value=>$request_url});
	  $LTIGradeMessage .= CGI::input({type=>'hidden', name=>'oauth_consumer_key', value=>$consumer_key});
	  $LTIGradeMessage .= CGI::input({type=>'hidden', name=>'oauth_signature_method', value=>$signature_method});
	  $LTIGradeMessage .= CGI::input({type=>'hidden', name=>'lis_result_sourcedid', value=>$sourcedid});
	  
	}

	my $localStorageMessages = CGI::start_div({id=>'local-storage-messages'});
	$localStorageMessages.= CGI::p('Your overall score for this problem is'.'&nbsp;'.CGI::span({id=>'problem-overall-score'},''));
	$localStorageMessages .= CGI::end_div();
		
	# my $pretty_print_self  = pretty_print($self);

	# Enable localized strings for the buttons:
	my $STRING_Preview     = $mt->maketext("Preview My Answers");
	my $STRING_ShowCorrect = $mt->maketext("Show correct answers");
	my $STRING_Submit      = $mt->maketext("Check Answers");

# With these values - things work, but the button text is English
# with the localized values, or any answers in UTF-8 - thing break
$STRING_Preview = "Preview My Answers";
$STRING_ShowCorrect = "Show correct answers";
$STRING_Submit = "Check Answers";

######################################################
# Return interpolated problem template
######################################################

	my $format_name = $self->{inputs_ref}->{outputformat}//'standard';

        # The json output format is special and cannot be handled by the
	# the standard code
	if ( $format_name eq "json" ) {
	  my %output_data_hash;
	  my $key_value_pairs = do("WebworkClient/${format_name}_format.pl");
	  my $key;
	  my $val;
	  while ( @$key_value_pairs ) {
	    $key = shift( @$key_value_pairs );
	    $val = shift( @$key_value_pairs );
	    if ( ( $key =~ /^hidden_input_field/ ) ||
		 ( $key =~ /^real_webwork/ ) ||
		 ( $key =~ /^internal/ ) ||
		 ( $key =~ /_VI$/ )
	       ) {
		# interpolate values into $val
		$val =~ s/(\$\w+)/$1/gee;
		if ( $key =~ /_VI$/ ) { $key =~ s/_VI$//; }
	    }
	    $output_data_hash{$key} = $val;
	  }
	  # Add the current score to the %output_data_hash
	  my $json_score = 0;
	  if ( $submitMode && $problemResult ) {
	    $json_score = wwRound(0, $problemResult->{score} * 100);
	  }
	  $output_data_hash{score} = $json_score;

	  my $json_output_data = to_json( \%output_data_hash ,{pretty=>1, canonical=>1});
	  # FIXME: Should set header of response to content_type("text/json; charset=utf-8");
	  return $json_output_data;
	}


	# find the appropriate template in WebworkClient folder
	my $template = do("WebworkClient/${format_name}_format.pl");
	die "Unknown format name $format_name" unless $template;
	# interpolate values into template
	$template =~ s/(\$\w+)/$1/gee;  
	return $template;
}
sub pretty_print {    # provides html output -- NOT a method
    my $r_input = shift;
    my $level = shift;
    $level = 4 unless defined($level);
    $level--;
    return '' unless $level > 0;  # only print three levels of hashes (safety feature)
    my $out = '';
    if ( not ref($r_input) ) {
    	$out = $r_input if defined $r_input;    # not a reference
    	$out =~ s/</&lt;/g  ;  # protect for HTML output
    } elsif ("$r_input" =~/hash/i) {  # this will pick up objects whose '$self' is hash and so works better than ref($r_iput).
	    local($^W) = 0;
	    
		$out .= "$r_input " ."<TABLE border = \"2\" cellpadding = \"3\" BGCOLOR = \"#FFFFFF\">";
		
		
		foreach my $key ( sort ( keys %$r_input )) {
			$out .= "<tr><TD> $key</TD><TD>=&gt;</td><td>&nbsp;".pretty_print($r_input->{$key}) . "</td></tr>";
		}
		$out .="</table>";
	} elsif (ref($r_input) eq 'ARRAY' ) {
		my @array = @$r_input;
		$out .= "( " ;
		while (@array) {
			$out .= pretty_print(shift @array, $level) . " , ";
		}
		$out .= " )";
	} elsif (ref($r_input) eq 'CODE') {
		$out = "$r_input";
	} else {
		$out = $r_input;
		$out =~ s/</&lt;/g; # protect for HTML output
	}
	
	return $out." ";
}


#####################
# error formatting
sub format_hash_ref {
	my $hash = shift;
	warn "Use a hash reference" unless ref($hash) =~/HASH/;
	return join(" ", map {$_="--" unless defined($_);$_ } %$hash),"\n";
}
1;
