package WeBWorK::ContentGenerator::Instructor::FileManager;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::FileManager.pm -- simple directory manager for WW files

=cut

use Mojo::File;
use File::Path;
use File::Copy;
use File::Spec;
use String::ShellQuote;
use Archive::Tar;
use Archive::Zip            qw(:ERROR_CODES);
use Archive::Zip::SimpleZip qw($SimpleZipError);

use WeBWorK::Utils                   qw(sortByName min);
use WeBWorK::Utils::CourseManagement qw(archiveCourse);
use WeBWorK::Utils::Files            qw(readFile path_is_subdir);
use WeBWorK::Upload;

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
sub pre_header_initialize ($c) {
	return unless $c->authz->hasPermissions($c->param('user'), 'manage_course_files');

	my $action = $c->param('action');
	$c->Download if $action && ($action eq 'Download' || $action eq $c->maketext('Download'));

	$c->downloadFile($c->param('download')) if defined $c->param('download');

	if ($action && ($action eq 'Archive Course' || $action eq $c->maketext('Archive Course'))) {
		my $ce       = $c->ce;
		my $courseID = $c->stash('courseID');

		my $message = eval {
			WeBWorK::Utils::CourseManagement::archiveCourse(
				courseID     => $courseID,
				archive_path => "$ce->{webworkDirs}{courses}/$courseID/templates/$courseID.tar.gz",
				ce           => $ce
			);
		};
		if ($@) {
			$c->addbadmessage($c->maketext('Failed to generate course archive: [_1]', $@));
		} else {
			$c->addgoodmessage($c->maketext('Archived course as [_1].tar.gz.', $courseID));
		}
		$c->addbadmessage($message) if ($message);
	}

	$c->{pwd}        = $c->checkPWD($c->param('pwd') || HOME);
	$c->{courseRoot} = $c->ce->{courseDirs}{root};
	$c->{courseName} = $c->stash('courseID');

	if ($c->{pwd} && $action && $action eq 'Edit') {
		my @files = $c->param('files');
		if (@files == 1 && $files[0] =~ /\.pg$/) {
			my $file = "$c->{courseRoot}/$c->{pwd}/$files[0]";
			if (-f $file && -T $file) {
				return $c->reply_with_redirect($c->systemLink(
					$c->url_for('instructor_problem_editor'),
					params => {
						file_type      => 'source_path_for_problem_file',
						sourceFilePath => $file
					}
				));
			}
		}
	}

	return;
}

# Download a given file
sub downloadFile ($c, $file, $directory = '') {
	if (my $invalidFilenameMessage = $c->checkName($file)) {
		$c->addbadmessage($invalidFilenameMessage);
		return;
	}
	my $pwd = $c->checkPWD($directory || $c->param('pwd') || HOME);
	return unless $pwd;
	$pwd = $c->{ce}{courseDirs}{root} . '/' . $pwd;
	unless (-e "$pwd/$file") {
		$c->addbadmessage($c->maketext(q{The file you are trying to download doesn't exist}));
		return;
	}
	unless (-f "$pwd/$file") {
		$c->addbadmessage($c->maketext('You can only download regular files.'));
		return;
	}
	my $type = 'application/octet-stream';
	$type = 'text/plain' if $file =~ m/\.(pg|pl|pm|txt|def|csv|lst)/;
	$type = 'image/gif'  if $file =~ m/\.gif/;
	$type = 'image/jpeg' if $file =~ m/\.(jpg|jpeg)/;
	$type = 'image/png'  if $file =~ m/\.png/;
	$c->reply_with_file($type, "$pwd/$file", $file, 0);
	return;
}

# First time through
sub Init ($c) {
	$c->param('unpack',     1)           unless defined($c->param('unpack'));
	$c->param('autodelete', 1)           unless defined($c->param('autodelete'));
	$c->param('format',     'Automatic') unless defined($c->param('format'));
	return $c->Refresh;
}

sub HiddenFlags ($c) {
	return $c->c(
		$c->hidden_field(dates      => $c->getFlag('dates')),
		$c->hidden_field(format     => $c->getFlag('format', 'Automatic')),
		$c->hidden_field(overwrite  => $c->getFlag('overwrite')),
		$c->hidden_field(unpack     => $c->getFlag('unpack')),
		$c->hidden_field(autodelete => $c->getFlag('autodelete')),
	)->join('');
}

# Display the directory listing and associated buttons.
sub Refresh ($c) {
	return $c->include('ContentGenerator/Instructor/FileManager/refresh');
}

# Move to the parent directory
sub ParentDir ($c) {
	$c->{pwd} = '.' unless ($c->{pwd} =~ s!/[^/]*$!!);
	return $c->Refresh;
}

# Move to the parent directory
sub Go ($c) {
	$c->{pwd} = $c->param('directory');
	return $c->Refresh;
}

# Open a directory or view a file
sub View ($c) {
	my $filename = $c->getFile('view');
	return '' unless $filename;

	my $name = "$c->{pwd}/$filename" =~ s!^\./?!!r;
	my $file = "$c->{courseRoot}/$c->{pwd}/$filename";

	# Don't follow symbolic links
	if ($c->isSymLink($file)) {
		$c->addbadmessage($c->maketext('You may not follow symbolic links'));
		return $c->Refresh;
	}

	# Handle directories by making them the working directory
	if (-d $file) {
		$c->{pwd} .= '/' . $filename;
		return $c->Refresh;
	}

	unless (-f $file) {
		$c->addbadmessage($c->maketext(q{You can't view files of that type}));
		return $c->Refresh;
	}

	return $c->include(
		'ContentGenerator/Instructor/FileManager/view',
		filename => $filename,
		name     => $name,
		file     => $file
	);
}

# Edit a file
sub Edit ($c) {
	my $filename = $c->getFile('edit');
	return $c->Refresh unless $filename;
	my $file = "$c->{courseRoot}/$c->{pwd}/$filename";

	# If its a restricted file, dont allow the web editor to edit it unless that option has been set for the course.
	for my $restrictedFile (@{ $c->ce->{uneditableCourseFiles} }) {
		if (Mojo::File->new($file)->realpath eq Mojo::File->new("$c->{courseRoot}/$restrictedFile")->realpath
			&& !$c->authz->hasPermissions($c->param('user'), 'edit_restricted_files'))
		{
			$c->addbadmessage($c->maketext('You do not have permission to edit this file.'));
			return $c->Refresh;
		}
	}

	if (-d $file) {
		$c->addbadmessage($c->maketext(q{You can't edit a directory}));
		return $c->Refresh;
	}

	unless (-f $file) {
		$c->addbadmessage($c->maketext('You can only edit text files'));
		return $c->Refresh;
	}
	if (-T $file) {
		return $c->RefreshEdit(readFile($file), $filename);
	} else {
		$c->addbadmessage($c->maketext('The file does not appear to be a text file'));
		return $c->Refresh;
	}
}

# Save the edited file
sub Save ($c, $filename = '') {
	my $pwd = $c->{pwd};
	if ($filename) {
		$pwd      = substr($filename, length($c->{courseRoot}) + 1) =~ s!(/|^)([^/]*)$!!r;
		$filename = $2;
		$pwd      = '.' if $pwd eq '';
	} else {
		$filename = $c->getFile('save');
		return unless $filename;
	}
	my $file = "$c->{courseRoot}/$pwd/$filename";
	my $data = $c->param('data');

	if (defined($data)) {
		$data =~ s/\r\n?/\n/g;    # convert DOS and Mac line ends to unix
		if (open(my $OUTFILE, '>:encoding(UTF-8)', $file)) {
			print $OUTFILE $data;
			close($OUTFILE);
			if ($@) { $c->addbadmessage($c->maketext('Failed to save: [_1]', $@)) }
			else    { $c->addgoodmessage($c->maketext('File saved')) }
		} else {
			$c->addbadmessage($c->maketext(q{Can't write to file [_1]}, $!));
		}
	} else {
		$data = '';
		$c->addbadmessage($c->maketext('Error: no file data was submitted!'));
	}

	$c->{pwd} = $pwd;
	return $c->RefreshEdit($data, $filename);
}

# Save the edited file under a new name
sub SaveAs ($c) {
	my $newfile  = $c->param('name');
	my $original = $c->param('files');
	$newfile = $c->verifyPath($newfile, $original);
	return $c->Save($newfile) if ($newfile);
	return $c->RefreshEdit($c->param('data'), $original);
}

# Display the Edit page
sub RefreshEdit ($c, $data, $file) {
	return $c->include('ContentGenerator/Instructor/FileManager/refresh_edit', contents => $data, file => $file);
}

# Copy a file
sub Copy ($c) {
	my $dir      = "$c->{courseRoot}/$c->{pwd}";
	my $original = $c->getFile('copy');
	return '' unless $original;
	my $oldfile = "$dir/$original";

	if (-d $oldfile) {
		# FIXME: need to do recursive directory copy
		$c->addbadmessage('Directory copies are not yet implemented');
		return $c->Refresh;
	}

	if ($c->param('confirmed')) {
		my $newfile = $c->param('name');
		if ($newfile = $c->verifyPath($newfile, $original)) {
			if (copy($oldfile, $newfile)) {
				$c->addgoodmessage($c->maketext('File successfully copied'));
				return $c->Refresh;
			} else {
				$c->addbadmessage($c->maketext(q{Can't copy file: [_1]}, $!));
			}
		}
	}

	return $c->c($c->Confirm($c->maketext('Copy file as:'), uniqueName($dir, $original), $c->maketext('Copy')),
		$c->hidden_field(files => $original))->join('');
}

# Rename a file
sub Rename ($c) {
	my $dir      = "$c->{courseRoot}/$c->{pwd}";
	my $original = $c->getFile('rename');
	return '' unless $original;
	my $oldfile = "$dir/$original";

	my $realpath = Mojo::File->new($oldfile)->realpath;
	if (grep { $realpath eq Mojo::File->new("$c->{courseRoot}/$_")->realpath } @{ $c->ce->{uneditableCourseFiles} }) {
		$c->addbadmessage($c->maketext('The file "[_1]" is protected and cannot be renamed.', $original));
		return $c->Refresh();
	}

	if (grep { $realpath eq $_ } values %{ $c->ce->{courseDirs} }) {
		$c->addbadmessage($c->maketext(
			'The directory "[_1]" is a required course directory and cannot be renamed.', $original));
		return $c->Refresh();
	}

	if ($c->param('confirmed')) {
		my $newfile = $c->param('name');
		if ($newfile = $c->verifyPath($newfile, $original)) {
			if (rename $oldfile, $newfile) {
				$c->addgoodmessage($c->maketext('File successfully renamed'));
				return $c->Refresh;
			} else {
				$c->addbadmessage($c->maketext(q{Can't rename file: [_1]}, $!));
			}
		}
	}

	return $c->c($c->Confirm($c->maketext('Rename file as:'), $original, $c->maketext('Rename')),
		$c->hidden_field(files => $original))->join('');
}

# Delete a file
sub Delete ($c) {
	my @files = $c->param('files');

	if (!@files) {
		$c->addbadmessage($c->maketext('You must select at least one file to delete'));
		return $c->Refresh;
	}

	my $dir = "$c->{courseRoot}/$c->{pwd}";

	my @course_dirs = values %{ $c->ce->{courseDirs} };

	# If only one file is selected and it is one of the uneditable course files,
	# then don't show the deletion confirmation page. Just warn about it now.
	if (@files == 1) {
		my $realpath = Mojo::File->new("$dir/$files[0]")->realpath;
		if (grep { $realpath eq Mojo::File->new("$c->{courseRoot}/$_")->realpath } @{ $c->ce->{uneditableCourseFiles} })
		{
			$c->addbadmessage($c->maketext('The file "[_1]" is protected and cannot be deleted.', $files[0]));
			return $c->Refresh();
		}
		if (grep { $realpath eq $_ } @course_dirs) {
			$c->addbadmessage($c->maketext(
				'The directory "[_1]" is a required course directory and cannot be deleted.',
				$files[0]
			));
			return $c->Refresh();
		}
	}

	if ($c->param('confirmed')) {
		# If confirmed, go ahead and delete the files
		for my $file (@files) {
			my $realpath = Mojo::File->new("$dir/$file")->realpath;
			if (grep { $realpath eq Mojo::File->new("$c->{courseRoot}/$_")->realpath }
				@{ $c->ce->{uneditableCourseFiles} })
			{
				$c->addbadmessage($c->maketext('The file "[_1]" is protected and cannot be deleted.', $file));
				next;
			}
			if (grep { $realpath eq $_ } @course_dirs) {
				$c->addbadmessage($c->maketext(
					'The directory "[_1]" is a required course directory and cannot be deleted.', $file
				));
				next;
			}

			if (defined $c->checkPWD("$c->{pwd}/$file", 1)) {
				if (-d "$dir/$file" && !-l "$dir/$file") {
					my $removed = eval { rmtree("$dir/$file", 0, 1) };
					if ($removed) {
						$c->addgoodmessage(
							$c->maketext('Directory "[_1]" removed (items deleted: [_2])', $file, $removed));
					} else {
						$c->addbadmessage($c->maketext('Directory "[_1]" not removed: [_2]', $file, $!));
					}
				} else {
					if (unlink("$dir/$file")) {
						$c->addgoodmessage($c->maketext('File "[_1]" successfully removed', $file));
					} else {
						$c->addbadmessage($c->maketext('File "[_1]" not removed: [_2]', $file, $!));
					}
				}
			} else {
				$c->addbadmessage($c->maketext('Illegal file "[_1]" specified', $file));
				last;
			}
		}
		return $c->Refresh;
	} else {
		return $c->include('ContentGenerator/Instructor/FileManager/delete', dir => $dir, files => \@files);
	}
}

# Make a gzipped tar or zip archive
sub MakeArchive ($c) {
	my @files = $c->param('files');
	if (scalar(@files) == 0) {
		$c->addbadmessage($c->maketext('You must select at least one file for the archive'));
		return $c->Refresh;
	}

	my $dir = $c->{pwd} eq '.' ? $c->{courseRoot} : "$c->{courseRoot}/$c->{pwd}";

	if ($c->param('confirmed')) {
		my $action = $c->param('action')          || 'Cancel';
		return $c->Refresh if $action eq 'Cancel' || $action eq $c->maketext('Cancel');

		unless ($c->param('archive_filename')) {
			$c->addbadmessage($c->maketext('The archive filename cannot be empty.'));
			return $c->include('ContentGenerator/Instructor/FileManager/archive', dir => $dir, files => \@files);
		}

		my $archive_type =
			$c->param('archive_type') || ($c->param('archive_filename') =~ /\.(zip|tgz|tar.gz)$/ ? $1 : 'zip');

		my $archive = $c->param('archive_filename');

		# Add the correct extension to the archive filename unless it already has it. If the extension for
		# the other archive type is given, then change it to the extension for this archive type.
		if ($archive_type eq 'zip') {
			$archive =~ s/(\.(tgz|tar.gz))?$/.zip/ unless $archive =~ /\.zip$/;
		} else {
			$archive =~ s/(\.zip)?$/.tgz/ unless $archive =~ /\.(tgz|tar.gz)$/;
		}

		# Check filename validity.
		if ($archive =~ m!/!) {
			$c->addbadmessage($c->maketext('The archive filename may not contain a path component'));
			return $c->include('ContentGenerator/Instructor/FileManager/archive', dir => $dir, files => \@files);
		}
		if ($archive =~ m!^\.! || $archive =~ m![^-_.a-zA-Z0-9 ]!) {
			$c->addbadmessage($c->maketext('The archive filename contains illegal characters'));
			return $c->include('ContentGenerator/Instructor/FileManager/archive', dir => $dir, files => \@files);
		}

		if (-e "$dir/$archive" && !$c->param('overwrite')) {
			$c->addbadmessage($c->maketext(
				'The file [_1] exists. Check "Overwrite existing archive" to force this file to be replaced.',
				$archive
			));
			return $c->include('ContentGenerator/Instructor/FileManager/archive', dir => $dir, files => \@files);
		}

		unless (@files > 0) {
			$c->addbadmessage($c->maketext('At least one file must be selected'));
			return $c->include('ContentGenerator/Instructor/FileManager/archive', dir => $dir, files => \@files);
		}

		my ($error, $ok);
		if ($archive_type eq 'zip') {
			if (my $zip = Archive::Zip::SimpleZip->new("$dir/$archive")) {
				for (@files) {
					$zip->add("$dir/$_", Name => $_, storelinks => 1);
				}
				$ok = $zip->close;
			}
			$error = $SimpleZipError unless $ok;
		} else {
			my $tar = Archive::Tar->new;
			$tar->add_files(map {"$dir/$_"} @files);
			# Make file names in the archive relative to the current working directory.
			for ($tar->get_files) {
				$tar->rename($_->full_path, $_->full_path =~ s!^$dir/!!r);
			}
			$ok    = $tar->write("$dir/$archive", COMPRESS_GZIP);
			$error = $tar->error unless $ok;
		}
		if ($ok) {
			$c->addgoodmessage(
				$c->maketext('Archive "[_1]" created successfully ([quant,_2,file])', $archive, scalar(@files)));
		} else {
			$c->addbadmessage($c->maketext(q{Can't create archive "[_1]": [_2]}, $archive, $error));
		}
		return $c->Refresh;
	} else {
		return $c->include('ContentGenerator/Instructor/FileManager/archive', dir => $dir, files => \@files);
	}
}

# Unpack a gzipped tar archive
sub UnpackArchive ($c) {
	my $archive = $c->getFile('unpack');
	return '' unless $archive;
	if ($archive !~ m/\.(tar|tar\.gz|tgz|zip)$/) {
		$c->addbadmessage($c->maketext('You can only unpack files ending in ".zip", ".tgz", ".tar" or ".tar.gz"'));
	} else {
		$c->unpack_archive($archive);
	}
	return $c->Refresh;
}

sub unpack_archive ($c, $archive) {
	my $dir = Mojo::File->new($c->{courseRoot}, $c->{pwd});

	my (@members, @existing_files, @outside_files, @forbidden_files);
	my $num_extracted = 0;

	if ($archive =~ m/\.zip$/) {
		my $zip = Archive::Zip->new($dir->child($archive)->to_string);
		unless ($zip) {
			$c->addbadmessage($c->maketext(q{Unable to read zip archive file "[_1]".}, $dir->child($archive)));
			return 0;
		}

		Archive::Zip::setErrorHandler(sub ($error) {
			chomp $error;
			$c->addbadmessage($error);
		});

		@members = $zip->members;
		for (@members) {
			my $out_file = $dir->child($_->fileName);
			if (!path_is_subdir($out_file, $dir)) {
				push(@outside_files, $_->fileName);
				next;
			}

			if (!$c->authz->hasPermissions($c->param('user'), 'edit_restricted_files')
				&& grep { $out_file eq Mojo::File->new("$c->{courseRoot}/$_")->realpath }
				@{ $c->ce->{uneditableCourseFiles} })
			{
				push(@forbidden_files, $_->fileName);
				next;
			}

			if (!$c->param('overwrite') && -e $out_file) {
				push(@existing_files, $_->fileName);
				next;
			}
			++$num_extracted if $zip->extractMember($_ => $out_file->to_string) == AZ_OK;
		}

		Archive::Zip::setErrorHandler();
	} elsif ($archive =~ m/\.(tar(\.gz)?|tgz)$/) {
		local $Archive::Tar::WARN = 0;

		my $tar = Archive::Tar->new($dir->child($archive)->to_string);
		unless ($tar) {
			$c->addbadmessage($c->maketext(q{Unable to read tar archive file "[_1]".}, $dir->child($archive)));
			return 0;
		}

		$tar->setcwd($dir->to_string);

		@members = $tar->list_files;
		for (@members) {
			my $out_file = $dir->child($_);
			if (!path_is_subdir($out_file->to_string, $dir->to_string)) {
				push(@outside_files, $_);
				next;
			}

			if (!$c->authz->hasPermissions($c->param('user'), 'edit_restricted_files')
				&& grep { $out_file eq Mojo::File->new("$c->{courseRoot}/$_")->realpath }
				@{ $c->ce->{uneditableCourseFiles} })
			{
				push(@forbidden_files, $_);
				next;
			}

			if (!$c->param('overwrite') && -e $dir->child($_)) {
				push(@existing_files, $_);
				next;
			}

			unless ($tar->extract_file($_)) {
				$c->addbadmessage($tar->error);
				next;
			}
			++$num_extracted;
		}
	} else {
		$c->addbadmessage($c->maketext('Unsupported archive type in file "[_1]"', $archive));
		return 0;
	}

	if (@outside_files) {
		$c->addbadmessage(
			$c->tag(
				'p',
				$c->maketext(
					'The following [plural,_1,file is,files are] outside the current working directory '
						. 'and cannot be safely unpacked.',
					scalar(@outside_files),
				)
				)
				. $c->tag(
					'div',
					$c->tag(
						'ul',
						$c->c(
							(map { $c->tag('li', $_) } @outside_files[ 0 .. min(29, $#outside_files) ]),
							(
								@outside_files > 30
								? $c->tag('li',
									$c->maketext('[quant,_1,more file,more files] not shown', @outside_files - 30))
								: ()
							)
					)->join('')
					)
				)
		);
	}

	# There aren't many of these, so all of them can be reported.
	if (@forbidden_files) {
		$c->addbadmessage(
			$c->tag(
				'p',
				$c->maketext(
					'The following [plural,_1,file] found in the archive [plural,_1,is,are]'
						. ' protected and were not extracted.',
					scalar(@forbidden_files),
				)
				)
				. $c->tag('div', $c->tag('ul', $c->c((map { $c->tag('li', $_) } @forbidden_files))->join('')))
		);
	}

	if (@existing_files) {
		$c->addbadmessage(
			$c->tag(
				'p',
				$c->maketext(
					'The following [plural,_1,file already exists,files already exist]. '
						. 'Check "Overwrite existing files silently" to unpack [plural,_1,this file,these files].',
					scalar(@existing_files),
				)
				)
				. $c->tag(
					'div',
					$c->tag(
						'ul',
						$c->c(
							(map { $c->tag('li', $_) } @existing_files[ 0 .. min(29, $#existing_files) ]),
							(
								@existing_files > 30
								? $c->tag('li',
									$c->maketext('[quant,_1,more file,more files] not shown', @existing_files - 30))
								: ()
							)
					)->join('')
					)
				)
		);
	}

	$c->addgoodmessage($c->maketext('[quant,_1,file] unpacked successfully', $num_extracted)) if $num_extracted;
	return $num_extracted == @members;
}

# Open the edit page with no contents. This does not actually create a file.
# That is done when the user clicks save on the edit page.
sub NewFile ($c) {
	return $c->RefreshEdit('', $c->param('name'))
		if $c->param('confirmed') && $c->verifyName($c->param('name'), 'file');
	return $c->Confirm($c->maketext('New file name:'), '', $c->maketext('New File'));
}

# Make a new directory
sub NewFolder ($c) {
	if ($c->param('confirmed')) {
		my $name = $c->param('name');
		if (my $dir = $c->verifyName($name, 'directory')) {
			if (mkdir $dir, 0750) {
				$c->{pwd} .= "/$name";
				return $c->Refresh;
			} else {
				$c->addbadmessage($c->maketext(q{Can't create directory: [_1]}, $!));
			}
		}
	}

	return $c->Confirm($c->maketext('New folder name:'), '', $c->maketext('New Folder'));
}

# Download a file
sub Download ($c) {
	my $pwd = $c->checkPWD($c->param('pwd') || HOME);
	return unless $pwd;
	my $filename = $c->getFile('download');
	return unless $filename;
	my $file = "$c->{ce}{courseDirs}{root}/$pwd/$filename";

	if     (-d $file) { $c->addbadmessage($c->maketext(q{You can't download directories}));        return }
	unless (-f $file) { $c->addbadmessage($c->maketext(q{You can't download files of that type})); return }

	$c->param('download', $filename);

	return;
}

# Upload a file to the server
sub Upload ($c) {
	my $dir        = "$c->{courseRoot}/$c->{pwd}";
	my $fileIDhash = $c->param('file');
	unless ($fileIDhash) {
		$c->addbadmessage($c->maketext('You have not chosen a file to upload.'));
		return $c->Refresh;
	}

	my $upload = WeBWorK::Upload->retrieve(split(/\s+/, $fileIDhash), $c->{ce}{webworkDirs}{uploadCache});

	my $name                     = $upload->filename;
	my $invalidUploadFilenameMsg = $c->checkName($name);

	my $action = $c->param('formAction') || 'Cancel';
	if ($c->param('confirmed')) {
		if ($action eq 'Cancel' || $action eq $c->maketext('Cancel')) {
			$upload->dispose;
			return $c->Refresh;
		}
		if ($action eq 'Rename' || $action eq $c->maketext('Rename')) {
			if (!$c->param('name') || $c->param('name') eq $name) {
				$c->addbadmessage($c->maketext('You must specify a new file name.'));
			} elsif (my $invalidFileNameMsg = $c->checkName($c->param('name'))) {
				$c->addbadmessage($invalidFileNameMsg);
			} else {
				$name = $c->param('name');

				# In this case the upload file name is still invalid, but it isn't going to be used anyway. So setting
				# this to 0 lets the new name go through (if it doesn't already exist).
				$invalidUploadFilenameMsg = 0;
			}
		}
	}

	$c->addbadmessage($invalidUploadFilenameMsg) if $invalidUploadFilenameMsg;

	if (-e "$dir/$name" || $invalidUploadFilenameMsg) {
		my $isProtected = !$c->authz->hasPermissions($c->param('user'), 'edit_restricted_files')
			&& grep { Mojo::File->new("$dir/$name")->realpath eq Mojo::File->new("$c->{courseRoot}/$_")->realpath }
			@{ $c->ce->{uneditableCourseFiles} };

		if (
			($invalidUploadFilenameMsg || $isProtected)
			|| (!$c->param('overwrite')
				&& $action ne 'Overwrite'
				&& $action ne $c->maketext('Overwrite'))
			)
		{
			return $c->c(
				$c->Confirm(
					$c->tag(
						'p',
						$c->b(
							$invalidUploadFilenameMsg
							? $c->maketext('<b>[_1]</b> is an invalid file name and must be renamed. Rename it as:',
								$name)
							: $isProtected
							? $c->maketext('File <b>[_1]</b> is protected and cannot be overwritten. Rename it as:',
								$name)
							: $c->maketext('File <b>[_1]</b> already exists. Overwrite it, or rename it as:', $name)
						)
					),
					uniqueName($dir, $name),
					$c->maketext('Rename'),
					$isProtected || $invalidUploadFilenameMsg ? '' : $c->maketext('Overwrite')
				),
				$c->hidden_field(action => 'Upload'),
				$c->hidden_field(file   => $fileIDhash)
			)->join('');
		}
	}
	$c->checkFileLocation($name, $c->{pwd});

	my $file = "$dir/$name";
	my $type = $c->getFlag('format', 'Automatic');
	my $data;

	#  Check if we need to convert linebreaks
	if ($type ne 'Binary') {
		my $fh    = $upload->fileHandle;
		my @lines = <$fh>;
		$fh->close;
		$data = join('', @lines);
		if ($type eq 'Automatic') { $type = isText($data) ? 'Text' : 'Binary' }
	}
	if ($type eq 'Text') {
		$upload->dispose;
		$data =~ s/\r\n?/\n/g;

		my $backup_data = $data;
		my $success     = utf8::decode($data);    # try to decode as utf8
		unless ($success) {
			warn "Trying to convert file $file from latin1? to UTF-8";
			utf8::upgrade($backup_data);          # try to convert data from latin1 to utf8.
			$data = $backup_data;
		}

		if (open(my $UPLOAD, '>:encoding(UTF-8)', $file)) {
			print $UPLOAD $data;
			close $UPLOAD;
		} else {
			$c->addbadmessage($c->maketext(q{Can't create file "[_1]": [_2]}, $name, $!));
		}
	} else {
		$upload->disposeTo($file);
	}

	if (-e $file) {
		$c->addgoodmessage($c->maketext('File "[_1]" uploaded successfully', $name));
		if ($name =~ m/\.(tar|tar\.gz|tgz|zip)$/ && $c->getFlag('unpack')) {
			if ($c->unpack_archive($name) && $c->getFlag('autodelete')) {
				if (unlink($file)) { $c->addgoodmessage($c->maketext('Archive "[_1]" deleted', $name)) }
				else               { $c->addbadmessage($c->maketext(q{Can't delete archive "[_1]": [_2]}, $name, $!)) }
			}
		}
	}

	return $c->Refresh;
}

# Print a confirmation dialog box
sub Confirm ($c, $message, $value, $button, $button2 = '') {
	return $c->include(
		'ContentGenerator/Instructor/FileManager/confirm',
		message => $message,
		value   => $value,
		button  => $button,
		button2 => $button2
	);
}

# Check that there is exactly one valid file
sub getFile ($c, $action) {
	my @files = $c->param('files');
	if (scalar(@files) > 1) {
		$c->addbadmessage($c->maketext('You can only [_1] one file at a time.', $action));
		$c->Refresh unless $action eq 'download';
		return;
	}
	if (scalar(@files) == 0 || $files[0] eq '') {
		$c->addbadmessage($c->maketext('You need to select a file to [_1].', $action));
		$c->Refresh unless $action eq 'download';
		return;
	}
	my $pwd = $c->checkPWD($c->{pwd} || $c->param('pwd') || HOME) || '.';
	if ($c->isSymLink($pwd . '/' . $files[0])) {
		$c->addbadmessage($c->maketext('You may not follow symbolic links'));
		$c->Refresh unless $action eq 'download';
		return;
	}
	unless ($c->checkPWD($pwd . '/' . $files[0], 1)) {
		$c->addbadmessage($c->maketext('You have specified an illegal file'));
		$c->Refresh unless $action eq 'download';
		return;
	}
	return $files[0];
}

# Get the entries for the directory menu
sub directoryMenu ($c, $dir) {
	$dir =~ s!^\.(/|$)!!;
	my @dirs = split('/', $dir);

	my @values;
	while (@dirs) {
		my $pwd = join('/', (@dirs)[ 0 .. $#dirs ]);
		$dir = pop(@dirs);
		push(@values, [ $dir => $pwd ]);
	}
	push(@values, [ $c->{courseName} => '.' ]);
	$c->param('directory', $values[0][0]);
	return \@values;
}

# Get the directory listing
sub directoryListing ($c, $pwd) {
	my $dir = "$c->{courseRoot}/$pwd";

	return unless -d $dir;

	my (@values, $size, $data);

	my $len   = 24;
	my @names = sortByName(undef, @{ Mojo::File->new($dir)->list({ dir => 1 })->map('basename') });
	for my $name (@names) {
		unless ($name eq 'DATA') {    #FIXME don't view the DATA directory
			my $file = "$dir/$name";

			my $type = 0;
			$type |= 1  if $c->isSymLink($file);                 # Symbolic link
			$type |= 2  if !$c->isSymLink($file) && -d $file;    # Directory
			$type |= 4  if -f $file;                             # Regular file
			$type |= 8  if -T $file;                             # Text file
			$type |= 16 if $file =~ m/\.(gif|jpg|png)$/i;        # Image file

			my $label = $name;
			$label .= '@' if $type & 1;
			$label .= '/' if $type & 2;

			$len = length($label) if length($label) > $len;

			push(@values, [ $label => $name, data => { type => $type } ]);
		}
	}
	if ($c->getFlag('dates')) {
		$len += 3;
		for my $name (@values) {
			my $file = "$dir/$name->[1]";
			my ($size, $date) = (lstat($file))[ 7, 9 ];
			$name->[0] = $c->b(
				sprintf("%-${len}s%-16s%10s", $name->[0], -d $file ? ('', '') : (getDate($date), getSize($size)))
					=~ s/\s/&nbsp;/gr);
		}
	}
	return \@values;
}

sub getDate ($date) {
	my ($sec, $min, $hour, $day, $month, $year) = localtime($date);
	return sprintf('%02d-%02d-%04d %02d:%02d', $month + 1, $day, $year + 1900, $hour, $min);
}

sub getSize ($size) {
	return $size . ' B ' if $size < 1024;
	return sprintf('%.1f KB', $size / 1024)        if $size < 1024 * 100;
	return sprintf('%d KB',   int($size / 1024))   if $size < 1024 * 1024;
	return sprintf('%.1f MB', $size / 1024 / 1024) if $size < 1024 * 1024 * 100;
	return sprintf('%d MB',   $size / 1024 / 1024);
}

# Check if a file is a symbolic link that we are not allowed to follow.
sub isSymLink ($c, $file) {
	return 0 unless -l $file;

	my $courseRoot = $c->{ce}{courseDirs}{root};
	$courseRoot = readlink($courseRoot) if -l $courseRoot;
	my $pwd  = $c->{pwd} || $c->param('pwd') || HOME;
	my $link = File::Spec->rel2abs(readlink($file), "$courseRoot/$pwd");

	# Remove /./ and dir/../ constructs
	$link =~ s!(^|/)(\.(/|$))+!$1!g;
	while ($link =~ s!((\.[^./]+|\.\.[^/]+|[^./][^/]*)/\.\.(/|$))!!) { }

	# Look through the list of valid paths to see if this link is OK
	my $valid = $c->{ce}{webworkDirs}{valid_symlinks};
	if (defined $valid && $valid) {
		for my $path (@{$valid}) {
			return 0 if substr($link, 0, length($path)) eq $path;
		}
	}

	return 1;
}

# Normalize the working directory and check if it is OK.
sub checkPWD ($c, $pwd, $renameError = 0) {
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
	my @path = ($c->{ce}{courseDirs}{root});
	for my $dir (@dirs) {
		push @path, $dir;
		return if ($c->isSymLink(join('/', @path)));
	}

	my $original = $pwd;
	$pwd =~ s!(^|/)\.!$1_!g;                  # don't enter hidden directories
	$pwd =~ s!^/!!;                           # remove leading /
	$pwd =~ s![^-_./A-Z0-9~,() ]!_!gi;        # no illegal characters
	return if $renameError && $original ne $pwd;

	$pwd = '.' if $pwd eq '';
	return $pwd;
}

# Check that a file is uploaded to the correct directory
sub checkFileLocation ($c, $extension, $dir) {
	$extension =~ s/.*\.//;
	my $location = $uploadDir{$extension};
	return unless defined $location;
	return if $dir =~ m/^$location$/;
	$location      =~ s!/\.\*!!;
	return if $dir =~ m/^$location$/;
	$c->addbadmessage(
		$c->maketext('Files with extension ".[_1]" usually belong in "[_2]"', $extension, $location)
			. (
				$extension eq 'csv'
				? $c->maketext('. If this is a class roster, rename it to have extension ".lst"')
				: ''
			)
	);

	return;
}

# Check a file name for bad characters, etc. This returns a message explaining what is wrong with the file name if
# something is wrong, and undefined if all is good.
sub checkName ($c, $file) {
	return $c->maketext('No filename specified.') unless $file;
	return $c->maketext('"[_1]" contains a path component which is not allowed.', $file) if $file =~ /\//;
	return $c->maketext('"[_1]" contains invalid characters.',               $file) if $file =~ m![^-_.a-zA-Z0-9 /]!;
	return $c->maketext('"[_1]" begins with a period which is not allowed.', $file) if $file =~ m/^\./;
	return;
}

# Get a unique name (in case it already exists)
sub uniqueName ($dir, $name) {
	return $name unless (-e "$dir/$name");
	my $type = '';
	my $n    = 1;
	$type = $1 if ($name =~ s/(\.[^.]*)$//);
	$n    = $1 if ($name =~ s/_(\d+)$/_/);
	while (-e "$dir/${name}_$n$type") { $n++ }
	return "${name}_$n$type";
}

# Verify that a name can be added to the current directory.
sub verifyName ($c, $name, $object) {
	if ($name) {
		unless ($name =~ m!/!) {
			unless ($name =~ m!^\.!) {
				unless ($name =~ m![^-_.a-zA-Z0-9 ]!) {
					my $file = "$c->{courseRoot}/$c->{pwd}/$name";
					return $file unless (-e $file);
					$c->addbadmessage($c->maketext('A file with that name already exists'));
				} else {
					$c->addbadmessage($c->maketext('Your [_1] name contains illegal characters', $object));
				}
			} else {
				$c->addbadmessage($c->maketext('Your [_1] name may not begin with a dot', $object));
			}
		} else {
			$c->addbadmessage($c->maketext('Your [_1] name may not contain a path component', $object));
		}
	} else {
		$c->addbadmessage($c->maketext('You must specify a [_1] name', $object));
	}
	return;
}

# Verify that a file path is valid
sub verifyPath ($c, $path, $name) {
	if ($path) {
		unless ($path =~ m![^-_.a-zA-Z0-9 /]!) {
			unless ($path =~ m!^/!) {
				$path = $c->checkPWD($c->{pwd} . '/' . $path, 1);
				if ($path) {
					$path = $c->{courseRoot} . '/' . $path;
					$path .= "/$name" if -d $path && $name;
					return $path unless (-e $path);
					$c->addbadmessage($c->maketext('A file with that name already exists'));
				} else {
					$c->addbadmessage($c->maketext('You have specified an illegal path'));
				}
			} else {
				$c->addbadmessage($c->maketext('You cannot specify an absolute path'));
			}
		} else {
			$c->addbadmessage($c->maketext('Your file name contains illegal characters'));
		}
	} else {
		$c->addbadmessage($c->maketext('You must specify a file name'));
	}
	return;
}

# Get the value of a parameter flag
sub getFlag ($c, $flag, $default = 0) {
	return $c->param($flag) // $default;
}

# Check if a string is plain text
sub isText ($string) {
	return utf8::is_utf8($string);
}

# Interpret command return errors
sub systemError ($status) {
	return "error: $!" if $status == 0xFF00;
	return 'exit status ' . ($status >> 8) if ($status & 0xFF) == 0;
	return 'signal ' . ($status &= ~0x80);
}

1;
