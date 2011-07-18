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

	if (defined($setName) and defined($problemNumber) )  {
		#####################################################################
		# print result table of answers
		#####################################################################
		my $answer_log    = $self->{ce}->{courseFiles}->{logs}->{'answer_log'};
	
		$studentUser = $r->param('studentUser') if ( defined($r->param('studentUser')) );
		
		print CGI::h3("Past Answers for $studentUser, set $setName, problem $problemNumber" );
	
		$studentUser = "[^|]*"   if ($studentUser eq ""    or $studentUser eq "*");
		$setName = "[^|]*"       if ($setName eq ""  or $setName eq "*");
		$problemNumber = "[^|]*" if ($problemNumber eq "" or $problemNumber eq "*");
		
		my $pattern = "^[^|]*\\|$studentUser\\|$setName\\|$problemNumber\\|";
		
		if (-e $answer_log) {
			if (open my $log, $answer_log) {
				my $line;
				$self->{lastdate} = '';
				$self->{lasttime} = 0;
				$self->{lastID}   = '';
				$self->{lastn}    = 0;
				
				my @lines = grep(/$pattern/,<$log>); close($log);
				chomp(@lines);
				foreach $line (@lines) {$line = substr($line,27)}; # remove datestamp
				
				print CGI::start_table({border=>0,cellpadding=>0,cellspacing=>3,align=>"center"});
				print "No entries for $studentUser set $setName, problem $problemNumber" unless @lines;
				foreach $line (sort byData @lines) {$self->tableRow(split("\t",$line,-1))}
				print CGI::Tr(CGI::td({colspan=>$self->{lastn}},CGI::hr({size=>3}))) if ($self->{lastn});
				print CGI::end_table();
			} else {
				$self->addbadmessage("Failed to open the answer log '$answer_log': $!");
			}
		} else {
			# no answer log exists yet -- this is probably not an error
			print "No answers have been logged. (Answer log '$answer_log' does not exist.)";
		}
	}
		
	return "";
}

sub byData {
  my ($A,$B) = ($a,$b);
  $A =~ s/\|[01]*\t([^\t]+)\t.*/|$1/; # remove answers and correct/incorrect status
  $B =~ s/\|[01]*\t([^\t]+)\t.*/|$1/;
  return $A cmp $B;
}

sub tableRow {
  my $self = shift;
  my ($answer,$score,$studentUser,$set,$prob);
  my ($ID,$rtime,@answers) = @_; pop(@answers);
  my $scores = ''; $scores = $1 if ($ID =~ s/\|([01]+)$/|/);
  my @scores = split(//, $scores);
  my $date = scalar(localtime($rtime)); $date =~ s/\s+/ /g;
  my ($day,$month,$mdate,$time,$year) = split(" ",$date);
  $date = "$mdate $month $year";
  my $n = 2*(scalar(@answers)+1);

  if ($self->{lastID} ne $ID) {
    if ($self->{lastn}) {
      print CGI::Tr(CGI::td({colspan=>$self->{lastn}},CGI::hr({size=>3}))),
            CGI::end_table(),CGI::p();
      print CGI::start_table({border=>0,cellpadding=>0,cellspacing=>3,align=>"center"});
    }
    ($studentUser,$set,$prob) = (split('\|',$ID))[1,2,3];
    print CGI::Tr({align=>"center"},
		  CGI::td({colspan=>$n},CGI::hr({size=>3}),
			  "User: "   .CGI::b($studentUser)." &nbsp; ",
			  "Set: "    .CGI::b($set)." &nbsp; ",
			  "Problem: ".CGI::b($prob))),"\n";
    $self->{lastID}   = $ID;
    $self->{lasttime} = 0;
    $self->{lastdate} = "";
  }

  print CGI::Tr(CGI::td({colspan=>$n},CGI::hr({size=>1})))
    if ($rtime - $self->{lasttime} > 30*60);
  $self->{lasttime} = $rtime;
  $self->{lastn} = $n;

  if ($self->{lastdate} ne $date) {
    print CGI::Tr(CGI::td({colspan=>$n},CGI::small(CGI::i($date))));
    $self->{lastdate} = $date;
  }

  ##
  ##  These colors really should use CSS and the template
  ##
  my @row = (CGI::td({width=>10}),CGI::td({style=>"color:#808080"},CGI::small($time)));
  my $td = {nowrap => 1};
  foreach $answer (@answers) {
    $answer =~ s/(^\s+|\s+$)//g;
    $answer = showHTML($answer);
    $score = shift(@scores); $td->{style} = $score? "color:#006600": "color:#660000";
    delete($td->{style}) unless $answer ne "" && defined($score);
    $answer = CGI::small(CGI::i("empty")) if ($answer eq "");
    push(@row,CGI::td({width=>20}),CGI::td($td,$answer));
  }
  print CGI::Tr(@row);
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
