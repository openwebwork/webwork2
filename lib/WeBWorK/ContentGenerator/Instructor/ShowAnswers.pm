################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/ShowAnswers.pm,v 1.20 2006/10/10 10:58:54 dpvc Exp $
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

package WeBWorK::ContentGenerator::Instructor::ShowAnswers;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ShowAnswers.pm  -- display past answers of students

=cut

use strict;
use warnings;
#use CGI;
use WeBWorK::CGI;


sub initialize {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $courseName = $urlpath->arg("courseID");
	my $user       = $r->param('user');
	
	unless ($authz->hasPermissions($user, "view_answers")) {
		$self->addbadmessage("You aren't authorized to view past answers");
		return;
	}
}


sub body {
	my $self          = shift;
	my $r             = $self->r;
	my $urlpath       = $r->urlpath;
	my $db            = $r->db;
	my $ce            = $r->ce;
	my $authz         = $r->authz;
	my $root          = $ce->{webworkURLs}->{root};
	my $courseName    = $urlpath->arg('courseID');  
	my $setName       = $r->param('setID');     # these are passed in the search args in this case
	my $problemNumber = $r->param('problemID');
	my $user          = $r->param('user');
	my $key           = $r->param('key');
	my $studentUser   = $r->param('studentUser') if ( defined($r->param('studentUser')) );
	
	return CGI::em("You are not authorized to access the instructor tools") unless $authz->hasPermissions($user, "access_instructor_tools");
	return CGI::em("You are not authorized to view past answers") unless $authz->hasPermissions($user, "view_answers");
	
	my $showAnswersPage   = $urlpath->newFromModule($urlpath->module,  $r, courseID => $courseName);
	my $showAnswersURL    = $self->systemLink($showAnswersPage,authen => 0 );
	
	#####################################################################
	# print form
	#####################################################################

	print CGI::p(),CGI::hr();

	print CGI::start_form("POST", $showAnswersURL,-target=>'information'),
	      $self->hidden_authen_fields;
	print CGI::submit(-name => 'action', -value=>'Past Answers for')," &nbsp; ",
	      CGI::textfield(-name => 'studentUser', -value => $studentUser, -size =>10 ),
	      " &nbsp; Set: &nbsp;",
	      CGI::textfield( -name => 'setID', -value => $setName, -size =>10  ), 
              " &nbsp; Problem: &nbsp;",
	      CGI::textfield(-name => 'problemID', -value => $problemNumber,-size =>10  ),  
  	      " &nbsp; ";
	print CGI::end_form();


		#####################################################################
		# print result table of answers
		#####################################################################

	my @pastAnswerIDs = $db->listProblemPastAnswers($courseName, $studentUser, $setName, $problemNumber);

	print CGI::start_table({border=>0,cellpadding=>0,cellspacing=>3,align=>"center"});
	print CGI::h3("Past Answers for $studentUser, set $setName, problem $problemNumber" );
	print "No entries for $studentUser set $setName, problem $problemNumber" unless @pastAnswerIDs;

	# changed this to use the db for the past answers.  
        # The code is better but the actual html out put is considerably less pretty
	# Todo: prettify

	foreach my $answerID (@pastAnswerIDs) {
	    my $pastAnswer = $db->getPastAnswer($answerID);
	    my $answers = $pastAnswer->answer_string;
	    my $scores = $pastAnswer->scores;
	    my $time = $self->formatDateTime($pastAnswer->timestamp);

	    my @scores = split(//, $scores);
	    my @answers = split(/\t/,$answers);
	    
	    my @row = (CGI::td({width=>10}),CGI::td({style=>"color:#808080"},CGI::small($time)));
	    my $td = {nowrap => 1};
	    foreach my $answer (@answers) {
		$answer = showHTML($answer);
		my $score = shift(@scores); $td->{style} = $score? "color:#006600": "color:#660000";
		delete($td->{style}) unless $answer ne "" && defined($score);
		$answer = CGI::small(CGI::i("empty")) if ($answer eq "");
		push(@row,CGI::td({width=>20}),CGI::td($td,$answer));
	    }
	    print CGI::Tr(@row);

	    
	}

	print CGI::end_table();
	    
	return "";
}

sub byData {
  my ($A,$B) = ($a,$b);
  $A =~ s/\|[01]*\t([^\t]+)\t.*/|$1/; # remove answers and correct/incorrect status
  $B =~ s/\|[01]*\t([^\t]+)\t.*/|$1/;
  return $A cmp $B;
}

##################################################
#
#  Make HTML symbols printable
#
sub showHTML {
    my $string = shift;
    return '' unless defined $string;
    $string =~ s/&/\&amp;/g;
    $string =~ s/</\&lt;/g;
    $string =~ s/>/\&gt;/g;
    $string =~ s/\000/,/g;  # anyone know why this is here?  (I didn't add it -- dpvc)
    $string;
}

1;
