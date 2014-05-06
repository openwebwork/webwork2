################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Feedback.pm,v 1.45 2008/03/13 22:22:23 sh002i Exp $
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

package WeBWorK::ContentGenerator::Feedback;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Feedback - Send mail to professors.

=cut

# *** feedback should be exempt from authentication, so that people can send
# feedback from the login page!

use strict;
use warnings;
use Data::Dumper;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use Mail::Sender;
use Socket qw/unpack_sockaddr_in inet_ntoa/; # for remote host/port info
use Text::Wrap qw(wrap);
use WeBWorK::Utils qw/ decodeAnswers/;

use mod_perl;
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

# request paramaters used
# 
# user
# key
# module
# set (if from ProblemSet or Problem)
# problem (if from Problem)
# displayMode (if from Problem)
# showOldAnswers (if from Problem)
# showCorrectAnswers (if from Problem)
# showHints (if from Problem)
# showSolutions (if from Problem)

# state data sent
# 
# user object for current user
# permission level of current user
# current session key
# which ContentGenerator module called Feedback?
# set object for current set (if from ProblemSet or Problem)
# problem object for current problem (if from Problem)
# display options (if from Problem)

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	
	# get form fields 
	my $key                = $r->param("key");
	my $userName           = $r->param("user");
	my $module             = $r->param("module");
	my $setName            = $r->param("set");
	my $problemNumber      = $r->param("problem");
	my $displayMode        = $r->param("displayMode");
	my $showOldAnswers     = $r->param("showOldAnswers");
	my $showCorrectAnswers = $r->param("showCorrectAnswers");
	my $showHints          = $r->param("showHints");
	my $showSolutions      = $r->param("showSolutions");
	my $from               = $r->param("from");
	my $feedback           = $r->param("feedback");
	my $courseID           = $r->urlpath->arg("courseID");
	
	my ($user, $set, $problem);
	$user = $db->getUser($userName) # checked
		if defined $userName and $userName ne "";
	if (defined $user) {
		$set = $db->getMergedSet($userName, $setName) # checked
			if defined $setName and $setName ne "";
		$problem = $db->getMergedProblem($userName, $setName, $problemNumber) # checked
			if defined $set and defined $problemNumber && $problemNumber ne "";
	} else {
		$set = $db->getGlobalSet($setName) # checked
			if defined $setName and $setName ne "";
		$problem = $db->getGlobalProblem($setName, $problemNumber) # checked
			if defined $set and defined $problemNumber && $problemNumber ne "";
	}
	
	# generate context URLs
	my $emailableURL;
	my $returnURL;
	if ($user) {
		my $modulePath;
		my @args;
		if ($set) {
			if ($problem) {
				$modulePath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::Problem", $r,
					courseID => $r->urlpath->arg("courseID"),
					setID => $set->set_id,
					problemID => $problem->problem_id,
				);
				@args = qw/displayMode showOldAnswers showCorrectAnswers showHints showSolutions/;
			} else {
				$modulePath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet", $r,
					courseID => $r->urlpath->arg("courseID"),
					setID => $set->set_id,
				);
				@args = ();
			}
		} else {
			$modulePath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r,
				courseID => $r->urlpath->arg("courseID"),
			);
			@args = ();
		}
		$emailableURL = $self->systemLink($modulePath,
			authen => 0,
			params => [ "effectiveUser", @args ],
			use_abs_url => 1,
		);
		$returnURL = $self->systemLink($modulePath,
			authen => 1,
			params => [ @args ],
		);
	} else {
		$emailableURL = "(not available)";
		$returnURL = "";
	}
	my $homeModulePath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::Home", $r);
	my $systemURL = $self->systemLink($homeModulePath, authen=>0, use_abs_url=>1);
	
	unless ($authz->hasPermissions($userName, "submit_feedback")) {
		$self->feedbackNotAllowed($returnURL);
		return "";
	}
	
	# determine the recipients of the email
	my @recipients = $self->getFeedbackRecipients($user);
	
	unless (@recipients) {
		$self->noRecipientsAvailable($returnURL);
		return "";
	}
	
	if (defined $r->param("sendFeedback")) {
		# get verbosity level
		my $verbosity = $ce->{mail}->{feedbackVerbosity};
		
		# determine the sender of the email
		my $sender;
		if ($user) {
			if ($user->email_address) {
				$sender = $user->rfc822_mailbox;
			} else {
				if ($user->full_name) {
					$sender = $user->full_name . " <$from>"
				} else {
					$sender = $from;
				}
			}
		} else {
			$sender = $from;
		}
		
		# sanity checks
		unless ($sender) {
			$self->feedbackForm($user, $returnURL,
				"No Sender specified.");
			return "";
		}
		unless ($feedback) {
			$self->feedbackForm($user, $returnURL,
				"Message was blank.");
			return "";
		}
		
		my %subject_map = (
			'c' => $courseID,
			'u' => $user    ? $user->user_id       : undef,
			's' => $set     ? $set->set_id         : undef,
			'p' => $problem ? $problem->problem_id : undef,
			'x' => $user    ? $user->section       : undef,
			'r' => $user    ? $user->recitation    : undef,
			'%' => '%',
		);
		my $chars = join("", keys %subject_map);
		my $subject = $ce->{mail}{feedbackSubjectFormat}
			|| "WeBWorK question from %c: %u set %s/prob %p"; # default if not entered
		$subject =~ s/%([$chars])/defined $subject_map{$1} ? $subject_map{$1} : ""/eg;
		
		# get info about remote user (stolen from &WeBWorK::Authen::write_log_entry)
		my ($remote_host, $remote_port);

		# If its apache 2.4 then it has to also mod perl 2.0 or better
		my $APACHE24 = 0;
		if (MP2) {
		    Apache2::ServerUtil::get_server_banner() =~ 
		      m:^Apache/(\d\.\d+\.\d+):;
		    $APACHE24 = version->parse($1) >= version->parse('2.4.00');
		}
		
		# If its apache 2.4 then the API has changed
		if ($APACHE24) {
		    $remote_host = $r->connection->client_addr->ip_get || "UNKNOWN";
		    $remote_port = $r->connection->client_addr->port || "UNKNOWN";
		} elsif (MP2) {
			$remote_host = $r->connection->remote_addr->ip_get || "UNKNOWN";
			$remote_port = $r->connection->remote_addr->port || "UNKNOWN";
		} else {
			($remote_port, $remote_host) = unpack_sockaddr_in($r->connection->remote_addr);
			$remote_host = defined $remote_host ? inet_ntoa($remote_host) : "UNKNOWN";
			$remote_port = "UNKNOWN" unless defined $remote_port;
		}
		#my $user_agent = $r->headers_in("User-Agent");
		
		my $headers = "X-Remote-Host: $remote_host\n";
		$headers .= "X-WeBWorK-Module: $module\n" if defined $module;
		$headers .= "X-WeBWorK-Course: $courseID\n" if defined $courseID;
		if ($user) {
			$headers .= "X-WeBWorK-User: ".$user->user_id."\n";
			$headers .= "X-WeBWorK-Section: ".$user->section."\n";
			$headers .= "X-WeBWorK-Recitation: ".$user->recitation."\n";
		}
		$headers .= "X-WeBWorK-Set: ".$set->set_id."\n" if $set;
		$headers .= "X-WeBWorK-Problem: ".$problem->problem_id."\n" if $problem;
		
		# bring up a mailer
		my $mailer = Mail::Sender->new({
			from => $ce->{mail}{smtpSender},
			fake_from => $sender,
			to => join(",", @recipients),
			smtp    => $ce->{mail}->{smtpServer},
			subject => $subject,
			headers => $headers,
		});
		unless (ref $mailer) {
			$self->feedbackForm($user, $returnURL,
				"Failed to create a mailer: $Mail::Sender::Error");
			return "";
		}
		unless (ref $mailer->Open()) {
			$self->feedbackForm($user, $returnURL,
				"Failed to open the mailer: $Mail::Sender::Error");
			return "";
		}
		my $MAIL = $mailer->GetHandle();
		
		# print message
		print $MAIL
			wrap("", "", "This  message was automatically generated by the WeBWorK",
				"system at $systemURL, in response to a request from $remote_host:$remote_port."
			), "\n\n";
		
		print $MAIL "Click this link to see the page from which the user sent feedback:\n",
			"$emailableURL\n\n";
		
		if ($feedback) {
			print $MAIL
				"***** The feedback message: *****\n\n",
				wrap("", "", $feedback), "\n\n";
		}
		if ($problem and $verbosity >= 1) {
			print $MAIL
				"***** Data about the problem processor: *****\n\n",

				"Display Mode:         $displayMode\n",
				"Show Old Answers:     " . ($showOldAnswers ? "yes" : "no") . "\n",
				"Show Correct Answers: " . ($showCorrectAnswers ? "yes" : "no") . "\n",
				"Show Hints:           " . ($showHints ? "yes" : "no") . "\n",
				"Show Solutions:       " . ($showSolutions ? "yes" : "no") . "\n\n",
		}
		if ($user and $verbosity >= 1) {
			print $MAIL
				"***** Data about the user: *****\n\n",
				#$user->toString(), "\n\n";
				$self->format_user($user), "\n";
		}
		if ($problem and $verbosity >= 1) {
			print $MAIL
				"***** Data about the problem: *****\n\n",
				#$problem->toString(), "\n\n";
				$self->format_userproblem($problem), "\n";
		}
		if ($set and $verbosity >= 1) {
			print $MAIL
				"***** Data about the homework set: *****\n\n",
				#$set->toString(), "\n\n";
				$self->format_userset($set), "\n";
		}
		if ($ce and $verbosity >= 2) {
			print $MAIL
				"***** Data about the environment: *****\n\n",
				Dumper($ce), "\n\n";
		}
		
		# Close returns the mailer object on success, a negative value on failure,
		# zero if mailer was not opened.
		my $result = $mailer->Close;
		
		if (ref $result) {
			# print confirmation
			print CGI::p("Your message was sent successfully.");
			print CGI::p(CGI::a({-href => $returnURL}, "Return to your work"));
			print CGI::pre(wrap("", "", $feedback));
		} else {
			$self->feedbackForm($user, $returnURL,
				"Failed to send message ($result): $Mail::Sender::Error");
		}
	} else {
		# just print the feedback form, with no message
		$self->feedbackForm($user, $returnURL, "");
	}
	
	return "";
}

sub feedbackNotAllowed {
	my ($self, $returnURL) = @_;
	
	print CGI::p("You are not allowed to send e-mail.");
	print CGI::p(CGI::a({-href=>$returnURL}, "Cancel E-Mail")) if $returnURL;
}

sub noRecipientsAvailable {
	my ($self, $returnURL) = @_;
	
	print CGI::p("No e-mail recipients are listed for this course.");
	print CGI::p(CGI::a({-href=>$returnURL}, "Cancel E-Mail")) if $returnURL;
}
sub title {
	my ($self, $user, $returnURL, $message) = @_;
	my $r = $self->r;
	return $r->maketext("E-mail Instructor");
}
sub feedbackForm {
	my ($self, $user, $returnURL, $message) = @_;
	my $r = $self->r;
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields(qw(
		module set problem displayMode showOldAnswers showCorrectAnswers
		showHints showSolutions
	));
	print CGI::p(CGI::b($r->maketext("From:")), " ",
		($user && $user->email_address
			? CGI::tt($user->email_address)
			: CGI::textfield("from", "", 40))
	);
	print CGI::p("Use this form to report to your professor a problem with the WeBWorK system or an error in a problem you are attempting. Along with your message, additional information about the state of the system will be included.");
	print CGI::p(CGI::i($message)) if $message;
	print CGI::p(
		CGI::b("E-mail:"), CGI::br(),
		CGI::textarea("feedback", "", 20, 80),
	);
	print CGI::submit("sendFeedback", $r->maketext("Send E-mail"));
	print CGI::end_form();
	print CGI::p(CGI::a({-href=>$returnURL}, $r->maketext("Cancel E-mail"))) if $returnURL;
}

sub getFeedbackRecipients {
	my ($self, $user) = @_;
	my $ce = $self->r->ce;
	my $db = $self->r->db;
	my $authz = $self->r->authz;
	
	my @recipients;
	
	# send to all users with permission to receive_feedback and an email address
	# DBFIXME iterator?
	foreach my $rcptName ($db->listUsers()) {
		if ($authz->hasPermissions($rcptName, "receive_feedback")) {
			my $rcpt = $db->getUser($rcptName); # checked
			next if $ce->{feedback_by_section} and defined $user
				and defined $rcpt->section and defined $user->section
				and $rcpt->section ne $user->section;
			if ($rcpt and $rcpt->email_address) {
				push @recipients, $rcpt->rfc822_mailbox;
			}
		}
	}
	
	if (defined $ce->{mail}->{feedbackRecipients}) {
		push @recipients, @{$ce->{mail}->{feedbackRecipients}};
	}
	
	return @recipients;
}

sub format_user {
	my ($self, $User) = @_;
	my $ce = $self->r->ce;
	
	my $result = "User ID:    " . $User->user_id . "\n";
	$result .= "Name:       " . $User->full_name . "\n";
	$result .= "Email:      " . $User->email_address . "\n";
	$result .= "Student ID: " . $User->student_id . "\n";
	
	my $status_name = $ce->status_abbrev_to_name($User->status);
	my $status_string = defined $status_name
		? "$status_name ('" . $User->status . "')"
		: $User->status . " (unknown status abbreviation)";
	$result .= "Status:     $status_string\n";
	
	$result .= "Section:    " . $User->section . "\n";
	$result .= "Recitation: " . $User->recitation . "\n";
	$result .= "Comment:    " . $User->comment . "\n";
	
	return $result;
}

sub format_userset {
	my ($self, $Set) = @_;
	my $ce = $self->r->ce;
	
	my $result = "Set ID:                    " . $Set->set_id . "\n";
	$result .= "Set header file:           " . $Set->set_header . "\n";
	$result .= "Hardcopy header file:      " . $Set->hardcopy_header . "\n";
	
	my $tz = $ce->{siteDefaults}{timezone};
	$result .= "Open date:                 " . $self->formatDateTime($Set->open_date, $tz). "\n";
	$result .= "Due date:                  " . $self->formatDateTime($Set->due_date, $tz). "\n";
	$result .= "Answer date:               " . $self->formatDateTime($Set->answer_date, $tz) . "\n";
	$result .= "Visible:                   " . ($Set->visible ? "yes" : "no") . "\n";
	$result .= "Assignment type:           " . $Set->assignment_type . "\n";
	if ($Set->assignment_type =~ /gateway/) {
		$result .= "Attempts per version:      " . $Set->assignment_type . "\n";
		$result .= "Time interval:             " . $Set->time_interval . "\n";
		$result .= "Versions per interval:     " . $Set->versions_per_interval . "\n";
		$result .= "Version time limit:        " . $Set->version_time_limit . "\n";
		$result .= "Version creation time:     " . $self->formatDateTime($Set->version_creation_time, $tz) . "\n";
		$result .= "Problem randorder:         " . $Set->problem_randorder . "\n";
		$result .= "Version last attempt time: " . $Set->version_last_attempt_time . "\n";
	}
	
	return $result;
}

sub format_userproblem {
	my ($self, $Problem) = @_;
	my $ce = $self->r->ce;
	
	my $result = "Problem ID:                   " . $Problem->problem_id . "\n";
	$result .= "Source file:                  " . $Problem->source_file . "\n";
	$result .= "Value:                        " . $Problem->value . "\n";
	$result .= "Max attempts                  " . ($Problem->max_attempts == -1 ? "unlimited" : $Problem->max_attempts) . "\n";
	$result .= "Random seed:                  " . $Problem->problem_seed . "\n";
	$result .= "Status:                       " . $Problem->status . "\n";
	$result .= "Attempted:                    " . ($Problem->attempted ? "yes" : "no") . "\n";
	
	my %last_answer = decodeAnswers($Problem->last_answer);
	if (%last_answer) {
		$result .= "Last answer:\n";
		foreach my $key (sort keys %last_answer) {
			$result .= "\t$key: $last_answer{$key}\n";
		}
	} else {
		$result .= "Last answer:                  none\n";
	}
	
	$result .= "Number of correct attempts:   " . $Problem->num_correct . "\n";
	$result .= "Number of incorrect attempts: " . $Problem->num_incorrect . "\n";
	
	return $result;
}

1;
