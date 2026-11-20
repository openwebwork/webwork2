package WeBWorK::Utils::Files;
use Mojo::Base 'Exporter', -signatures;

use File::Spec::Functions qw(canonpath);
use File::Find;
use Mojo::File qw(path);

our @EXPORT_OK = qw(
	surePathToFile
	readFile
	listFilesRecursive
	pathIsSafe
	pathIsSubdir
	fileNameIsValid
	filePathIsValid
	fileNameRequirementsMessage
	filePathRequirementsMessage
	getHumanReadableFileSize
);

sub surePathToFile ($start_directory, $path) {
	# If the path starts with $start_directory (which is permitted but optional) remove this initial segment.
	$path =~ s|^\Q$start_directory\E/?|| if $path =~ m|^\Q$start_directory\E|;

	my $parent = path($start_directory);
	my $child  = $parent->child($path);

	# Create the path with the mode of the parent directory.
	$path = eval { $child->dirname->make_path({ mode => $parent->stat->mode }) };
	warn "Failed to create directory $path with start directory $start_directory: $@" if $@;

	return $child->to_string;
}

sub readFile ($fileName) {
	my $result = '';

	if (-r $fileName) {
		eval { $result = path($fileName)->slurp('UTF-8') };
		warn "$@\n" if $@;
	}

	# Convert Windows and Mac (classic) line endings to UNIX line endings in a string.
	# Windows uses CRLF, Mac uses CR, UNIX uses LF. (CR is ASCII 15, LF if ASCII 12)
	return ($result // '') =~ s/\015\012?/\012/gr;
}

sub listFilesRecursive ($dir, $match_qr, $prune_qr = '', $match_full = 0, $prune_full = 0) {
	my @matches;

	find(
		{
			wanted => sub {
				my $relFile = $File::Find::name =~ s|^\Q$dir\E/?||r;

				if (-d $File::Find::name) {
					# Skip unreadable directories (and broken symlinks, incidentally).
					unless (-r $File::Find::name) {
						warn "Directory/symlink $File::Find::name not readable";
						$File::Find::prune = 1;
						return;
					}

					# Prune the directory if it matches $prune_qr.
					$File::Find::prune = 1 if defined $prune_qr && ($prune_full ? $relFile : $_) =~ m/$prune_qr/;
				}

				# Only match plain files.
				return unless -f $File::Find::name;

				push @matches, $relFile if ($match_full ? $relFile : $_) =~ m/$match_qr/;
			},
			follow_fast => 1,
			follow_skip => 2
		},
		$dir
	);

	return @matches;
}

sub pathIsSafe ($path) {
	return defined $path && $path !~ m#^\.\.$|^\.\./|/\.\./|/\.\.$# ? 1 : 0;
}

sub pathIsSubdir ($path, $dir, $allow_relative = 0) {
	return 0 unless pathIsSafe($path);

	return $allow_relative ? 1 : 0 unless $path =~ /^\//;

	$path = canonpath($path);
	$path .= '/' unless $path =~ m|/$|;

	$dir = canonpath($dir);
	$dir .= '/' unless $dir =~ m|/$|;

	return $path =~ m|^\Q$dir\E| ? 1 : 0;
}

sub fileNameIsValid ($name) {
	return defined $name && $name =~ /^[-\w+,()~ ][-\w.+,()~ ]*\z/a ? 1 : 0;
}

sub filePathIsValid ($path) {
	return defined $path && $path ne '' && !(grep { !fileNameIsValid($_) } split('/', $path, -1)) ? 1 : 0;
}

sub fileNameRequirementsMessage ($c, $name = undef) {
	my $requirements = $c->maketext('Names can only contain letters, digits, spaces, and the characters '
			. '"-", "_", ".", "+", ",", "(", ")", and "~~", and cannot start with a period.');
	return defined $name ? $c->maketext('"[_1]" is not an allowed name.', $name) . " $requirements" : $requirements;
}

sub filePathRequirementsMessage ($c, $path = undef) {
	my $requirements = $c->maketext('Each part of a file path can only contain letters, digits, spaces, and the '
			. 'characters "-", "_", ".", "+", ",", "(", ")", and "~~", and cannot start with a period.');
	return
		defined $path ? $c->maketext('"[_1]" is not an allowed file path.', $path) . " $requirements" : $requirements;
}

sub getHumanReadableFileSize ($file) {
	my $size     = $file->stat->size;
	my @units    = qw(B KB MB GB);
	my $unit_idx = 0;
	while ($size >= 1024 && $unit_idx < $#units) {
		$size /= 1024;
		++$unit_idx;
	}
	my $round = 10**($unit_idx > 0 ? $unit_idx - 1 : 0);

	return sprintf("%s %s", int($size * $round) / $round, $units[$unit_idx]);
}

1;

=head1 NAME

WeBWorK::Utils::Files - contains utility subroutines for files system
interaction.

=head2 surePathToFile

Usage: C<surePathToFile($start_directory, $path)>

Constructs intermediate directories en-route to the file relative to the start
directory.  The input path can be the path relative to the start directory or
can include the start directory.

=head2 readFile

Usage: C<readFile($fileName)>

Read the entire contents of C<$fileName> into memory. The file contents are
returned after transforming line endings into UNIX line feeds.

=head2 listFilesRecursive

    listFilesRecursive($dir, $match_qr, $prune_qr, $match_full, $prune_full)

Traverses the directory tree rooted at C<$dir>, returning a list of files, named
pipes, and sockets matching the regular expression C<$match_qr>. Directories
matching the regular expression C<$prune_qr> are not visited.

C<$match_full> and C<$prune_full> are boolean values that indicate whether
C<$match_qr> and C<$prune_qr>, respectively, should be applied to the bare
directory entry (false) or to the path to the directory entry relative to
C<$dir>.

The method returns a list of paths relative to C<$dir>.

=head2 pathIsSafe

    pathIsSafe($path)

Returns true if a path is "safe", and false otherwise.  This simply means that
C<$path> is defined and does not contain any ".." path components that could
possibly take the path to a location outside of an allowed location.

This is the definition of a safe path that should be used throughout webwork2.
Use this method (or C<pathIsSubdir> which calls this method) whenever a path
from user input or the database is to be validated.

=head2 pathIsSubdir

    pathIsSubdir($path, $dir, $allow_relative)

Ensures that C<$path> refers to a location "inside" C<$dir>. If
C<$allow_relative> is true and C<$path> is not absolute, it is assumed to be
relative to C<$dir>.

The method of checking is rather rudimentary. First, upreferences ("..") are
disallowed in C<$path>, then it is checked to make sure that some prefix of it
matches C<$dir>.

If either of these checks fails, a false value is returned. Otherwise, a true
value is returned.

Note that this check is based on the name of the path only, and does not check
for symbolic links that may actually resolve elsewhere.

=head2 fileNameIsValid

    fileNameIsValid($name)

Returns true if C<$name> is a valid name for a file or directory, and false
otherwise.  A valid name is a single path component (it contains no slashes)
that consists only of ASCII letters, digits, spaces, and the characters
"-", "_", ".", "+", ",", "(", ")", and "~", and does not start with a period.
So "a.." is valid, but hidden files such as ".a" or "..a" are not.

This is the definition of a valid file name that should be used throughout
webwork2 whenever a user provides the name of a file or directory that is to be
created.

=head2 filePathIsValid

    filePathIsValid($path)

Returns true if C<$path> is a valid relative path for a file or directory that
is to be created, and false otherwise.  The path is valid if each of its slash
separated components is a valid name in the sense of C<fileNameIsValid>.  So the
path cannot be absolute, cannot end with a slash, and cannot contain consecutive
slashes or components that start with a period (including "." and "..").  Note
that a valid path is also safe in the sense of C<pathIsSafe>.

=head2 fileNameRequirementsMessage

    fileNameRequirementsMessage($c, $name)

Returns a localized message describing the requirements for a valid file name in
the sense of C<fileNameIsValid>.  If C<$name> is given, the message begins by
stating that C<$name> is not an allowed name.  C<$c> must be an object with a
C<maketext> method, usually a C<WeBWorK::Controller>.

Use this method to report an invalid file name so that the description stays in
sync with C<fileNameIsValid>.

=head2 filePathRequirementsMessage

    filePathRequirementsMessage($c, $path)

Returns a localized message describing the requirements for a valid file path in
the sense of C<filePathIsValid>.  If C<$path> is given, the message begins by
stating that C<$path> is not an allowed file path.  C<$c> must be an object with
a C<maketext> method, usually a C<WeBWorK::Controller>.

Use this method to report an invalid file path so that the description stays in
sync with C<filePathIsValid>.

=head2 getHumanReadableFileSize

    getHumanReadableFileSize($file)

Returns the human readable size (the size with the appropriate unit of C<B>,
C<KB>, C<MB>, or C<GB>) of a C<$file> where C<$file> is a C<Mojo::File> object.
Note that this method assumes the passed C<$file> exists and is readable.

=cut
