################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Feedback.pm,v 1.21 2004/03/15 04:10:36 sh002i Exp $
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
use CGI::Pretty qw();
use Mail::Sender;
use Text::Wrap qw(wrap);

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
	
	# get some network settings
	my $hostname = $r->hostname();
	my $port     = $r->get_server_port();
	my $remoteIdent = $r->get_remote_logname() || "UNKNOWN";
	my $remoteHost = $r->get_remote_host();
	
	# generate context URLs
	my $emailableURL;
	my $returnURL;
	if ($user) {
		my $modulePath;
		my @args;
		if ($set) {
			if ($problem) {
				$modulePath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
					courseID => $r->urlpath->arg("courseID"),
					setID => $set->set_id,
					problemID => $problem->problem_id,
				);
				@args = qw/displayMode showOldAnswers showCorrectAnswers showHints showSolutions/;
			} else {
				$modulePath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
					courseID => $r->urlpath->arg("courseID"),
					setID => $set->set_id,
				);
				@args = ();
			}
		} else {
			$modulePath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",
				courseID => $r->urlpath->arg("courseID"),
			);
			@args = ();
		}
		my $URL;
		if($port == 443) { # for secure servers
			$URL = "https://$hostname";
		} else {
			$URL = "http://$hostname:$port"; # FIXME: there should probably be an option for adding this stuff in systemLink()
		}
		$emailableURL = $URL . $self->systemLink($modulePath,
			authen => 0,
			params => [ "effectiveUser", @args ],
		);
		$returnURL = $URL . $self->systemLink($modulePath,
			authen => 1,
			params => [ @args ],
		);
	} else {
		$emailableURL = "(not available)";
		$returnURL = "";
	}
	
	if (defined $r->param("sendFeedback")) {
		# get verbosity level
		my $verbosity = $ce->{mail}->{feedbackVerbosity};
		
		# determine the sender of the email
		my $sender = ($user && $user->email_address
			? $user->email_address
			: $from);
		
		# determine the recipients of the email
		my @recipients;
		if (defined $ce->{mail}->{feedbackRecipients}) {
			@recipients = @{$ce->{mail}->{feedbackRecipients}};
		} else {
			# send to all professors and TAs
			foreach my $rcptName ($db->listUsers()) {
				my $rcptPerm = $db->getPermissionLevel($rcptName); # checked
				next unless $rcptPerm;
				if ($rcptPerm->permission() == 5 or $rcptPerm->permission() == 10) {
					my $rcpt = $db->getUser($rcptName); # checked
					if ($rcpt and $rcpt->email_address) {
						push @recipients, $rcpt->email_address;
					}
				}
			}
		}
		
		# sanity checks
		unless ($sender) {
			$self->feedbackForm($user, $returnURL,
				"No Sender specified.");
			return "";
		}
		unless (@recipients) {
			$self->feedbackForm($user, $returnURL,
				"No recipients specified.");
			return "";
		}
		unless ($feedback) {
			$self->feedbackForm($user, $returnURL,
				"Message was blank.");
			return "";
		}
		
		# bring up a mailer
		my $mailer = Mail::Sender->new({
			from => $sender,
			to => join(",", @recipients),
			# *** we might want to have a CE setting for
			# "additional recipients"
			smtp    => $ce->{mail}->{smtpServer},
			subject => "WeBWorK feedback: ".$user->first_name." ".$user->last_name. 
			                (   ( defined($setName) && defined($problemNumber) ) ?
			                				 " set$setName/prob$problemNumber" : ""
			                ),
			headers => "X-Remote-Host: ".$r->get_remote_host(),
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
			wrap("", "", "This feedback message was automatically",
			     "generated by the WeBWorK system at",
			     "$hostname:$port, in response to a request from",
			     "$remoteIdent\@$remoteHost."), "\n\n";
		print $MAIL "Context: $emailableURL\n\n";
		
		if ($feedback) {
			print $MAIL
				"***** The feedback message: *****\n\n",
				wrap("", "", $feedback), "\n\n";
		}
		if ($problem and $verbosity >= 1) {
			print $MAIL
				"***** Data about the problem processor: *****\n\n",

				"Display Mode:         $displayMode\n",
				"Show Old Answers?     $showOldAnswers\n",
				"Show Correct Answers? $showCorrectAnswers\n",
				"Show Hints?           $showHints\n",
				"Show Solutions?       $showSolutions\n\n",
		}
		if ($user and $verbosity >= 1) {
			print $MAIL
				"***** Data about the user: *****\n\n",
				$user->toString(), "\n\n";
		
		}
		if ($problem and $verbosity >= 1) {
			print $MAIL
				"***** Data about the problem: *****\n\n",
				$problem->toString(), "\n\n";
		
		}
		if ($set and $verbosity >= 1) {
			print $MAIL
				"***** Data about the problem set: *****\n\n",
				$set->toString(), "\n\n";
		
		}
		if ($ce and $verbosity >= 2) {
			print $MAIL
				"***** Data about the environment: *****\n\n",
				Dumper($ce), "\n\n";
		
		}
		
		# end the message
		close $MAIL;
		
		# print confirmation
		print CGI::p("Your message was sent successfully.");
		print CGI::p(CGI::a({-href => $returnURL}, "Return to your work"));
		print CGI::pre(wrap("", "", $feedback));
	} else {
		# just print the feedback form, with no message
		$self->feedbackForm($user, $returnURL, "");
	}
	
	return "";
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
	print CGI::p(CGI::b("From:"), " ",
		($user && $user->email_address
			? CGI::tt($user->email_address)
			: CGI::textfield("from", "", 40))
	);
	print CGI::p("Use this form to report to your professor a
		problem with the WeBWorK system or an error in a problem
		you are attempting. Along with your message, additional
		information about the state of the system will be
		included.");
	print CGI::p(CGI::i($message)) if $message;
	print CGI::p(
		CGI::b("Feedback:"), CGI::br(),
		CGI::textarea("feedback", "", 20, 80),
	);
	print CGI::submit("sendFeedback", "Send Feedback");
	print CGI::end_form();
	print CGI::p(CGI::a({-href=>$returnURL}, "Cancel Feedback"));
}

1;
