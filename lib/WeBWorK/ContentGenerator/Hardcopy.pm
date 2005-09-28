################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Hardcopy.pm,v 1.63 2005/09/27 23:32:41 sh002i Exp $
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
use Apache::Constants qw/:common REDIRECT/;
use CGI qw//;
use String::ShellQuote;
use WeBWorK::DB::Utils qw/user2global/;
use WeBWorK::Debug;
use WeBWorK::Form;
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;
use WeBWorK::PG;
use WeBWorK::Utils qw/readFile makeTempDirectory surePathToFile/;

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
		unless (@setIDs) {
			$self->addbadmessage("Please select at least one set and try again.");
			$validation_failed = 1;
		}
		
		# is the user allowed to request multiple sets/users at a time?
		my $perm_multiset = $authz->hasPermissions($userID, "download_hardcopy_multiset");
		my $perm_multiuser = $authz->hasPermissions($userID, "download_hardcopy_multiuser");
		
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
		
		unless ($validation_failed) {
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
	
	if (my $num = $self->get_errors) {
		my $final_file_url = $self->{final_file_url};
		my %temp_file_map = %{$self->{temp_file_map}};
		
		my $errors_str = $num > 1 ? "errors" : "error";
		print CGI::p("$num $errors_str occured while generating hardcopy:");
		
		print CGI::ul(CGI::li($self->get_errors_ref));
		
		if ($final_file_url) {
			print CGI::p(
				"A hardcopy file was generated, but it may not be complete or correct: ",
				CGI::a({href=>$final_file_url}, "Download Hardcopy")
			);
		}
		
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
		
		print CGI::hr();
	}
	
	$self->display_form();
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
	my $perm_unpublished = $authz->hasPermissions($userID, "view_unpublished_sets");
	
	# get formats
	my @formats;
	foreach my $format (keys %HC_FORMATS) {
		push @formats, $format if $authz->hasPermissions($userID, "download_hardcopy_format_$format");
	}
	
	# get format names hash for radio buttons
	my %format_labels = map { $_ => $HC_FORMATS{$_}{name} || $_ } @formats;
	
	# get users for selection
	my @Users;
	if ($perm_multiuser) {
		# if we're allowed to select multiple users, get all the users
		@Users = $db->getUsers($db->listUsers);
	} else {
		# otherwise, we get our own record only
		@Users = $db->getUser($eUserID);
	}
	
	# get sets for selection
	my @GlobalSets;
	if ($perm_multiuser) {
		# if we're allowed to select sets for multiple users, get all sets.
		@GlobalSets = $db->getGlobalSets($db->listGlobalSets);
	} else {
		# otherwise, only get the sets assigned to the effective user.
		# note that we are getting GlobalSets, but using the list of UserSets assigned to the
		# effective user. this is because if we pass UserSets  to ScrollingRecordList it will
		# give us composite IDs back, which is a pain in the ass to deal with.
		@GlobalSets = $db->getGlobalSets($db->listUserSets($eUserID));
	}
	
	# filter out unwanted sets
	foreach my $i (0 .. $#GlobalSets) {
		my $Set = $GlobalSets[$i];
		unless (defined $Set) {
			warn "\$GlobalSets[\$i] not defined -- skipping";
			next;
		}
		splice @GlobalSets, $i, 1 unless $Set->open_date <= time or $perm_unopened;
		splice @GlobalSets, $i, 1 unless $Set->published or $perm_unpublished;
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
		default_format => "set_id",
		default_filters => ["all"],
		size => 20,
		multiple => $perm_multiset,
	}, @GlobalSets);
	
	# we change the text a little bit depending on whether the user has multiuser privileges
	my $ss = $perm_multiuser ? "s" : "";
	my $aa = $perm_multiuser ? " " : " a ";
	my $phrase_for_privileged_users = $perm_multiuser ? "to privileged users or" : "";
	
	print CGI::start_p();
	print "Select the homework set$ss for which to generate${aa}hardcopy version$ss.";
	if ($authz->hasPermissions($userID, "download_hardcopy_multiuser")) {
		print "You may also select multiple users from the users list. You will receive hardcopy for each (set, user) pair.";
	}
	print CGI::end_p();
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields();
	print CGI::hidden("in_hc_form", 1);
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::th("Users"),
			CGI::th("Sets"),
		),
		CGI::Tr(
			CGI::td($scrolling_user_list),
			CGI::td($scrolling_set_list),
		),
		CGI::Tr(
			CGI::td({colspan=>2, class=>"ButtonRow"},
				CGI::small("You may choose to show any of the following data. Correct answers and solutions are only available $phrase_for_privileged_users after the answer date of the homework set."),
				CGI::br(),
				CGI::b("Show:"), " ",
				CGI::checkbox(
					-name    => "showCorrectAnswers",
					-checked => scalar($r->param("showCorrectAnswers")) || 0,
					-label   => "Correct answers",
				),
				CGI::checkbox(
					-name    => "showHints",
					-checked => scalar($r->param("showHints")) || 0,
					-label   => "Hints",
				),
				CGI::checkbox(
					-name    => "showSolutions",
					-checked => scalar($r->param("showSolutions")) || 0,
					-label   => "Solutions",
				),
			),
		),
		CGI::Tr(
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
		CGI::Tr(
			CGI::td({colspan=>2, class=>"ButtonRow"},
				CGI::submit(
					-name => "generate_hardcopy",
					-value => "Generate hardcopy for selected sets and selected users",
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
	#my $temp_dir_path = eval { makeTempDirectory($ce->{webworkDirs}{tmp}, "webwork-hardcopy") };
	my $temp_dir_parent_path = $ce->{courseDirs}{html_temp} . "/hardcopy"; # makeTempDirectory will ensure that .../hardcopy exists
	my $temp_dir_path = eval { makeTempDirectory($temp_dir_parent_path, "work") };
	if ($@) {
		$self->add_errors($@);
		return;
	}
	
	# do some error checking
	unless (-e $temp_dir_path) {
		$self->add_errors("Temporary directory '$temp_dir_path' does not exist, but creation didn't fail. This shouldn't happen.");
		return;
	}
	unless (-w $temp_dir_path) {
		$self->add_errors("Temporary directory '$temp_dir_path' is not writeable.");
		$self->delete_temp_dir($temp_dir_path);
		return;
	}
	
	my $tex_file_name = "hardcopy.tex";
	my $tex_file_path = "$temp_dir_path/$tex_file_name";
	
	# write TeX
	my $open_result = open my $FH, ">", $tex_file_path;
	unless ($open_result) {
		$self->add_errors("Failed to open file '$tex_file_path' for writing: $!");
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
		$self->add_errors("'hardcopy.tex' not written to temporary directory '$temp_dir_path'. Can't continue.");
		$self->delete_temp_dir($temp_dir_path);
		return;
	}
	
	# determine base name of final file
	my $final_file_user = @$userIDsRef > 1 ? "multiuser" : $userIDsRef->[0];
	my $final_file_set = @$setIDsRef > 1 ? "multiset" : $setIDsRef->[0];
	my $final_file_basename = "$courseID.$final_file_user.$final_file_set";
	
	# call format subroutine
	# $final_file_name is the name of final hardcopy file
	# @temp_files is a list of temporary files of interest used by the subroutine
	# (all are relative to $temp_dir_path)
	my $format_subr = $HC_FORMATS{$format}{subr};
	my ($final_file_name, @temp_files) = $self->$format_subr($temp_dir_path, $final_file_basename);
	my $final_file_path = "$temp_dir_path/$final_file_name";
	
	#warn "final_file_name=$final_file_name\n";
	#warn "temp_files=@temp_files\n";
	
	# calculate URLs for each temp file of interest
	# makeTempDirectory's interface forces us to reverse-engineer the name of the temp dir from the path
	my $temp_dir_parent_url = $ce->{courseURLs}{html_temp} . "/hardcopy";
	(my $temp_dir_url = $temp_dir_path) =~ s/^$temp_dir_parent_path/$temp_dir_parent_url/; 
	my %temp_file_map;
	foreach my $temp_file_name (@temp_files) {
		$temp_file_map{$temp_file_name} = "$temp_dir_url/$temp_file_name";
	}
	
	my $final_file_url;
	
	# make sure final file exists
	unless (-e $final_file_path) {
		$self->add_errors("Final hardcopy file '$final_file_path' not found after calling '$format_subr': $!");
		return $final_file_url, %temp_file_map;
	}
	
	# try to move the hardcopy file out of the temp directory
	# set $final_file_url accordingly
	my $final_file_final_path = "$temp_dir_parent_path/$final_file_name";
	my $mv_cmd = "2>&1 /bin/mv " . shell_quote($final_file_path, $final_file_final_path);
	my $mv_out = readpipe $mv_cmd;
	if ($?) {
		$self->add_errors("Failed to move hardcopy file '$final_file_name' from '$temp_dir_path' to '$temp_dir_parent_path':"
			.CGI::br().CGI::pre($mv_out));
		$final_file_url = "$temp_dir_url/$final_file_name";
	} else {
		$final_file_url = "$temp_dir_parent_url/$final_file_name";
	}
	
	# remove the temp directory if there are no errors
	unless ($self->get_errors or $PreserveTempFiles) {
		$self->delete_temp_dir($temp_dir_path);
	}
	
	warn "Preserved temporary files in directory '$temp_dir_path'.\n" if $PreserveTempFiles;
	
	return $final_file_url, %temp_file_map;
}

# helper function to remove temp dirs
sub delete_temp_dir {
	my ($self, $temp_dir_path) = @_;
	
	my $rm_cmd = "2>&1 /bin/rm -rf " . shell_quote($temp_dir_path);
	my $rm_out = readpipe $rm_cmd;
	if ($?) {
		$self->add_errors("Failed to remove temporary directory '$temp_dir_path':"
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
	my $mv_cmd = "2>&1 /bin/mv " . shell_quote("$temp_dir_path/$src_name", "$temp_dir_path/$dest_name");
	my $mv_out = readpipe $mv_cmd;
	if ($?) {
		$self->add_errors("Failed to rename '$src_name' to '$dest_name' in directory '$temp_dir_path':".CGI::br().CGI::pre($mv_out));
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
	if (system $pdflatex_cmd) {
		$self->add_errors("Failed to convert TeX to PDF with command '$pdflatex_cmd'.");
	}
	
	my $final_file_name;
	
	# try rename the pdf file
	my $src_name = "hardcopy.pdf";
	my $dest_name = "$final_file_basename.pdf";
	my $mv_cmd = "2>&1 /bin/mv " . shell_quote("$temp_dir_path/$src_name", "$temp_dir_path/$dest_name");
	my $mv_out = readpipe $mv_cmd;
	if ($?) {
		$self->add_errors("Failed to rename '$src_name' to '$dest_name' in directory '$temp_dir_path':".CGI::br().CGI::pre($mv_out));
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
		$self->add_errors("Can't generate hardcopy for user '$targetUserID' -- no such user exists.\n");
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
	
	# get set record
	my $MergedSet = $db->getMergedSet($TargetUser->user_id, $setID); # checked
	unless ($MergedSet) {
		$self->add_errors("Can't generate hardcopy for set '$setID' for user '".$TargetUser->user_id."' -- set is not assigned to that user.");
		return;
	}
	
	# see if the *real* user is allowed to access this problem set
	if ($MergedSet->open_date > time and not $authz->hasPermissions($userID, "view_unopened_sets")) {
		$self->add_errors("Can't generate hardcopy for set '$setID' for user '".$TargetUser->user_id."' -- set is not yet open.");
		return;
	}
	if (not $MergedSet->published and not $authz->hasPermissions($userID, "view_unpublished_sets")) {
		$self->addbadmessage("Can't generate hardcopy for set '$setID' for user '".$TargetUser->user_id."' -- set has not been published.");
		return;
	}
	
	# get snippets
	my $header = $MergedSet->hardcopy_header
		? $MergedSet->hardcopy_header
		: $ce->{webworkFiles}->{hardcopySnippets}->{setHeader};
	my $footer = $ce->{webworkFiles}->{hardcopySnippets}->{setFooter};
	my $divider = $ce->{webworkFiles}->{hardcopySnippets}->{problemDivider};
	
	# get list of problem IDs
	my @problemIDs = sort { $a <=> $b } $db->listUserProblems($MergedSet->user_id, $MergedSet->set_id);
	
	# write set header
	$self->write_problem_tex($FH, $TargetUser, $MergedSet, 0, $header); # 0 => pg file specified directly
	
	# write each problem
	while (my $problemID = shift @problemIDs) {
		$self->write_tex_file($FH, $divider);
		$self->write_problem_tex($FH, $TargetUser, $MergedSet, $problemID);
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
	
	my @errors;
	
	# get problem record
	my $MergedProblem;
	if ($problemID) {
		# a non-zero problem ID was given -- load that problem
		$MergedProblem = $db->getMergedProblem($MergedSet->user_id, $MergedSet->set_id, $problemID); # checked
		
		# handle nonexistent problem
		unless ($MergedProblem) {
			$self->add_errors("Can't generate hardcopy for problem '$problemID' in set '".$MergedSet->set_id."' for user '".$MergedSet->user_id."' -- problem does not exist in that set or is not assigned to that user.");
			return;
		}
	} elsif ($pgFile) {
		# otherwise, we try an explicit PG file
		$MergedProblem = $db->newUserProblem(
			user_id => $MergedSet->user_id,
			set_id => $MergedSet->set_id,
			problem_id => 0,
			source_file => $pgFile,
		);
		die "newUserProblem failed -- WTF?" unless $MergedProblem; # this should never happen
	} else {
		# this shouldn't happen -- error out for real
		die "write_problem_tex needs either a non-zero \$problemID or a \$pgFile";
	}
	
	# figure out if we're allowed to get correct answers, hints, and solutions
	# (eventually, we'd like to be able to use the same code as Problem)
	my $showCorrectAnswers  = $r->param("showCorrectAnswers") || 0;
	my $showHints           = $r->param("showHints")          || 0;
	my $showSolutions       = $r->param("showSolutions")      || 0;
	unless ($authz->hasPermissions($userID, "view_answers") or time > $MergedSet->answer_date) {
		$showCorrectAnswers = 0;
		$showSolutions      = 0;
	}
	
	# FIXME -- there can be a problem if the $siteDefaults{timezone} is not defined?  Why is this?
	# why does it only occur with hardcopy?
	my $pg = WeBWorK::PG->new(
		$ce,
		$TargetUser,
		scalar($r->param('key')), # avoid multiple-values problem
		$MergedSet,
		$MergedProblem,
		$MergedSet->psvn,
		{}, # no form fields!
		{ # translation options
			displayMode     => "tex",
			showHints       => $showHints          ? 1 : 0, # insure that this value is numeric
			showSolutions   => $showSolutions      ? 1 : 0, # (or what? -sam)
			processAnswers  => $showCorrectAnswers ? 1 : 0,
		},
	);
	
	# only bother to generate this info if there were warnings or errors
	my $edit_url;
	my $problem_name;
	my $problem_desc;
	if ($pg->{warnings} ne "" or $pg->{flags}->{error_flag}) {
		my $edit_urlpath = $r->urlpath->newFromModule(
			"WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
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
			$edit_url = CGI::a({href=>$self->systemLink($edit_urlpath)}, "Edit it");
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
		$self->add_errors(CGI::a({href=>$edit_url}, "[edit]")
			."Warnings encountered while processing $problem_desc. "
			."Error text:".CGI::br().CGI::pre($pg->{warnings})
		);
	}
	
	# deal with PG errors
	if ($pg->{flags}->{error_flag}) {
		$self->add_errors(CGI::a({href=>$edit_url}, "[edit]")
			."Errors encountered while processing $problem_desc. "
			."This $problem_name has been omitted from the hardcopy. "
			."Error text:".CGI::br().CGI::pre($pg->{errors})
		);
		return;
	}
	
	# if we got here, there were no errors (because errors cause a return above)
	$self->{at_least_one_problem_rendered_without_error} = 1;
	
	print $FH $pg->{body_text};
	
	# write the list of correct answers is appropriate
	if ($showCorrectAnswers && $MergedProblem->problem_id != 0) {
		my $correctTeX = "\\par{\\small{\\it Correct Answers:}\n"
			. "\\vspace{-\\parskip}\\begin{itemize}\n";
		
		foreach my $ansName (@{$pg->{flags}->{ANSWER_ENTRY_ORDER}}) {
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
		$self->add_errors("Failed to include TeX file '$file': $@");
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
