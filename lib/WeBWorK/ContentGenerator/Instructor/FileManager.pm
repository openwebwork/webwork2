################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/FileManager.pm,v 1.30 2007/09/08 21:15:16 dpvc Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator::Instructor::FileManager;
use base qw(WeBWorK::ContentGenerator::Instructor);

use utf8;
use WeBWorK::Utils qw(readDirectory readFile sortByName listFilesRecursive);
use WeBWorK::Upload;
use File::Path;
use File::Copy;
use File::Spec;

use String::ShellQuote;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::FileManager.pm -- simple directory manager for WW files

=cut

use strict;
use warnings;
#use CGI;
use WeBWorK::CGI;

use WeBWorK::Utils::CourseManagement qw(archiveCourse);

use constant HOME => 'templates';

#
#  The list of file extensions and the directories they usually go in.
#
my %uploadDir = (
  csv  => 'scoring',
  lst  => 'templates',
  pg   => 'templates/.*',
  pl   => 'templates/macros',
  def  => 'templates',
  html => 'html/.*',
);

##################################################
#
# Check that the user is authorized, and then
# see if there is a download to perform.
#
sub pre_header_initialize {
	my $self = shift;
	my $r = $self->r;
	my $authz = $r->authz;
	my $user = $r->param('user');
	
	# we don't need to return an error here, because body() will print an error for us :)
	return unless $authz->hasPermissions($user, "manage_course_files");
	
	my $action = $r->param('action');
	$self->Download if ($action && ($action eq 'Download' || $action eq $r->maketext("Download")));
	my $file = $r->param('download');
	$self->downloadFile($file) if (defined $file);
	my $ce = $r->ce;
	my $urlpath = $r->urlpath;
	my $courseID = $r->urlpath->arg("courseID");
	# removed archived_course_ prefix -- it is important that path matches the $courseID for consitency with the database dump
	my $archive_path = $ce->{webworkDirs}{courses} . "/$courseID/templates/$courseID.tar.gz";
	my %options = (courseID => $courseID, archive_path => $archive_path, ce=>$ce );
	$self->{archive_options}= \%options;

}

##################################################
#
# Download a given file
#
sub downloadFile {
	my $self = shift;
	my $r = $self->r;
	my $file = checkName(shift);
	my $pwd = $self->checkPWD(shift || $self->r->param('pwd') || HOME);
	return unless $pwd;
	$pwd = $self->{ce}{courseDirs}{root} . '/' . $pwd;
	unless (-e "$pwd/$file") {
		$self->addbadmessage($r->maketext("The file you are trying to download doesn't exist"));
		return;
	}
	unless (-f "$pwd/$file") {
		$self->addbadmessage($r->maketext("You can only download regular files."));
		return;
	}
	my $type = "application/octet-stream";
	$type = "text/plain" if $file =~ m/\.(pg|pl|pm|txt|def|csv|lst)/;
	$type = "image/gif"  if $file =~ m/\.gif/;
	$type = "image/jpeg" if $file =~ m/\.(jpg|jpeg)/;
	$type = "image/png"  if $file =~ m/\.png/;
	$self->reply_with_file($type, "$pwd/$file", $file, 0);
}

##################################################
#
# The main body of the page
#
sub body {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $courseRoot = $ce->{courseDirs}{root};
	my $courseName = $urlpath->arg('courseID');
	my $user       = $r->param('user');
	my $key        = $r->param('key');
	
	return CGI::em("You are not authorized to manage course files")
		unless $authz->hasPermissions($user, "manage_course_files");

	$self->{pwd} = $self->checkPWD($r->param('pwd') || HOME);
	return CGI::em("You have specified an illegal working directory!") unless defined $self->{pwd};

	my $fileManagerPage = $urlpath->newFromModule($urlpath->module, $r, courseID => $courseName);
	my $fileManagerURL  = $self->systemLink($fileManagerPage, authen => 0);

	print CGI::start_form(
		-method=>"POST",
		-action=>$fileManagerURL,
		-id=>"FileManager",
		-enctype=> 'multipart/form-data',
		-name=>"FileManager",
         -style=>"margin:0",
	);
	print $self->hidden_authen_fields;

	$self->{courseRoot} = $courseRoot;
	$self->{courseName} = $courseName;

	#
	#replaced by a list of if/elsif because the translation didn't recognize the translated actions.
	#
	my $action = $r->param('action') || $r->param('formAction') || $r->param("confirmed") || 'Init';
	#$self->addgoodmessage("|$action|");
	if($action eq "Refresh" 	|| $action eq $r->maketext("Refresh")) {$self->Refresh;}
	elsif($action eq "Cancel" 	|| $action eq $r->maketext("Cancel")) {$self->Refresh;} 
	elsif($action eq "Directory"|| $action eq $r->maketext("Directory")) {$self->Go;} 
	elsif($action eq "Go" 		|| $action eq $r->maketext("Go")) {$self->Go;} 
	elsif($action eq "View" 	|| $action eq $r->maketext("View")) {$self->View;} 
	elsif($action eq "Edit" 	|| $action eq $r->maketext("Edit")) {$self->Edit;} 
	elsif($action eq "Download" 	|| $action eq $r->maketext("Download")) {$self->Refresh;} 
	elsif($action eq "Copy" 	|| $action eq $r->maketext("Copy")) {$self->Copy;} 
	elsif($action eq "Rename" 	|| $action eq $r->maketext("Rename")) {$self->Rename;} 
	elsif($action eq "Delete" 	|| $action eq $r->maketext("Delete")) {$self->Delete;} 
	elsif($action eq "Make Archive" || $action eq $r->maketext("Make Archive")) {$self->MakeArchive;} 
	elsif($action eq "Unpack" 	|| $action eq $r->maketext("Unpack")) {$self->UnpackArchive;} 
	elsif($action eq "New Folder"	|| $action eq $r->maketext("New Folder")) {$self->NewFolder;} 
	elsif($action eq "New File" 	|| $action eq $r->maketext("New File")) {$self->NewFile;} 
	elsif($action eq "Upload" 	|| $action eq $r->maketext("Upload")) {$self->Upload;} 
	elsif($action eq "Revert" 	|| $action eq $r->maketext("Revert")) {$self->Edit;} 
	elsif($action eq "Save As" 	|| $action eq $r->maketext("Save As")) {$self->SaveAs;} 
	elsif($action eq "Save" 	|| $action eq $r->maketext("Save")) {$self->Save;} 
	elsif($action eq "Init" 	|| $action eq $r->maketext("Init")) {$self->Init;} 
	elsif($action eq "^"        || $action eq "\\") {$self->ParentDir;} 
	else {
	  $self->addbadmessage("Unknown action");
	  $self->Refresh;
	}
	#for ($action) {
#		/^Refresh/i    and do {$self->Refresh; last};
#		/^Cancel/i     and do {$self->Refresh; last};
#		/^\^/i         and do {$self->ParentDir; last};
#		/^Directory/i  and do {$self->Go; last};
#		/^Go/i         and do {$self->Go; last};
#		/^View/i       and do {$self->View; last};
#		/^Edit/i       and do {$self->Edit; last};
#		/^Download/i   and do {$self->Refresh; last};
#		/^Copy/i       and do {$self->Copy; last};
#		/^Rename/i     and do {$self->Rename; last};
#		/^Delete/i     and do {$self->Delete; last};
#		/^Make/i       and do {$self->MakeArchive; last};
#		/^Unpack/i     and do {$self->UnpackArchive; last};
#		/^New Folder/i and do {$self->NewFolder; last};
#		/^New File/i   and do {$self->NewFile; last};
#		/^Upload/i     and do {$self->Upload; last};
#		/^Revert/i     and do {$self->Edit; last};
#		/^Save As/i    and do {$self->SaveAs; last};
#		/^Save/i       and do {$self->Save; last};
#		/^Init/i       and do {$self->Init; last};
	#}
    if ($r->param('archiveCourse') ) {
         my %options = %{$self->{archive_options}};
        my $courseID = $options{courseID};
        $self->addgoodmessage($r->maketext("Archiving course as [_1].tar.gz. Reload FileManager to see it.",$courseID));
    	WeBWorK::Utils::CourseManagement::archiveCourse(%options);
    	$self->addgoodmessage($r->maketext("Course archived."));
    	
    }
	print CGI::hidden({name=>'pwd',value=>$self->{pwd}});
	print CGI::hidden({name=>'formAction',value=>""});
	print CGI::end_form();

	return "";
}


##################################################
#
#  First time through
#
sub Init {
	my $self = shift;
	$self->r->param('unpack',1);
	$self->r->param('autodelete',1);
	$self->r->param('format','Automatic');
	$self->Refresh;
}

sub HiddenFlags {
	my $self = shift;
	print CGI::hidden({name=>"dates",     value=>$self->getFlag('dates')});
	print CGI::hidden({name=>"overwrite", value=>$self->getFlag('overwrite')});
	print CGI::hidden({name=>"unpack",    value=>$self->getFlag('unpack')});
	print CGI::hidden({name=>"autodelete",value=>$self->getFlag('autodelete')});
	print CGI::hidden({name=>"format",    value=>$self->getFlag('format','Automatic')});
}

##################################################
#
# Display the directory listing and associated buttons
#

sub Refresh {
 	my $self = shift;
	my $r = $self->r;
	my $pwd = shift || $self->{pwd};
	my $isTop = $pwd eq '.' || $pwd eq '';

	my ($dirs,$dirlabels) = directoryMenu($self->{courseName},$pwd);
	my ($files,$filelabels) = directoryListing($self->{courseRoot},$pwd,$self->getFlag('dates'));

	unless ($files) {
		$self->addbadmessage($r->maketext("The directory you specified doesn't exist"));
		$files = []; $filelabels = {};
	}

	#
	# Some JavaScript to make things easier for the user
	#
	print CGI::script(<<EOF);
		function doForm(action) {
			var form = window.document.getElementById('FileManager');
			form.formAction.value = action;
			form.submit();
		}
		function disableButton(id,state) {
			var element = window.document.getElementById(id);
			element.disabled = state;
		}
		function checkFiles() {
			var files = window.document.getElementById('files');
			var state = files.selectedIndex < 0;
			disableButton('View',state);
			disableButton('Edit',state);
			disableButton('Download',state);
			disableButton('Rename',state);
			disableButton('Copy',state);
			disableButton('Delete',state);
			disableButton('MakeArchive',state);
			checkArchive(files,state);
		}
		function checkFile() {
			var file = window.document.getElementById('file');
			if (navigator.vendor && navigator.vendorSub && navigator.vendor == "Netscape") {
			  if (navigator.vendorSub.match(/(\\d+)\.(\\d+)/)) {
			    if (RegExp.\$1 < 7 || (RegExp.\$1 == 7 && RegExp.\$2 < 2)) return;
			  }
			}
			var state = (file.value == "");
			disableButton('Upload',state);
		}
		function checkArchive(files,disabled) {
			var button = document.getElementById('MakeArchive');
			//button.value = 'Make Archive';
			if (disabled) return;
			if (!files.childNodes[files.selectedIndex].value.match(/\\.(tar|tar\\.gz|tgz)\$/)) return;
			for (var i = files.selectedIndex+1; i < files.length; i++)
			  {if (files.childNodes[i].selected) return}
			button.value = 'Unpack Archive';
		}
EOF

	#
	# Start the table
	#
	print CGI::start_table({border=>0,cellpadding=>0,cellspacing=>3, style=>"margin:1em 0 0 3em"});

	#
	# Directory menu and date/size checkbox
	#
	print CGI::Tr({},
		CGI::td({colspan=>2},
			CGI::input({type=>"submit", name=>"action", value => "^", ($isTop? (disabled=>1): ())}),
			CGI::popup_menu(
				-name => "directory",
				-values => $dirs,
				-labels => $dirlabels,
				-style => "width:25em",
				-onChange => "doForm('Go')"
			),
			CGI::noscript(CGI::input({type=>"submit",name=>"action",value=>"Go"}))
		),
		CGI::td(CGI::small(CGI::checkbox(
			-name => 'dates',
			-checked => $self->getFlag('dates'),
			-value => 1,
			-label => $r->maketext('Show Date & Size'),
			-onClick => 'doForm("Refresh")',
		))),
	);

	#
	# Directory Listing and column of buttons
	#
	my %button = (type=>"submit",name=>"action",style=>"width:10em");
	my $width = ($self->getFlag('dates') && scalar(@{$files}) > 0) ? "": " width:30em";
	print CGI::Tr({valign=>"middle"},
		fixSpaces(CGI::td(CGI::scrolling_list(
			-name => "files", id => "files",
			-style => "font-family:monospace; $width",
			-size => 17,
			-multiple => 1,
			-values => $files,
			-labels => $filelabels,
			-onDblClick => "doForm('View')",
			-onChange => "checkFiles()"
		))),
		CGI::td({width=>15}),
		CGI::td({},
			CGI::start_table({border=>0,cellpadding=>0,cellspacing=>3}),
			CGI::Tr([
				CGI::td(CGI::input({%button,value=>$r->maketext("View"),id=>"View"})),
				CGI::td(CGI::input({%button,value=>$r->maketext("Edit"),id=>"Edit"})),
				CGI::td(CGI::input({%button,value=>$r->maketext("Download"),id=>"Download"})),
				CGI::td(CGI::input({%button,value=>$r->maketext("Rename"),id=>"Rename"})),
				CGI::td(CGI::input({%button,value=>$r->maketext("Copy"),id=>"Copy"})),
				CGI::td(CGI::input({%button,value=>$r->maketext("Delete"),id=>"Delete"})),
				CGI::td(CGI::input({%button,value=>$r->maketext("Make Archive"),id=>"MakeArchive"})),
				CGI::td({height=>10}),
				CGI::td(CGI::input({%button,value=>$r->maketext("New File")})),
				CGI::td(CGI::input({%button,value=>$r->maketext("New Folder")})),
				CGI::td(CGI::input({%button,value=>$r->maketext("Refresh")})),
			]),
			CGI::end_table(),
		),
	);

	#
	# Upload button and checkboxes
	#
	print CGI::Tr([
		CGI::td(),
		CGI::td({colspan=>3},
		  CGI::input({type=>"submit",name=>"action",style=>"width:7em",value=>$r->maketext("Upload"),id=>"Upload"}),
		  CGI::input({type=>"file",name=>"file",id=>"file",size=>40,onChange=>"checkFile()"}),
		  CGI::br(),
		  CGI::small(join(' &nbsp; ',$r->maketext('Format').':',
		    CGI::radio_group(-name=>'format', -value=>[$r->maketext('Text'),$r->maketext('Binary'),$r->maketext('Automatic')],
				     -default=>$self->getFlag('format','Automatic')))),
		),
	]);
	print CGI::Tr([
		CGI::td(),
		CGI::td({colspan=>3},
		  CGI::small(CGI::checkbox(-name=>'overwrite',-checked=>$self->getFlag('overwrite'),-value=>1,
					   -label=>$r->maketext('Overwrite existing files silently'))),
		  CGI::br(),
		  CGI::small(CGI::checkbox(-name=>'unpack',-checked=>$self->getFlag('unpack'),-value=>1,
					   -label=>$r->maketext('Unpack archives automatically'))),
		  CGI::small(CGI::checkbox(-name=>'autodelete',-checked=>$self->getFlag('autodelete'),-value=>1,
					   -label=>$r->maketext('then delete them'))),
		),
	]);

	#
	# End the table
	# 
	print CGI::end_table();
	print CGI::script("checkFiles(); checkFile();");
}

##################################################
#
# Move to the parent directory
#
sub ParentDir {
	my $self = shift;
	$self->{pwd} = '.' unless ($self->{pwd} =~ s!/[^/]*$!!);
	$self->Refresh;
}

##################################################
#
# Move to the parent directory
#
sub Go {
	my $self = shift;
	$self->{pwd} = $self->r->param('directory');
	$self->Refresh;
}

##################################################
#
# Open a directory or view a file
#
sub View {
	my $self = shift; my $pwd = $self->{pwd};
	my $r = $self->r;
	my $filename = $self->getFile("view"); return unless $filename;
	my $name = "$pwd/$filename"; $name =~ s!^\./?!!;
	my $file = "$self->{courseRoot}/$pwd/$filename";

	#
	# Don't follow symbolic links
	#
	if ($self->isSymLink($file)) {
	  $self->addbadmessage($r->maketext("You may not follow symbolic links"));
	  $self->Refresh; return;
	}

	#
	# Handle directories by making them the working directory
	#
	if (-d $file) {
		$self->{pwd} .= '/'.$filename;
		$self->Refresh; return;
	}

	unless (-f $file) {
		$self->addbadmessage($r->maketext("You can't view files of that type"));
		$self->Refresh; return;
	}

	#
	# Include a download link
	#
	my $urlpath = $self->r->urlpath;
	my $fileManagerPage = $urlpath->newFromModule($urlpath->module, $r, courseID => $self->{courseName});
	my $fileManagerURL  = $self->systemLink($fileManagerPage, params => {download => $filename, pwd => $pwd});
	print CGI::div({style=>"float:right"},
		 CGI::a({href=>$fileManagerURL},"Download"));
	print CGI::p(),CGI::b($name),CGI::p();
	print CGI::hr();

	#
	# For files, display the file, if possible.
	# If the file is an image, display it as an image.
	#
	if (-T $file) { #check that it is a text file
		my $data = readFile($file);
		print CGI::div({dir=>"auto"},
		    CGI::pre(showHTML($data)));
	} elsif ($file =~ m/\.(gif|jpg|png)/i) {
		print CGI::img({src=>$fileManagerURL, border=>0});
	} else {
		print CGI::div({class=>"ResultsWithError"},
			"The file $file does not appear to be a text or image file.");
	}
}

##################################################
#
# Edit a file
#
sub Edit {
	my $self = shift;
	my $filename = $self->getFile('edit'); return unless $filename;
	my $file = "$self->{courseRoot}/$self->{pwd}/$filename";
	my $r = $self->r;
	my $userID = $r->param('user');
	my $ce = $r->ce;
	my $authz = $r->authz;

	# if its a restricted file, dont allow the web editor to edit it unless
	# that option has been set for the course.  
	foreach my $restrictedFile (@{$ce->{uneditableCourseFiles}}) {
	    if (File::Spec->canonpath($file) eq
		File::Spec->canonpath("$self->{courseRoot}/$restrictedFile") &&
		!$authz->hasPermissions($userID, "edit_restricted_files") ) {
		    $self->addbadmessage($r->maketext("You do not have permission to edit this file."));
		    $self->Refresh; return;
	    }
	}

	if (-d $file) {
		$self->addbadmessage($r->maketext("You can't edit a directory"));
		$self->Refresh; return;
	}

	

	unless (-f $file) {
		$self->addbadmessage($r->maketext("You can only edit text files"));
		$self->Refresh; return;
	}
	if (-T $file) {
		my $data = readFile($file);
		$self->RefreshEdit($data,$filename);
	} else {
		$self->addbadmessage($r->maketext("The file does not appear to be a text file"));
		$self->Refresh; 
	}	
	return;
}

##################################################
#
# Save the edited file
#
sub Save {
	my $self = shift; my $filename = shift;
	my $r=$self->r;
	my $pwd = $self->{pwd};
	if ($filename) {
		$pwd = substr($filename,length($self->{courseRoot})+1);
		$pwd =~ s!(/|^)([^/]*)$!!; $filename = $2;
                $pwd = '.' if $pwd eq '';
	} else {
		$filename = $self->getFile("save"); return unless $filename;
	}
	my $file = "$self->{courseRoot}/$pwd/$filename";
	my $data = $self->r->param("data");

	if (defined($data)) {
		$data =~ s/\r\n?/\n/g;  # convert DOS and Mac line ends to unix
		local (*OUTFILE);
		if (open(OUTFILE,">:encoding(UTF-8)",$file)) {
			eval {print OUTFILE $data; close(OUTFILE)};
			if ($@) {$self->addbadmessage($r->maketext("Failed to save: [_1]",$@))}
			   else {$self->addgoodmessage($r->maketext("File saved"))}
		} else {$self->addbadmessage($r->maketext("Can't write to file [_1]", $!))}
	} else {$data = ""; $self->addbadmessage($r->maketext("Error: no file data was submitted!"))}

	$self->{pwd} = $pwd;
	$self->RefreshEdit($data,$filename);
}

##################################################
#
# Save the edited file under a new name
#
sub SaveAs {
	my $self = shift;

	my $newfile = $self->r->param('name');
	my $original = $self->r->param('files');
	$newfile = $self->verifyPath($newfile,$original);
	if ($newfile) {$self->Save($newfile); return}
	$self->RefreshEdit($self->r->param('data'),$original);
}

##################################################
#
# Display the Edit page
#
sub RefreshEdit {
	my $self = shift; my $data = shift; my $file = shift;
	my $r = $self->r;
	my $pwd = shift || $self->{pwd};
	my $name = "$pwd/$file"; $name =~ s!^\./?!!;

	my %button = (type=>"submit",name=>"action",style=>"width:6em");

	print CGI::p();
	print CGI::start_table({border=>0,cellspacing=>0,cellpadding=>2, width=>"95%", align=>"center"});
	print CGI::Tr([
		CGI::td({align=>"center",style=>"background-color:#CCCCCC"},CGI::b($name)),
		CGI::td(CGI::textarea(-name=>"data",-default=>$data,-override=>1,-rows=>30,-columns=>80,"dir"=>"auto",
				-style=>"width:100%")), ## can't seem to get variable height to work
		CGI::td({align=>"center", nowrap=>1},
			CGI::input({%button,value=>$r->maketext("Cancel")}),"&nbsp;",
			CGI::input({%button,value=>$r->maketext("Revert")}),"&nbsp;",
			CGI::input({%button,value=>$r->maketext("Save")}),,"&nbsp;",
			CGI::input({%button,value=>$r->maketext("Save As")}),
			CGI::input({type=>"text",name=>"name",size=>20,style=>"width:50%"}),
		),
	]);
	print CGI::end_table();
	print CGI::hidden({name=>"files", value=>$file});
	$self->HiddenFlags;
}

##################################################
#
# Copy a file
#
sub Copy {
	my $self = shift;
	my $r = $self->r;	
        my $dir = "$self->{courseRoot}/$self->{pwd}";
	my $original = $self->getFile('copy'); return unless $original;
	my $oldfile = "$dir/$original";

	if (-d $oldfile) {
		# FIXME: need to do recursive directory copy
		$self->addbadmessage("Directory copies are not yet implemented");
		$self->Refresh;
		return;
	}

	if ($self->r->param('confirmed')) {
		my $newfile = $self->r->param('name');
		if ($newfile = $self->verifyPath($newfile,$original)) {
			if (copy($oldfile, $newfile)) {
				$self->addgoodmessage($r->maketext("File successfully copied"));
				$self->Refresh; return;
			} else {$self->addbadmessage($r->maketext("Can't copy file: [_1]", $!))}
		}
	}

	$self->Confirm($r->maketext("Copy file as:"),uniqueName($dir,$original),$r->maketext("Copy"));
	print CGI::hidden({name=>"files",value=>$original});
}

##################################################
#
# Rename a file
#
sub Rename {
	my $self = shift;
	my $r = $self->r;	
        my $dir = "$self->{courseRoot}/$self->{pwd}";
	my $original = $self->getFile('rename'); return unless $original;
	my $oldfile = "$dir/$original";

	if ($self->r->param('confirmed')) {
		my $newfile = $self->r->param('name');
		if ($newfile = $self->verifyPath($newfile,$original)) {
			if (rename $oldfile, $newfile) {
				$self->addgoodmessage($r->maketext("File successfully renamed"));
				$self->Refresh; return;
			} else {$self->addbadmessage($r->maketext("Can't rename file: [_1]", $!))}
		}
	}

	$self->Confirm($r->maketext("Rename file as:"),$original,$r->maketext("Rename"));
	print CGI::hidden({name=>"files",value=>$original});
}

##################################################
#
# Delete a file
#
sub Delete {
	my $self = shift;
	my $r = $self->r;	
	my @files = $self->r->param('files');
	if (scalar(@files) == 0) {
		$self->addbadmessage($r->maketext("You must select at least one file to delete"));
		$self->Refresh; return;
	}

	my $pwd = $self->{pwd};
	my $dir = $self->{courseRoot}.'/'.$pwd;
	if ($self->r->param('confirmed')) {

		#
		# If confirmed, go ahead and delete the files
		#
		foreach my $file (@files) {
			if (defined $self->checkPWD("$pwd/$file",1)) {
				if (-d "$dir/$file" && !-l "$dir/$file") {
					my $removed = eval {rmtree("$dir/$file",0,1)};
					if ($removed) {$self->addgoodmessage($r->maketext("Directory '[_1]' removed (items deleted: [_2])",$file, $removed))}
					else {$self->addbadmessage($r->maketext("Directory '[_1]' not removed: [_2]",$file, $!))}
				} else {
					if (unlink("$dir/$file")) {$self->addgoodmessage($r->maketext("File '[_1]' successfully removed",$file))}
					else {$self->addbadmessage($r->maketext("File '[_1]' not removed: [_2]",$file,$!))}
				}
			} else {$self->addbadmessage($r->maketext("Illegal file '[_1]' specified",$file)); last}
		}
		$self->Refresh;

	} else {

		#
		#  Look up the files to be deleted, and for directories, add / and the contents of the directory
		#
		my @filelist = ();
		foreach my $file (@files) {
			if (defined $self->checkPWD("$pwd/$file",1)) {
				if (-l "$dir/$file") {
					push(@filelist,"$file@");
				} elsif (-d "$dir/$file") {
					my @contents = (); my $dcount = 0;
					foreach my $item (readDirectory("$dir/$file")) {
						next if $item eq "." || $item eq "..";
						if (-l "$dir/$file/$item") {
							push(@contents, "$item@");
						} elsif (-d "$dir/$file/$item") {
							my $count = scalar(listFilesRecursive("$dir/$file/$item",".*"));
							my $s = ($count == 1 ? "" : "s"); $dcount += $count;
							push (@contents, "$item/".CGI::small({style=>"float:right;margin-right:3em"},CGI::i("($count item$s)")));
						} else {
							push(@contents, $item);
						}
						$dcount += 1;
					}
					my $s = ($dcount == 1 ? "": "s");
					@contents = (@contents[0..10],"&nbsp; .","&nbsp; .","&nbsp; .") if scalar(@contents) > 15;
					push (@filelist,$file."/".
								CGI::small({style=>"float:right;margin-right:4em"},CGI::i("($dcount item$s total)")).
								CGI::div({style=>"margin-left:1ex"},join(CGI::br(),@contents)));
				} else {
					push(@filelist,$file);
				}
			}
		}

		#
		# Put up the confirmation dialog box
		#
		print CGI::start_table({border=>1,cellspacing=>2,cellpadding=>20, style=>"margin: 1em 0 0 5em"});
		print CGI::Tr(
			CGI::td(
			  CGI::b($r->maketext("Warning").': '),$r->maketext("You have requested that the following items be deleted"),
			  CGI::ul(CGI::li(\@filelist)),
			    ((grep { -d "$dir/$_" } @files)?
					 CGI::p({style=>"width:500"},$r->maketext("Some of these files are directories. Only delete directories if you really know what you are doing. You can seriously damage your course if you delete the wrong thing.")): ""),
			  CGI::p({style=>"color:red"},$r->maketext("There is no undo for deleting files or directories!")),
			  CGI::p($r->maketext("Really delete the items listed above?")),
			  CGI::div({style=>"float:left; padding-left:3ex"},
			    CGI::input({type=>"submit",name=>"action",value=>"Cancel"})),
			  CGI::div({style=>"float:right; padding-right:3ex"},
			    CGI::input({type=>"submit",name=>"action",value=>"Delete"})),
			),
		);
		print CGI::end_table();

		print CGI::hidden({name=>"confirmed",value=>"Delete"});
		foreach my $file (@files) {print CGI::hidden({name=>"files",value=>$file})}
		$self->HiddenFlags;
	}
}

##################################################
#
# Make a gzipped tar archive
#
sub MakeArchive {
	my $self = shift;
	my $r = $self->r;
	my @files = $self->r->param('files');
	if (scalar(@files) == 0) {
		$self->addbadmessage($r->maketext("You must select at least one file for the archive"));
		$self->Refresh; return;
	}

	my $dir = $self->{courseRoot}.'/'.$self->{pwd};
	my $archive = uniqueName($dir,(scalar(@files) == 1)?
				 $files[0].".tgz": $self->{courseName}.".tgz");
	my $tar = "cd ".shell_quote($dir)." && $self->{ce}{externalPrograms}{tar} -cvzf ".shell_quote($archive,@files);
	@files = readpipe $tar." 2>&1";
	if ($? == 0) {
		my $n = scalar(@files); 
		$self->addgoodmessage($r->maketext("Archive '[_1]' created successfully ([quant, _2, file])",$archive, $n));
	} else {
		$self->addbadmessage($r->maketext("Can't create archive '[_1]': command returned [_2]",$archive,systemError($?)));
	}
	$self->Refresh;
}

##################################################
#
# Unpack a gzipped tar archive
#
sub UnpackArchive {
	my $self = shift;
	my $r = $self->r;
	my $archive = $self->getFile("unpack"); return unless $archive;
	if ($archive !~ m/\.(tar|tar\.gz|tgz)$/) {
		$self->addbadmessage($r->maketext("You can only unpack files ending in '.tgz', '.tar' or '.tar.gz'"));
	} else {
		$self->unpack($archive);
	}
	$self->Refresh;
}

sub unpack {
	my $self = shift;
	my $r = $self->r;
	my $archive = shift; my $z = 'z'; $z = '' if $archive =~ m/\.tar$/;
	my $dir = $self->{courseRoot}.'/'.$self->{pwd};
	my $tar = "cd ".shell_quote($dir)." && $self->{ce}{externalPrograms}{tar} -vx${z}f ".shell_quote($archive);
	my @files = readpipe $tar." 2>&1";
	if ($? == 0) {
		my $n = scalar(@files); 
		$self->addgoodmessage($r->maketext("[quant,_1,file] unpacked successfully",$n));
		return 1;
	} else {
		$self->addbadmessage($r->maketext("Can't unpack '[_1]': command returned [_2]",$archive,systemError($?)));
		return 0;
	}
}

##################################################
#
# Make a new file and edit it
#
sub NewFile {
	my $self = shift;
	my $r = $self->r;

	if ($self->r->param('confirmed')) {
		my $name = $self->r->param('name');
		if (my $file = $self->verifyName($name,"file")) {
			local (*NEWFILE);
			if (open(NEWFILE,">:encoding(UTF-8)",$file)) {
				close(NEWFILE);
				$self->RefreshEdit("",$name);
				return;
			} else {$self->addbadmessage($r->maketext("Can't create file: [_1]",$!))}
		}
	}

	$self->Confirm($r->maketext("New file name:"),"",$r->maketext("New File"));
}

##################################################
#
# Make a new directory
#
sub NewFolder {
	my $self = shift;
	my $r = $self->r;

	if ($self->r->param('confirmed')) {
		my $name = $self->r->param('name');
		if (my $dir = $self->verifyName($name,"directory")) {
			if (mkdir $dir, 0750) {
				$self->{pwd} .= '/'.$name;
				$self->Refresh; return;
			} else {$self->addbadmessage($r->maketext("Can't create directory: [_1]",$!))}
		}
	}

	$self->Confirm($r->maketext("New folder name:"),"",$r->maketext("New Folder"));
}

##################################################
#
# Download a file
#
sub Download {
	my $self = shift;
	my $r = $self->r;	
	my $pwd = $self->checkPWD($self->r->param('pwd') || HOME);
	return unless $pwd;
	my $filename = $self->getFile("download"); return unless $filename;
	my $file = $self->{ce}{courseDirs}{root}.'/'.$pwd.'/'.$filename;

	if (-d $file) {$self->addbadmessage($r->maketext("You can't download directories")); return}
	unless (-f $file) {$self->addbadmessage($r->maketext("You can't download files of that type")); return}

	$self->r->param('download',$filename);
}

##################################################
#
# Upload a file to the server
#
sub Upload {
	my $self = shift;
	my $r = $self->r;
	my $dir = "$self->{courseRoot}/$self->{pwd}";
	my $fileIDhash = $self->r->param('file');
	unless ($fileIDhash) {
		$self->addbadmessage($r->maketext("You have not chosen a file to upload."));
		$self->Refresh;
		return;
	}

	my ($id,$hash) = split(/\s+/,$fileIDhash);
	my $upload = WeBWorK::Upload->retrieve($id,$hash,dir=>$self->{ce}{webworkDirs}{uploadCache});

	my $name = checkName($upload->filename);
	my $action = $self->r->param("formAction") || "Cancel";
	if ($self->r->param("confirmed")) {
		if ($action eq "Cancel" || $action eq $r->maketext("Cancel")) {
			$upload->dispose;
			$self->Refresh;
			return;
		}
		$name = checkName($self->r->param('name')) if ($action eq "Rename" || $action eq $r->maketext("Rename"));
	}

	if (-e "$dir/$name") {
		unless ($self->r->param('overwrite') || $action eq "Overwrite" || $action eq $r->maketext("Overwrite")) {
			
			$self->Confirm($r->maketext("File <b>[_1]</b> already exists. Overwrite it, or rename it as:",$name).CGI::p(),uniqueName($dir,$name),$r->maketext("Rename"),$r->maketext("Overwrite"));
			#$self->Confirm("File ".CGI::b($name)." already exists. Overwrite it, or rename it as:".CGI::p(),uniqueName($dir,$name),"Rename","Overwrite");
			print CGI::hidden({name=>"action",value=>"Upload"});
			print CGI::hidden({name=>"file",value=>$fileIDhash});
			return;
		}
	}
	$self->checkFileLocation($name,$self->{pwd});

	my $file = "$dir/$name";
	my $type = $self->getFlag('format','Automatic');
	my $data;
	
	#
	#  Check if we need to convert linebreaks
	#
	if ($type ne 'Binary') {
		my $fh = $upload->fileHandle;
		my @lines = <$fh>; $data = join('',@lines);
		if ($type eq 'Automatic') {$type = isText($data) ? 'Text' : 'Binary'}
	}
	if ($type eq 'Text') {
		$upload->dispose;
		$data =~ s/\r\n?/\n/g;
		if (open(UPLOAD,">:encoding(UTF-8)",$file)) {
			my $backup_data=$data; 
			my $success= utf8::decode($data); # try to decode as utf8
			unless ($success){
				warn "Trying to convert file $file from latin1? to UTF-8";
				utf8::upgrade($backup_data); # try to convert data from latin1 to utf8.
				$data=$backup_data;
			}
		  print UPLOAD $data; # print massaged data to file. 
		  close(UPLOAD)}
		  else {$self->addbadmessage($r->maketext("Can't create file '[_1]': [_2]", $name, $!))}
	} else {
		$upload->disposeTo($file);
	}

	if (-e $file) {
	  $self->addgoodmessage($r->maketext("File '[_1]' uploaded successfully",$name));
	  if ($name =~ m/\.(tar|tar\.gz|tgz)$/ && $self->getFlag('unpack')) {
	    if ($self->unpack($name) && $self->getFlag('autodelete')) {
	      if (unlink($file)) {$self->addgoodmessage($r->maketext("Archive '[_1]' deleted", $name))}
	        else {$self->addbadmessage($r->maketext("Can't delete archive '[_1]': [_2]", $name, $!))}
	    }
	  }
	}

	$self->Refresh;
}

##################################################
##################################################
#
# Print a confirmation dialog box
#
sub Confirm {
	my $self = shift;
	my $r = $self->r;
	my $message = shift; my $value = shift;
	my $button = shift; my $button2 = shift;

	print CGI::p();
	print CGI::start_table({border=>1,cellspacing=>2,cellpadding=>20, style=>"margin: 1em 0 0 3em"});
	print CGI::Tr(
		CGI::td({align=>"CENTER"},
		  $message,
		  CGI::input({type=>"text",name=>"name",size=>50,value=>$value}),
		  CGI::p(), CGI::center(
		    CGI::div({style=>"float:right; padding-right:3ex"},
		      CGI::input({type=>"submit",name=>"formAction",value=>$button})), # this will be the default
		    CGI::div({style=>"float:left; padding-left:3ex"},
		    CGI::input({type=>"submit",name=>"formAction",value=>$r->maketext("Cancel")})),
		    ($button2 ? CGI::input({type=>"submit",name=>"formAction",value=>$button2}): ()),
		  ),
		),
	      );
	print CGI::end_table();
	print CGI::hidden({name=>"confirmed", value=>$button});
	$self->HiddenFlags;
	print CGI::script("window.document.FileManager.name.focus()");
}

##################################################
##################################################
#
# Check that there is exactly one valid file
#
sub getFile {
	my $self = shift; my $action = shift;
	my $r = $self->r;
	my @files = $self->r->param("files");
	if (scalar(@files) > 1) {
		$self->addbadmessage($r->maketext("You can only [_1] one file at a time.",$action));
		$self->Refresh unless $action eq 'download';
		return;
	}
	if (scalar(@files) == 0 || $files[0] eq "") {
		$self->addbadmessage($r->maketext("You need to select a file to [_1].",$action));
		$self->Refresh unless $action eq 'download';
		return;
	}
	my $pwd = $self->checkPWD($self->{pwd} || $self->r->param('pwd') || HOME) || '.';
	if ($self->isSymLink($pwd.'/'.$files[0])) {
		$self->addbadmessage($r->maketext("You may not follow symbolic links"));
		$self->Refresh unless $action eq 'download';
		return;
	}
	unless ($self->checkPWD($pwd.'/'.$files[0],1)) {
		$self->addbadmessage($r->maketext("You have specified an illegal file"));
		$self->Refresh unless $action eq 'download';
		return;
	}
	return $files[0];
}

##################################################
#
# Get the entries for the directory menu
#
sub directoryMenu {
	my $course = shift;
	my $dir  = shift; $dir =~ s!^\.(/|$)!!;
	my @dirs = split('/',$dir);
	my $menu = ""; my $pwd;
	
	my (@values,%labels);
	while (scalar(@dirs)) {
		$pwd = join('/',(@dirs)[0..$#dirs]);
		$dir = pop(@dirs);
		push(@values,$pwd); $labels{$pwd} = $dir;
	}
	push(@values,'.'); $labels{'.'} = $course;
	return (\@values,\%labels);
}

##################################################
#
# Get the directory listing
#
sub directoryListing {
	my $root = shift; my $pwd = shift; my $showdates = shift;
	my $dir = $root.'/'.$pwd;
	my (@values,%labels,$size,$data);

	return unless -d $dir;
        my $len = 24;
	my @names = sortByName(undef,grep(/^[^.]/,readDirectory($dir)));
	foreach my $name (@names) {
		unless ($name eq 'DATA') {   #FIXME don't view the DATA directory
			my $file = "$dir/$name";
			push(@values,$name); $labels{$name} = $name;
			$labels{$name} .= '@' if (-l $file);
			$labels{$name} .= '/' if (-d $file && !-l $file);
			$len = length($labels{$name}) if length($labels{$name}) > $len;
		}
	}
	if ($showdates) {
		$len += 3;
		foreach my $name (@values) {
			my $file = "$dir/$name";
			my ($size,$date) = (lstat($file))[7,9];
			$labels{$name} = sprintf("%-${len}s%-16s%10s",$labels{$name},
						 ((-d $file)? ("",""):
						  (getDate($date),getSize($size))));
		}
	}
	return (\@values,\%labels);
}

sub getDate {
  my ($sec,$min,$hour,$day,$month,$year) = localtime(shift);
  sprintf("%02d-%02d-%04d %02d:%02d",$month+1,$day,$year+1900,$hour,$min);
}

sub getSize {
  my $size = shift;
  return $size." B "                        if $size < 1024;
  return sprintf("%.1f KB",$size/1024)      if $size < 1024*100;
  return sprintf("%d KB",int($size/1024))   if $size < 1024*1024;
  return sprintf("%.1f MB",$size/1024/1024) if $size < 1024*1024*100;
  return sprintf("%d MB",$size/1024/1024);
}

##################################################
#
#  Check if a file is a symbolic link that we
#  are not allowed to follow.
#
sub isSymLink {
	my $self = shift; my $file = shift;
	return 0 unless -l $file;

	my $courseRoot = $self->{ce}{courseDirs}{root};
	$courseRoot = readlink($courseRoot) if -l $courseRoot;
	my $pwd = $self->{pwd} || $self->r->param('pwd') || HOME;
	my $link = File::Spec->rel2abs(readlink($file),"$courseRoot/$pwd");
	#
	# Remove /./ and dir/../ constructs
	#
	$link =~ s!(^|/)(\.(/|$))+!$1!g;
	while ($link =~ s!((\.[^./]+|\.\.[^/]+|[^./][^/]*)/\.\.(/|$))!!) {};

	#
	# Look through the list of valid paths to see if this link is OK
	#
	my $valid = $self->{ce}{webworkDirs}{valid_symlinks};
	if (defined $valid && $valid) {
		foreach my $path (@{$valid}) {
			return 0 if substr($link,0,length($path)) eq $path;
		}
	}

	return 1;
}

##################################################
#
# Normalize the working directory and check if it is OK.
#
sub checkPWD {
	my $self = shift;
	my $pwd = shift;
	my $renameError = shift;

	$pwd =~ s!//+!/!g;               # remove duplicate slashes
	$pwd =~ s!(^|/)~!$1_!g;          # remove ~user references
	$pwd =~ s!(^|/)(\.(/|$))+!$1!g;  # remove dot directories
	
	# remove dir/.. constructions
	while ($pwd =~ s!((\.[^./]+|\.\.[^/]+|[^./][^/]*)/\.\.(/|$))!!) {};
	
	$pwd =~ s!/$!!;                        # remove trailing /
	return if ($pwd =~ m!(^|/)\.\.(/|$)!); # Error if outside the root

	# check for bad symbolic links
	my @dirs = split('/',$pwd);
	pop(@dirs) if $renameError;      # don't check file iteself in this case
	my @path = ($self->{ce}{courseDirs}{root});
	foreach my $dir (@dirs) {
		push @path,$dir;
		return if ($self->isSymLink(join('/',@path)));
	}

	my $original = $pwd;
	$pwd =~ s!(^|/)\.!$1_!g;         # don't enter hidden directories
	$pwd =~ s!^/!!;                  # remove leading /
	$pwd =~ s![^-_./A-Z0-9~, ]!_!gi; # no illegal characters
	return if $renameError && $original ne $pwd;

	$pwd = '.' if $pwd eq '';
	return $pwd;
}

##################################################
#
# Check that a file is uploaded to the correct directory
#
sub checkFileLocation {
  	my $self = shift;
	my $r = $self->r;
	my $extension = shift; $extension =~ s/.*\.//;
	my $dir = shift; my $location = $uploadDir{$extension};
	return unless defined($location);
	return if $dir =~ m/^$location$/;
	$location =~ s!/\.\*!!;
	return if $dir =~ m/^$location$/;
	$self->addbadmessage(
		$r->maketext("Files with extension '.[_1]' usually belong in '[_2]'",$extension,$location)
		. (($extension eq 'csv') ? $r->maketext(". If this is a class roster, rename it to have extension '.lst'") : '')
	);
}

##################################################
#
# Check a name for bad characters, etc.
#
sub checkName {
	my $file = shift;
	$file =~ s!.*[/\\]!!;               # remove directory
	$file =~ s/[^-_.a-zA-Z0-9 ]/_/g;    # no illegal characters
	$file =~ s/^\./_/;                  # no initial dot
	$file = "newfile.txt" unless $file; # no blank names
	return $file;
}

##################################################
#
# Get a unique name (in case it already exists)
#
sub uniqueName {
	my $dir = shift; my $name = shift;
	return $name unless (-e "$dir/$name");
	my $type = ""; my $n = 1;
	$type = $1 if ($name =~ s/(\.[^.]*)$//);
	$n = $1 if ($name =~ s/_(\d+)$/_/);
	while (-e "$dir/${name}_$n$type") {$n++}
	return "${name}_$n$type";
}

##################################################
#
# Verify that a name can be added to the current
# directory.
#
sub verifyName {
	my $self = shift; my $name = shift; my $object = shift;
	my $r = $self->r;
	if ($name) {
		unless ($name =~ m!/!) {
			unless ($name =~ m!^\.!) {
				unless ($name =~ m![^-_.a-zA-Z0-9 ]!) {
					my $file = "$self->{courseRoot}/$self->{pwd}/$name";
					return $file unless (-e $file);
					$self->addbadmessage($r->maketext("A file with that name already exists"));
				} else {$self->addbadmessage($r->maketext("Your [_1] name contains illegal characters",$object))}
			} else {$self->addbadmessage($r->maketext("Your [_1] name may not begin with a dot",$object))}
		} else {$self->addbadmessage($r->maketext("Your [_1] name may not contain a path component",$object))}
	} else {$self->addbadmessage($r->maketext("You must specify a [_1] name",$object))}
	return
}

##################################################
#
# Verify that a file path is valid
#
sub verifyPath {
	my $self = shift; my $path = shift; my $name = shift;
	my $r = $self->r;
	
	if ($path) {
		unless ($path =~ m![^-_.a-zA-Z0-9 /]!) {
			unless ($path =~ m!^/!) {
				$path = $self->checkPWD($self->{pwd}.'/'.$path,1);
				if ($path) {
					$path = $self->{courseRoot}.'/'.$path;
					$path .= '/'.$name if -d $path && $name;
					return $path unless (-e $path);
					$self->addbadmessage($r->maketext("A file with that name already exists"));
				} else {$self->addbadmessage($r->maketext("You have specified an illegal path"))}
			} else {$self->addbadmessage($r->maketext("You can not specify an absolute path"))}
		} else {$self->addbadmessage($r->maketext("Your file name contains illegal characters"))}
	} else {$self->addbadmessage($r->maketext("You must specify a file name"))}
	return
}

##################################################
#
# Get the value of a parameter flag
#
sub getFlag {
  my $self = shift; my $flag = shift;
  my $default = shift; $default = 0 unless defined $default;
  my $value = $self->r->param($flag);
  $value = $default unless defined $value;
  return $value;
}

##################################################
#
# Make HTML symbols printable
#
sub showHTML {
	my $string = shift;
	return '' unless defined $string;
	$string =~ s/&/\&amp;/g;
	$string =~ s/</\&lt;/g;
	$string =~ s/>/\&gt;/g;
	$string;
}

##################################################
#
# Check if a string is plain text
#
sub isText {
	my $string = shift;

	#return $string !~ m/[^\s\x20-\x7E]{4}/;
	return utf8::is_utf8($string);
	# return $string !~ m/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]{2}/;
}

##################################################
#
#  Convert spaces to &nbsp;, but only REAL spaces
#
sub sp2nbsp {
	my $s = shift;
	$s =~ s/ /\&nbsp;/g;
	return $s;
}

##################################################
#
#  Hack to convert multiple spaces in the file
#  selection box into &nbsp; so that the columns
#  will allign properly in fixed-width fonts.
#  We have to do it agter the fact, since CGI::
#  is being "helpful" by turning & in the labels
#  into &amp; for us.  So we have to convert
#  after the <SELECT> is created (ugh).
#
sub fixSpaces {
	my $s = shift;
	$s =~ s!(<option[^>]*>)(.*?)(</option>)!$1.sp2nbsp($2).$3!gei;
	return $s;
}

##################################################
#
#  Interpret command return errors
#
sub systemError {
  my $status = shift;
  return "error: $!" if $status == 0xFF00;
  return "exit status ".($status >> 8) if ($status & 0xFF) == 0;
  return "signal ".($status &= ~0x80);
}

##################################################

1;
