################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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
use parent qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::FileManager.pm -- simple directory manager for WW files

=cut

use strict;
use warnings;
use utf8;

use File::Path;
use File::Copy;
use File::Spec;
use String::ShellQuote;

use WeBWorK::Utils qw(readDirectory readFile sortByName listFilesRecursive);
use WeBWorK::Upload;
use WeBWorK::Utils::CourseManagement qw(archiveCourse);

use constant HOME => 'templates';

# The list of file extensions and the directories they usually go in.
my %uploadDir = (
	csv  => 'scoring',
	lst  => 'templates',
	pg   => 'templates/.*',
	pl   => 'templates/macros',
	def  => 'templates',
	html => 'html/.*',
);

# Check that the user is authorized, and see if there is a download to perform.
async sub pre_header_initialize {
	my $self = shift;
	my $r    = $self->r;

	return unless $r->authz->hasPermissions($r->param('user'), 'manage_course_files');

	my $action = $r->param('action');
	$self->Download if $action && ($action eq 'Download' || $action eq $r->maketext('Download'));

	$self->downloadFile($r->param('download')) if defined $r->param('download');

	if ($r->param('archiveCourse')) {
		my $ce       = $r->ce;
		my $courseID = $r->urlpath->arg('courseID');

		my $message = eval {
			WeBWorK::Utils::CourseManagement::archiveCourse(
				courseID     => $courseID,
				archive_path => "$ce->{webworkDirs}{courses}/$courseID/templates/$courseID.tar.gz",
				ce           => $ce
			);
		};
		if ($@) {
			$self->addbadmessage($r->maketext('Failed to generate course archive: [_1]', $@));
		} else {
			$self->addgoodmessage($r->maketext('Archived course as [_1].tar.gz.', $courseID));
		}
		$self->addbadmessage($message) if ($message);
	}

	$self->{pwd}        = $self->checkPWD($r->param('pwd') || HOME);
	$self->{courseRoot} = $r->ce->{courseDirs}{root};
	$self->{courseName} = $r->urlpath->arg('courseID');

	return;
}

# Download a given file
sub downloadFile {
	my $self = shift;
	my $r    = $self->r;
	my $file = checkName(shift);
	my $pwd  = $self->checkPWD(shift || $self->r->param('pwd') || HOME);
	return unless $pwd;
	$pwd = $self->{ce}{courseDirs}{root} . '/' . $pwd;
	unless (-e "$pwd/$file") {
		$self->addbadmessage($r->maketext(q{The file you are trying to download doesn't exist}));
		return;
	}
	unless (-f "$pwd/$file") {
		$self->addbadmessage($r->maketext('You can only download regular files.'));
		return;
	}
	my $type = 'application/octet-stream';
	$type = 'text/plain' if $file =~ m/\.(pg|pl|pm|txt|def|csv|lst)/;
	$type = 'image/gif'  if $file =~ m/\.gif/;
	$type = 'image/jpeg' if $file =~ m/\.(jpg|jpeg)/;
	$type = 'image/png'  if $file =~ m/\.png/;
	$self->reply_with_file($type, "$pwd/$file", $file, 0);
}

# First time through
sub Init {
	my $self = shift;
	$self->r->param('unpack',     1);
	$self->r->param('autodelete', 1);
	$self->r->param('format',     'Automatic');
	$self->Refresh;
}

sub HiddenFlags {
	my $self = shift;
	my $r    = $self->r;
	return $r->c(
		$r->hidden_field(dates      => ''),
		$r->hidden_field(overwrite  => ''),
		$r->hidden_field(unpack     => ''),
		$r->hidden_field(autodelete => ''),
		$r->hidden_field(autodelete => 'Automatic'),
	)->join('');
}

# Display the directory listing and associated buttons.
sub Refresh {
	my ($self) = @_;
	return $self->r->include('ContentGenerator/Instructor/FileManager/refresh');
}

# Move to the parent directory
sub ParentDir {
	my $self = shift;
	$self->{pwd} = '.' unless ($self->{pwd} =~ s!/[^/]*$!!);
	$self->Refresh;
}

# Move to the parent directory
sub Go {
	my $self = shift;
	$self->{pwd} = $self->r->param('directory');
	$self->Refresh;
}

# Open a directory or view a file
sub View {
	my $self = shift;
	my $r    = $self->r;

	my $filename = $self->getFile('view');
	return '' unless $filename;

	my $name = "$self->{pwd}/$filename" =~ s!^\./?!!r;
	my $file = "$self->{courseRoot}/$self->{pwd}/$filename";

	# Don't follow symbolic links
	if ($self->isSymLink($file)) {
		$self->addbadmessage($r->maketext('You may not follow symbolic links'));
		return $self->Refresh;
	}

	# Handle directories by making them the working directory
	if (-d $file) {
		$self->{pwd} .= '/' . $filename;
		return $self->Refresh;
	}

	unless (-f $file) {
		$self->addbadmessage($r->maketext(q{You can't view files of that type}));
		return $self->Refresh;
	}

	return $r->include(
		'ContentGenerator/Instructor/FileManager/view',
		filename => $filename,
		name     => $name,
		file     => $file
	);
}

# Edit a file
sub Edit {
	my $self     = shift;
	my $filename = $self->getFile('edit');
	return '' unless $filename;
	my $file   = "$self->{courseRoot}/$self->{pwd}/$filename";
	my $r      = $self->r;
	my $userID = $r->param('user');
	my $ce     = $r->ce;
	my $authz  = $r->authz;

	# If its a restricted file, dont allow the web editor to edit it unless that option has been set for the course.
	for my $restrictedFile (@{ $ce->{uneditableCourseFiles} }) {
		if (File::Spec->canonpath($file) eq File::Spec->canonpath("$self->{courseRoot}/$restrictedFile")
			&& !$authz->hasPermissions($userID, 'edit_restricted_files'))
		{
			$self->addbadmessage($r->maketext('You do not have permission to edit this file.'));
			return $self->Refresh;
		}
	}

	if (-d $file) {
		$self->addbadmessage($r->maketext(q{You can't edit a directory}));
		return $self->Refresh;
	}

	unless (-f $file) {
		$self->addbadmessage($r->maketext('You can only edit text files'));
		return $self->Refresh;
	}
	if (-T $file) {
		return $self->RefreshEdit(readFile($file), $filename);
	} else {
		$self->addbadmessage($r->maketext('The file does not appear to be a text file'));
		return $self->Refresh;
	}
	return '';
}

# Save the edited file
sub Save {
	my $self     = shift;
	my $filename = shift;
	my $r        = $self->r;
	my $pwd      = $self->{pwd};
	if ($filename) {
		$pwd      = substr($filename, length($self->{courseRoot}) + 1) =~ s!(/|^)([^/]*)$!!r;
		$filename = $2;
		$pwd      = '.' if $pwd eq '';
	} else {
		$filename = $self->getFile('save');
		return unless $filename;
	}
	my $file = "$self->{courseRoot}/$pwd/$filename";
	my $data = $self->r->param('data');

	if (defined($data)) {
		$data =~ s/\r\n?/\n/g;    # convert DOS and Mac line ends to unix
		if (open(my $OUTFILE, '>:encoding(UTF-8)', $file)) {
			print $OUTFILE $data;
			close($OUTFILE);
			if ($@) { $self->addbadmessage($r->maketext('Failed to save: [_1]', $@)) }
			else    { $self->addgoodmessage($r->maketext('File saved')) }
		} else {
			$self->addbadmessage($r->maketext(q{Can't write to file [_1]}, $!));
		}
	} else {
		$data = '';
		$self->addbadmessage($r->maketext('Error: no file data was submitted!'));
	}

	$self->{pwd} = $pwd;
	$self->RefreshEdit($data, $filename);
}

# Save the edited file under a new name
sub SaveAs {
	my $self = shift;

	my $newfile  = $self->r->param('name');
	my $original = $self->r->param('files');
	$newfile = $self->verifyPath($newfile, $original);
	return $self->Save($newfile) if $newfile;
	$self->RefreshEdit($self->r->param('data'), $original);
}

# Display the Edit page
sub RefreshEdit {
	my ($self, $data, $file) = @_;
	return $self->r->include('ContentGenerator/Instructor/FileManager/refresh_edit', contents => $data, file => $file);
}

# Copy a file
sub Copy {
	my $self     = shift;
	my $r        = $self->r;
	my $dir      = "$self->{courseRoot}/$self->{pwd}";
	my $original = $self->getFile('copy');
	return '' unless $original;
	my $oldfile = "$dir/$original";

	if (-d $oldfile) {
		# FIXME: need to do recursive directory copy
		$self->addbadmessage('Directory copies are not yet implemented');
		return $self->Refresh;
	}

	if ($self->r->param('confirmed')) {
		my $newfile = $self->r->param('name');
		if ($newfile = $self->verifyPath($newfile, $original)) {
			if (copy($oldfile, $newfile)) {
				$self->addgoodmessage($r->maketext('File successfully copied'));
				return $self->Refresh;
			} else {
				$self->addbadmessage($r->maketext(q{Can't copy file: [_1]}, $!));
			}
		}
	}

	return $r->c($self->Confirm($r->maketext('Copy file as:'), uniqueName($dir, $original), $r->maketext('Copy')),
		$r->hidden_field(files => $original))->join('');
}

# Rename a file
sub Rename {
	my $self     = shift;
	my $r        = $self->r;
	my $dir      = "$self->{courseRoot}/$self->{pwd}";
	my $original = $self->getFile('rename');
	return '' unless $original;
	my $oldfile = "$dir/$original";

	if ($self->r->param('confirmed')) {
		my $newfile = $self->r->param('name');
		if ($newfile = $self->verifyPath($newfile, $original)) {
			if (rename $oldfile, $newfile) {
				$self->addgoodmessage($r->maketext('File successfully renamed'));
				return $self->Refresh;
			} else {
				$self->addbadmessage($r->maketext(q{Can't rename file: [_1]}, $!));
			}
		}
	}

	return $r->c($self->Confirm($r->maketext('Rename file as:'), $original, $r->maketext('Rename')),
		$r->hidden_field(files => $original))->join('');
}

# Delete a file
sub Delete {
	my $self  = shift;
	my $r     = $self->r;
	my @files = $self->r->param('files');

	if (!@files) {
		$self->addbadmessage($r->maketext('You must select at least one file to delete'));
		return $self->Refresh;
	}

	my $dir = "$self->{courseRoot}/$self->{pwd}";
	if ($self->r->param('confirmed')) {
		# If confirmed, go ahead and delete the files
		for my $file (@files) {
			if (defined $self->checkPWD("$self->{pwd}/$file", 1)) {
				if (-d "$dir/$file" && !-l "$dir/$file") {
					my $removed = eval { rmtree("$dir/$file", 0, 1) };
					if ($removed) {
						$self->addgoodmessage(
							$r->maketext('Directory "[_1]" removed (items deleted: [_2])', $file, $removed));
					} else {
						$self->addbadmessage($r->maketext('Directory "[_1]" not removed: [_2]', $file, $!));
					}
				} else {
					if (unlink("$dir/$file")) {
						$self->addgoodmessage($r->maketext('File "[_1]" successfully removed', $file));
					} else {
						$self->addbadmessage($r->maketext('File "[_1]" not removed: [_2]', $file, $!));
					}
				}
			} else {
				$self->addbadmessage($r->maketext('Illegal file "[_1]" specified', $file));
				last;
			}
		}
		return $self->Refresh;
	} else {
		return $r->include('ContentGenerator/Instructor/FileManager/delete', dir => $dir, files => \@files);
	}
}

# Make a gzipped tar archive
sub MakeArchive {
	my $self  = shift;
	my $r     = $self->r;
	my @files = $self->r->param('files');
	if (scalar(@files) == 0) {
		$self->addbadmessage($r->maketext('You must select at least one file for the archive'));
		return $self->Refresh;
	}

	my $dir     = $self->{courseRoot} . '/' . $self->{pwd};
	my $archive = uniqueName($dir, (scalar(@files) == 1) ? $files[0] . '.tgz' : $self->{courseName} . '.tgz');
	my $tar =
		'cd ' . shell_quote($dir) . " && $self->{ce}{externalPrograms}{tar} -cvzf " . shell_quote($archive, @files);
	@files = readpipe $tar . ' 2>&1';
	if ($? == 0) {
		my $n = scalar(@files);
		$self->addgoodmessage($r->maketext('Archive "[_1]" created successfully ([quant, _2, file])', $archive, $n));
	} else {
		$self->addbadmessage(
			$r->maketext(q{Can't create archive "[_1]": command returned [_2]}, $archive, systemError($?)));
	}
	return $self->Refresh;
}

# Unpack a gzipped tar archive
sub UnpackArchive {
	my $self    = shift;
	my $r       = $self->r;
	my $archive = $self->getFile('unpack');
	return '' unless $archive;
	if ($archive !~ m/\.(tar|tar\.gz|tgz)$/) {
		$self->addbadmessage($r->maketext('You can only unpack files ending in ".tgz", ".tar" or ".tar.gz"'));
	} else {
		$self->unpack($archive);
	}
	return $self->Refresh;
}

sub unpack {
	my $self    = shift;
	my $r       = $self->r;
	my $archive = shift;
	my $z       = 'z';
	$z = '' if $archive =~ m/\.tar$/;
	my $dir   = $self->{courseRoot} . '/' . $self->{pwd};
	my $tar   = 'cd ' . shell_quote($dir) . " && $self->{ce}{externalPrograms}{tar} -vx${z}f " . shell_quote($archive);
	my @files = readpipe $tar . ' 2>&1';

	if ($? == 0) {
		my $n = scalar(@files);
		$self->addgoodmessage($r->maketext('[quant,_1,file] unpacked successfully', $n));
		return 1;
	} else {
		$self->addbadmessage($r->maketext(q{Can't unpack "[_1]": command returned [_2]}, $archive, systemError($?)));
		return 0;
	}
}

# Make a new file and edit it
sub NewFile {
	my $self = shift;
	my $r    = $self->r;

	if ($self->r->param('confirmed')) {
		my $name = $self->r->param('name');
		if (my $file = $self->verifyName($name, 'file')) {
			if (open(my $NEWFILE, '>:encoding(UTF-8)', $file)) {
				close $NEWFILE;
				return $self->RefreshEdit('', $name);
			} else {
				$self->addbadmessage($r->maketext(q{Can't create file: [_1]}, $!));
			}
		}
	}

	return $self->Confirm($r->maketext('New file name:'), '', $r->maketext('New File'));
}

# Make a new directory
sub NewFolder {
	my $self = shift;
	my $r    = $self->r;

	if ($self->r->param('confirmed')) {
		my $name = $self->r->param('name');
		if (my $dir = $self->verifyName($name, 'directory')) {
			if (mkdir $dir, 0750) {
				$self->{pwd} .= '/' . $name;
				return $self->Refresh;
			} else {
				$self->addbadmessage($r->maketext(q{Can't create directory: [_1]}, $!));
			}
		}
	}

	return $self->Confirm($r->maketext('New folder name:'), '', $r->maketext('New Folder'));
}

# Download a file
sub Download {
	my $self = shift;
	my $r    = $self->r;
	my $pwd  = $self->checkPWD($self->r->param('pwd') || HOME);
	return unless $pwd;
	my $filename = $self->getFile('download');
	return unless $filename;
	my $file = $self->{ce}{courseDirs}{root} . '/' . $pwd . '/' . $filename;

	if     (-d $file) { $self->addbadmessage($r->maketext(q{You can't download directories}));        return }
	unless (-f $file) { $self->addbadmessage($r->maketext(q{You can't download files of that type})); return }

	$self->r->param('download', $filename);
}

# Upload a file to the server
sub Upload {
	my $self       = shift;
	my $r          = $self->r;
	my $dir        = "$self->{courseRoot}/$self->{pwd}";
	my $fileIDhash = $self->r->param('file');
	unless ($fileIDhash) {
		$self->addbadmessage($r->maketext('You have not chosen a file to upload.'));
		return $self->Refresh;
	}

	my ($id, $hash) = split(/\s+/, $fileIDhash);
	my $upload = WeBWorK::Upload->retrieve($id, $hash, dir => $self->{ce}{webworkDirs}{uploadCache});

	my $name   = checkName($upload->filename);
	my $action = $self->r->param('formAction') || 'Cancel';
	if ($self->r->param('confirmed')) {
		if ($action eq 'Cancel' || $action eq $r->maketext('Cancel')) {
			$upload->dispose;
			return $self->Refresh;
		}
		$name = checkName($self->r->param('name')) if ($action eq 'Rename' || $action eq $r->maketext('Rename'));
	}

	if (-e "$dir/$name") {
		unless ($self->r->param('overwrite') || $action eq 'Overwrite' || $action eq $r->maketext('Overwrite')) {
			return $r->c(
				$self->Confirm(
					$r->tag(
						'p',
						$r->b(
							$r->maketext('File <b>[_1]</b> already exists. Overwrite it, or rename it as:', $name)
						)
					),
					uniqueName($dir, $name),
					$r->maketext('Rename'),
					$r->maketext('Overwrite')
				),
				$r->hidden_field(action => 'Upload'),
				$r->hidden_field(file   => $fileIDhash)
			)->join('');
		}
	}
	$self->checkFileLocation($name, $self->{pwd});

	my $file = "$dir/$name";
	my $type = $self->getFlag('format', 'Automatic');
	my $data;

	#  Check if we need to convert linebreaks
	if ($type ne 'Binary') {
		my $fh    = $upload->fileHandle;
		my @lines = <$fh>;
		$data = join('', @lines);
		if ($type eq 'Automatic') { $type = isText($data) ? 'Text' : 'Binary' }
	}
	if ($type eq 'Text') {
		$upload->dispose;
		$data =~ s/\r\n?/\n/g;
		if (open(my $UPLOAD, '>:encoding(UTF-8)', $file)) {
			my $backup_data = $data;
			my $success     = utf8::decode($data);    # try to decode as utf8
			unless ($success) {
				warn "Trying to convert file $file from latin1? to UTF-8";
				utf8::upgrade($backup_data);          # try to convert data from latin1 to utf8.
				$data = $backup_data;
			}
			print $UPLOAD $data;                      # print massaged data to file.
			close $UPLOAD;
		} else {
			$self->addbadmessage($r->maketext(q{Can't create file "[_1]": [_2]}, $name, $!));
		}
	} else {
		$upload->disposeTo($file);
	}

	if (-e $file) {
		$self->addgoodmessage($r->maketext('File "[_1]" uploaded successfully', $name));
		if ($name =~ m/\.(tar|tar\.gz|tgz)$/ && $self->getFlag('unpack')) {
			if ($self->unpack($name) && $self->getFlag('autodelete')) {
				if (unlink($file)) { $self->addgoodmessage($r->maketext('Archive "[_1]" deleted', $name)) }
				else { $self->addbadmessage($r->maketext(q{Can't delete archive "[_1]": [_2]}, $name, $!)) }
			}
		}
	}

	return $self->Refresh;
}

# Print a confirmation dialog box
sub Confirm {
	my ($self, $message, $value, $button, $button2) = @_;
	return $self->r->include(
		'ContentGenerator/Instructor/FileManager/confirm',
		message => $message,
		value   => $value,
		button  => $button,
		button2 => $button2
	);
}

# Check that there is exactly one valid file
sub getFile {
	my $self   = shift;
	my $action = shift;
	my $r      = $self->r;
	my @files  = $self->r->param('files');
	if (scalar(@files) > 1) {
		$self->addbadmessage($r->maketext('You can only [_1] one file at a time.', $action));
		$self->Refresh unless $action eq 'download';
		return;
	}
	if (scalar(@files) == 0 || $files[0] eq '') {
		$self->addbadmessage($r->maketext('You need to select a file to [_1].', $action));
		$self->Refresh unless $action eq 'download';
		return;
	}
	my $pwd = $self->checkPWD($self->{pwd} || $self->r->param('pwd') || HOME) || '.';
	if ($self->isSymLink($pwd . '/' . $files[0])) {
		$self->addbadmessage($r->maketext('You may not follow symbolic links'));
		$self->Refresh unless $action eq 'download';
		return;
	}
	unless ($self->checkPWD($pwd . '/' . $files[0], 1)) {
		$self->addbadmessage($r->maketext('You have specified an illegal file'));
		$self->Refresh unless $action eq 'download';
		return;
	}
	return $files[0];
}

# Get the entries for the directory menu
sub directoryMenu {
	my ($self, $dir) = @_;

	$dir =~ s!^\.(/|$)!!;
	my @dirs = split('/', $dir);

	my @values;
	while (@dirs) {
		my $pwd = join('/', (@dirs)[ 0 .. $#dirs ]);
		$dir = pop(@dirs);
		push(@values, [ $dir => $pwd ]);
	}
	push(@values, [ $self->{courseName} => '.' ]);
	return \@values;
}

# Get the directory listing
sub directoryListing {
	my ($self, $pwd) = @_;
	my $dir = "$self->{courseRoot}/$pwd";

	return unless -d $dir;

	my (@values, $size, $data);

	my $len   = 24;
	my @names = sortByName(undef, grep {/^[^.]/} readDirectory($dir));
	for my $name (@names) {
		unless ($name eq 'DATA') {    #FIXME don't view the DATA directory
			my $file  = "$dir/$name";
			my $label = $name;
			$label .= '@' if (-l $file);
			$label .= '/' if (-d $file && !-l $file);
			$len = length($label) if length($label) > $len;
			push(@values, [ $label => $name ]);
		}
	}
	if ($self->getFlag('dates')) {
		$len += 3;
		for my $name (@values) {
			my $file = "$dir/$name->[1]";
			my ($size, $date) = (lstat($file))[ 7, 9 ];
			$name->[0] =
				$self->r->b(
					sprintf("%-${len}s%-16s%10s", $name->[0], -d $file ? ('', '') : (getDate($date), getSize($size)))
					=~ s/\s/&nbsp;/gr);
		}
	}
	return \@values;
}

sub getDate {
	my ($sec, $min, $hour, $day, $month, $year) = localtime(shift);
	return sprintf('%02d-%02d-%04d %02d:%02d', $month + 1, $day, $year + 1900, $hour, $min);
}

sub getSize {
	my $size = shift;
	return $size . ' B ' if $size < 1024;
	return sprintf('%.1f KB', $size / 1024)        if $size < 1024 * 100;
	return sprintf('%d KB',   int($size / 1024))   if $size < 1024 * 1024;
	return sprintf('%.1f MB', $size / 1024 / 1024) if $size < 1024 * 1024 * 100;
	return sprintf('%d MB',   $size / 1024 / 1024);
}

# Check if a file is a symbolic link that we are not allowed to follow.
sub isSymLink {
	my $self = shift;
	my $file = shift;
	return 0 unless -l $file;

	my $courseRoot = $self->{ce}{courseDirs}{root};
	$courseRoot = readlink($courseRoot) if -l $courseRoot;
	my $pwd  = $self->{pwd} || $self->r->param('pwd') || HOME;
	my $link = File::Spec->rel2abs(readlink($file), "$courseRoot/$pwd");

	# Remove /./ and dir/../ constructs
	$link =~ s!(^|/)(\.(/|$))+!$1!g;
	while ($link =~ s!((\.[^./]+|\.\.[^/]+|[^./][^/]*)/\.\.(/|$))!!) { }

	# Look through the list of valid paths to see if this link is OK
	my $valid = $self->{ce}{webworkDirs}{valid_symlinks};
	if (defined $valid && $valid) {
		for my $path (@{$valid}) {
			return 0 if substr($link, 0, length($path)) eq $path;
		}
	}

	return 1;
}

# Normalize the working directory and check if it is OK.
sub checkPWD {
	my $self        = shift;
	my $pwd         = shift;
	my $renameError = shift;

	$pwd =~ s!//+!/!g;                 # remove duplicate slashes
	$pwd =~ s!(^|/)~!$1_!g;            # remove ~user references
	$pwd =~ s!(^|/)(\.(/|$))+!$1!g;    # remove dot directories

	# remove dir/.. constructions
	while ($pwd =~ s!((\.[^./]+|\.\.[^/]+|[^./][^/]*)/\.\.(/|$))!!) { }

	$pwd =~ s!/$!!;                           # remove trailing /
	return if ($pwd =~ m!(^|/)\.\.(/|$)!);    # Error if outside the root

	# check for bad symbolic links
	my @dirs = split('/', $pwd);
	pop(@dirs) if $renameError;               # don't check file iteself in this case
	my @path = ($self->{ce}{courseDirs}{root});
	for my $dir (@dirs) {
		push @path, $dir;
		return if ($self->isSymLink(join('/', @path)));
	}

	my $original = $pwd;
	$pwd =~ s!(^|/)\.!$1_!g;                  # don't enter hidden directories
	$pwd =~ s!^/!!;                           # remove leading /
	$pwd =~ s![^-_./A-Z0-9~, ]!_!gi;          # no illegal characters
	return if $renameError && $original ne $pwd;

	$pwd = '.' if $pwd eq '';
	return $pwd;
}

# Check that a file is uploaded to the correct directory
sub checkFileLocation {
	my $self      = shift;
	my $r         = $self->r;
	my $extension = shift;
	$extension =~ s/.*\.//;
	my $dir      = shift;
	my $location = $uploadDir{$extension};
	return unless defined($location);
	return if $dir =~ m/^$location$/;
	$location      =~ s!/\.\*!!;
	return if $dir =~ m/^$location$/;
	$self->addbadmessage(
		$r->maketext('Files with extension ".[_1]" usually belong in "[_2]"', $extension, $location)
			. (
				($extension eq 'csv')
				? $r->maketext('. If this is a class roster, rename it to have extension ".lst"')
				: ''
			)
	);

	return;
}

# Check a name for bad characters, etc.
sub checkName {
	my $file = shift;
	$file =~ s!.*[/\\]!!;                  # remove directory
	$file =~ s/[^-_.a-zA-Z0-9 ]/_/g;       # no illegal characters
	$file =~ s/^\./_/;                     # no initial dot
	$file = 'newfile.txt' unless $file;    # no blank names
	return $file;
}

# Get a unique name (in case it already exists)
sub uniqueName {
	my $dir  = shift;
	my $name = shift;
	return $name unless (-e "$dir/$name");
	my $type = '';
	my $n    = 1;
	$type = $1 if ($name =~ s/(\.[^.]*)$//);
	$n    = $1 if ($name =~ s/_(\d+)$/_/);
	while (-e "$dir/${name}_$n$type") { $n++ }
	return "${name}_$n$type";
}

# Verify that a name can be added to the current directory.
sub verifyName {
	my $self   = shift;
	my $name   = shift;
	my $object = shift;
	my $r      = $self->r;
	if ($name) {
		unless ($name =~ m!/!) {
			unless ($name =~ m!^\.!) {
				unless ($name =~ m![^-_.a-zA-Z0-9 ]!) {
					my $file = "$self->{courseRoot}/$self->{pwd}/$name";
					return $file unless (-e $file);
					$self->addbadmessage($r->maketext('A file with that name already exists'));
				} else {
					$self->addbadmessage($r->maketext('Your [_1] name contains illegal characters', $object));
				}
			} else {
				$self->addbadmessage($r->maketext('Your [_1] name may not begin with a dot', $object));
			}
		} else {
			$self->addbadmessage($r->maketext('Your [_1] name may not contain a path component', $object));
		}
	} else {
		$self->addbadmessage($r->maketext('You must specify a [_1] name', $object));
	}
	return;
}

# Verify that a file path is valid
sub verifyPath {
	my $self = shift;
	my $path = shift;
	my $name = shift;
	my $r    = $self->r;

	if ($path) {
		unless ($path =~ m![^-_.a-zA-Z0-9 /]!) {
			unless ($path =~ m!^/!) {
				$path = $self->checkPWD($self->{pwd} . '/' . $path, 1);
				if ($path) {
					$path = $self->{courseRoot} . '/' . $path;
					$path .= '/' . $name if -d $path && $name;
					return $path unless (-e $path);
					$self->addbadmessage($r->maketext('A file with that name already exists'));
				} else {
					$self->addbadmessage($r->maketext('You have specified an illegal path'));
				}
			} else {
				$self->addbadmessage($r->maketext('You can not specify an absolute path'));
			}
		} else {
			$self->addbadmessage($r->maketext('Your file name contains illegal characters'));
		}
	} else {
		$self->addbadmessage($r->maketext('You must specify a file name'));
	}
	return;
}

# Get the value of a parameter flag
sub getFlag {
	my ($self, $flag, $default) = @_;
	$default //= 0;
	return $self->r->param($flag) // $default;
}

# Check if a string is plain text
sub isText {
	my $string = shift;
	return utf8::is_utf8($string);
}

# Interpret command return errors
sub systemError {
	my $status = shift;
	return "error: $!" if $status == 0xFF00;
	return 'exit status ' . ($status >> 8) if ($status & 0xFF) == 0;
	return 'signal ' . ($status &= ~0x80);
}

1;
