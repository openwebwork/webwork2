################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/FileManager.pm,v 1.10 2004/09/05 01:03:13 dpvc Exp $
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

package WeBWorK::ContentGenerator::Instructor::FileManager;
use base qw(WeBWorK::ContentGenerator::Instructor);

use WeBWorK::Utils qw(readDirectory readFile sortByName);
use WeBWorK::Upload;
use File::Path;
use File::Copy;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::FileManager.pm  -- simple directory manager for WW files

=cut

use strict;
use warnings;
use CGI;

##################################################
#
#  Check that the user is authorized, and then
#    see if there is a download to perform.
#
sub pre_header_initialize {
  my $self       = shift;
  my $r          = $self->r;
  my $authz      = $r->authz;
  my $user       = $r->param('user');
	
  unless ($authz->hasPermissions($user, "access_instructor_tools")) {
    $self->addbadmessage("You aren't authorized to manage course files");
    return;
  }

  my $action = $r->param('action');
  $self->Download if ($action && $action eq 'Download');
  my $file = $r->param('download');
  $self->downloadFile($file) if (defined $file);
}

##################################################
#
#  Download a given file
#
sub downloadFile {
  my $self = shift;
  my $file = checkName(shift);
  my $pwd = checkPWD(shift || $self->r->param('pwd') || '.');
  return unless $pwd;
  $pwd = $self->{ce}{courseDirs}{root} . '/' . $pwd;
  unless (-e "$pwd/$file") {
    $self->addbadmessage("The file you are trying to download doesn't exist");
    return;
  }
  unless (-f "$pwd/$file") {
    $self->addbadmessage("You can only download regular files.");
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
#  The main body of the page
#
sub body {
  my $self          = shift;
  my $r             = $self->r;
  my $urlpath       = $r->urlpath;
  my $db            = $r->db;
  my $ce            = $r->ce;
  my $authz         = $r->authz;
  my $courseRoot    = $ce->{courseDirs}{root};
  my $courseName    = $urlpath->arg('courseID');  
  my $user          = $r->param('user');
  my $key           = $r->param('key');
	
  return CGI::em("You are not authorized to access the instructor tools")
    unless $authz->hasPermissions($user, "access_instructor_tools");

  $self->{pwd} = checkPWD($r->param('pwd') || '.');
  return CGI::em("You have specified an illegal working directory!") unless defined $self->{pwd};

  my $fileManagerPage = $urlpath->newFromModule($urlpath->module, courseID => $courseName);
  my $fileManagerURL  = $self->systemLink($fileManagerPage, authen => 0);

  print CGI::start_multipart_form(
    -method=>"POST",
    -action=>$fileManagerURL,
    -id=>"FileManager",
    -name=>"FileManager"
  );
  print $self->hidden_authen_fields;

  $self->{courseRoot} = $courseRoot;
  $self->{courseName} = $courseName;

  my $action = $r->param('action') || $r->param('formAction') || 'Refresh';

  for ($action) {
    /^Refresh/i       and do {$self->Refresh; last};
    /^Cancel/i        and do {$self->Refresh; last};
    /^\^/i            and do {$self->ParentDir; last};
    /^Directory/i     and do {$self->Go; last};
    /^Go/i            and do {$self->Go; last};
    /^View/i          and do {$self->View; last};
    /^Edit/i          and do {$self->Edit; last};
    /^Download/i      and do {$self->Refresh; last};
    /^Copy/i          and do {$self->Copy; last};
    /^Rename/i        and do {$self->Rename; last};
    /^Delete/i        and do {$self->Delete; last};
    /^New Folder/i    and do {$self->NewFolder; last};
    /^New File/i      and do {$self->NewFile; last};
    /^Upload/i        and do {$self->Upload; last};
    /^Revert/i        and do {$self->Edit; last};
    /^Save As/i       and do {$self->SaveAs; last};
    /^Save/i          and do {$self->Save; last};
    $self->addbadmessage("Unknown action.");
    $self->Refresh;
  }

  print CGI::hidden({name=>'pwd',value=>$self->{pwd}});
  print CGI::hidden({name=>'formAction'});
  print CGI::end_multipart_form();

  return "";
}


##################################################
#
#  Display the directory listing and associated buttons
#
sub Refresh {
  my $self = shift;
  my $pwd = shift || $self->{pwd};
  my $isTop = $pwd eq '.' || $pwd eq '';

  my ($dirs,$dirlabels) = directoryMenu($self->{courseName},$pwd);
  my ($files,$filelabels) = directoryListing($self->{courseRoot},$pwd);

  unless ($files) {
    $self->addbadmessage("The directory you specified doesn't exist");
    $files = []; $filelabels = {};
  }

  #
  #  Some JavaScript to make things easier for the user
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
    }
    function checkFile() {
      var file = window.document.getElementById('file');
      var state = (file.value == "");
      disableButton('Upload',state);
    }
EOF

  #
  #  Start the table
  #
  print CGI::start_table({border=>0,cellpadding=>0,cellspacing=>10, style=>"margin:1em 0 0 3em"});

  #
  #  Directory menu
  #
  print CGI::Tr(
	  CGI::td({colspan=>3},
            CGI::input({type=>"submit", name=>"action", value => "^", ($isTop? (disabled=>1): ())}),
	    CGI::popup_menu(-name   => "directory",
			    -values => $dirs, -labels => $dirlabels,
			    -style  => "width:25em",
			    -onChange => "doForm('Go')"),
	    CGI::noscript(CGI::input({type=>"submit",name=>"action",value=>"Go"}))
	  )
        );

  #
  #  Directory Listing
  #
  my %button = (type=>"submit",name=>"action",style=>"width:10em");
  print CGI::Tr({valign=>"middle"},
	  CGI::td(CGI::scrolling_list(-name => "files", id => "files",
				      -style => "font-family:monospace; width:30em; height:100%",
				      -size => 15, -multiple => 1,
				      -values => $files, -labels => $filelabels,
				      -onDblClick => "doForm('View')",
				      -onChange => "checkFiles()")),
	  CGI::td({width=>3}),
	  CGI::td(
	    CGI::start_table({border=>0,cellpadding=>0,cellspacing=>3}),
	    CGI::Tr([
	      CGI::td(CGI::input({%button,value=>"View",id=>"View"})),
	      CGI::td(CGI::input({%button,value=>"Edit",id=>"Edit"})),
	      CGI::td(CGI::input({%button,value=>"Download",id=>"Download"})),
	      CGI::td(CGI::input({%button,value=>"Rename",id=>"Rename"})),
	      CGI::td(CGI::input({%button,value=>"Copy",id=>"Copy"})),
	      CGI::td(CGI::input({%button,value=>"Delete",id=>"Delete"})),
	      CGI::td({height=>10}),
	      CGI::td(CGI::input({%button,value=>"New File"})),
	      CGI::td(CGI::input({%button,value=>"New Folder"})),
	      CGI::td(CGI::input({%button,value=>"Refresh"})),
	    ]),
	    CGI::end_table(),
	  ),
	);

  #
  #  Upload button
  #
  print CGI::Tr([
	  CGI::td(),
	  CGI::td({colspan=>3},
	    CGI::input({type=>"submit",name=>"action",style=>"width:7em",value=>"Upload:",id=>"Upload"}),
	    CGI::input({type=>"file",name=>"file",id=>"file",size=>40,onChange=>"checkFile()"}),
          ),
	]);

  #
  #  End the table
  #	       		   
  print CGI::end_table();
  print CGI::script("checkFiles(); checkFile();");
}

##################################################
#
#  Move to the parent directory
#
sub ParentDir {
  my $self = shift;
  $self->{pwd} = '.' unless ($self->{pwd} =~ s!/[^/]*$!!);
  $self->Refresh;
}

##################################################
#
#  Move to the parent directory
#
sub Go {
  my $self = shift;
  $self->{pwd} = $self->r->param('directory');
  $self->Refresh;
}

##################################################
#
#  Open a directory or view a file
#
sub View {
  my $self = shift; my $pwd = $self->{pwd};
  my $filename = $self->getFile("view"); return unless $filename;
  my $name = "$pwd/$filename"; $name =~ s!^\./?!!;

  #
  #  Handle directories by making them the working directory
  #
  my $file = "$self->{courseRoot}/$pwd/$filename";
  if (-d $file) {
    $self->{pwd} .= '/'.$filename;
    $self->Refresh; return;
  }

  unless (-f $file) {
    $self->addbadmessage("You can't view files of that type");
    $self->Refresh; return;
  }

  #
  #  Include a download link
  #
  my $urlpath = $self->r->urlpath;
  my $fileManagerPage = $urlpath->newFromModule($urlpath->module, courseID => $self->{courseName});
  my $fileManagerURL  = $self->systemLink($fileManagerPage, params => {download => $filename, pwd => $pwd});
  print CGI::div({style=>"float:right"},
		 CGI::a({href=>$fileManagerURL},"Download"));
  print CGI::p(),CGI::b($name),CGI::p();
  print CGI::hr();

  #
  #  For files, display the file, if possible.
  #  If the file is an image, display it as an image.
  #
  my $data = readFile($file);
  if (isText($data)) {
    print CGI::pre(showHTML($data));
  } elsif ($file =~ m/\.(gif|jpg|png)/i) {
    print CGI::img({src=>$fileManagerURL, border=>0});
  } else {
    print CGI::div({class=>"ResultsWithError"},
      "The file does not appear to be a text file.");
  }
}

##################################################
#
#  Edit a file
#
sub Edit {
  my $self = shift;
  my $filename = $self->getFile('edit'); return unless $filename;
  my $file = "$self->{courseRoot}/$self->{pwd}/$filename";

  if (-d $file) {
    $self->addbadmessage("You can't edit a directory");
    $self->Refresh; return;
  }
  unless (-f $file) {
    $self->addbadmessage("You can only edit text files");
    $self->Refresh; return;
  }
  my $data = readFile($file);
  if (!isText($data)) {
    $self->addbadmessage("The file does not appear to be a text file");
    $self->Refresh; return;
  }

  $self->RefreshEdit($data,$filename);
}

##################################################
#
#  Save the edited file
#
sub Save {
  my $self = shift; my $filename = shift;
  my $pwd = $self->{pwd};
  if ($filename) {
    $pwd = substr($filename,length($self->{courseRoot})+1);
    $pwd =~ s!/([^/]*)$!!; $filename = $1;
  } else {
    $filename = $self->getFile("save"); return unless $filename;
  }
  my $file = "$self->{courseRoot}/$pwd/$filename";
  my $data = $self->r->param("data");

  if (defined($data)) {
    if (open(OUTFILE,">$file")) {
      eval {print OUTFILE $data; close(OUTFILE)};
      if ($@) {$self->addbadmessage("Failed to save:  $@")}
         else {$self->addgoodmessage("File saved")}
    } else {$self->addbadmessage("Can't write to file:  $!")}
  } else {$data = ""; $self->addbadmessage("Error: no file data was submitted!")}

  $self->{pwd} = $pwd;
  $self->RefreshEdit($data,$filename);
}

##################################################
#
#  Save the edited file under a new name
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
#  Display the Edit page
#
sub RefreshEdit {
  my $self = shift; my $data = shift; my $file = shift;
  my $pwd = shift || $self->{pwd};
  my $name = "$pwd/$file"; $name =~ s!^\./?!!;

  my %button = (type=>"submit",name=>"action",style=>"width:6em");
  print CGI::p();
  print CGI::start_table({border=>0,cellspacing=>0,cellpadding=>2, width=>"95%", align=>"center"});
  print CGI::Tr([
	  CGI::td({align=>"center",style=>"background-color:#CCCCCC"},CGI::b($name)),
	  CGI::td(CGI::textarea(-name=>"data",-default=>$data,-override=>1,-rows=>30,-columns=>80,
				-style=>"width:100%")), ## can't seem to get variable height to work
	  CGI::td({align=>"center", nowrap=>1},
	    CGI::input({%button,value=>"Cancel"}),"&nbsp;",
	    CGI::input({%button,value=>"Revert"}),"&nbsp;",
	    CGI::input({%button,value=>"Save As:"}),
	    CGI::input({type=>"text",name=>"name",size=>20,style=>"width:50%"}),"&nbsp;",
	    CGI::input({%button,value=>"Save"}),
	  ),
	]);
  print CGI::end_table();
  print CGI::hidden({name=>"files",value=>$file});
}

##################################################
#
#  Copy a file
#
sub Copy {
  my $self = shift;
  my $oldfile = $self->getFile('copy'); return unless $oldfile;
  my $original = $oldfile;
  $oldfile = "$self->{courseRoot}/$self->{pwd}/$oldfile";

  if (-d $oldfile) {
    ## FIXME:  need to do recursive directory copy
    $self->addbadmessage("Directory copies are not yet implemented");
    $self->Refresh;
    return;
  }

  if ($self->r->param('confirmed')) {
    my $newfile = $self->r->param('name');
    if ($newfile = $self->verifyPath($newfile,$original)) {
      if (copy($oldfile, $newfile)) {
	$self->addgoodmessage("File successfully copied");
	$self->Refresh;	return;
      } else {$self->addbadmessage("Can't copy file: $!")}
    }
  }

  Confirm("Copy file as:","Copy");
  print CGI::hidden({name=>"files",value=>$original});
}

##################################################
#
#  Rename a file
#
sub Rename {
  my $self = shift;
  my $oldfile = $self->getFile('rename'); return unless $oldfile;
  my $original = $oldfile;
  $oldfile = "$self->{courseRoot}/$self->{pwd}/$oldfile";

  if ($self->r->param('confirmed')) {
    my $newfile = $self->r->param('name');
    if ($newfile = $self->verifyPath($newfile,$original)) {
      if (rename $oldfile, $newfile) {
	$self->addgoodmessage("File successfully renamed");
	$self->Refresh; return;
      } else {$self->addbadmessage("Can't rename file: $!")}
    }
  }

  Confirm("Rename file as:","Rename");
  print CGI::hidden({name=>"files",value=>$original});
}

##################################################
#
#  Delete a file
#
sub Delete {
  my $self = shift;
  my @files = $self->r->param('files');
  if (scalar(@files) == 0) {
    $self->addbadmessage("You must select at least one file to delete");
    $self->Refresh; return;
  }

  my $pwd = $self->{pwd};
  my $dir = $self->{courseRoot}.'/'.$pwd;
  if ($self->r->param('confirmed')) {

    #
    #  If confirmed, go ahead and delete the files
    #
    foreach my $file (@files) {
      if (defined checkPWD("$pwd/$file",1)) {
	if (-d "$dir/$file") {
	  my $removed = eval {rmtree("$dir/$file",0,1)};
	  if ($removed) {$self->addgoodmessage("Directory '$file' removed (items deleted: $removed)")}
	    else {$self->addbadmessage("Directory '$file' not removed:  $!")}
	} else {
	  if (unlink("$dir/$file")) {$self->addgoodmessage("File '$file' successfully removed")}
	    else {$self->addbadmessage("File '$file' not removed: $!")}
	}
      } else {$self->addbadmessage("Illegal file '$file' specified"); last}
    }
    $self->Refresh;

  } else {

    #
    #  Put up the confirmation dialog box
    #
    print CGI::start_table({border=>1,cellspacing=>2,cellpadding=>20, style=>"margin: 1em 0 0 5em"});
    print CGI::Tr(
	    CGI::td(
	      CGI::b("Warning:")," You have requested that the following items be deleted\n",
	      CGI::ul(CGI::li(\@files)),
	      ((grep { -d "$dir/$_" } @files)?
		 CGI::p({style=>"width:500"},"Some of these files are directories.  ",
                        "Only delete directories if you really know what you are doing.  ",
                        "You can seriously damage your course if you delete the wrong thing."): ""),
	      CGI::p({style=>"color:red"},"There is no undo for deleting files or directories!"),
	      CGI::p("Really delete the items listed above?"),
	      CGI::div({style=>"float:left; padding-left:3ex"},
		CGI::input({type=>"submit",name=>"action",value=>"Cancel"})),
	      CGI::div({style=>"float:right; padding-right:3ex"},
		CGI::input({type=>"submit",name=>"action",value=>"Delete"})),
	    ),
	  );
    print CGI::end_table();

    print CGI::hidden({name=>"confirmed",value=>1});
    foreach my $file (@files) {print CGI::hidden({name=>"files",value=>$file})}
  }
}

##################################################
#
#  Make a new file and edit it
#
sub NewFile {
  my $self = shift;

  if ($self->r->param('confirmed')) {
    my $name = $self->r->param('name');
    if (my $file = $self->verifyName($name,"file")) {
      if (open(NEWFILE,">$file")) {
	close(NEWFILE);
	$self->RefreshEdit("",$name);
	return;
      } else {$self->addbadmessage("Can't create file: $!")}
    }
  }

  Confirm("New file name:","New File");
}

##################################################
#
#  Make a new directory
#
sub NewFolder {
  my $self = shift;

  if ($self->r->param('confirmed')) {
    my $name = $self->r->param('name');
    if (my $dir = $self->verifyName($name,"directory")) {
      if (mkdir $dir, 0750) {
	$self->{pwd} .= '/'.$name;
	$self->Refresh;	return;
      } else {$self->addbadmessage("Can't create directory: $!")}
    }
  }

  Confirm("New folder name:","New Folder");
}

##################################################
#
#  Download a file
#
sub Download {
  my $self = shift;
  my $filename = $self->getFile("download"); return unless $filename;
  my $pwd = checkPWD($self->r->param('pwd') || '.');
  return unless $pwd;
  my $file = $self->{ce}{courseDirs}{root}.'/'.$pwd.'/'.$filename;

  if (-d $file) {$self->addbadmessage("You can't download directories"); return}
  unless (-f $file) {$self->addbadmessage("You can't download files of that type"); return}

  $self->r->param('download',$filename);
}

##################################################
#
#  Upload a file to the server
#
sub Upload {
  my $self = shift;
  my $dir = "$self->{courseRoot}/$self->{pwd}";
  my $fileIDhash = $self->r->param('file');
  unless ($fileIDhash) {
    $self->addbadmessage("You have not chosen a file to upload.");
    $self->Refresh;
    return;
  }

  my ($id,$hash) = split(/\s+/,$fileIDhash);
  my $upload = WeBWorK::Upload->retrieve($id,$hash,dir=>$self->{ce}{webworkDirs}{uploadCache});

  my $name = uniqueName($dir,checkName($upload->filename));
  if (-e "$dir/$name") {
    $self->addbadmessage("A file with that name already exists");
    $self->Refresh;
    $upload->dispose;
    return;
  }

  $upload->disposeTo("$dir/$name");
  $self->addgoodmessage("File '$name' uploaded successfully");
  $self->Refresh;
}

##################################################
##################################################
#
#  Print a confirmation dialog box
#
sub Confirm {
  my $message = shift;
  my $button = shift;

  print CGI::p();
  print CGI::start_table({border=>1,cellspacing=>2,cellpadding=>20, style=>"margin: 1em 0 0 3em"});
  print CGI::Tr(
	  CGI::td(
	      $message,
	      CGI::input({type=>"text",name=>"name",size=>50}),
	      CGI::p(),
	      CGI::div({style=>"float:right; padding-right:3ex"},
		CGI::input({type=>"submit",name=>"action",value=>$button})),  # this will be the default
	      CGI::div({style=>"float:left; padding-left:3ex"},
		CGI::input({type=>"submit",name=>"action",value=>"Cancel"})),
	    ),
	  );
  print CGI::end_table();
  print CGI::hidden({name=>"confirmed",value=>1});
  print CGI::script("window.document.FileManager.name.focus()");
}

##################################################
#
#  Check that there is exactly one vailid file
#
sub getFile {
  my $self = shift; my $action = shift;
  my @files = $self->r->param("files");
  if (scalar(@files) > 1) {
    $self->addbadmessage("You can only $action one file at a time.");
    $self->Refresh unless $action eq 'download';
    return;
  }
  if (scalar(@files) == 0 || $files[0] eq "") {
    $self->addbadmessage("You need to select a file to $action.");
    $self->Refresh unless $action eq 'download';
    return;
  }
  my $pwd = checkPWD($self->{pwd} || $self->r->param('pwd') || '.') || '.';
  $self->addbadmessage("You have specified an illegal file")
    unless checkPWD($pwd.'/'.$files[0],1);
  return $files[0];
}

##################################################
#
#  Get the entries for the directory menu
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
#  Get the directory listing
#
sub directoryListing {
  my $root = shift; my $pwd = shift;
  my $dir = $root.'/'.$pwd;
  my (@values,%labels,$size,$data);

  return unless -d $dir;
  my @names = sortByName(undef,grep(/^[^.]/,readDirectory($dir)));
  foreach my $name(@names) {
    push(@values,$name); $labels{$name} = $name;
    $labels{$name} .= '/' if (-d $dir.'/'.$name);
  }
  return (\@values,\%labels);
}

##################################################
#
#  Normalize the working directory and check if it is OK.
#
sub checkPWD {
  my $pwd = shift;
  my $renameError = shift;

  $pwd =~ s!//+!/!g;                        # remove duplicate slashes
  $pwd =~ s!(^|/)~!$1_!g;                   # remove ~user references
  $pwd =~ s!(^|/)(\.(/|$))+!$1!g;           # remove dot directories
                                            # remove dir/.. constructions
  while ($pwd =~ s!((\.[^./]+|\.\.[^/]+|[^./][^/]*)/\.\.(/|$))!!) {};
  $pwd =~ s!/$!!;                           # remove trailing /
  return if ($pwd =~ m!(^|/)\.\.(/|$)!);    # Error if outside the root

  my $original = $pwd;
  $pwd =~ s!(^|/)\.!$1_!g;                  # don't enter hidden directories
  $pwd =~ s!^/!!;                           # remove leading /
  $pwd =~ s![^-_./a-zA-Z0-9 ]!_!g;          # no illegal characters
  return if $renameError && $original ne $pwd;

  $pwd = '.' if $pwd eq '';
  return $pwd;
}

##################################################
#
#  Check a name for bad characters, etc.
#
sub checkName {
  my $file = shift;
  $file =~ s!.*[/\\]!!;                     #  remove directory
  $file =~ s/[^-_.a-zA-Z0-9 ]/_/g;          #  no illegal characters
  $file = "newfile.txt" unless $file;       #  no blank names
  $file =~ s/^\./_/;                        #  no initial dot
  return $file;
}

##################################################
#
#  Get a unique name (in case it already exists)
#
sub uniqueName {
  my $dir = shift; my $name = shift;
  my $type = ""; my $n = -1;
  $type = $1 if ($name =~ s/(\.[^.]*)$//);
  $n = $1 if ($name =~ s/(\d+)$//);
  while (-e "$dir/$name$n$type") {if ($n < 0) {$n--} else {$n++}}
  return "$name$n$type";
}

##################################################
#
#  Verify that a name can be added tot he current
#  directory.
#
sub verifyName {
  my $self = shift; my $name = shift; my $object = shift;
  if ($name) {
    unless ($name =~ m!/!) {
      unless ($name =~ m!^\.!) {
	unless ($name =~ m![^-_.a-zA-Z0-9 ]!) {
	  my $file = "$self->{courseRoot}/$self->{pwd}/$name";
	  return $file unless (-e $file);
	  $self->addbadmessage("A file with that name already exists");
	} else {$self->addbadmessage("Your $object name contains illegal characters")}
      } else {$self->addbadmessage("Your $object name may not begin with a dot")}
    } else {$self->addbadmessage("Your $object name may not contain a path component")}
  } else {$self->addbadmessage("You must specify a $object name")}
  return
}

##################################################
#
#  Verify that a file path is valid
#
sub verifyPath {
  my $self = shift; my $path = shift; my $name = shift;

  if ($path) {
    unless ($path =~ m![^-_.a-zA-Z0-9 /]!) {
      unless ($path =~ m!^/!) {
	$path = checkPWD($self->{pwd}.'/'.$path,1);
	if ($path) {
	  $path = $self->{courseRoot}.'/'.$path;
	  $path .= '/'.$name if -d $path && $name;
	  return $path unless (-e $path);
	  $self->addbadmessage("A file with that name already exists");
	} else {$self->addbadmessage("You have specified an illegal path")}
      } else {$self->addbadmessage("You can not specify an absolute path")}
    } else {$self->addbadmessage("Your file name contains illegal characters")}
  } else {$self->addbadmessage("You must specify a file name")}
  return
}

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
    $string;
}

##################################################
#
#  Check if a string is plain text
#    (i.e., doesn't contain three non-regular
#     characters in a row.)
#
sub isText {
  my $string = shift;
  return $string !~ m/[^\s\x20-\x7E]{3,}/;
}

##################################################

1;
