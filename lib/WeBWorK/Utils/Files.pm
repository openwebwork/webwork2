################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::Utils::Files;
use Mojo::Base 'Exporter', -signatures;

use File::Spec::Functions qw(canonpath);
use File::Find;
use Mojo::File qw(path);

our @EXPORT_OK = qw(
	surePathToFile
	readFile
	listFilesRecursive
	path_is_subdir
);

sub surePathToFile ($start_directory, $path) {
	# If the path starts with $start_directory (which is permitted but optional) remove this initial segment.
	$path =~ s|^$start_directory/?|| if $path =~ m|^$start_directory|;

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
				my $relFile = $File::Find::name =~ s|^$dir/?||r;

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

sub path_is_subdir ($path, $dir, $allow_relative = 0) {
	unless ($path =~ /^\//) {
		if ($allow_relative) {
			$path = "$dir/$path";
		} else {
			return 0;
		}
	}

	$path = canonpath($path);
	$path .= '/' unless $path =~ m|/$|;
	return 0 if $path =~ m#(^\.\.$|^\.\./|/\.\./|/\.\.$)#;

	$dir = canonpath($dir);
	$dir .= '/' unless $dir =~ m|/$|;
	return 0 unless $path =~ m|^$dir|;

	return 1;
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

    listFilesRecusive($dir, $match_qr, $prune_qr, $match_full, $prune_full)

Traverses the directory tree rooted at C<$dir>, returning a list of files, named
pipes, and sockets matching the regular expression C<$match_qr>. Directories
matching the regular expression C<$prune_qr> are not visited.

C<$match_full> and C<$prune_full> are boolean values that indicate whether
C<$match_qr> and C<$prune_qr>, respectively, should be applied to the bare
directory entry (false) or to the path to the directory entry relative to
C<$dir>.

The method returns a list of paths relative to C<$dir>.

=head2 path_is_subdir

    path_is_subdir($path, $dir, $allow_relative)

Ensures that C<$path> refers to a location "inside" C<$dir>. If
C<$allow_relative> is true and C<$path> is not absolute, it is assumed to be
relative to C<$dir>.

The method of checking is rather rudimentary at the moment. First, upreferences
("..") are disallowed in C<$path>, then it is checked to make sure that some
prefix of it matches C<$dir>.

If either of these checks fails, a false value is returned. Otherwise, a true
value is returned.

=cut
