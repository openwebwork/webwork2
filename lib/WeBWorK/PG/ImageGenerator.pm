################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::PG::ImageGenerator;

=head1 NAME

WeBWorK::PG::ImageGenerator - create an object for holding bits of math for
LaTeX, and then to process them all at once.

=head1 SYNPOSIS

FIXME: add this

=cut

use strict;
use warnings;
use WeBWorK::PG::EquationCache;
use WeBWorK::Utils qw(readDirectory makeTempDirectory removeTempDirectory);

use constant PREAMBLE => <<'EOF';
\documentclass[12pt]{article}
\nonstopmode
\usepackage{amsmath,amsfonts,amssymb}
\def\gt{>}
\def\lt{<}
\usepackage[active,textmath,displaymath]{preview}
\begin{document}
EOF
use constant POSTAMBLE => <<'EOF';
\end{document}
EOF
use constant DVIPNG_ARGS => join " ", qw(
-x4000.5
-bgTransparent
-Q6
-mode toshiba
-D180
);

=head1 METHODS

=over

=item new

Returns a new ImageGenerator object. C<%options> must contain the following
entries:

 tempDir  => directory in which to create temporary processing directory
 dir	  => directory for resulting files
 url	  => url to directory for resulting files
 basename => base name for image files
 latex    => path to latex binary
 dvipng   => path to dvipng binary

C<%options> may also contain the following entries:

 useCache => boolean, whether to use global image cache
 cacheDir => directory for resulting files
 cacheURL => url to imageCacheDir
 cacheDB  => path to cache database file

If C<useCache> is true, then C<basename> is ignored, and C<cacheDir>
and C<cacheURL> override C<dir> and C<url>, respectively.

=cut

sub new {
	my ($invocant, %options) = @_;
	my $class = ref $invocant || $invocant;
	my $self = {
		names   => [],
		strings => [],
		%options,
	};
	
	if ($self->{useCache}) {
		$self->{dir} = $self->{cacheDir};
		$self->{url} = $self->{cacheURL};
		$self->{basename} = "";
		$self->{equationCache} = WeBWorK::PG::EquationCache->new(cacheDB => $self->{cacheDB});
	}
	
	bless $self, $class;
}

=item add($string, $mode)

Adds the equation in C<$string> to the object. C<$mode> can be "display" or
"inline". If not specified, "inline" is assumed. Returns the proper HTML tag
for displaying the image.

=cut

sub add {
	my ($self, $string, $mode) = @_;
	
	my $names    = $self->{names};
	my $strings  = $self->{strings};
	my $dir      = $self->{dir};
	my $url      = $self->{url};
	my $basename = $self->{basename};
	my $useCache = $self->{useCache};
	
	# if the string came in with delimiters, chop them off and set the mode
	# based on whether they were \[ .. \] or \( ... \). this means that if
	# the string has delimiters, the mode *argument* is ignored.
	if ($string =~ s/^\\\[(.*)\\\]$/$1/s) {
		$mode = "display";
	} elsif ($string =~ s/^\\\((.*)\\\)$/$1/s) {
		$mode = "inline";
	}
	# otherwise, leave the string and the mode alone.
	
	# assume that a bare string with no mode specified is inline
	$mode ||= "inline";
	
	# now that we know what mode we're dealing with, we can generate a "real"
	# string to pass to latex
	my $realString = ($mode eq "display")
		? '\(\displaystyle{' . $string . '}\)'
		: '\(' . $string . '\)';
	
	# determine what the image's "number" is
	my $imageNum = ($useCache)
		? $self->{equationCache}->lookup($realString)
		: @$strings + 1;
	
	# get the full file name of the image
	my $imageName = ($basename)
		? "$basename.$imageNum.png"
		: "$imageNum.png";
	
	# store the full file name of the image, and the "real" tex string to the object
	push @$names, $imageName;
	push @$strings, $realString;
	#warn "ImageGenerator: added string $realString with name $imageName\n";
	
	# ... and the full URL.
	my $imageURL = "$url/$imageName";
	
	my $imageTag  = ($mode eq "display")
		? " <div align=\"center\"><img src=\"$imageURL\" align=\"middle\" alt=\"$string\"></div> "
		: " <img src=\"$imageURL\" align=\"middle\" alt=\"$string\"> ";
	
	return $imageTag;
}

=item render(%options)

Uses LaTeX and dvipng to render the equations stored in the object. If the key
"mtime" in C<%options> is given, its value will be interpreted as a unix date
and compared with the modification date on any existing copy of the first image
to be generated. It is recommended that the modification time of the source
file from which the equations originate be used for this value. If the key
"refresh" in C<%options> is true, images will be regenerated regardless of when
they were last modified. If neither option is supplied, "refresh" is assumed.

=cut

sub render {
	my ($self, %options) = @_;
	
	my $tempDir  = $self->{tempDir};
	my $dir      = $self->{dir};
	my $basename = $self->{basename};
	my $latex    = $self->{latex};
	my $dvipng   = $self->{dvipng};
	my $names    = $self->{names};
	my $strings  = $self->{strings};
	
	my $mtime   = $options{mtime};
	my $refresh = $options{refresh} || ! defined $mtime;
		# must refresh if no mtime is given
	
	#unless ($refresh) {
	#	#my $firstImage = "$dir/$basename.1.png";
	#	my $firstImage = "$dir/" . $names->[0];
	#	if (-e $firstImage) {
	#		# return if first image newer than $mtime
	#		return if (stat $firstImage)[9] >= $mtime;
	#	}
	#}
	
	# determine which images need to be generated
	my (@newStrings, @newNames);
	for (my $i = 0; $i < @$strings; $i++) {
		my $string = $strings->[$i];
		my $name = $names->[$i];
		if (-e "$dir/$name") {
			#warn "ImageGenerator: found a file named $name, skipping string $string\n";
		} else {
			#warn "ImageGenerator: didn't find a file named $name, including string $string\n";
			push @newStrings, $string;
			push @newNames, $name;
		}
	}
	
	return unless @newStrings; # Don't run latex if there are no images to generate
	
	# create temporary directory in which to do TeX processing
	my $wd = makeTempDirectory($tempDir, "ImageGenerator");
	
	# store equations in a tex file
	my $texFile = "$wd/equation.tex";
	open my $tex, ">", $texFile
		or die "failed to open file $texFile for writing: $!";
	print $tex PREAMBLE;
	print $tex "$_\n" foreach @newStrings;
	print $tex POSTAMBLE;
	close $tex;
	
	# call LaTeX
	my $latexCommand  = "cd $wd && $latex equation > latex.out 2> latex.err";
	my $latexStatus = system $latexCommand;
	warn "$latexCommand returned non-zero status $latexStatus: $!"
		if $latexStatus;
	warn "$latexCommand failed to generate a DVI file"
		unless -e "$wd/equation.dvi";
	
	# call dvipng
	my $dvipngCommand = "cd $wd && $dvipng " . DVIPNG_ARGS . " equation > dvipng.out 2> dvipng.err";
	my $dvipngStatus = system $dvipngCommand;
	#warn "$dvipngCommand returned non-zero status $dvipngStatus: $!"
	#	if $dvipngStatus;
	
	# move/rename images
	foreach my $image (readDirectory($wd)) {
		# only work on equation#.png files
		next unless $image =~ m/^equation(\d+)\.png$/;
		
		# get image number from above match
		my $imageNum = $1;
		
		#warn "ImageGenerator: found generated image $imageNum with name $newNames[$imageNum-1]\n";
		
		# move/rename image
		#my $mvCommand = "cd $wd && /bin/mv $wd/$image $dir/$basename.$imageNum.png";
		my $mvCommand = "cd $wd && /bin/mv $wd/$image $dir/" . $newNames[$imageNum-1];
		my $mvStatus = system $mvCommand;
		warn "$mvCommand returned non-zero status $mvStatus: $!"
			if $mvStatus;
	}
	
	# remove temporary directory (and its contents)
	removeTempDirectory($wd);
}

1;
