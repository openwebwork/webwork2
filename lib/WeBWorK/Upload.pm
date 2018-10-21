################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Upload.pm,v 1.7 2006/01/25 23:13:51 sh002i Exp $
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

Given C<$u>, an Apache::Upload object

 my $upload = WeBWorK::Upload->store($u,
 	dir => $ce->{webworkDirs}->{DATA}
 );
 my $id = $upload->id;
 my $hash = $upload->hash;

Later...

 my $upload = WeBWorK::Upload->retrieve($id, $hash,
 	dir => $ce->{webworkDirs}->{uploadCache}
 );
 my $fh = $upload->fileHandle;
 my $path = $upload->filePath;
 
 # get rid of the upload -- $upload is useless after this!
 $upload->dispose;
 
 # ...or move it somewhere before disposal
 $upload->disposeTo($path);

=head1 DESCRIPTION

WeBWorK::Upload provides a method for securely storing uploaded files until such
time as they are needed. This is useful for situations in which an upload cannot
be handled by the system until some later request, such as the case where a user
is not yet authenticated, and a login page must be returned. Since a file upload
should not be sent back to the client and then uploaded again with the user
provides his login information, some proxy must be sent in its place.
WeBWorK::Upload generates a unique ID which can be used to retrieve the original
file.

=cut

use strict;
use warnings;
use Carp qw(croak);
use Data::UUID; # this is probably overkill ;)
use Digest::MD5 qw(md5_hex);
use File::Copy qw(copy move);

=head1 STORING UPLOADS

Uploads represented as Apache::Uploads objects can be stored in an upload cache
and later retrieved, given the proper ID and hash. The hash is used to confirm
the authenticity of the ID.

=head2 CONSTRUCTOR

=over

=item store($u, %options)

Stores the Apache::Upload C<$u> securely. The following keys must be defined in
%options:

 dir => the directory in which to store the uploaded file

=cut

sub store {
	my ($invocant, $apacheUpload, %options) = @_;
	
	croak "no Apache::Upload specified" unless $apacheUpload;
	
	# generate UUID
	my $ug = new Data::UUID;
	my $uuid = $ug->create_str;
	
	# generate one-time secret
	my $secret = sprintf("%X"x4, map { int rand 2**32 } 1..4);
	
	# generate hash from $uuid and $secret
	my $hash = md5_hex($uuid, $secret);
	
	# get information about uploaded file
	my $realFileName = $apacheUpload->filename;
	my $fh = $apacheUpload->fh;
	
	my $infoName = "$uuid.info";
	my $infoPath = "$options{dir}/$infoName";
	
	my $fileName = "$uuid.file";
	my $filePath = "$options{dir}/$fileName";
	
	# write info file
	open my $infoFH, ">", $infoPath
		or die "failed to write upload info file $infoPath: $!";
	print $infoFH "$realFileName\n$secret\n";
	close $infoFH;
	
	# copy uploaded file
	copy($fh, $filePath); # the file name is a secret!
	
	return bless {
		uuid => $uuid,
		dir  => $options{dir},
		hash => $hash,
		realFileName => $realFileName,
	}, ref($invocant) || $invocant;
}

=item id

Return the upload's unique ID, or an undefiend value if the upload is not valid.

=cut

sub id {
	my ($self) = @_;
	my $uuid = $self->{uuid};
	my $dir = $self->{dir};
	
	my $infoName = "$uuid.info";
	my $infoPath = "$dir/$infoName";
	
	# make sure info file still exists (i.e. the file hasn't been disposed of)
	return unless -e $infoPath;
	
	return $uuid;
}

=item hash

Return the upload's hash, or an undefiend value if the upload is not valid.

=cut

sub hash {
	my ($self) = @_;
	my $uuid = $self->{uuid};
	my $dir = $self->{dir};
	my $hash = $self->{hash};
	
	my $infoName = "$uuid.info";
	my $infoPath = "$dir/$infoName";
	
	# make sure info file still exists (i.e. the file hasn't been disposed of)
	return unless -e $infoPath;
	
	return $hash;
}

=back

=head1 RETRIEVING UPLOADS

An upload stored in the upload cache can be retrieved by supplying its ID and
hash (accessible from the above C<id> and C<hash> methods, respectivly. The file
can then be accessed by name or file handle, moved, and disposed of.

=head2 CONSTRUCTOR

=over

=item retrieve($id, $hash, %options)

Retrieves the Apache::Upload referenced by C<$id> and C<$hash>. The following
keys must be defined in %options:

 dir => the directory in which to store the uploaded file

=cut

sub retrieve {
	my ($invocant, $uuid, $hash, %options) = @_;
	
	croak "no upload ID specified" unless $uuid;
	croak "no upload hash specified" unless $hash;
	
	my $infoName = "$uuid.info";
	my $infoPath = "$options{dir}/$infoName";
	
	my $fileName = "$uuid.file";
	my $filePath = "$options{dir}/$fileName";
	
	croak "no upload matches the ID specified" unless -e $infoPath;
	
	# get real file name and secret from info file
	open my $infoFH, "<", $infoPath
		or die "failed to read upload info file $infoPath: $!";
	my ($realFileName, $secret) = <$infoFH>;
	close $infoFH;
	
	# jesus christ
	chomp $realFileName;
	chomp $secret;
	
	# generate correct hash from $uuid and $secret
	my $correctHash = md5_hex($uuid, $secret);
	
	#warn __PACKAGE__, ": secret is $secret\n";
	#warn __PACKAGE__, ": correctHash is $correctHash\n";
	
	croak "upload hash incorrect!" unless $hash eq $correctHash;
	
	# -- you passed the test... --
	
	return bless {
		uuid => $uuid,
		dir => $options{dir},
		hash => $hash,
		realFileName => $realFileName,
	}, ref($invocant) || $invocant;
}

=back

=head2 METHODS

=over

=item filename

Returns the original name of the uploaded file.

=cut

sub filename {
	my ($self) = @_;
	my $uuid = $self->{uuid};
	my $dir = $self->{dir};
	my $realFileName = $self->{realFileName};
	
	my $infoName = "$uuid.info";
	my $infoPath = "$dir/$infoName";
	
	my $fileName = "$uuid.file";
	my $filePath = "$dir/$fileName";
	
	# make sure info file still exists (i.e. the file hasn't been disposed of)
	return unless -e $infoPath;
	
	return $realFileName;
}

=item fileHandle

Return a file handle pointing to the uploaded file, or an undefiend value if the
upload is not valid. Suitable for reading.

=cut

sub fileHandle {
	my ($self) = @_;
	my $uuid = $self->{uuid};
	my $dir = $self->{dir};
	
	my $infoName = "$uuid.info";
	my $infoPath = "$dir/$infoName";
	
	my $fileName = "$uuid.file";
	my $filePath = "$dir/$fileName";
	
	# make sure info file still exists (i.e. the file hasn't been disposed of)
	return unless -e $infoPath;
	
	open my $fh, "<", $filePath
		or die "failed to open upload $filePath for reading: $!";
	return $fh;
}

=item filePath

Return the path to the uploaded file, or an undefiend value if the upload is not
valid.

If you use this, bear in mind that you must not dispose of the upload (either by
moving or deleting the uploaded file or calling the C<dispose> method). If you
wish to move the file, use the C<disposeTo> method instead.

=cut

sub filePath {
	my ($self) = @_;
	my $uuid = $self->{uuid};
	my $dir = $self->{dir};
	
	my $infoName = "$uuid.info";
	my $infoPath = "$dir/$infoName";
	
	my $fileName = "$uuid.file";
	my $filePath = "$dir/$fileName";
	
	# make sure info file still exists (i.e. the file hasn't been disposed of)
	return unless -e $infoPath;
	
	return $filePath;
}

=item dispose

Remove the file from the upload cache. Returns true if the upload was
successfully destroyed, or an undefiend value if the upload is not valid.

=cut

sub dispose {
	my ($self) = @_;
	my $uuid = $self->{uuid};
	my $dir = $self->{dir};
	
	my $infoName = "$uuid.info";
	my $infoPath = "$dir/$infoName";
	
	my $fileName = "$uuid.file";
	my $filePath = "$dir/$fileName";
	
	# make sure info file still exists (i.e. the file hasn't been disposed of)
	return unless -e $infoPath;
	
	unlink $infoPath;
	unlink $filePath;
	
	return 1;
}

=item disposeTo($path)

Remove the file from the upload cache, and move it to C<$path>. Returns true if
the upload was successfully moved, or an undefiend value if the upload is not
valid.

=cut

sub disposeTo {
	my ($self, $newPath) = @_;
	my $uuid = $self->{uuid};
	my $dir = $self->{dir};
	
	croak "no path specified" unless $newPath;
	
	my $infoName = "$uuid.info";
	my $infoPath = "$dir/$infoName";
	
	my $fileName = "$uuid.file";
	my $filePath = "$dir/$fileName";
	
	# make sure info file still exists (i.e. the file hasn't been disposed of)
	return unless -e $infoPath;
	
	unlink $infoPath;
	move($filePath, $newPath);
}

=back

=head1 AUTHOR

Written by Sam Hathaway, sh002i at math.rochester.edu. Based on the original
WeBWorK::Upload module by Dennis Lambe, Jr., malsyned at math.rochester.edu.

=cut

1;
