################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
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

package WeBWorK::ContentGenerator::Instructor::FileXfer;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::FileXfer - transfer course files from/to
client

=cut

use strict;
use warnings;
use Apache::Constants qw(:common REDIRECT DONE);
use CGI qw();

=for comment

Use this to check for permissions:

unless ($authz->hasPermissions($user, "PERMISSION")) {
	$self->{submitError} = "You are not authorized to PERMISSION";
	return;
}

=cut

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $userID = $r->param("user");
	
	my ($type, $action) = ("", "");
	if (defined $r->param("deleteDef"))         { $type = "def";       $action = "delete";   }
	if (defined $r->param("downloadDef"))       { $type = "def";       $action = "download"; }
	if (defined $r->param("uploadDef"))         { $type = "def";       $action = "upload";   }
	if (defined $r->param("deleteClasslist"))   { $type = "classlist"; $action = "delete";   }
	if (defined $r->param("downloadClasslist")) { $type = "classlist"; $action = "download"; }
	if (defined $r->param("uploadClasslist"))   { $type = "classlist"; $action = "upload";   }
	
	# make sure we have permission to do what we want to do
	if ($type eq "def") {
		unless ($authz->hasPermissions($userID, "modify_set_def_files")) {
			$self->{submitError} = "You are not authorized to modify the list of set definition files.";
			return;
		}
	} elsif ($type eq "classlist") {
		unless ($authz->hasPermissions($userID, "modify_classlist_files")) {
			$self->{submitError} = "You are not authorized to modify the list of classlist files.";
			return;
		}
	}
	
	# call handler for the action we want to perform
	if ($action eq "delete") {
		$self->handleDelete($type);
	} elsif ($action eq "download") {
		$self->handleDownload($type);
	} elsif ($action eq "upload") {
		$self->handleUpload($type);
	}
}

sub handleDelete {
	my ($self, $type) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	
	my (@fileList, $selectParam, $dir);
	if ($type eq "classlist") {
		@fileList = $self->getCSVList;
		$selectParam = "classlist";
		$dir = $ce->{courseDirs}->{templates};
	} elsif ($type eq "def") {
		@fileList = $self->getDefList;
		$selectParam = "def";
		$dir = $ce->{courseDirs}->{templates};
	}
	
	# get file name
	my $fileToDelete = $r->param($selectParam);
	unless ($fileToDelete) {
		$self->{submitError} = "No file selected for deletion.";
		return;
	}
	
	# make sure it's in the file list
	unless (grep { $_ eq $fileToDelete } @fileList) {
		$self->{submitError} = "File \"$fileToDelete\" not found in file list.";
		return;
	}
	
	# delete it
	unlink "$dir/$fileToDelete";
}

sub handleDownload {
	my ($self, $type) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	
	my (@fileList, $selectParam, $dir);
	if ($type eq "classlist") {
		@fileList = $self->getCSVList;
		$selectParam = "classlist";
		$dir = $ce->{courseDirs}->{templates};
	} elsif ($type eq "def") {
		@fileList = $self->getDefList;
		$selectParam = "def";
		$dir = $ce->{courseDirs}->{templates};
	}
	
	# get file name
	my $fileToDownload = $r->param($selectParam);
	unless ($fileToDownload) {
		$self->{submitError} = "No file selected for download.";
		return;
	}
	
	# make sure it's in the file list
	unless (grep { $_ eq $fileToDownload } @fileList) {
		$self->{submitError} = "File \"$fileToDownload\" not found in file list.";
		return;
	}
	
	# set the file to sent:
	$self->{sendFile} = {
		source => "$dir/$fileToDownload",
		type => "text/plain",
		name => $fileToDownload,
	};
}

sub handleUpload {
	my ($self, $type) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	
	my (@fileList, $uploadParam, $uploadNameParam, $ext, $destDir);
	if ($type eq "classlist") {
		@fileList = $self->getCSVList;
		$uploadParam = "newClasslist";
		$uploadNameParam = "newClasslistName";
		$ext = ".lst";
		$destDir = $ce->{courseDirs}->{templates};
	} elsif ($type eq "def") {
		@fileList = $self->getDefList;
		$uploadParam = "newDef";
		$uploadNameParam = "newDefName";
		$ext = ".def";
		$destDir = $ce->{courseDirs}->{templates};
	}
	
	# get upload ID and hash
	my $uploadIDHash = $r->param($uploadParam);
	unless ($uploadIDHash) {
		$self->{submitError} = "No file selected for upload.";
		return;
	}
	my ($id, $hash) = split /\s+/, $uploadIDHash;
	
	#warn "upload param contains $uploadIDHash\n";
	#warn "upload ID is $id\n";
	#warn "upload hash is $hash\n";
	
	# retrieve upload from upload cache
	my $upload = WeBWorK::Upload->retrieve($id, $hash,
		dir => $ce->{webworkDirs}->{uploadCache}
	);
	
	# determine what to call the resulting file
	my $fileName = $r->param($uploadNameParam) || $upload->filename;
	
	# tack on the file extension if it's not already there
	$fileName .= $ext unless $fileName =~ m/$ext$/;
	
	# does the file name have the path separator in it?
	die "illegal character in upload name: \"/\". (no hacking!)" if $fileName =~ m|/|;
	
	# does a file already exist with that name?
	if (grep { $_ eq $fileName } @fileList) {
		$self->{submitError} = "A file named \"$fileName\" exists. Either remove it, or chose a different name for your upload.";
		return;
	}
	
	$upload->disposeTo("$destDir/$fileName");
}

# override contentGenerator header routine for now
# FIXME
#sub header {
#	my $self = shift;
#	
#	
#	
#	return OK;
#}

sub initialize {
	my ($self) = @_;
}

sub path {
	my $self = shift;
	my $args = $_[-1];
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home"             => "$root/",
		$courseName        => "$root/$courseName/",
		"Instructor Tools" => "$root/$courseName/instructor/",
		"File Transfer"    => "",
	);
}

sub title {
	my $self = shift;
	
	return "File Transfer";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $authz = $self->{authz};
	
	my $userID = $r->param("user");
	
	return CGI::em("You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($userID, "access_instructor_tools");
	
	# if we needed to get either of these lists earlier, use the cached copy
	# otherwise, get them from the filesystem
	#my $classlistsRef = $self->{classlists} || [ $self->getCSVList ];
	#my $setDefsRef    = $self->{setDefs}    || [ $self->getDefList ];
	my $classlistsRef = [ $self->getCSVList ];
	my $setDefsRef    = [ $self->getDefList ];
	
	print CGI::p(<<EOT);
Use the tools below to modify course files. Set definition files and classlist
files are only used for importing and exporting set and user data.
EOT
	
	print CGI::table({-border=>1},
		CGI::Tr({-valign=>"top"},
			CGI::td({},
				CGI::p("Set Definition Files"),
				CGI::startform("POST", $r->uri, "multipart/form-data"),
				$self->hidden_authen_fields,
				CGI::scrolling_list(
					-name => "def",
					-values => $setDefsRef,
					-size => 8,
					-multiple => 0,
				), CGI::br(),
				CGI::submit("deleteDef", "Delete"),
				CGI::font({-color=>"red"}, CGI::em("Delete is not undoable!")),
				CGI::br(),
				CGI::submit("downloadDef", "Download"),
				CGI::br(),
				CGI::p("Upload New Set Definition File:"),
				CGI::filefield(
					-name => "newDef",
					-size => 30,
				), CGI::br(),
				"Use name:", CGI::textfield("newDefName", "", 30), CGI::br(),
				CGI::submit("uploadDef", "Upload Set Definition File"),
				CGI::endform(),
			),
			CGI::td({},
				CGI::p("Classlist Files"),
				CGI::startform("POST", $r->uri, "multipart/form-data"),
				$self->hidden_authen_fields,
				CGI::scrolling_list(
					-name => "classlist",
					-values => $classlistsRef,
					-size => 8,
					-multiple => 0,
				), CGI::br(),
				CGI::submit("deleteClasslist", "Delete"),
				CGI::font({-color=>"red"}, CGI::em("Delete is not undoable!")),
				CGI::br(),
				CGI::submit("downloadClasslist", "Download"), CGI::br(),
				CGI::p("Upload New Classlist File:"),
				CGI::filefield(
					-name => "newClasslist",
					-size => 30,
				), CGI::br(),
				"Use name:", CGI::textfield("newClasslistName", "", 30), CGI::br(),
				CGI::submit("uploadClasslist", "Upload Classlist File"),
				CGI::endform(),
			),
		)
	);
	
	return "";
}

1;

__END__

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu

=cut
