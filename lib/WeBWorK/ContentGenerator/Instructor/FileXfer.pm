################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/FileXfer.pm,v 1.8 2004/07/08 14:53:47 gage Exp $
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

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $authz = $r->authz;
	
	my $userID = $r->param("user");
	
	my ($type, $action) = ("", "");
	if (defined $r->param("deleteDef"))           { $type = "def";         $action = "delete";   }
	if (defined $r->param("downloadDef"))         { $type = "def";         $action = "download"; }
	if (defined $r->param("uploadDef"))           { $type = "def";         $action = "upload";   }
	if (defined $r->param("deleteClasslist"))     { $type = "classlist";   $action = "delete";   }
	if (defined $r->param("downloadClasslist"))   { $type = "classlist";   $action = "download"; }
	if (defined $r->param("uploadClasslist"))     { $type = "classlist";   $action = "upload";   }
	if (defined $r->param("deleteScoringFile"))   { $type = "scoringFile"; $action = "delete";   }
	if (defined $r->param("downloadScoringFile")) { $type = "scoringFile"; $action = "download"; }
	if (defined $r->param("uploadScoringFile"))   { $type = "scoringFile"; $action = "upload";   }
	if (defined $r->param("deleteTemplateFile"))  { $type = "templateFile"; $action = "delete";   }
	if (defined $r->param("downloadTemplateFile")){ $type = "templateFile"; $action = "download"; }
	if (defined $r->param("uploadTemplateFile"))  { $type = "templateFile"; $action = "upload";   }

	
	# make sure we have permission to do what we want to do
	if ($type eq "def") {
		unless ($authz->hasPermissions($userID, "modify_set_def_files")) {
			$self->addbadmessage(CGI::p("You are not authorized to modify the list of set definition files."));
			return;
		}
	} elsif ($type eq "classlist") {
		unless ($authz->hasPermissions($userID, "modify_classlist_files")) {
			$self->addbadmessage(CGI::p("You are not authorized to modify the list of classlist files."));
			return;
		}
	} elsif ($type eq "scoringFile") {
		unless ($authz->hasPermissions($userID, "modify_scoring_files")) {
			$self->addbadmessage(CGI::p("You are not authorized to modify the list of scoring files."));
			return;
		}
	} elsif ($type eq "templateFile") {
		unless ($authz->hasPermissions($userID, "modify_problem_template_files")) {
			$self->addbadmessage(CGI::p("You are not authorized to modify the list of problem template files."));
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
	my $r = $self->r;
	my $ce = $r->ce;
	
	my (@fileList, $selectParam, $dir);
	if ($type eq "classlist") {
		@fileList = $self->getCSVList;
		$selectParam = "classlist";
		$dir = $ce->{courseDirs}->{templates};
	} elsif ($type eq "def") {
		@fileList = $self->getDefList;
		$selectParam = "def";
		$dir = $ce->{courseDirs}->{templates};
	} elsif ($type eq "scoringFile") {
		@fileList = $self->getScoringFileList;
		$selectParam = "scoringFile";
		$dir = $ce->{courseDirs}->{scoring};
	} elsif ($type eq "templateFile") {
	    my $templateSubDir    = $r->param("templateSubDir");
		@fileList = $self->getTemplateFileList($templateSubDir);
		$selectParam = "templateFile";
		$dir = $ce->{courseDirs}->{templates}."/$templateSubDir";
	} else {
		die "handleDelete() doesn't know what to do with file type $type!";
	}
	
	# get file name
	my $fileToDelete = $r->param($selectParam);
	unless ($fileToDelete) {
		$self->addbadmessage(CGI::p("No file selected for deletion."));
		return;
	}
	
	# FIXME: FOR THE LOVE OF GOD, ADD SECURITY CHECKS!!!!!!
	# (actually I think it's not such a big deal, since we're checking the
	# tainted input against a finite set of files that we know are okay to
	# delete)
	
	# make sure it's in the file list
	unless (grep { $_ eq $fileToDelete } @fileList) {
		$self->addbadmessage(CGI::p("File \"$fileToDelete\" not found in file list."));
		return;
	}
	
	# (at this point we know the filename isn't dangerous)
	
	# delete it
	unlink "$dir/$fileToDelete";
	$self->addgoodmessage("$dir/$fileToDelete has been deleted.");
}

sub handleDownload {
	my ($self, $type) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	my (@fileList, $selectParam, $dir);
	if ($type eq "classlist") {
		@fileList = $self->getCSVList;
		$selectParam = "classlist";
		$dir = $ce->{courseDirs}->{templates};
	} elsif ($type eq "def") {
		@fileList = $self->getDefList;
		$selectParam = "def";
		$dir = $ce->{courseDirs}->{templates};
	} elsif ($type eq "scoringFile") {
		@fileList = $self->getScoringFileList;
		$selectParam = "scoringFile";
		$dir = $ce->{courseDirs}->{scoring};
	} elsif ($type eq "templateFile") {
	    my $templateSubDir    = $r->param("templateSubDir");
		@fileList = $self->getTemplateFileList($templateSubDir);
		$selectParam = "templateFile";
		$dir = $ce->{courseDirs}->{templates};
		$dir = $ce->{courseDirs}->{templates}."/$templateSubDir";
	} else {
		die "handleDownload() doesn't know what to do with file type $type!";
	}
	
	# get file name
	my $fileToDownload = $r->param($selectParam);
	unless ($fileToDownload) {
		$self->addbadmessage(CGI::p("No file selected for download."));
		return;
	}
	
	# make sure it's in the file list
	unless (grep { $_ eq $fileToDownload } @fileList) {
		$self->addbadmessage(CGI::p("File \"$fileToDownload\" not found in file list."));
		return;
	}
	
	# set the file to sent:
	$self->reply_with_file("text/plain", "$dir/$fileToDownload", $fileToDownload, 0);
}

sub handleUpload {
	my ($self, $type) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
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
	} elsif ($type eq "scoringFile") {
		@fileList = $self->getScoringFileList;
		$uploadParam = "newScoringFile";
		$uploadNameParam = "newScoringFileName";
		$ext = ".csv";
		$destDir = $ce->{courseDirs}->{scoring};
	} elsif ($type eq "templateFile") {
	    my $templateSubDir    = $r->param("templateSubDir");
		@fileList = $self->getTemplateFileList($templateSubDir);
		$uploadParam = "newTemplateFile";
		$uploadNameParam = "newTemplateFileName";
		$ext = ".pg";
		$destDir = $ce->{courseDirs}->{templates}."/$templateSubDir";
	}
	
	# get upload ID and hash
	my $uploadIDHash = $r->param($uploadParam);
	unless ($uploadIDHash) {
		$self->addbadmessage(CGI::p("No file selected for upload."));
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
		$self->addbadmessage(CGI::p("A file named \"$fileName\" exists. Either remove it, or chose a different name for your upload."));
		return;
	}
	
	$upload->disposeTo("$destDir/$fileName");
	$self->addgoodmessage("$destDir/$fileName has been uploaded.");
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $authz = $r->authz;
	
	my $userID = $r->param("user");
	
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($r->param("user"), "access_instructor_tools");
	
	# if we needed to get either of these lists earlier, use the cached copy
	# otherwise, get them from the filesystem
	#my $classlistsRef = $self->{classlists} || [ $self->getCSVList ];
	#my $setDefsRef    = $self->{setDefs}    || [ $self->getDefList ];
	
	my $templateSubDir    = $r->param("templateSubDir");
	$templateSubDir = "" if $templateSubDir and $templateSubDir eq ' Top'; #deal with special value for top directory
	my $classlistsRef     = [ $self->getCSVList         ];
	my $setDefsRef        = [ $self->getDefList         ];
	my $scoringFileRef    = [ $self->getScoringFileList ];
	my $templateDirRef    = [ $self->getTemplateDirList ];
	my $templateFileRef   = [ $self->getTemplateFileList($templateSubDir) ];
	
	
	
	print CGI::p(<<EOT);
Use the tools below to modify course files. Set definition files and classlist
files are only used for importing and exporting set and user data.
EOT
	
	print CGI::table({-border=>1, -nowrap=>1},
		CGI::Tr({-valign=>"top"},
			$authz->hasPermissions($userID, "modify_set_def_files") ?
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
			) : CGI::td({}, CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to modify the list of set definition files."))),
			$authz->hasPermissions($userID, "modify_classlist_files") ?
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
				) : CGI::td({}, CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to modify the list of classlist files."))),
		),
		CGI::Tr({-valign=>"top"},
			$authz->hasPermissions($userID, "modify_scoring_files") ?
				CGI::td({},
					CGI::p("Scoring Files"),
					CGI::startform("POST", $r->uri, "multipart/form-data"),
					$self->hidden_authen_fields,
					CGI::scrolling_list(
						-name => "scoringFile",
						-values => $scoringFileRef,
						-size => 8,
						-multiple => 0,
					), CGI::br(),
					CGI::submit("deleteScoringFile", "Delete"),
					CGI::font({-color=>"red"}, CGI::em("Delete is not undoable!")),
					CGI::br(),
					CGI::submit("downloadScoringFile", "Download"),
					CGI::br(),
					CGI::p("Upload New Scoring File:"),
					CGI::filefield(
						-name => "newScoringFile",
						-size => 30,
					), CGI::br(),
					"Use name:", CGI::textfield("newScoringFileName", "", 30), CGI::br(),
					CGI::submit("uploadScoringFile", "Upload Scoring File"),
					CGI::endform(),
				) : CGI::td({}, CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to modify the list of scoring files."))),
			 $authz->hasPermissions($userID, "modify_problem_template_files") ?
				CGI::td({},
					CGI::p("Problem Template Files"),
					CGI::startform("POST", $r->uri, "multipart/form-data"),
					$self->hidden_authen_fields,
					CGI::popup_menu(
						-name => "templateSubDir",
						-values => $templateDirRef,
						-default => ( defined($templateSubDir) )?  $templateSubDir:' Top',
					),CGI::br(),
					CGI::submit('UpdateList','Update List'),CGI::br(),
					CGI::scrolling_list(
						-name => "templateFile",
						-values => $templateFileRef,
						-size => 8,
						-multiple => 0,
					), CGI::br(),
					CGI::submit("deleteTemplateFile", "Delete"),
					CGI::font({-color=>"red"}, CGI::em("Delete is not undoable!")),
					CGI::br(),
					CGI::submit("downloadTemplateFile", "Download"),
					CGI::br(),
					CGI::p("Upload New Problem Template File:"),
					CGI::filefield(
						-name => "newTemplateFile",
						-size => 30,
					), CGI::br(),
					"Use name:", CGI::textfield("newTemplateFileName", "", 30), CGI::br(),
					CGI::submit("uploadTemplateFile", "Upload Problem Template File"),
					CGI::endform(),
				) : CGI::td({}, CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to modify the list of problem template files."))),

		),
			
	);
	
	return "";
}

1;

__END__

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu

=cut
