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

package WeBWorK::Upload;

=head1 NAME

WeBWorK::Upload - store uploads securely across requests.

=head1 SYNOPSIS

Given C<$u>, a C<Mojo::Upload> object

    my $upload  = WeBWorK::Upload->store($u, $ce->{webworkDirs}{uploadCache});
    my $tmpFile = $upload->tmpFile;
    my $hash    = $upload->hash;

Later...

    my $upload = WeBWorK::Upload->retrieve($tmpFile, $hash, $ce->{webworkDirs}{uploadCache});
    my $fh     = $upload->fileHandle;
    my $path   = $upload->filePath;

    # Get rid of the upload -- $upload is useless after this!
    $upload->dispose;

    # Or move it somewhere and dispose of it - $upload is also useless after this!
    $upload->disposeTo($path);

=head1 DESCRIPTION

WeBWorK::Upload provides a method for securely storing uploaded files until such
time as they are needed. This is useful for situations in which an upload needs
to be handled in a later request.  WeBWorK::Upload generates a unique temporary
file name and hash which can be used to retrieve the original file.

=cut

use strict;
use warnings;

use Carp        qw(croak);
use Digest::MD5 qw(md5_hex);
use Mojo::File  qw(path);

=head1 STORING UPLOADS

Uploads can be stored in an upload cache and later retrieved, given the
temporary file name and hash. The hash is used to confirm the authenticity of
the temporary file.

Uploads are constructed from Mojo::Upload objects.

=head2 store

    my $upload = WeBWorK::Upload->store($u, $dir);

Stores the Mojo::Upload C<$u> into the directory specified by C<$dir>.

=cut

sub store {
	my ($invocant, $upload, $dir) = @_;

	croak "no upload specified" unless $upload;

	my $tmpFile = path($upload->asset->to_file->path)->basename;
	$upload->move_to("$dir/$tmpFile");

	# Generate a one-time secret.
	my $secret = sprintf('%X' x 4, map { int rand 2**32 } 1 .. 4);

	# Get the original file name of the uploaded file.
	my $realFileName = $upload->filename;

	# Write the info file.
	my $infoPath = path($dir)->child("$tmpFile.info");
	eval { $infoPath->spew("$realFileName\n$secret\n", 'UTF-8') };
	die "failed to write upload info file $infoPath: $@" if $@;

	return bless {
		tmpFile      => $tmpFile,
		dir          => $dir,
		hash         => md5_hex($tmpFile, $secret),
		realFileName => $realFileName,
		},
		ref($invocant) || $invocant;
}

=head2 tmpFile

Return the temporary file name of the upload, or an undefined value if the
upload is not valid.

=cut

sub tmpFile {
	my ($self) = @_;

	# Make sure file still exists (i.e. the file hasn't been disposed of).
	return unless -e "$self->{dir}/$self->{tmpFile}";

	return $self->{tmpFile};
}

=head2 hash

Return the hash of the upload, or an undefined value if the upload is not valid.

=cut

sub hash {
	my ($self) = @_;

	# Make sure file still exists (i.e. the file hasn't been disposed of).
	return unless -e "$self->{dir}/$self->{tmpFile}";

	return $self->{hash};
}

=head1 RETRIEVING UPLOADS

An upload stored in the upload cache can be retrieved by supplying its temporary
file name and hash (accessible from the above C<tmpFile> and C<hash> methods),
respectively.  The file can then be accessed by name or file handle, moved, and
disposed of.

=head2 retrieve

    my $upload = WeBWorK::Upload->retrieve($tmpFile, $hash, $dir);

Retrieves the upload referenced by C<$tempFile> and C<$hash> and located in
C<$dir>.

=cut

sub retrieve {
	my ($invocant, $tmpFile, $hash, $dir) = @_;

	croak 'no upload temporary file name specified' unless $tmpFile;
	croak 'no upload hash specified'                unless $hash;
	croak 'no upload directory specified'           unless $dir;

	my $infoPath = path($dir)->child("$tmpFile.info");

	croak 'no upload matches the ID specified' unless -e $infoPath;

	# Get the original file name and secret from info file.
	my ($realFileName, $secret) = eval { split(/\n/, $infoPath->slurp('UTF-8')) };
	die "failed to read upload info file $infoPath: $@" if $@;

	# Generate the correct hash from the $tmpFile and $secret.
	my $correctHash = md5_hex($tmpFile, $secret);

	croak 'upload hash incorrect!' unless $hash eq $correctHash;

	return bless {
		tmpFile      => $tmpFile,
		dir          => $dir,
		hash         => $hash,
		realFileName => $realFileName,
		},
		ref($invocant) || $invocant;
}

=head2 METHODS

=head3 filename

Returns the original name of the uploaded file, or an undefined value if the
upload is not valid.

=cut

sub filename {
	my ($self) = @_;

	# Make sure info file still exists (i.e. the file hasn't been disposed of).
	return unless -e "$self->{dir}/$self->{tmpFile}";

	return $self->{realFileName};
}

=head3 fileHandle

Return a file handle pointing to the uploaded file suitable for reading, or an
undefined value if the upload is not valid.

=cut

sub fileHandle {
	my ($self) = @_;

	my $filePath = path($self->{dir})->child($self->{tmpFile});

	# Make sure file still exists (i.e. the file hasn't been disposed of).
	return unless -e $filePath;

	my $fh = $filePath->open('<') or die "failed to open upload $filePath for reading: $!";
	return $fh;
}

=head3 filePath

Return the path to the uploaded file, or an undefined value if the upload is not
valid.

If you use this, bear in mind that you must not dispose of the upload (either by
moving or deleting the uploaded file or calling the C<dispose> method). If you
wish to move the file, use the C<disposeTo> method instead.

=cut

sub filePath {
	my ($self) = @_;

	my $filePath = "$self->{dir}/$self->{tmpFile}";

	# Make sure file still exists (i.e. the file hasn't been disposed of).
	return unless -e $filePath;

	return $filePath;
}

=head3 dispose

Remove the file from the upload cache.

=cut

sub dispose {
	my ($self) = @_;

	my $dir = path($self->{dir});
	$dir->child("$self->{tmpFile}.info")->remove;
	$dir->child($self->{tmpFile})->remove;

	return;
}

=head3 disposeTo

    $upload->diposeTo($path);

Remove the file from the upload cache, and move it to C<$path>. Returns the
destination as a C<Mojo::File> object if the upload was successfully moved, or
an undefined value if the upload is not valid.

=cut

sub disposeTo {
	my ($self, $newPath) = @_;

	croak 'no path specified' unless $newPath;

	my $dir = path($self->{dir});
	$dir->child("$self->{tmpFile}.info")->remove;

	my $filePath = $dir->child($self->{tmpFile});

	# Make sure file still exists (i.e. the file hasn't been disposed of).
	return unless -e $filePath;

	return $filePath->move_to($newPath);
}

1;
