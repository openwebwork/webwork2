################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Options.pm,v 1.24 2006/07/24 23:28:41 gage Exp $
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

package WeBWorK::ContentGenerator::Options;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Options - Change user options.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Utils qw(cryptPassword dequote);
use WeBWorK::Localize;



sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	
	my $userID = $r->param("user");
	my $User = $db->getUser($userID);
	die "record not found for user '$userID'." unless defined $User;
	
	my $eUserID = $r->param('effectiveUser');
	my $EUser = $db->getUser($eUserID); # checked
	die "record not found for effective user '$eUserID'." unless defined $EUser;
	
	my $user_name = $User->first_name . " " . $User->last_name;
	my $e_user_name = $EUser->first_name . " " . $EUser->last_name;
	
	my $changeOptions = $r->param("changeOptions");
	my $currP = $r->param("currPassword");
	my $newP = $r->param("newPassword");
	my $confirmP = $r->param("confirmPassword");
	my $newA = $r->param("newAddress");
		
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	
	print CGI::h2($r->maketext("Change Password"));
	
	my $Password = eval {$db->getPassword($User->user_id)}; # checked
	# Its ok if the $Password doesn't exist because students
	# might be setting it for the first time. 
	warn $r->maketext("Can't get password record for user '[_1]': [_2]",$userID,$@) if $@;
			
	
	if ($changeOptions and ($currP or $newP or $confirmP)) {
		
		if ($authz->hasPermissions($userID, "change_password")) {
			
		  my $EPassword = eval {$db->getPassword($EUser->user_id)}; # checked
		  warn $r->maketext("Can't get password record for effective user '[_1]': [_2]",$eUserID,$@) if $@;

		  #Check that either password is not defined or if it is
		  #defined then we have the right one.  
		  if ((not defined $Password) || (crypt($currP // '', $Password->password) eq $Password->password)) {
		    if ($newP or $confirmP) {
		      if ($newP eq $confirmP) {
			if (not defined $EPassword) {
			  $EPassword = $db->newPassword();
			  $EPassword->user_id($EUser->user_id);
			  $EPassword->password(cryptPassword($newP));
			  eval {$db->addPassword($EPassword)};
			  $Password = $Password // $EPassword;
			  if ($@) {
			    print CGI::div({class=>"ResultsWithError", tabindex=>'-1'},
					   CGI::p($r->maketext("Couldn't change [_1]'s password: [_2]",$e_user_name,$@)));
			  } else {
			    print CGI::div({class=>"ResultsWithoutError"},
					   CGI::p($r->maketext("[_1]'s password has been changed.",$e_user_name)),
					  );
			  }

			} else {
			    
			    $EPassword->password(cryptPassword($newP));
			    eval { $db->putPassword($EPassword) };
			    $Password = $Password // $EPassword;
			    if ($@) {
			      print CGI::div({class=>"ResultsWithError", tabindex=>'-1'},
					     CGI::p($r->maketext("Couldn't change [_1]'s password: [_2]",$e_user_name,$@)));
			    } else {
			      print CGI::div({class=>"ResultsWithoutError"},
					     CGI::p($r->maketext("[_1]'s password has been changed.",$e_user_name)),
					    );
			    }

			  }
		      } else {
			print CGI::div({class=>"ResultsWithError", tabindex=>'-1'},
				       CGI::p(
					      $r->maketext("The passwords you entered in the [_1] and [_2] fields don't match. Please retype your new password and try again.", CGI::b($r->maketext("[_1]'s New Password",$e_user_name)), CGI::b($r->maketext("Confirm [_1]'s New Password",$e_user_name))) 
					     ),
				      );
		      }
		    } else {
		      print CGI::div({class=>"ResultsWithError",tabindex=>'-1'},
				     CGI::p($r->maketext("[_1]'s new password cannot be blank.",$e_user_name)),
					);
		    }
		  } else {
		    print CGI::div({class=>"ResultsWithError",tabindex=>'-1'},
				   CGI::p($r->maketext("The password you entered in the [_1] field does not match your current password. Please retype your current password and try again.", CGI::b($r->maketext("[_1]'s Current Password",$user_name)))
					 ),
				  );
		  }
		  
		} else {
		  print CGI::div({class=>"ResultsWithError",tabindex=>'-1'},
				 CGI::p($r->maketext("You do not have permission to change your password.")))
		    unless $changeOptions and ($currP or $newP or $confirmP); # avoid double message
		}
		
	      }
	
	if ($authz->hasPermissions($userID, "change_password")) {
		print CGI::table({class=>"FormLayout"},
			CGI::Tr({},
				CGI::td(CGI::label({'for'=>'currPassword'},$r->maketext("[_1]'s Current Password",$user_name))),
				CGI::td(CGI::password_field(-name=>"currPassword", -id=>"currPassword", (defined $Password) ? (): (-disabled, 1) )),
			),
			CGI::Tr({},
				CGI::td(CGI::label({'for'=>"newPassword"},$r->maketext("[_1]'s New Password",$e_user_name))),
				CGI::td(CGI::password_field(-name=>"newPassword", -id=>"newPassword")),
			),
			CGI::Tr({},
				CGI::td(CGI::label({'for'=>'confirmPassword'},$r->maketext("Confirm [_1]'s New Password",$e_user_name))),
				CGI::td(CGI::password_field(-name=>"confirmPassword",-id=>"confirmPassword")),
			),
		);
	} else {
		print CGI::p($r->maketext("You do not have permission to change your password."));
	}
	
	print CGI::h2($r->maketext("Change Email Address"));
	
	if ($changeOptions and $newA) {
		if ($authz->hasPermissions($userID, "change_email_address")) {
			
			my $oldA = $EUser->email_address;
			$EUser->email_address($newA);
			eval { $db->putUser($EUser) };
			if ($@) {
				$EUser->email_address($oldA);
				print CGI::div({class=>"ResultsWithError",tabindex=>'-1'},
					CGI::p($r->maketext("Couldn't change your email address: [_1]",$@)),
				);
			} else {
				print CGI::div({class=>"ResultsWithoutError"},
					CGI::p($r->maketext("Your email address has been changed.")),
				);
			}
			
		} else {
			print CGI::div({class=>"ResultsWithError",tabindex=>'-1'},
				CGI::p($r->maketext("You do not have permission to change email addresses.")),
			);
		}
	}
	
	if ($authz->hasPermissions($userID, "change_email_address")) {
		print CGI::table({class=>"FormLayout"},
			CGI::Tr({},
				CGI::td(CGI::label({'for' => 'currAddress'},$r->maketext("[_1]'s Current Address",$e_user_name))),
				CGI::td(CGI::input({ type=>"text", readonly=>"true", id=>"currAddress", name=>"currAddress", value=>$EUser->email_address})),
			),
			CGI::Tr({},
				CGI::td(CGI::label({'for'=>'newAddress'},$r->maketext("[_1]'s New Address",$e_user_name))),
#				CGI::td(CGI::textfield(-name=>"newAddress", -text=>$newA)),
				CGI::td(CGI::textfield(-name=>"newAddress",-id,=>"newAddress")),
			),
		);
	} else {
		print CGI::p($r->maketext("You do not have permission to change email addresses."))
			unless $changeOptions and $newA; # avoid double message
	}
	

	
	print CGI::h2($r->maketext("Change Display Settings"));

	if ($changeOptions) {
	    
	    if ((defined($r->param('displayMode')) &&
			$EUser->displayMode() ne $r->param('displayMode')) ||
		(defined($r->param('showOldAnswers')) &&
			$EUser->showOldAnswers() ne $r->param('showOldAnswers')) ||
		(defined($r->param('useMathView')) && 
			 $EUser->useMathView() ne $r->param('useMathView'))) {
		
		$EUser->displayMode($r->param('displayMode'));
		$EUser->showOldAnswers($r->param('showOldAnswers'));
		$EUser->useMathView($r->param('useMathView'));
		
		eval { $db->putUser($EUser) };
		if ($@) {
		    print CGI::div({class=>"ResultsWithError",tabindex=>'-1'},
				   CGI::p($r->maketext("Couldn't save your display options: [_1]",$@)),
			);
		} else {
		    print CGI::div({class=>"ResultsWithoutError"},
				   CGI::p($r->maketext("Your display options have been saved.")),
			);
		}
	    }

	    if ((defined($r->param('displayMode')) &&
			$EUser->displayMode() ne $r->param('displayMode')) ||
		(defined($r->param('showOldAnswers')) &&
			$EUser->showOldAnswers() ne $r->param('showOldAnswers')) ||
		(defined($r->param('useWirisEditor')) && 
			 $EUser->useWirisEditor() ne $r->param('useWirisEditor')) ||
		(defined($r->param('useMathQuill')) && 
			 $EUser->useMathQuill() ne $r->param('useMathQuill'))) {		
		$EUser->displayMode($r->param('displayMode'));
		$EUser->showOldAnswers($r->param('showOldAnswers'));
		$EUser->useWirisEditor($r->param('useWirisEditor'));
		$EUser->useMathQuill($r->param('useMathQuill'));
		
		eval { $db->putUser($EUser) };
		if ($@) {
		    print CGI::div({class=>"ResultsWithError",tabindex=>'-1'},
				   CGI::p($r->maketext("Couldn't save your display options: [_1]",$@)),
			);
		} else {
		    print CGI::div({class=>"ResultsWithoutError"},
				   CGI::p($r->maketext("Your display options have been saved.")),
			);
		}
	    }
	}
	
	my $result = '';

	
	my $curr_displayMode = $EUser->displayMode || $ce->{pg}->{options}->{displayMode};
	my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
	my @active_modes = grep { exists $display_modes{$_} } @{$ce->{pg}->{displayModes}};

	if (@active_modes > 1) {
	    $result .= CGI::start_fieldset();
	    $result .= CGI::legend($r->maketext("View equations as").":");
	    $result .= CGI::radio_group(
		-name => "displayMode",
		-values => \@active_modes,
		-default => $curr_displayMode,
		);
	    $result .= CGI::end_fieldset();
	    $result .= CGI::br();
	}

	if ($authz->hasPermissions($userID,"can_show_old_answers")) {
	    my $curr_showOldAnswers = $EUser->showOldAnswers ne '' ? $EUser->showOldAnswers : $ce->{pg}->{options}->{showOldAnswers};
	    $result .= CGI::start_fieldset();
	    $result .= CGI::legend($r->maketext("Show saved answers?"));
	    $result .= CGI::radio_group(
		-name => "showOldAnswers",
		-values => [1,0],
		-default => $curr_showOldAnswers,
		-labels => { 0=>$r->maketext('No'), 1=>$r->maketext('Yes') },
		);
	    $result .= CGI::end_fieldset();
	    $result .= CGI::br();
	}

	if ($ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathView') {
	    # Note, 0 is a legal value, so we can't use || in setting this
	    my $curr_useMathView = $EUser->useMathView ne '' ?
		$EUser->useMathView : $ce->{pg}->{options}->{useMathView};
	    $result .= CGI::start_fieldset();
	    $result .= CGI::legend($r->maketext("Use Equation Editor?"));
	    $result .= CGI::radio_group(
		-name => "useMathView",
		-values => [1,0],
		-default => $curr_useMathView,
		-labels => { 0=>$r->maketext('No'), 1=>$r->maketext('Yes') },
		);
	    $result .= CGI::end_fieldset();
	    $result .= CGI::br();
	}

	if ($ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'WIRIS') {
	    # Note, 0 is a legal value, so we can't use || in setting this
	    my $curr_useWirisEditor = $EUser->useWirisEditor ne '' ?
		$EUser->useWirisEditor : $ce->{pg}->{options}->{useWirisEditor};
	    $result .= CGI::start_fieldset();
	    $result .= CGI::legend($r->maketext("Use Equation Editor?"));
	    $result .= CGI::radio_group(
		-name => "useWirisEditor",
		-values => [1,0],
		-default => $curr_useWirisEditor,
		-labels => { 0=>$r->maketext('No'), 1=>$r->maketext('Yes') },
		);
	    $result .= CGI::end_fieldset();
	    $result .= CGI::br();
	}

	if ($ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathQuill') {
	    # Note, 0 is a legal value, so we can't use || in setting this
	    my $curr_useMathQuill = $EUser->useMathQuill ne '' ?
		$EUser->useMathQuill : $ce->{pg}->{options}->{useMathQuill};
	    $result .= CGI::start_fieldset();
	    $result .= CGI::legend($r->maketext("Use live equation rendering?"));
	    $result .= CGI::radio_group(
		-name => "useMathQuill",
		-values => [1,0],
		-default => $curr_useMathQuill,
		-labels => { 0=>$r->maketext('No'), 1=>$r->maketext('Yes') },
		);
	    $result .= CGI::end_fieldset();
	    $result .= CGI::br();
	}
	
	print CGI::p($result);
	print CGI::br();
	print CGI::submit("changeOptions", $r->maketext("Change User Settings"));
	print CGI::end_form();
	
	return "";
}

1;
