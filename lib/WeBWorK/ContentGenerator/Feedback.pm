################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
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
use CGI qw();
use Mail::Sender;
use Text::Wrap qw(wrap);
use WeBWorK::Utils qw(dequoteHere wrapText);

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

sub path {
	my ($self, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		"Feedback" => "",
	);
}

sub title {
	return "Feedback";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	
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
	
	my $permissionLevel = ($userName
		? $db->getPermissionLevel($userName)->permission()
		: undef);
	my $user = (defined $userName && $userName ne ""
		? $db->getUser($userName)
		: undef);
	my $set = (defined $setName && $setName ne ""
		? $db->getGlobalUserSet($userName, $setName)
		: undef);
	my $problem = (defined $setName && $setName ne ""
	               && defined $problemNumber && $problemNumber ne ""
		? $db->getGlobalUserProblem($userName, $setName, $problemNumber)
		: undef);
	
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
				my $rcptPerm = $db->getPermissionLevel($rcptName);
				next unless $rcptPerm;
				if ($rcptPerm->permission() == 5 or $rcptPerm->permission() == 10) {
					my $rcpt = $db->getUser($rcptName);
					if ($rcpt->email_address) {
						push @recipients, $rcpt->email_address;
					}
				}
			}
		}
		
		# sanity checks
		unless ($sender) {
			$self->feedbackForm($user,
				"No Sender specified.");
			return "";
		}
		unless (@recipients) {
			$self->feedbackForm($user,
				"No recipients specified.");
			return "";
		}
		
		# get some network settings
		my $hostname = $r->hostname();
		my $port     = $r->get_server_port();
		my $remoteIdent = $r->get_remote_logname() || "UNKNOWN";
		my $remoteHost = $r->get_remote_host();
		
		# generate context URL
		my $URL;
		if ($user) {
			$URL = "http://$hostname:$port"
				. $ce->{webworkURLs}->{root}
				. "/" . $ce->{courseName}
				. ($set 
					? "/".$problem->set_id . ($problem ? "/".$problem->problem_id : "")
					: "")
				. "/" . "?effectiveUser=$userName"
				. ($problem 
					? "&displayMode=$displayMode" 
					. "&showOldAnswers=$showOldAnswers"
					. "&showCorrectAnswers=$showCorrectAnswers"
					. "&showHints=$showHints"
					. "&showSolutions=$showSolutions" 
					: "" );
		} else {
			$URL = "(not available)";
		}
		
		# bring up a mailer
		my $mailer = Mail::Sender->new({
			from => $sender,
			to => join(",", @recipients),
			# *** we might want to have a CE setting for
			# "additional recipients"
			smtp    => $ce->{mail}->{smtpServer},
			subject => "Feedback from the WeBWorK system",
			headers => "X-Remote-Host: ".$r->get_remote_host(),
		});
		unless (ref $mailer) {
			$self->feedbackForm($user,
				"Failed to create a mailer: $Mail::Sender::Error");
			return "";
		}
		unless (ref $mailer->Open()) {
			$self->feedbackForm($user,
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
		print $MAIL "Context: $URL\n\n";
		
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
	} else {
		# just print the feedback form, with no message
		$self->feedbackForm($user);
	}
	
	return "";
}

sub feedbackForm($;$$) {
	my ($self, $user, $message) = @_;
	my $r = $self->{r};
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_state_fields($r);
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
		CGI::textarea("feedback", "", 10, 50),
	);
	print CGI::submit("sendFeedback", "Send Feedback");
	print CGI::end_form();
}

sub hidden_state_fields($) {
	my $self = shift;
	my $r = $self->{r};
	
	print CGI::hidden("$_", $r->param("$_"))
		foreach (qw(module set problem displayMode showOldAnswers
		            showCorrectAnswers showHints showSolutions));
}

1;
