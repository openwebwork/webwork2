################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/Preflight.pm,v 1.8 2006/09/25 22:14:53 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor::Preflight;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Preflight.pm  -- display past answers of many students

=cut

use strict;
use warnings;
use CGI qw(-nosticky );
use WeBWorK::HTML::OptionList qw/optionList/;
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;

sub initialize {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $courseName = $urlpath->arg("courseID");
	my $user       = $r->param('user');
	
	# Check permissions
	return unless ($authz->hasPermissions($user, "access_instructor_tools"));
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
	my $setName       = $r->param('setID') || "";     # these are passed in the search args in this case
	my $problemNumber = $r->param('problemID') || "";
	if ($problemNumber =~ /\!(\d+)/) { $problemNumber = $1 };
	my $user          = $r->param('user');
	my $key           = $r->param('key');
	my $studentUser   = $r->param('studentUser') || "";
	
	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($r->param("user"), "access_instructor_tools");

	
	my $showAnswersPage   = $urlpath->newFromModule($urlpath->module, $r, courseID => $courseName);
	my $showAnswersURL    = $self->systemLink($showAnswersPage,authen => 0 );
	
	my ($safeUser, $safeCourse) = (showHTML($studentUser), showHTML($courseName));
	my ($safeSet, $safeProb) = (showHTML($setName), showHTML($problemNumber));

	my @defaultOrder = qw(user_id set_id problem_id date answers);

	my %prettyFieldNames;
	
	@prettyFieldNames{qw(
		user_id
		set_id
		problem_id
		date
		answers
	)} = (
		"User ID",
		"Set Name",
		"Problem Number",
		"Date", 
		"Answers",
	);
	$prettyFieldNames{nofield} = "";
	
	#####################################################################
	# print form
	#####################################################################
	
	# FIXME why are we filtering out users with non-word characters in their userIDs?
	my @userIDs = grep /\w/, sort $db->listUsers();
	# DBFIXME for these "get all" type queries, we shouldn't need the lists of setIDs
	my @Users = $db->getUsers(@userIDs);
	my %users = map { $_ => $db->getUser($_)->first_name } @userIDs;
	my @setIDs = sort $db->listGlobalSets();
	my @GlobalSets = $db->getGlobalSets(@setIDs);
	my @GlobalProblems = $db->getAllGlobalProblems($setName);

	my $scrolling_user_list = scrollingRecordList({
		name => "studentUser",
		request => $r,
		default_sort => "lnfn",
		default_format => "lnfn_uid",
		default_filters => ["all"],
		default => "Select one or more users: ",
#		hide_sort => 1,
#		hide_format => 1,
#		hide_filter => 1,
		size => 10,
#		multiple => 0,
	}, @Users);
	
	my $scrolling_set_list = scrollingRecordList({
		name => "setID",
		request => $r,
		default_sort => "set_id",
		default_format => "set_id",
		default_filters => ["all"],
		default => "Select one or more sets: ",
#		hide_sort => 1,
#		hide_format => 1,
#		hide_filter => 1,		
		size => 10,
#		multiple => 0,
	}, @GlobalSets);

	my $scrolling_problem_list = scrollingRecordList({
		name => "problemID",
		request => $r,
		default => "Select one or more problems: ",
		default_filters => ["all"],		
#		hide_sort => 1,
#		hide_format => 1,
#		hide_filter => 1,		
		size => 10,
#		multiple => 0,
	}, @GlobalProblems);
	
	my @selected_fields = $r->param("selected_fields");
	my @selected_answers = $r->param("selected_answers");

	print join ("",
		CGI::br(),
		"\n\n",
		CGI::hr(),
		CGI::start_form(
			-method => "post", 
			-action => $showAnswersURL, 
			-target => 'information',
		),
			CGI::start_table(
				-border => "0", 
				-cellpadding => "0", 
				-cellspacing => "0",
			),
				CGI::Tr(
					CGI::td({style=>"width:33%"}, $scrolling_user_list),
					CGI::td({style=>"width:33%"}, $scrolling_set_list),
					CGI::td({style=>"width:33%"}, $scrolling_problem_list),					
				),
				CGI::Tr({}, 
					CGI::submit(
						-name => 'action',
						-value => 'Past Answers for',
					), "\n",
#					$self->hidden_authen_fields,
#					" &nbsp; \n User: &nbsp;",
#					CGI::textfield(
#						-name => 'studentUser1',
#						-value => $safeUser,
#						-size => 10,
#					),
#					" &nbsp; \n Set: &nbsp;",
#					CGI::textfield(
#						-name => 'setID1',
#						-value => $safeSet,
#						-size => 10, 
#					),
#					" &nbsp; \n Problem:  &nbsp;",
#					CGI::textfield(
#						-name => 'problemID',
#						-value => $safeProb,
#						-size => 10,
#					),
#					" &nbsp; \n",
#					CGI::br(),CGI::br(),
				),
#				CGI::Tr({},
#					CGI::popup_menu(
#						-name => 'studentUser',
#						-size => 10,
#						-values => \@userIDs,
#						-multiple => 1,
#					),
#					CGI::popup_menu(
#						-name => 'setID',
#						-values => \@setIDs,
#						-size => 10,
#						-multiple => 1,
#					),
#				),
				CGI::Tr({},
					CGI::td({}, 
						"Select which fields to show: " . CGI::br(),
						CGI::scrolling_list(
							-name => "selected_fields",
							-values => \@defaultOrder,
							-labels => \%prettyFieldNames,
							-default => \@selected_fields,
							-size => 5,
							-multiple => 1,
						),
					),
					CGI::td({},
						"and which answers to show: " . CGI::br(),
						CGI::scrolling_list(
							-name => "selected_answers",
							-values => [1..100],
							-default => \@selected_answers,
							-size => 5,
							-multiple => 1,
						)
					),
				),
			CGI::end_table({}),
		CGI::end_form({}),	
	);
	
	#####################################################################
	# create ordering system
	#####################################################################

	# FIXME: We need a way to choose the order as well as the fields!
	my (@fieldOrder) = @selected_fields ? @selected_fields : @defaultOrder;

	if (defined($setName) and defined($problemNumber) )  {
		#####################################################################
		# print result table of answers
		#####################################################################
		my $answer_log    = $self->{ce}->{courseFiles}->{logs}->{'answer_log'};
	
		$studentUser = $r->param('studentUser') if ( defined($r->param('studentUser')) );
		my ($safeUser, $safeCourse) = (showHTML($studentUser), showHTML($courseName));
		my ($safeSet, $safeProb) = (showHTML($setName), showHTML($problemNumber));
	
		
		print CGI::h3( "Past Answers for " . ($safeUser ? "user $safeUser " : '' ) . ($safeSet ? "set $safeSet " : '' ) . ($safeSet and $safeProb ? ', ' : '') . ($safeProb ? "problem $safeProb" : ''));
	
		$studentUser = "[^|]*"    if (not defined $studentUser or $studentUser eq ""    or $studentUser eq "*");
		$setName = "[^|]*"  if ($setName eq ""  or $setName eq "*");
		$problemNumber = "[^|]*" if ($problemNumber eq "" or $problemNumber eq "*");

		#my $pattern = "^[[^]]*]|[^|]*\\|$setName\\|$problemNumber\\|";
		my $pattern = "\\|$studentUser\\|$setName\\|$problemNumber\\|";
		
		our ($lastdate, $lasttime, $lastID, $lastn);
		
		
		if (open(LOG,"$answer_log")) {
			my $line;
			local ($lastdate, $lasttime, $lastID, $lastn) = ("",0,"",0);
			$self->{lastdate}       = '';
			$self->{lasttime}       = '';
			$self->{lastID}         = '';
			$self->{lastn}          = '';
		  
			# get data from file
			
			my @lines = grep(/$pattern/,<LOG>); close(LOG);
			chomp(@lines);
						
			my $maxcount = 0;
			foreach my $newline (@lines) {
				my @words = split /\t/, $newline;
				my $count = @words;
				$maxcount = $count if $count > $maxcount;
			}
			@selected_answers = (1..$maxcount) unless @selected_answers;
			
#			print "<CENTER>\n";
			print CGI::start_table({
					-border => "1",
#					-cellpadding => '3',
#					-cellspacing => '0',
					-onload => "",
				}) . "\n";
			
			my @tableHeaders;
			foreach (@fieldOrder) {
				push @tableHeaders, $prettyFieldNames{$_} unless $_ eq "answers";
			}
			print CGI::Tr({}, CGI::th({}, \@tableHeaders) , CGI::th({-colspan => 200}, $prettyFieldNames{answers}));

			my @Records;
			#####################################################################
			# create array of records
			#####################################################################
			foreach $line ( @lines ) {
				my %fakeRecord = ();
				#print CGI::br() . $line;
				next if not $line =~ /\|(\w+)\|([\w\d_-]+)\|(\d+)\|\s*(\d+)(.*?)\t?$/;
				$fakeRecord{user_id} = "$1";
				$fakeRecord{set_id} = "$2";
				$fakeRecord{problem_id} = "$3";
				$fakeRecord{date} = $4; #$self->formatDateTime($4);
				$fakeRecord{answers} = [ split "\t", "$5", -1 ] if $5; # the -1 stops split from dropping any trailing null fields
				my @answers = map { $_ ? showHTML($_) : CGI::small(CGI::i("empty")) } @{ $fakeRecord{answers} }; 
				shift @answers;	# first field is always empty
				$fakeRecord{answers} = \@answers;
				

				my @tableCells;
				foreach (@fieldOrder) {
				
					#push @tableCells, showHTML($fakeRecord{$_});
				}

				push @Records, \%fakeRecord;

				#print join " ", map { "$_ = $fakeRecord{$_}" } keys %fakeRecord;
				#print CGI::br();
#				print CGI::Tr({}, CGI::td({}, \@tableCells));
			
				#print $self->tableRow(split("\t",$line."\tx"));
			}

			#####################################################################
			# sort array of records
			#####################################################################

			@Records = sort byUSPD @Records;

			#####################################################################
			# print array of records
			#####################################################################
			
			foreach my $record (@Records) {
				my @tableCells;
				foreach (@fieldOrder) {
					if ($_ eq "answers") {
						my $i = 0;
						my %answers = map { ++$i => $_ } @{ $record->{$_} };
						push @tableCells, @answers{@selected_answers};
					} elsif ($_ eq "date") {
						my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime $record->{$_};
						$wday = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")[$wday];
						$mon = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")[$mon];
						$year += 1900;
						my $ampm = ("am", "pm")[$hour > 12];
						$hour = $hour % 12;
						push @tableCells, showHTML("$wday $mday $mon $year $hour:$min $ampm");
					} else {
						push @tableCells, $record->{$_};
					}
				}
				
				print CGI::Tr({}, CGI::td({}, \@tableCells));
			}
				
			# print a horizontal line 
			#print CGI::Tr({}, CGI::td({colspan => $lastn}, CGI::hr({size => 3})));
			print CGI::end_table({});
#			print "\n</CENTER>\n\n";
			print CGI::p(
	        	      CGI::i("No entries for " . ($safeUser ? "user $safeUser " : '' ) . ($safeSet ? "set $safeSet " : '' ) . ($safeSet and $safeProb ? ', ' : '') . ($safeProb ? "problem $safeProb" : ''))
			) unless @lines;
			
		} else {
			print CGI::em("Can't open the access log $answer_log");
		}
	}

		
	return "";
}

sub tableRow {
	my $self       = shift;
	my $lastID     = $self->{lastID};
	my $lastn      = $self->{lastn};
	my $lasttime   = $self->{lasttime};
	my $lastdate   = $self->{lastdate};
	my ($out,$answer,$studentUser,$set,$prob) = "";
	my ($ID,$rtime,@answers) = @_; pop(@answers);
	my $date = scalar(localtime($rtime)); $date =~ s/\s+/ /g;
	my ($day,$month,$mdate,$time,$year) = split(" ",$date);
	$date = "$mdate $month $year";
	my $n = 2*(scalar(@answers)+1);

	if ($lastID ne $ID) {
		if ($lastn) {
			print qq{<TR><TD COLSPAN="$lastn"><HR SIZE="3"></TD></TR>\n<P>\n\n};
			print '<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="3">',"\n";
		}
		($studentUser,$set,$prob) = (split('\|',$ID))[1,2,3];
		$out .= qq{<TR ALIGN="CENTER"><TD COLSPAN="$n"><HR SIZE="3">
			User: <B>$studentUser</B> &nbsp;
			Set: <B>$set</B> &nbsp;
			Problem: <B>$prob</B></TD></TR>\n};
		$lastID = $ID; $lasttime = 0; $lastdate = "";
	}

	$out .= qq{<TR><TD COLSPAN="$n"><HR SIZE="1"></TD></TR>\n}
	if ($rtime - $lasttime > 30*60);
	$lasttime = $rtime; $lastn = $n;

	if ($lastdate ne $date) {
		$out .= qq{<TR><TD COLSPAN="$n"><SMALL><I>$date</I></SMALL></TD></TR>\n};
		$lastdate = $date;
	}

	$out .= '<TR><TD WIDTH="10"></TD>'.
		'<TD><FONT COLOR="#808080"><SMALL>'.$time.'</SMALL></FONT></TD>';
	foreach $answer (@answers) {
		$answer =~ s/(^\s+|\s+$)//g;
		$answer = showHTML($answer);
		$answer = "<SMALL><I>empty</I></SMALL>" if ($answer eq "");
		$out .= qq{<TD WIDTH="20"></TD><TD NOWRAP>$answer</TD>};
	}
	$out .= "</TR>\n";
	$out;
}

################################################################################
# sorts
################################################################################

sub byUserID      { $a->{user_id}      cmp $b->{user_id}    }
sub bySetID       { lc($a->{set_id})   cmp lc($b->{set_id})     }
sub byProblemID   { $a->{problem_id}   <=> $b->{problem_id} }  
sub byDate        { $a->{date}         cmp $b->{date}       }

sub byUSPD	{ &byUserID || &bySetID || &byProblemID || &byDate }

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
	$string =~ s/\0/,/g;
	$string =~ s/ /&nbsp;/g;
	return $string;
}

1;
