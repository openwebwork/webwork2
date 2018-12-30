###############################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2016 The WeBWorK Project, http://openwebwork.sf.net/
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

package WeBWorK::Authen::LTIAdvanced::SubmitGrade;
use base qw/WeBWorK::Authen::LTIAdvanced/;

=head1 NAME

WeBWorK::Authen::LTIAdvanced::SubmitGrade - pass back grades to an enabled LMS

=cut


use strict;
use warnings;
use WeBWorK::Debug;
use WeBWorK::CGI;
use Carp;
use WeBWorK::Utils qw(grade_set grade_gateway grade_all_sets wwRound);
use Net::OAuth;
use HTTP::Request;
use LWP::UserAgent;

use Digest::SHA qw(sha1_base64);

# This package contains utilities for submitting grades to the LMS
sub new {
  my ($invocant, $r) = @_;
  my $class = ref($invocant) || $invocant;
  my $self = {
	      r => $r,
	     };
  # sanity check
  my $ce = $r->{ce};
  my $db = $self->{r}->{db};

  unless (ref($ce//'') and ref($db)//'') {
  	warn("course environment is not defined") unless ref($ce//'');
  	warn("database reference is not defined") unless ref($db//'');
  	croak("Could not create WeBWorK::Authen::LTIAdvanced::SubmitGrade object, missing items from request");
  }
 
  bless $self, $class;
  return $self;
}

# This updates the sourcedid for the object we are looking at.  Its either
# the sourcedid for the user for course grades or the sourcedid for the
# userset for homework grades. 
sub update_sourcedid {
  my $self = shift;
  my $userID = shift;
  my $r = $self->{r};
  my $ce = $r->{ce};
  my $db = $self->{r}->{db};
  
  # These parameters are used to build the passback request
  # warn if no outcome service url
  if (!defined($r->param('lis_outcome_service_url'))) {
    carp "The parameter lis_outcome_service_url is not defined.  Unable to report grades to the LMS.".
    " Are external grades enabled in the LMS?" if $ce->{debug_lti_grade_passback};
  } else {
    # otherwise keep it up to date
    my $lis_outcome_service_url = $db->getSettingValue('lis_outcome_service_url');
    if (!defined($lis_outcome_service_url) ||
	$lis_outcome_service_url ne $r->param('lis_outcome_service_url')) {
      $db->setSettingValue('lis_outcome_service_url',
			   $r->param('lis_outcome_service_url'));
    }
  }
  
  # these parameters have to be here or we couldn't have gotten this far
  my $consumer_key = $db->getSettingValue('consumer_key');
  if (!defined($consumer_key) ||
      $consumer_key ne $r->param('oauth_consumer_key')) {
    $db->setSettingValue('consumer_key',
			 $r->param('oauth_consumer_key'));
  }
  
  my $signature_method = $db->getSettingValue('signature_method');
  if (!defined($signature_method) ||
      $signature_method ne $r->param('oauth_signature_method')) {
    $db->setSettingValue('signature_method',
			 $r->param('oauth_signature_method'));
  }
  
  # The $sourcedid is what identifies the user and assignment
  # to the LMS.  It is either a course grade or a set grade
  # depending on the request and the mode we are in.  
  my $sourcedid = $r->param('lis_result_sourcedid');
  if (!defined($sourcedid)) {
    warn "No LISSourceID! Some LMS's do not give grades to instructors, but this".  
     "could also be a sign that external grades are not enabled in your LMS." if $ce->{debug_lti_grade_passback};
  } elsif ($ce->{LTIGradeMode} eq 'course') {
    # Update the SourceDID for the user if we are in course mode
    my $User = $db->getUser($userID);
    if (!defined($User->lis_source_did) || $User->lis_source_did ne $sourcedid) {
      $User->lis_source_did($sourcedid);
      $db->putUser($User);
    }
  } elsif ($ce->{LTIGradeMode} eq 'homework') {
    my $urlpath = $r->urlpath;
    my $setID = $urlpath->arg("setID");
    if (!defined($setID)) {
      warn "Not a link to a Problem Set and in homework grade mode.".
        " Links to WeBWorK should point to specific problem sets.";
    } else {
      my $set = $db->getUserSet($userID,$setID);
      # if set is not defined and we are going to a page with
      # is set dependent then there are problems that will be caught
      # later
      if (defined($set) &&
	   (!defined($set->lis_source_did) ||
	   $set->lis_source_did ne $sourcedid)) {
		$set->lis_source_did($sourcedid);
		$db->putUserSet($set);
	
      }
    }
  }
} # end update_sourcedid

# computes and submits the course grade for userID to the LMS
# the course grade is the average of all sets assigned to the user.  
sub submit_course_grade {
  my $self = shift;
  my $userID = shift;
  my $r = $self->{r};
  my $ce = $r->{ce};
  my $db = $self->{r}->{db};

  my $score = grade_all_sets($db,$userID);
  my $user = $db->getUser($userID);

  die("$userID does not exist") unless $user;
  warn "submitting all grades for user: $userID  \n" if $ce->{debug_lti_grade_passback};
  warn "lis_source_did is not available for user: $userID \n" if !($user->lis_source_did) and $ce->{debug_lti_grade_passback};
  return $self->submit_grade($user->lis_source_did,$score);
  
}

# computes and submits the set grade for $userID and $setID to the
# LMS.  For gateways the best score is used.  
sub submit_set_grade {
  my $self = shift;
  my $userID = shift;
  my $setID = shift;
  my $r = $self->{r};
  my $ce = $r->{ce};
  my $db = $self->{r}->{db};

  my $user = $db->getUser($userID);

  die("$userID does not exist") unless $user;

  my $userSet = $db->getMergedSet($userID,$setID);
  my $score = 0;

  if ($userSet->assignment_type() =~ /gateway/) {
    $score = grade_gateway($db,$userSet,$userSet->set_id,$userID);
  } else {
    $score = grade_set($db,$userSet,$userSet->set_id,$userID,0);
  }
  # make debug prettier
  my $message_string = '';
  $message_string .= "\nmass_update: " if $self->{post_processing_mode};
  $message_string .= "submitting grade for user: $userID set $setID ";
  $message_string .= "-- lis_source_did is not available " unless ($userSet->lis_source_did);
  warn($message_string."\n") if $ce->{debug_lti_grade_passback};
  return $self->submit_grade($userSet->lis_source_did,$score);
}

# error in reporting michael.gage@rochester.edu, Demo, Global $r object is not available. Set:
# 	PerlOptions +GlobalRequest
# in httpd.conf at /opt/rh/perl516/root/usr/local/share/perl5/CGI.pm line 346, <IN> line 76.
# so we don't use CGI::escapeHTML in post processing mode but use this local version instead.

sub local_escape_html {  # a local version of escapeHTML that works for post processing
	my $self = shift;   # a grading object
	my @message = @_;
	if ($self->{post_processing_mode}) {		
		return join('', @message);    # this goes to log files in post processing to escapeHTML is not essential
	} else {
		return CGI::escapeHTML(@message);  #FIXME -- why won't this work in post_processing_mode (missing $r ??)
	}
}

# submits a score of $score to the lms with $sourcedid as the
# identifier.  
sub submit_grade {
  my $self = shift;
  my $sourcedid = shift;
  my $score = shift;
  my $r = $self->{r};
  my $ce = $r->{ce};
  my $db = $self->{r}->{db};

  $score = wwRound(2,$score);
  
  # We have to fail gracefully here because some users, like instructors,
  # may not actually have a sourcedid
  if (!$sourcedid) {
#     carp("No sourcedid for this user/assignment.  Some LMS's do not provide ".
#      "sourcedid for instructors so this may not be a problem, or it might ".
#      "mean your settings are not correct.") if $ce->{debug_lti_grade_passback};
    return 0;
  }
  
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

  chomp($replaceResultXML);
  
  my $bodyhash = sha1_base64($replaceResultXML);

  # since sha1_base64 doesn't pad we have to do so manually 
  while (length($bodyhash) % 4) {
    $bodyhash .= '=';
  }
  my $message2='';
  $message2 .= "mass_update: " if $self->{post_processing_mode};
  $message2 .= "Submitting grade using sourcedid: $sourcedid and score: $score\n";
  warn($message2) if $ce->{debug_lti_grade_passback};
  
  my $request_url = $db->getSettingValue('lis_outcome_service_url');
  
  unless ($request_url//'' ) {
    warn("Cannot submit grades to LMS, no request_url obtained from 'lis_outcome_service_url' ");
    return 0;
  }

  my $consumer_key = $db->getSettingValue('consumer_key');
  unless ($consumer_key//'') {
    warn("Cannot submit grades to LMS, no consumer_key");
    return 0;
  }
  
  my $signature_method = $db->getSettingValue('signature_method');
  unless ($signature_method//'') {
    warn("Cannot submit grades to LMS, no signature_method");
    return 0;
  }
  debug("found data required for submitting grades to LMS");
  my $requestGen = Net::OAuth->request("consumer");
  debug( "obtained requestGen $requestGen");
  $requestGen->add_required_message_params('body_hash');
  debug("add required message params"); 
  my $gradeRequest = $requestGen->new(
		  request_url => $request_url,
		  request_method => "POST",
		  consumer_secret => $ce->{LTIBasicConsumerSecret},
		  consumer_key => $consumer_key,
		  signature_method => $signature_method,
		  nonce => int(rand( 2**32)),
		  timestamp => time(),
		  body_hash => $bodyhash
							 );
	debug("created grade request ". $gradeRequest);
  $gradeRequest->sign();
	debug("signed grade request"); 
  my $HTTPRequest = HTTP::Request->new(
	       $gradeRequest->request_method,
	       $gradeRequest->request_url,
	       [
		  'Authorization' => $gradeRequest->to_authorization_header,
		  'Content-Type'  => 'application/xml',
	       ],
	       $replaceResultXML,
		);
    debug ("posting grade request: $HTTPRequest");
 
my $response = eval {   
   LWP::UserAgent->new->request($HTTPRequest);
 };
 if ($@) {
  	warn "error sending HTTP request to LMS, $@";
  }

# debug section


	if ($ce->{debug_lti_grade_passback} and $ce->{debug_lti_parameters}){
	  warn "The response is:\n ". ($self->local_escape_html(join(" ", %$response )));  
	  warn "The request was:\n ". ($self->local_escape_html(join(" ",%$HTTPRequest))); 
	}


# end debug section 
  if ($response->is_success) {
    $response->content =~ /<imsx_codeMajor>\s*(\w+)\s*<\/imsx_codeMajor>/;
    my $message = $1;
    warn ("result is: $message\n") if $ce->{debug_lti_grade_passback};
    if ($message ne 'success') {
      debug("Unable to update LMS grade $sourcedid . LMS responded with message: ". $message) ;
      return 0;
    } else {
      # if we got here we got successes from both the post and the lms
      debug("Successfully updated LMS grade $sourcedid. LMS responded with message: ".$message );
    }
  } else {
    debug("Unable to update LMS grade $sourcedid. Error: ".($response->message) );
    debug(local_escape_html($response->content)); 
    return 0;
  }
   debug("Success submitting grade using sourcedid: $sourcedid and score: $score\n") ;
 
   return 1; # success
}

# does a mass update of all grades.  This is all user grades for
# course grade mode and all user set grades for homework grade mode.  
sub mass_update {
  my $self = shift;
  my $r = $self->{r};
  my $ce = $r->{ce};
  my $db = $self->{r}->{db};
  $self->{post_processing_mode}=1;
  
  # sanity check
  warn("course environment is not defined") unless ref($ce//'');
  warn("database reference is not defined") unless ref($db//'');
  warn "\nperforming mass_update via LTI"  if $ce->{debug_lti_grade_passback};
    
  my $lastUpdate = $db->getSettingValue('LTILastUpdate') // 0;
  my $updateInterval = $ce->{LTIMassUpdateInterval} // -1; # -1 suppresses update

  if ($updateInterval != -1 &&
      time - $lastUpdate > $updateInterval) {

    $db->setSettingValue('LTILastUpdate',time());
    
    if ($ce->{LTIGradeMode} eq 'course') {
      my @users = $db->listUsers();

      foreach my $user (@users) {
		$self->submit_course_grade($user);
      }
      
    } elsif ($ce->{LTIGradeMode} eq 'homework') {
      my @users = $db->listUsers();
      
      foreach my $user (@users) {
		my @sets = $db->listUserSets($user);
		warn "\nmass_update: all sets assigned to user $user :\n".join(" ",  @sets)."\n" if $ce->{debug_lti_grade_passback};
		foreach my $set (@sets) {
		    eval {
		    	#$self->update_sourcedid($user);  #CHECK is this the right user id -- this doesn't update properly
	  			$self->submit_set_grade($user,$set);
	  		};
	  		if ($@) {
	  			warn "error in reporting $user, $set, $@" if $ce->{debug_lti_grade_passback};
	  		}
	  	
		}
      }
    }
  }
  $self->{post_processing_mode}=0; 
}

1;

