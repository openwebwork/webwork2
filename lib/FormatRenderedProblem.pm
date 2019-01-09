#!/usr/bin/perl -w

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
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
use WeBWorK::Utils qw( wwRound);   # required for score summary
our $UNIT_TESTS_ON  = 0; 
#####################
# error formatting
sub format_hash_ref {
	my $hash = shift;
	warn "Use a hash reference" unless ref($hash) =~/HASH/;
	return join(" ", map {$_="--" unless defined($_);$_ } %$hash),"\n";
}

sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
	$self = {
		return_object => {},
		encoded_source => {},
		sourceFilePath => '',
		url            => 'https://demo.webwork.rochester.edu',
		form_action_url =>'',
		maketext   	   => sub {return @_}, 
		courseID       => 'daemon_course',  # optional?
		userID         => 'daemon',  # optional?
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
sub url {
	my $self = shift;
	my $new_url = shift;
	$self->{url} = $new_url if defined($new_url) and $new_url =~ /\S/;
	$self->{url};
}
sub formatRenderedProblem {
	my $self 			  = shift;
	my $problemText       ='';
	my $rh_result         = $self->return_object() || {};  # wrap problem in formats
	$problemText          = "No output from rendered Problem" unless $rh_result ;
	print "\nformatRenderedProblem return_object $rh_result = ",join(" ", sort keys %$rh_result),"\n" if $UNIT_TESTS_ON;
	if (ref($rh_result) and $rh_result->{text} ) {  ##text vs body_text
		$problemText       =  $rh_result->{text};
	} else {
		$problemText       .= "Unable to decode problem text<br/>\n".
		$self->{error_string}."\n".
		format_hash_ref($rh_result);
	}
	my $problemHeadText   = $rh_result->{header_text}//'';  ##head_text vs header_text
	my $rh_answers        = $rh_result->{answers}//{};
	print"\n return_object answers ", join(" ",  %{$rh_result->{PG_ANSWERS_HASH}} ) if $UNIT_TESTS_ON;
	my $answerOrder       = $rh_result->{flags}->{ANSWER_ENTRY_ORDER}; #[sort keys %{ $rh_result->{answers} }];
	my $encoded_source    = $self->encoded_source//'';
	my $sourceFilePath    = $self->{sourceFilePath}//'';
	my $warnings          = '';
	
	#################################################
	# regular Perl warning messages generated with warn
	#################################################

	if ( defined ($rh_result->{WARNINGS}) and $rh_result->{WARNINGS} ){
		$warnings = "<div style=\"background-color:pink\">
		             <p >WARNINGS</p><p>".decode_base64($rh_result->{WARNINGS})."</p></div>";
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
	my $XML_URL      	 =  $self->url//'';
	my $FORM_ACTION_URL  =  $self->{form_action_url}//'';
	my $courseID         =  $self->{courseID}//'';
	my $userID           =  $self->{userID}//'';
	my $course_password  =  $self->{course_password}//'';
	my $problemSeed      =  $self->{inputs_ref}->{problemSeed}//6666;
	my $session_key      =  $rh_result->{session_key}//'';
	my $displayMode      =  $self->{inputs_ref}->{displayMode}//'foobar';
	
	my $previewMode      =  defined($self->{inputs_ref}->{preview})||0;
	my $checkMode        =  defined($self->{inputs_ref}->{WWcheck})||0;
	my $submitMode       =  defined($self->{inputs_ref}->{WWsubmit})||0;
	my $showCorrectMode  =  defined($self->{inputs_ref}->{WWcorrectAns})||0;
        # problemIdentifierPrefix can be added to the request as a parameter.  
        # It adds a prefix to the 
        # identifier used by the  format so that several different problems
        # can appear on the same page.   
	my $problemIdentifierPrefix = $self->{inputs_ref}->{problemIdentifierPrefix} //'';
    my $problemResult    =  $rh_result->{problem_result}//'';
    my $problemState     =  $rh_result->{problem_state}//'';
    my $showSummary      = ($self->{inputs_ref}->{showSummary})//1; #default to show summary for the moment
	my $formLanguage     = ($self->{inputs_ref}->{language})//'en';

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
		summary                => $problemResult->{summary} //'', # can be set by problem grader???
	);


	my $answerTemplate = $tbl->answerTemplate;
	my $color_input_blanks_script = $tbl->color_answer_blanks;
	$tbl->imgGen->render(refresh => 1) if $tbl->displayMode eq 'images';


	# FIXME -- can we avoid using imgGenerator here?
	# warn "imgGen is ", $tbl->imgGen;
	#warn "answerOrder ", $tbl->answerOrder;
	#warn "answersSubmitted ", $tbl->answersSubmitted;
	# render equation images



	if ($submitMode && $problemResult) {
		$scoreSummary = CGI::p('Your score on this attempt is '.wwRound(0, $problemResult->{score} * 100).'%');
		if ($problemResult->{msg}) {
			 $scoreSummary .= CGI::p($problemResult->{msg});
		}

		$scoreSummary .= CGI::p('Your score on this problem has not been recorded.');
		$scoreSummary .= CGI::hidden({id=>'problem-result-score', name=>'problem-result-score',value=>$problemResult->{score}});
	}

	# This stuff is put here because eventually we will add locale support so the 
	# text will have to be done server side. 
	my $localStorageMessages = CGI::start_div({id=>'local-storage-messages'});
	$localStorageMessages.= CGI::p('Your overall score for this problem is'.'&nbsp;'.CGI::span({id=>'problem-overall-score'},''));
	$localStorageMessages .= CGI::end_div();
		
	#my $pretty_print_self  = pretty_print($self);
######################################################
# Return interpolated problem template
######################################################

	my $format_name = $self->{inputs_ref}->{outputformat}//'standard';
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

1;
