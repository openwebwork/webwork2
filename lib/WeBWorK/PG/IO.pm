################################################################################
# WeBWorK mod-perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::PG::IO;

use strict;
use warnings;
use Exporter;
use GD;

our @ISA = qw(Exporter);
our @EXPORT = (
	#'REMOTE_HOST',             # replaced with a problem envir. variable
	#'REMOTE_ADDR',             # replaced with a problem envir. variable
	'includePGtext',
	#'send_mail_to',            # moved to IO.pl
	'read_whole_problem_file',
	'read_whole_file',
	'convertPath',
	'getDirDelim',
	#'getCourseTempDirectory',  # moved to IO.pl
	#'surePathToTmpFile',       # moved to IO.pl
	'fileFromPath',
	'directoryFromPath',
	'createFile',
	'createDirectory',
	'getImageDimmensions',
);


=head1 Private functions (not methods) used by PGtranslator for file IO.

=head2 includePGtext

	includePGtext($string_ref, $envir_ref)

Calls C<createPGtext> recursively with the $safeCompartment variable set to 0
so that the rendering continues in the current safe compartment.  The output
is the same as the output from createPGtext. This is used in processing
some of the sample CAPA files.

=cut

sub includePGtext  {
	my $evalString = shift;
	if (ref($evalString) eq 'SCALAR') {
		$evalString = $$evalString;
	} 
	$evalString =~ s/\nBEGIN_TEXT/TEXT\(EV3\(<<'END_TEXT'\)\);/g;
	$evalString =~ s/\\/\\\\/g; # \ can't be used for escapes because of TeX conflict
	$evalString =~ s/~~/\\/g;   # use ~~ as escape instead, use # for comments
	no strict;
	eval("package main; $evalString") ;
	my $errors = $@;
	die eval(q! "ERROR in included file:\n$main::envir{probFileName}\n $errors\n"!) if $errors;
	use strict;
	return "";
}

=head2   read_whole_problem_file

	read_whole_problem_file($filePath);

	Returns: A reference to a string containing
	         the contents of the file.

Don't use for huge files. The file name will have .pg appended to it if it doesn't
already end in .pg.  Files may become double spaced.?  Check the join below. This is 
used in importing additional .pg files as is done in the 
sample problems translated from CAPA.

=cut

sub read_whole_problem_file {
	my $filePath = shift;
	$filePath =~s/^\s*//; # get rid of initial spaces
	$filePath =~s/\s*$//; # get rid of final spaces
	$filePath = "$filePath.pg" unless $filePath =~ /\.pg$/;
	read_whole_file($filePath);
}

sub read_whole_file {
	my $filePath = shift;
	local (*INPUT);
	open(INPUT, "<$filePath") || die "$0: readWholeProblemFile subroutine: <BR>Can't read file $filePath";
	local($/)=undef;
	my $string = <INPUT>;  # can't append spaces because this causes trouble with <<'EOF'   \nEOF construction
	close(INPUT);
	\$string;
}

=head2 convertPath

	$path = convertPath($path);

Normalizes the delimiters in the path using delimiter from C<&getDirDelim()>
which is defined in C<Global.pm>.

=cut

sub convertPath {
    return wantarray ? @_ : shift;
}

# hacks to make this program work independent of Global.pm
sub getDirDelim {
	return ("/");
}

=head2 fileFromPath

	$fileName = fileFromPath($path)

Defined in C<FILE.pl>.

Uses C<&getDirDelim()> to determine the path delimiter.  Returns the last segment
of the path (after the last delimiter.)

=cut

sub fileFromPath {
	my $path = shift;
	my $delim =&getDirDelim();
	$path =  convertPath($path);
	$path =~  m|([^$delim]+)$|;
	$1;
} 

=head2 directoryFromPath


	$directoryPath = directoryFromPath($path)

Defined in C<FILE.pl>.

Uses C<&getDirDelim()> to determine the path delimiter.  Returns the initial segments
of the of the path (up to the last delimiter.)

=cut
   
sub directoryFromPath {
	my $path = shift;
	my $delim =&getDirDelim();
	$path = convertPath($path);
	$path =~ s|[^$delim]*$||;
	$path;
}

=head2 createFile

	createFile($filePath);

Calls C<FILE.pl> version of createFile with
C<createFile($filePath,0660(permission),$Global::numericalGroupID)>

=cut

sub createFile {
	my ($fileName, $permission, $numgid) = @_;
	open(TEMPCREATEFILE, ">$fileName")
		or die "Can't open $fileName: $!";
	my @stat = stat TEMPCREATEFILE;
	close(TEMPCREATEFILE);
	
	## if the owner of the file is running this script (e.g. when the file is first created)
	## set the permissions and group correctly
	if ($< == $stat[4]) {
		my $tmp = chmod($permission,$fileName)
			or warn "Can't do chmod($permission, $fileName): $!";
		chown(-1,$numgid,$fileName)
			or warn "Can't do chown($numgid, $fileName): $!";
	}
}

sub createDirectory {
	my ($dirName, $permission, $numgid) = @_;
	mkdir($dirName, $permission)
		or warn "Can't do mkdir($dirName, $permission): $!";
	chmod($permission, $dirName)
		or warn "Can't do chmod($permission, $dirName): $!";
	unless ($numgid == -1) {
		chown(-1,$numgid,$dirName)
			or warn "Can't do chown(-1,$numgid,$dirName): $!";
	}
}

=head2 getImageDimmensions

(height, width) = getImageDimmensions(imagePath)

Returns the height and width of an image, given a path the the image file. Uses GD

=cut

sub getImageDimmensions($) {
	my $imageName = shift;
	my $image = GD::Image->new($imageName);
	my ($width, $height) = $image->getBounds();
	return ($height, $width);
}

1;
