################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Hardcopy.pm,v 1.102 2009/09/25 00:39:49 gage Exp $
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

package WeBWorK::ContentGenerator::Hardcopy;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Hardcopy - generate printable versions of one or more
problem sets.

=cut

use strict;
use warnings;

#use Apache::Constants qw/:common REDIRECT/;
#use CGI qw(-nosticky );
use WeBWorK::CGI;

use File::Path;
use File::Temp qw/tempdir/;
use String::ShellQuote;
use WeBWorK::DB::Utils qw/user2global/;
use WeBWorK::Debug;
use WeBWorK::Form;
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;
use WeBWorK::PG;
use WeBWorK::Utils qw/readFile decodeAnswers jitar_id_to_seq is_restricted after/;
use PGrandom;

=head1 CONFIGURATION VARIABLES

=over

=item $PreserveTempFiles

If true, don't delete temporary files.

=cut

our $PreserveTempFiles = 0 unless defined $PreserveTempFiles;

=back

=cut

our $HC_DEFAULT_FORMAT = "pdf"; # problems if this is not an allowed format for the user...
our %HC_FORMATS = (
	tex => { name => "TeX Source", subr => "generate_hardcopy_tex" },
	pdf => { name => "Adobe PDF",  subr => "generate_hardcopy_pdf" },
# Not ready for prime time
#	tikz =>{ name => "TikZ PDF file", subr => "generate_hardcopy_tigz"},
);

# custom fields used in $self hash
# FOR HEAVEN'S SAKE, PLEASE KEEP THIS UP-TO-DATE!
# 
# final_file_url
#   contains the URL of the final hardcopy file generated
#   set by generate_hardcopy(), used by pre_header_initialize() and body()
# 
# temp_file_map
#   reference to a hash mapping temporary file names to URL
#   set by pre_header_initialize(), used by body()
# 
# hardcopy_errors
#   reference to array containing HTML strings describing generation errors (and warnings)
#   used by add_errors(), get_errors(), get_errors_ref()
# 
# at_least_one_problem_rendered_without_error
#   set to a true value by write_problem_tex if it is able to sucessfully render
#   a problem. checked by generate_hardcopy to determine whether to continue
#   with the generation process.
#
# versioned
#   set to a true value in write_set_tex if the set_id indicates that 
#   the set being rendered is a versioned set; this is used in 
#   write_problem_tex to determine which problem merging routine from 
#   DB.pm to use, and to indicate what problem number in a versioned 
#   test we're on
#
# mergedSets
#   a reference to a hash { userID!setID => setObject }, where setID is 
#   either the set id or the fake versioned set id "setName,vN" depending 
#   on whether the set is a versioned set or not.  this may include the 
#   sets for which the hardcopy is being generated (or may not), depending
#   on whether they were needed to determine the required permissions for 
#   generating a hardcopy
#
# canShowScore
#   a reference to a hash { userID!setID => boolean }, where setID is either 
#   the set id or the fake versioned set id "setName,vN" depending on whether 
#   the set is a versioned set or not, and the value of the boolean is 
#   determined by the corresponding userSet's value of hide_score and the 
#   current time

################################################################################
# UI subroutines
################################################################################

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	
	my $userID = $r->param("user");
	my $eUserID = $r->param("effectiveUser");
	my @setIDs = $r->param("selected_sets");
	my @userIDs = $r->param("selected_users");
	my $hardcopy_format = $r->param("hardcopy_format");
	my $generate_hardcopy = $r->param("generate_hardcopy");
	my $send_existing_hardcopy = $r->param("send_existing_hardcopy");
	my $final_file_url = $r->param("final_file_url");
	
	# if there's an existing hardcopy file that can be sent, get set up to do that
	if ($send_existing_hardcopy) {
		$self->reply_with_redirect($final_file_url);
		$self->{final_file_url} = $final_file_url;
		$self->{send_hardcopy} = 1;
		return;
	}

	# this should never happen, but apparently it did once (see bug #714), so we check for it
	die "Parameter 'user' not defined -- this should never happen" unless defined $userID;
	
	if ($generate_hardcopy) {
		my $validation_failed = 0;
		
		# set default format
		$hardcopy_format = $HC_DEFAULT_FORMAT unless defined $hardcopy_format;
		
		# make sure format is valid
		unless (grep { $_ eq $hardcopy_format } keys %HC_FORMATS) {
			$self->addbadmessage("'$hardcopy_format' is not a valid hardcopy format.");
			$validation_failed = 1;
		}
		
		# make sure we are allowed to generate hardcopy in this format
		unless ($authz->hasPermissions($userID, "download_hardcopy_format_$hardcopy_format")) {
			$self->addbadmessage("You do not have permission to generate hardcopy in $hardcopy_format format.");
			$validation_failed = 1;
		}
		
		# is there at least one user and set selected?
		unless (@userIDs) {
			$self->addbadmessage("Please select at least one user and try again.");
			$validation_failed = 1;
		}	

# when students don't select any sets the size of @setIDs is 1 with a null character in $setIDs[0].
# when professors don't select any sets the size of @setIDs is 0. 
# the following test "unless ((@setIDs) and ($setIDs[0] =~ /\S+/))" catches both cases and prevents
# warning messages in the case of a professor's empty array.
		unless ((@setIDs) and ($setIDs[0] =~ /\S+/)) {
			$self->addbadmessage("Please select at least one set and try again.");
			$validation_failed = 1;			
		}
		
		# is the user allowed to request multiple sets/users at a time?
		my $perm_multiset = $authz->hasPermissions($userID, "download_hardcopy_multiset");
		my $perm_multiuser = $authz->hasPermissions($userID, "download_hardcopy_multiuser");
		
		my $perm_viewhidden = $authz->hasPermissions($userID, "view_hidden_work");
		my $perm_viewfromip = $authz->hasPermissions($userID, "view_ip_restricted_sets");
		
		my $perm_viewunopened =  $authz->hasPermissions($userID, "view_unopened_sets");

		if (@setIDs > 1 and not $perm_multiset) {
			$self->addbadmessage("You are not permitted to generate hardcopy for multiple sets. Please select a single set and try again.");
			$validation_failed = 1;
		}
		if (@userIDs > 1 and not $perm_multiuser) {
			$self->addbadmessage("You are not permitted to generate hardcopy for multiple users. Please select a single user and try again.");
			$validation_failed = 1;
		}
		if (@userIDs and $userIDs[0] ne $eUserID and not $perm_multiuser) {
			$self->addbadmessage("You are not permitted to generate hardcopy for other users.");
			$validation_failed = 1;
			# FIXME -- download_hardcopy_multiuser controls both whether a user can generate hardcopy
			# that contains sets for multiple users AND whether she can generate hardcopy that contains
			# sets for users other than herself. should these be separate permission levels?
		}

		# to check if the set has a "hide_work" flag, or if we aren't
		#    allowed to view the set from the user's IP address, we 
		#    need the userset objects; if we've not failed validation 
		#    yet, get those to check on this
		my %canShowScore = ();
		my %mergedSets = ();
		unless ($validation_failed ) {
			foreach my $sid ( @setIDs ) {
				my($s,undef,$v) = ($sid =~ /([^,]+)(,v(\d+))?$/);
				foreach my $uid ( @userIDs ) {
					if ( $perm_viewhidden && $perm_viewfromip ) { 
						$canShowScore{"$uid!$sid"} = 1;
					} else {
						my $userSet;
						if ( defined($v) ) {
							$userSet = $db->getMergedSetVersion($uid,$s,$v);
						} else {
							$userSet = $db->getMergedSet($uid,$s);
						}
						$mergedSets{"$uid!$sid"} = $userSet;

						if ( ! $perm_viewunopened && 						     
						     ! (time >= $userSet->open_date && !(
										      $ce->{options}{enableConditionalRelease} && 
											is_restricted($db, $userSet, $userID)))) {
						    $validation_failed = 1;
						    $self->addbadmessage("You are not permitted to generate a hardcopy for an unopened set.");
						    last;

						}


						if ( ! $perm_viewhidden &&
						     defined( $userSet->hide_work ) &&
						     ( $userSet->hide_work eq 'Y' ||
						       ( $userSet->hide_work eq 'BeforeAnswerDate' &&
							 time < $userSet->answer_date ) ) ) {
							$validation_failed = 1;
							$self->addbadmessage("You are not permitted to generate a hardcopy for a set with hidden work.");
							last;
						}

						if ( $authz->invalidIPAddress($userSet) ) {
							$validation_failed = 1;
							$self->addbadmessage("You are not allowed to generate a " .
									     "hardcopy for " . $userSet->set_id . 
									     " from your IP address, " .
									     $r->connection->remote_ip . ".");
							last;
						}

						$canShowScore{"$uid!$sid"} = 
						    ( ! defined( $userSet->hide_score ) ||
						      $userSet->hide_score eq '' ) ||
							( $userSet ->hide_score eq 'N' ||
							  ( $userSet->hide_score eq 'BeforeAnswerDate' &&
							    time >= $userSet->answer_date ) );
# 	die("hide_score = ", $userSet->hide_score, "; canshow{$uid!$sid} = ", (($canShowScore{"$uid!$sid"})?"True":"False"), "\n");

					}
					last if $validation_failed;
				}
			}
		}
		
		unless ($validation_failed) {
			$self->{canShowScore} = \%canShowScore;
			$self->{mergedSets} = \%mergedSets;
			my ($final_file_url, %temp_file_map) = $self->generate_hardcopy($hardcopy_format, \@userIDs, \@setIDs);
			if ($self->get_errors) {
				# store the URLs in self hash so that body() can make a link to it
				$self->{final_file_url} = $final_file_url;
				$self->{temp_file_map} = \%temp_file_map;
			} else {
				# send the file only
				$self->reply_with_redirect($final_file_url);
			}
		}
	}
}

sub body {
	my ($self) = @_;
	my $userID = $self->r->param("user");
	my $perm_view_errors = $self->r->authz->hasPermissions($userID, "download_hardcopy_view_errors");
	$perm_view_errors = (defined($perm_view_errors) ) ? $perm_view_errors : 0;
	if (my $num = $self->get_errors) {
		my $final_file_url = $self->{final_file_url};
		my %temp_file_map = %{$self->{temp_file_map}};
		if($perm_view_errors) {
			my $errors_str = $num > 1 ? "errors" : "error";
			print CGI::p("$num $errors_str occured while generating hardcopy:");
			
			print CGI::ul(CGI::li($self->get_errors_ref));
		}
		
		if ($final_file_url) {
			print CGI::p(
				"A hardcopy file was generated, but it may not be complete or correct.", 
				"Please check that no problems are missing and that they are all legible." , 
				"If not, please inform your instructor.<br />",
				CGI::a({href=>$final_file_url}, "Download Hardcopy"),
			);
		} else {
			print CGI::p(
				"WeBWorK was unable to generate a paper copy of this homework set.  Please inform your instructor. "
			); 
		
		}
		if($perm_view_errors) {
			if (%temp_file_map) {
				print CGI::start_p();
				print "You can also examine the following temporary files: ";
				my $first = 1;
				while (my ($temp_file_name, $temp_file_url) = each %temp_file_map) {
					if ($first) {
						$first = 0;
					} else {
						print ", ";
					}
					print CGI::a({href=>$temp_file_url}, " $temp_file_name");
				}
				print CGI::end_p();
			}
		}
		
		print CGI::hr();
	}

	# don't display the retry form if there are errors and the user doesn't have permission to view the errors.
	unless ($self->get_errors and not $perm_view_errors) {
		$self->display_form();
	}
	''; # return a blank
}

sub display_form {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $authz = $r->authz;
	my $userID = $r->param("user");
	my $eUserID = $r->param("effectiveUser");
	
	# first time we show up here, fill in some values
	unless ($r->param("in_hc_form")) {
		# if a set was passed in via the path_info, add that to the list of sets.
		my $singleSet = $r->urlpath->arg("setID");
		if (defined $singleSet and $singleSet ne "") {
			my @selected_sets = $r->param("selected_sets");
			$r->param("selected_sets" => [ @selected_sets, $singleSet]) unless grep { $_ eq $singleSet } @selected_sets;
		}
		
		# if no users are selected, select the effective user
		my @selected_users = $r->param("selected_users");
		unless (@selected_users) {
			$r->param("selected_users" => $eUserID);
		}
	}
	
	my $perm_multiset = $authz->hasPermissions($userID, "download_hardcopy_multiset");
	my $perm_multiuser = $authz->hasPermissions($userID, "download_hardcopy_multiuser");
	my $perm_texformat = $authz->hasPermissions($userID, "download_hardcopy_format_tex");
	my $perm_unopened = $authz->hasPermissions($userID, "view_unopened_sets");
	my $perm_view_hidden = $authz->hasPermissions($userID, "view_hidden_sets");
	my $perm_view_answers = $authz->hasPermissions($userID, "show_correct_answers_before_answer_date");
        my $perm_view_solutions = $authz->hasPermissions($userID, "show_solutions_before_answer_date");
	
	# get formats
	my @formats;
	foreach my $format (keys %HC_FORMATS) {
		push @formats, $format if $authz->hasPermissions($userID, "download_hardcopy_format_$format");
	}
	
	# get format names hash for radio buttons
	my %format_labels = map { $_ => $r->maketext($HC_FORMATS{$_}{name}) || $_ } @formats;
	
	# get users for selection
	my @Users;
	if ($perm_multiuser) {
		# if we're allowed to select multiple users, get all the users
		# DBFIXME shouldn't need to pass list of users, should use iterator for results?
		@Users = $db->getUsers($db->listUsers);
	} else {
		# otherwise, we get our own record only
		@Users = $db->getUser($eUserID);
	}
	
	# get sets for selection
	# DBFIXME should use WHERE clause to filter on open_date and visible, rather then getting all
	my @globalSetIDs;
	my @GlobalSets;
	if ($perm_multiuser) {
		# if we're allowed to select sets for multiple users, get all sets.
		@globalSetIDs = $db->listGlobalSets;
		@GlobalSets = $db->getGlobalSets(@globalSetIDs);
	} else {
		# otherwise, only get the sets assigned to the effective user.
		# note that we are getting GlobalSets, but using the list of UserSets assigned to the
		# effective user. this is because if we pass UserSets  to ScrollingRecordList it will
		# give us composite IDs back, which is a pain in the ass to deal with.
		@globalSetIDs = $db->listUserSets($eUserID);
		@GlobalSets = $db->getGlobalSets(@globalSetIDs);
	}
	# we also want to get the versioned sets for this user
	# FIXME: this is another place where we assume that there is a 
	#    one-to-one correspondence between assignment_type =~ gateway
	#    and versioned sets.  I think we really should have a 
	#    "is_versioned" flag on set objects instead.
	my @versionedSets = grep {$_->assignment_type =~ /gateway/} @GlobalSets;
	my @SetVersions = ();
	foreach my $v (@versionedSets) {
		my @usv = map { [$eUserID, $v->set_id, $_] } ( $db->listSetVersions( $eUserID, $v->set_id ) );
		push( @SetVersions, $db->getSetVersions( @usv ) );
	}
	# FIXME: this is a hideous, horrible hack.  the identifying key for 
	#    a global set is the set_id.  those for a set version are the 
	#    set_id and version_id.  but this means that we have trouble 
	#    displaying them both together in HTML::scrollingRecordList.  
	#    so we brutally play tricks with the set_id here, which probably
	#    is not very robust, and certainly is aesthetically displeasing.
	#    yuck.
	foreach ( @SetVersions ) { 
		$_->set_id($_->set_id . ",v" . $_->version_id); 
	}
	
	# filter out unwanted sets
	my @WantedGlobalSets;
	foreach my $i (0 .. $#GlobalSets) {
		my $Set = $GlobalSets[$i];
		unless (defined $Set) {
			warn "\$GlobalSets[$i] (ID $globalSetIDs[$i]) not defined -- skipping";
			next;
		}
		next unless $Set->open_date <= time or $perm_unopened;
		next unless $Set->visible or $perm_view_hidden;
		# also skip gateway sets, for which we have to have a 
		#    version to print something
		next if $Set->assignment_type =~ /gateway/;
		push @WantedGlobalSets, $Set;
	}
	
	my $scrolling_user_list = scrollingRecordList({
		name => "selected_users",
		request => $r,
		default_sort => "lnfn",
		default_format => "lnfn_uid",
		default_filters => ["all"],
		size => 20,
		multiple => $perm_multiuser,
	}, @Users);
	
	my $scrolling_set_list = scrollingRecordList({
		name => "selected_sets",
		request => $r,
		default_sort => "set_id",
		default_format => "sid",
		default_filters => ["all"],
		size => 20,
		multiple => $perm_multiset,
	}, @WantedGlobalSets, @SetVersions );
	
	# we change the text a little bit depending on whether the user has multiuser privileges
	my $ss = $perm_multiuser ? "s" : "";
	my $aa = $perm_multiuser ? " " : " a ";
	my $phrase_for_privileged_users = $perm_multiuser ? "to privileged users or" : "";
	my $button_label = $perm_multiuser ? $r->maketext("Generate hardcopy for selected sets and selected users") : $r->maketext("Generate Hardcopy");
	
# 	print CGI::start_p();
# 	print "Select the homework set$ss for which to generate${aa}hardcopy version$ss.";
# 	if ($authz->hasPermissions($userID, "download_hardcopy_multiuser")) {
# 		print "You may also select multiple users from the users list. You will receive hardcopy for each (set, user) pair.";
# 	}
# 	print CGI::end_p();
	
	print CGI::start_form(-name=>"hardcopy-form", -id=>"hardcopy-form", -method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields();
	print CGI::hidden("in_hc_form", 1);
	
	my $canShowCorrectAnswers = 0;
	my $canShowSolutions = 0;

	if ($perm_multiuser and $perm_multiset) {
		print CGI::p($r->maketext("Select the homework sets for which to generate hardcopy versions. You may"
		      ." also select multiple users from the users list. You will receive hardcopy" 
		      ." for each (set, user) pair."));
		
		print CGI::table({class=>"FormLayout"},
			CGI::Tr({},
				CGI::th($r->maketext("Users")),
				CGI::th($r->maketext("Sets")),
			),
			CGI::Tr({},
				CGI::td($scrolling_user_list),
				CGI::td($scrolling_set_list),
			),
		);
		
		$canShowCorrectAnswers = 1;
		$canShowSolutions = 1;

	} else { # single user mode
		#FIXME -- do a better job of getting the set and the user when in the single set mode
		my $selected_set_id = $r->param("selected_sets");
		$selected_set_id = '' unless defined $selected_set_id;

		my $selected_user_id = $Users[0]->user_id;
		print CGI::hidden("selected_sets",   $selected_set_id ),
		      CGI::hidden( "selected_users", $selected_user_id);

		my $mergedSet = $db->getMergedSet($selected_user_id,
						  $selected_set_id);

	        # make display for versioned sets a bit nicer
		$selected_set_id =~ s/,v(\d+)$/ (test $1)/;
	
		# FIXME!	
		print CGI::p($r->maketext("Download hardcopy of set [_1] for [_2]?", $selected_set_id, $Users[0]->first_name." ".$Users[0]->last_name));
		
		$canShowCorrectAnswers = $perm_view_answers ||
		    (defined($mergedSet) && after($mergedSet->answer_date));

		$canShowSolutions = $perm_view_answers ||
		    (defined($mergedSet) && after($mergedSet->answer_date));

	
	}

	    

	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::td({colspan=>2, class=>"ButtonRow"},
				# FIXME!
				CGI::small($r->maketext("You may choose to show any of the following data. Correct answers, hints, and solutions are only available [_1] after the answer date of the homework set.", $phrase_for_privileged_users)),
				CGI::br(),
				CGI::b($r->maketext("Show:")), " ",
				CGI::checkbox(
					-name    => "printStudentAnswers",
					-checked => defined($r->param("printStudentAnswers"))? $r->param("printStudentAnswers") : 1, # checked by default
					-label   => $r->maketext("Student answers"),
				),
				$canShowCorrectAnswers ? 
				CGI::checkbox(
					-name    => "showCorrectAnswers",
					-checked => scalar($r->param("showCorrectAnswers")) || 0,
					-label   => $r->maketext("Correct answers"),
				) : '',
				$canShowSolutions ? 
				CGI::checkbox(
					-name    => "showHints",
					-checked => scalar($r->param("showHints")) || 0,
					-label   => $r->maketext("Hints"),
				) : '',
				$canShowSolutions ? 
				CGI::checkbox(
					-name    => "showSolutions",
					-checked => scalar($r->param("showSolutions")) || 0,
					-label   => $r->maketext("Solutions"),
				) : '',
			),
		),
		CGI::Tr({},
			CGI::td({colspan=>2, class=>"ButtonRow"},
				CGI::b("Hardcopy Format:"), " ",
				CGI::radio_group(
					-name    => "hardcopy_format",
					-values  => \@formats,
					-default => scalar($r->param("hardcopy_format")) || $HC_DEFAULT_FORMAT,
					-labels  => \%format_labels,
				),
			),
		),
		CGI::Tr({},
			CGI::td({colspan=>2, class=>"ButtonRow"},
				CGI::submit(
					-name => "generate_hardcopy",
					-value => $button_label,
					#-style => "width: 45ex",
				),
			),
		),
	);
	
	print CGI::end_form();
	
	return "";
}

################################################################################
# harddcopy generating subroutines
################################################################################

sub generate_hardcopy {
	my ($self, $format, $userIDsRef, $setIDsRef) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	
	my $courseID = $r->urlpath->arg("courseID");
	my $userID = $r->param("user");
	my $eUserID = $r->param("effectiveUser");
	
	# we want to make the temp directory web-accessible, for error reporting
	# use mkpath to ensure it exists (mkpath is pretty much ``mkdir -p'')
	my $temp_dir_parent_path = $ce->{courseDirs}{html_temp} . "/hardcopy";
	eval { mkpath($temp_dir_parent_path) };
	if ($@) {
		die "Couldn't create hardcopy directory $temp_dir_parent_path: $@";
	}
	
	# create a randomly-named working directory in the hardcopy directory
	my $temp_dir_path = eval { tempdir("work.XXXXXXXX", DIR => $temp_dir_parent_path) };
	if ($@) {
		$self->add_errors("Couldn't create temporary working directory: ".CGI::code(CGI::escapeHTML($@)));
		return;
	}
	# make sure the directory can be read by other daemons e.g. lighttpd
	chmod 0755, $temp_dir_path;

	
	# do some error checking
	unless (-e $temp_dir_path) {
		$self->add_errors("Temporary directory '".CGI::code(CGI::escapeHTML($temp_dir_path))
			."' does not exist, but creation didn't fail. This shouldn't happen.");
		return;
	}
	unless (-w $temp_dir_path) {
		$self->add_errors("Temporary directory '".CGI::code(CGI::escapeHTML($temp_dir_path))
			."' is not writeable.");
		$self->delete_temp_dir($temp_dir_path);
		return;
	}
	
	my $tex_file_name = "hardcopy.tex";
	my $tex_file_path = "$temp_dir_path/$tex_file_name";
	
	#######################################
	# create TeX file  (callback  write_multiuser_tex,  or ??)
	#######################################
	
	my $open_result = open my $FH, ">", $tex_file_path;
	unless ($open_result) {
		$self->add_errors("Failed to open file '".CGI::code(CGI::escapeHTML($tex_file_path))
			."' for writing: ".CGI::code(CGI::escapeHTML($!)));
		$self->delete_temp_dir($temp_dir_path);
		return;
	}
	$self->write_multiuser_tex($FH, $userIDsRef, $setIDsRef);
	close $FH;
	
	# if no problems got rendered successfully, we can't continue
	unless ($self->{at_least_one_problem_rendered_without_error}) {
		$self->add_errors("No problems rendered. Can't continue.");
		$self->delete_temp_dir($temp_dir_path);
		return;
	}
	
	# if no hardcopy.tex file was generated, fail now
	unless (-e "$temp_dir_path/hardcopy.tex") {
		$self->add_errors("'".CGI::code("hardcopy.tex")."' not written to temporary directory '"
			.CGI::code(CGI::escapeHTML($temp_dir_path))."'. Can't continue.");
		$self->delete_temp_dir($temp_dir_path);
		return;
	}
	
	##############################################
	# end creation of TeX file
	##############################################
	
	# determine base name of final file
	my $final_file_user = @$userIDsRef > 1 ? "multiuser" : $userIDsRef->[0];
	my $final_file_set = @$setIDsRef > 1 ? "multiset" : $setIDsRef->[0];
	my $final_file_basename = "$courseID.$final_file_user.$final_file_set";
	
	###############################################
	# call format subroutine  (call back)
	###############################################
	# $final_file_name is the name of final hardcopy file
	# @temp_files is a list of temporary files of interest used by the subroutine
	# (all are relative to $temp_dir_path)
	my $format_subr = $HC_FORMATS{$format}{subr};
	my ($final_file_name, @temp_files) = $self->$format_subr($temp_dir_path, $final_file_basename);
	my $final_file_path = "$temp_dir_path/$final_file_name";
	
	#warn "final_file_name=$final_file_name\n";
	#warn "temp_files=@temp_files\n";
	
	################################################
	# calculate URLs for each temp file of interest
	#################################################
	# makeTempDirectory's interface forces us to reverse-engineer the name of the temp dir from the path
	my $temp_dir_parent_url = $ce->{courseURLs}{html_temp} . "/hardcopy";
	(my $temp_dir_url = $temp_dir_path) =~ s/^$temp_dir_parent_path/$temp_dir_parent_url/; 
	my %temp_file_map;
	foreach my $temp_file_name (@temp_files) {
		$temp_file_map{$temp_file_name} = "$temp_dir_url/$temp_file_name";
	}
	
	my $final_file_url;
	
	##################################################
	# make sure final file exists
	##################################################
    # returns undefined unless $final_file_path points to a file
	unless (-e $final_file_path) {
		$self->add_errors("Final hardcopy file '".CGI::code(CGI::escapeHTML($final_file_path))
			."' not found after calling '".CGI::code(CGI::escapeHTML($format_subr))."': "
			.CGI::code(CGI::escapeHTML($!)));
		return $final_file_url, %temp_file_map;
	}
	
	##################################################	
	# try to move the hardcopy file out of the temp directory
	##################################################

	# set $final_file_url accordingly
	my $final_file_final_path = "$temp_dir_parent_path/$final_file_name";
	my $mv_cmd = "2>&1 " . $ce->{externalPrograms}{mv} . " " . shell_quote($final_file_path, $final_file_final_path);
	my $mv_out = readpipe $mv_cmd;
	if ($?) {
		$self->add_errors("Failed to move hardcopy file '".CGI::code(CGI::escapeHTML($final_file_name))
			."' from '".CGI::code(CGI::escapeHTML($temp_dir_path))."' to '"
			.CGI::code(CGI::escapeHTML($temp_dir_parent_path))."':".CGI::br()
			.CGI::pre(CGI::escapeHTML($mv_out)));
		$final_file_url = "$temp_dir_url/$final_file_name";
	} else {
		$final_file_url = "$temp_dir_parent_url/$final_file_name";
	}
	
	##################################################	
	# remove the temp directory if there are no errors
	##################################################

	unless ($self->get_errors or $PreserveTempFiles) {
		$self->delete_temp_dir($temp_dir_path);
	}
	
	warn "Preserved temporary files in directory '$temp_dir_path'.\n" if $PreserveTempFiles;
	
	return $final_file_url, %temp_file_map;
}

# helper function to remove temp dirs
sub delete_temp_dir {
	my ($self, $temp_dir_path) = @_;
	
	my $rm_cmd = "2>&1 " . $self->r->ce->{externalPrograms}{rm} . " -rf " . shell_quote($temp_dir_path);
	my $rm_out = readpipe $rm_cmd;
	if ($?) {
		$self->add_errors("Failed to remove temporary directory '".CGI::code(CGI::escapeHTML($temp_dir_path))."':"
			.CGI::br().CGI::pre($rm_out));
		return 0;
	} else {
		return 1;
	}
}

# format subroutines
# 
# assume that TeX source is located at $temp_dir_path/hardcopy.tex
# the generated file will being with $final_file_basename
# first element of return value is the name of the generated file (relative to $temp_dir_path)
# rest of return value elements are names of temporary files that may be of interest in the
#   case of an error, relative to $temp_dir_path. these are returned whether or not an error
#   actually occured.

sub generate_hardcopy_tex {
	my ($self, $temp_dir_path, $final_file_basename) = @_;
	
	my $final_file_name;
	
	# try to rename tex file
	my $src_name = "hardcopy.tex";
	my $dest_name = "$final_file_basename.tex";
	my $mv_cmd = "2>&1 " . $self->r->ce->{externalPrograms}{mv} . " " . shell_quote("$temp_dir_path/$src_name", "$temp_dir_path/$dest_name");
	my $mv_out = readpipe $mv_cmd;
	if ($?) {
		$self->add_errors("Failed to rename '".CGI::code(CGI::escapeHTML($src_name))."' to '"
			.CGI::code(CGI::escapeHTML($dest_name))."' in directory '"
			.CGI::code(CGI::escapeHTML($temp_dir_path))."':".CGI::br()
			.CGI::pre(CGI::escapeHTML($mv_out)));
		$final_file_name = $src_name;
	} else {
		$final_file_name = $dest_name;
	}
	
	return $final_file_name;
}

sub generate_hardcopy_pdf {
	my ($self, $temp_dir_path, $final_file_basename) = @_;
	
	# call pdflatex - we don't want to chdir in the mod_perl process, as
	# that might step on the feet of other things (esp. in Apache 2.0)
	my $pdflatex_cmd = "cd " . shell_quote($temp_dir_path) . " && "
		. $self->r->ce->{externalPrograms}{pdflatex}
		. " >pdflatex.stdout 2>pdflatex.stderr hardcopy";
	if (my $rawexit = system $pdflatex_cmd) {
		my $exit = $rawexit >> 8;
		my $signal = $rawexit & 127;
		my $core = $rawexit & 128;
		$self->add_errors("Failed to convert TeX to PDF with command '"
			.CGI::code(CGI::escapeHTML($pdflatex_cmd))."' (exit=$exit signal=$signal core=$core).");
		
		# read hardcopy.log and report first error
		my $hardcopy_log = "$temp_dir_path/hardcopy.log";
		if (-e $hardcopy_log) {
			if (open my $LOG, "<", $hardcopy_log) {
				my $line;
				while ($line = <$LOG>) {
					last if $line =~ /^!\s+/;
				}
				my $first_error = $line;
				while ($line = <$LOG>) {
					last if $line =~ /^!\s+/;
					$first_error .= $line;
				}
				close $LOG;
				if (defined $first_error) {
					$self->add_errors("First error in TeX log is:".CGI::br().
						CGI::pre(CGI::escapeHTML($first_error)));
				} else {
					$self->add_errors("No errors encoundered in TeX log.");
				}
			} else {
				$self->add_errors("Could not read TeX log: ".CGI::code(CGI::escapeHTML($!)));
			}
		} else {
			$self->add_errors("No TeX log was found.");
		}
	}
	
	my $final_file_name;
	
	# try rename the pdf file
	my $src_name = "hardcopy.pdf";
	my $dest_name = "$final_file_basename.pdf";
	my $mv_cmd = "2>&1 " . $self->r->ce->{externalPrograms}{mv} . " " . shell_quote("$temp_dir_path/$src_name", "$temp_dir_path/$dest_name");
	my $mv_out = readpipe $mv_cmd;
	if ($?) {
		$self->add_errors("Failed to rename '".CGI::code(CGI::escapeHTML($src_name))."' to '"
			.CGI::code(CGI::escapeHTML($dest_name))."' in directory '"
			.CGI::code(CGI::escapeHTML($temp_dir_path))."':".CGI::br()
			.CGI::pre(CGI::escapeHTML($mv_out)));
		$final_file_name = $src_name;
	} else {
		$final_file_name = $dest_name;
	}
	
	return $final_file_name, qw/hardcopy.tex hardcopy.log hardcopy.aux pdflatex.stdout pdflatex.stderr/;
}

################################################################################
# TeX aggregating subroutines
################################################################################

sub write_multiuser_tex {
	my ($self, $FH, $userIDsRef, $setIDsRef) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	my @userIDs = @$userIDsRef;
	my @setIDs = @$setIDsRef;
	
	# get snippets
	my $preamble = $ce->{webworkFiles}->{hardcopySnippets}->{preamble};
	my $postamble = $ce->{webworkFiles}->{hardcopySnippets}->{postamble};
	my $divider = $ce->{webworkFiles}->{hardcopySnippets}->{userDivider};
	
	# write preamble
	$self->write_tex_file($FH, $preamble);
	
	# write section for each user
	while (defined (my $userID = shift @userIDs)) {
		$self->write_multiset_tex($FH, $userID, @setIDs);
		$self->write_tex_file($FH, $divider) if @userIDs; # divide users, but not after the last user
	}
	
	# write postamble
	$self->write_tex_file($FH, $postamble);
}

sub write_multiset_tex {
	my ($self, $FH, $targetUserID, @setIDs) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	
	# get user record
	my $TargetUser = $db->getUser($targetUserID); # checked
	unless ($TargetUser) {
		$self->add_errors("Can't generate hardcopy for user '".CGI::code(CGI::escapeHTML($targetUserID))."' -- no such user exists.\n");
		return;
	}
	
	# get set divider
	my $divider = $ce->{webworkFiles}->{hardcopySnippets}->{setDivider};
	
	# write each set
	while (defined (my $setID = shift @setIDs)) {
		$self->write_set_tex($FH, $TargetUser, $setID);
		$self->write_tex_file($FH, $divider) if @setIDs; # divide sets, but not after the last set
	}
}

sub write_set_tex {
	my ($self, $FH, $TargetUser, $setID) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz  = $r->authz;
	my $userID = $r->param("user");

	# we may already have the MergedSet from checking hide_work and 
	#    hide_score in pre_header_initialize; check to see if that's true,
	#    and otherwise, get the set.
	my %mergedSets = %{$self->{mergedSets}};
	my $uid = $TargetUser->user_id;
	my $MergedSet;
	my $versioned = 0;
	if ( defined( $mergedSets{"$uid!$setID"} ) ) {
		$MergedSet = $mergedSets{"$uid!$setID"};
		$versioned = ($setID =~ /,v(\d+)$/) ? $1 : 0;
	} else {
		if ( $setID =~ /(.+),v(\d+)$/ ) {
			$setID = $1;
			$versioned = $2;
		}
		if ( $versioned ) {
			$MergedSet = $db->getMergedSetVersion($TargetUser->user_id, $setID, $versioned);
		} else {
			$MergedSet = $db->getMergedSet($TargetUser->user_id, $setID); # checked
		}
	}
	# save versioned info for use in write_problem_tex
	$self->{versioned} = $versioned;

	unless ($MergedSet) {
		$self->add_errors("Can't generate hardcopy for set ''".CGI::code(CGI::escapeHTML($setID))
			."' for user '".CGI::code(CGI::escapeHTML($TargetUser->user_id))
			."' -- set is not assigned to that user.");
		return;
	}
	
	# see if the *real* user is allowed to access this problem set
	if ($MergedSet->open_date > time and not $authz->hasPermissions($userID, "view_unopened_sets")) {
		$self->add_errors("Can't generate hardcopy for set '".CGI::code(CGI::escapeHTML($setID))
			."' for user '".CGI::code(CGI::escapeHTML($TargetUser->user_id))
			."' -- set is not yet open.");
		return;
	}
	if (not $MergedSet->visible and not $authz->hasPermissions($userID, "view_hidden_sets")) {
		$self->addbadmessage("Can't generate hardcopy for set '".CGI::code(CGI::escapeHTML($setID))
			."' for user '".CGI::code(CGI::escapeHTML($TargetUser->user_id))
			."' -- set is not visible to students.");
		return;
	}
	
	# get snippets
	my $header = $MergedSet->hardcopy_header
		? $MergedSet->hardcopy_header
		: $ce->{webworkFiles}->{hardcopySnippets}->{setHeader};
  if ($header eq 'defaultHeader') {$header = $ce->{webworkFiles}->{hardcopySnippets}->{setHeader};}
	my $footer = $ce->{webworkFiles}->{hardcopySnippets}->{setFooter};
	my $divider = $ce->{webworkFiles}->{hardcopySnippets}->{problemDivider};
	
	# get list of problem IDs
	# DBFIXME use ORDER BY in database
	my @problemIDs = sort { $a <=> $b } $db->listUserProblems($MergedSet->user_id, $MergedSet->set_id);

	# for versioned sets (gateways), we might have problems in a random
	# order; reset the order of the problemIDs if this is the case
	if ( defined( $MergedSet->problem_randorder ) && 
	     $MergedSet->problem_randorder ) {
		my @newOrder = ();

	# to set the same order each time we set the random seed to the psvn,
 	# and to avoid messing with the system random number generator we use
	# our own PGrandom object
		my $pgrand = PGrandom->new();
		$pgrand->srand( $MergedSet->psvn );
		while ( @problemIDs ) {
			my $i = int($pgrand->rand(scalar(@problemIDs)));
			push( @newOrder, $problemIDs[$i] );
			splice(@problemIDs, $i, 1);
		}
		@problemIDs = @newOrder;
	}
		    
	# write set header
	$self->write_problem_tex($FH, $TargetUser, $MergedSet, 0, $header); # 0 => pg file specified directly
       
	# write each problem
	# for versioned problem sets (gateway tests) we like to include 
	#   problem numbers
	my $i = 1;
	while (my $problemID = shift @problemIDs) {
		$self->write_tex_file($FH, $divider);
		$self->{versioned} = $i if $versioned;
		$self->write_problem_tex($FH, $TargetUser, $MergedSet, $problemID);
		$i++;
	}
	
	# write footer
	$self->write_problem_tex($FH, $TargetUser, $MergedSet, 0, $footer); # 0 => pg file specified directly
}

sub write_problem_tex {
	my ($self, $FH, $TargetUser, $MergedSet, $problemID, $pgFile) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz  = $r->authz;
	my $userID = $r->param("user");
	my $eUserID = $r->param("effectiveUser");
	my $versioned = $self->{versioned};
	my %canShowScore = %{$self->{canShowScore}};

	my @errors;
	
	# get problem record
	my $MergedProblem;
	if ($problemID) {
		# a non-zero problem ID was given -- load that problem
	        # we use $versioned to determine which merging routine to use
		if ( $versioned ) {
			$MergedProblem = $db->getMergedProblemVersion($MergedSet->user_id, $MergedSet->set_id, $MergedSet->version_id, $problemID);

		} else {
			$MergedProblem = $db->getMergedProblem($MergedSet->user_id, $MergedSet->set_id, $problemID); # checked
		}
		
		# handle nonexistent problem
		unless ($MergedProblem) {
			$self->add_errors("Can't generate hardcopy for problem '"
				.CGI::code(CGI::escapeHTML($problemID))."' in set '"
				.CGI::code(CGI::escapeHTML($MergedSet->set_id))
				."' for user '".CGI::code(CGI::escapeHTML($MergedSet->user_id))
				."' -- problem does not exist in that set or is not assigned to that user.");
			return;
		}
	} elsif ($pgFile) {
		# otherwise, we try an explicit PG file
		$MergedProblem = $db->newUserProblem(
			user_id => $MergedSet->user_id,
			set_id => $MergedSet->set_id,
			problem_id => 0,
			source_file => $pgFile,
			num_correct   => 0,
			num_incorrect => 0,
		);
		die "newUserProblem failed -- WTF?" unless $MergedProblem; # this should never happen
	} else {
		# this shouldn't happen -- error out for real
		die "write_problem_tex needs either a non-zero \$problemID or a \$pgFile";
	}
	
	# figure out if we're allowed to get correct answers, hints, and solutions
	# (eventually, we'd like to be able to use the same code as Problem)
	my $versionName = $MergedSet->set_id . 
		(( $versioned ) ?  ",v" . $MergedSet->version_id : '');

	my $showCorrectAnswers  = $r->param("showCorrectAnswers") || 0;
	my $printStudentAnswers = $r->param("printStudentAnswers") || 0;
	my $showHints           = $r->param("showHints")          || 0;
	my $showSolutions       = $r->param("showSolutions")      || 0;

	unless( ( $authz->hasPermissions($userID, "show_correct_answers_before_answer_date") or
		  ( time > $MergedSet->answer_date or 
		    ( $versioned && 
		      $MergedProblem->num_correct + 
		      $MergedProblem->num_incorrect >= 
		      $MergedSet->attempts_per_version &&
		      $MergedSet->due_date == $MergedSet->answer_date ) ) ) &&
		( $canShowScore{$MergedSet->user_id . "!$versionName"} ) ) {
		$showCorrectAnswers = 0;
		$showSolutions      = 0;
	}
	
	# FIXME -- there can be a problem if the $siteDefaults{timezone} is not defined?  Why is this?
	# why does it only occur with hardcopy?

	# we need an additional translation option for versioned sets; also,
	#   for versioned sets include old answers in the set if we're also 
	#   asking for the answers
	my $transOpts = 
		{ # translation options
			displayMode     => "tex",
			showHints       => $showHints          ? 1 : 0, # insure that this value is numeric
			showSolutions   => $showSolutions      ? 1 : 0, # (or what? -sam)
			processAnswers  => ($showCorrectAnswers || $printStudentAnswers) ? 1 : 0,
			permissionLevel => $db->getPermissionLevel($userID)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($eUserID)->permission,
		};

	if ( $versioned && $MergedProblem->problem_id != 0 ) {

		$transOpts->{QUIZ_PREFIX} = 'Q' . sprintf("%04d",$MergedProblem->problem_id()) . '_';

	}
	my $formFields = { };
	if ( $showCorrectAnswers ||$printStudentAnswers ) { 
			my %oldAnswers = decodeAnswers($MergedProblem->last_answer);
			$formFields->{$_} = $oldAnswers{$_} foreach (keys %oldAnswers);
			print $FH "%% decoded old answers, saved. (keys = " . join(',', keys(%oldAnswers)) . "\n";
		}

#	warn("problem ", $MergedProblem->problem_id, ": source = ", $MergedProblem->source_file, "\n");

	my $pg = WeBWorK::PG->new(
		$ce,
		$TargetUser,
		scalar($r->param('key')), # avoid multiple-values problem
		$MergedSet,
		$MergedProblem,
		$MergedSet->psvn,
		$formFields, # no form fields!
		$transOpts,
	);
	
	# only bother to generate this info if there were warnings or errors
	my $edit_url;
	my $problem_name;
	my $problem_desc;
	if ($pg->{warnings} ne "" or $pg->{flags}->{error_flag}) {
		my $edit_urlpath = $r->urlpath->newFromModule(
			"WeBWorK::ContentGenerator::Instructor::PGProblemEditor2", $r,
			courseID  => $r->urlpath->arg("courseID"),
			setID     => $MergedProblem->set_id,
			problemID => $MergedProblem->problem_id,
		);
		
		if ($MergedProblem->problem_id == 0) {
			# link for an fake problem (like a header file)
			$edit_url = $self->systemLink($edit_urlpath,
				params => {
					sourceFilePath => $MergedProblem->source_file,
					problemSeed    => $MergedProblem->problem_seed,
				},
			);
		} else {
			# link for a real problem
			$edit_url = $self->systemLink($edit_urlpath);
		}
		
		if ($MergedProblem->problem_id == 0) {
			$problem_name = "snippet";
			$problem_desc = $problem_name." '".$MergedProblem->source_file
				."' for set '".$MergedProblem->set_id."' and user '"
				.$MergedProblem->user_id."'";
		} else {
			$problem_name = "problem";
			$problem_desc = $problem_name." '".$MergedProblem->problem_id
				."' in set '".$MergedProblem->set_id."' for user '"
				.$MergedProblem->user_id."'";
		}
	}
		
	# deal with PG warnings
	if ($pg->{warnings} ne "") {
		$self->add_errors(CGI::a({href=>$edit_url, target=>"WW_Editor"}, "[edit]")
			." Warnings encountered while processing $problem_desc. "
			."Error text:".CGI::br().CGI::pre(CGI::escapeHTML($pg->{warnings}))
		);
	}
	
	# deal with PG errors
	if ($pg->{flags}->{error_flag}) {
		$self->add_errors(CGI::a({href=>$edit_url, target=>"WW_Editor"}, "[edit]")
			." Errors encountered while processing $problem_desc. "
			."This $problem_name has been omitted from the hardcopy. "
			."Error text:".CGI::br().CGI::pre(CGI::escapeHTML($pg->{errors}))
		);
		return;
	}
	
	# if we got here, there were no errors (because errors cause a return above)
	$self->{at_least_one_problem_rendered_without_error} = 1;

	print $FH "{\\bf Problem $versioned.}\n" 
		if ( $versioned && $MergedProblem->problem_id != 0 );

	my $body_text = $pg->{body_text};

	# Use the pretty problem number if its a jitar problem
	if (defined($MergedSet) && $MergedSet->assignment_type eq 'jitar') {
	    my $id = $MergedProblem->problem_id;
	    my $prettyID = join('.',jitar_id_to_seq($id));
	    
	    $body_text =~ s/$id/$prettyID/;
	}

	print $FH $body_text;

	my @ans_entry_order = defined($pg->{flags}->{ANSWER_ENTRY_ORDER}) ? @{$pg->{flags}->{ANSWER_ENTRY_ORDER}} : ( );

	# print the list of student answers if it is requested
	if (  $printStudentAnswers && 
	     $MergedProblem->problem_id != 0 && @ans_entry_order ) {
			my $recScore = $pg->{state}->{recorded_score};
			my $corrMsg = '';
			if ( $recScore == 1 ) {
				$corrMsg = ' (correct)';
			} elsif ( $recScore == 0 ) {
				$corrMsg = ' (incorrect)';
			} else {
				$corrMsg = " (score $recScore)";
			}
		my $stuAnswers = "\\par{\\small{\\it Answer(s) submitted:}\n" .
			"\\vspace{-\\parskip}\\begin{itemize}\n";
		for my $ansName ( @ans_entry_order ) {
			my $stuAns = $pg->{answers}->{$ansName}->{original_student_ans};
			$stuAnswers .= "\\item\\begin{verbatim}$stuAns\\end{verbatim}\n";
		}
		$stuAnswers .= "\\end{itemize}}$corrMsg\\par\n";
		print $FH $stuAnswers;
	}
	
	# write the list of correct answers is appropriate; ANSWER_ENTRY_ORDER
	#   isn't defined for versioned sets?  this seems odd FIXME  GWCHANGE
	if ($showCorrectAnswers && $MergedProblem->problem_id != 0 && @ans_entry_order) {
		my $correctTeX = "\\par{\\small{\\it Correct Answers:}\n"
			. "\\vspace{-\\parskip}\\begin{itemize}\n";
		
		foreach my $ansName (@ans_entry_order) {
			my $correctAnswer = $pg->{answers}->{$ansName}->{correct_ans};
			$correctTeX .= "\\item\\begin{verbatim}$correctAnswer\\end{verbatim}\n";
			# FIXME: What about vectors (where TeX will complain about < and > outside of math mode)?
		}
		
		$correctTeX .= "\\end{itemize}}\\par\n";
		
		print $FH $correctTeX;
	}
}

sub write_tex_file {
	my ($self, $FH, $file) = @_;
	
	my $tex = eval { readFile($file) };
	if ($@) {
		$self->add_errors("Failed to include TeX file '".CGI::code(CGI::escapeHTML($file))."': "
			.CGI::escapeHTML($@));
	} else {
		print $FH $tex;
	}
}

################################################################################
# utilities
################################################################################

sub add_errors {
	my ($self, @errors) = @_;
	push @{$self->{hardcopy_errors}}, @errors;
}

sub get_errors {
	my ($self) = @_;
	return $self->{hardcopy_errors} ? @{$self->{hardcopy_errors}} : ();
}

sub get_errors_ref {
	my ($self) = @_;
	return $self->{hardcopy_errors};
}

1;
