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

Returns a new ImageGenerator object. <C%options> must contain the following
entries:

 tempDir  => directory in which to create temporary processing directory
 dir	  => directory for resulting files
 url	  => url to directory for resulting files
 basename => base name for image files
 latex    => path to latex binary
 dvipng   => path to dvipng binary

=cut

sub new {
	my ($invocant, %options) = @_;
	my $class = ref $invocant || $invocant;
	my $self = {
		strings => [],
		%options,
	};
	
	bless $self, $class;
}

=item add($string, $mode)

Adds the equation in C<$string> to the object. C<$mode> can be "display" or
"inline". If not specified, "inline" is assumed. Returns the proper HTML tag
for displaying the image.

=cut

sub add {
	my ($self, $string, $mode) = @_;
	
	my $strings  = $self->{strings};
	my $dir      = $self->{dir};
	my $url      = $self->{url};
	my $basename = $self->{basename};
	
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
	
	my $imageNum  = @$strings + 1;
	my $imageURL  = "$url/$basename.$imageNum.png";
	my $imageTag  = "<img src=\"$imageURL\" align=\"middle\" alt=\"$string\">";
	
	if ($mode eq "display") {
		push @$strings, '\(\displaystyle{' . $string . '}\)';
		return " <div align=\"center\">$imageTag</div> ";
	} else {
		push @$strings, '\(' . $string . '\)';
		return " $imageTag ";
	}
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
	my $strings  = $self->{strings};
	
	my $mtime   = $options{mtime};
	my $refresh = not defined $mtime || $options{refresh};
		# must refresh if no mtime is given
	
	return unless @$strings; # Don't run latex if there are no images to generate
	
	unless ($refresh) {
		my $firstImage = "$dir/$basename.1.png";
		if (-e $firstImage) {
			# return if first image newer than $mtime
			return if (stat $firstImage)[9] >= $mtime;
		}
	}
	
	# create temporary directory in which to do TeX processing
	my $wd = makeTempDirectory($tempDir, "ImageGenerator");
	
	# store equations in a tex file
	my $texFile = "$wd/equation.tex";
	open my $tex, ">", $texFile
		or die "failed to open file $texFile for writing: $!";
	print $tex PREAMBLE;
	print $tex "$_\n" foreach @$strings;
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
		
		# move/rename image
		my $mvCommand = "cd $wd && /bin/mv $wd/$image $dir/$basename.$imageNum.png";
		my $mvStatus = system $mvCommand;
		warn "$mvCommand returned non-zero status $mvStatus: $!"
			if $mvStatus;
	}
	
	# remove temporary directory (and its contents)
	removeTempDirectory($wd);
}

1;

__END__

################################################################################
# OLD VERSIONS OF SUBROUTINES
################################################################################


sub getCount {
	my $self = shift;
	return $self->{count};
}

sub tmpurl {
	my $self = shift;
	return "$self->{tmpURLstart}/$self->{filenamestart}";
}

sub initialize {
	my ($self, $envir) = @_;
	
	my $problemnum  = $envir->{'probNum'};
	my $studname    = $envir->{'studentLogin'};
	my $psvn        = $envir->{'psvn'};
	my $setname     = $envir->{'setNumber'};
	my $tmpURLstart = $envir->{'tempURL'};
	
	my $path=main::surePathToTmpFile(main::convertPath("png/$setname/$psvn/foo"));
	$path =~ s/foo$//; # remove final foo
	
	$self->{sourceFile} = $envir->{templateDirectory} . "/" . $envir->{fileName};
	$self->{tmpURLstart} = $tmpURLstart."png/$setname/$psvn";
	$self->{tmppath}=$path;
	$self->{filenamestart}="$studname-prob${problemnum}image";
}

# Add another string to list to be LaTeX'ed
# return the tag
sub add {
	my $self = shift;
	my $newstr = shift;
	my $tag = $newstr;
	$self->{count}++;
	my $tempURL= $self->tmpurl()."$self->{count}.png";

	if ($tag =~ /^\\\(/) {
		$tag =~ s|^\\\( *||;
		$tag =~ s|\\\)$||;
		$tag = qq!<img src="$tempURL" align="middle" alt="$tag">!;
	} else {
		# Displayed math comes in with \[ stuff \].  To get a good
		# bounding box through preview, we change that to \( \displaystyle{
		# stuff } \), and then center the resulting image
		$tag =~ s|^\\\[ *||;
		$tag =~ s|\\\]$||;
		$newstr = '\(\displaystyle{'.$tag.'}\)';
		$tag = qq!<div align="center"><img src="$tempURL" align="middle" alt="$tag"></div>!;
	}
	
	push @{$self->{latexlines}}, $newstr;
	return $tag;
}

sub render {
	my $self = shift;
	my %opts = @_;
	
	# Don't run latex if there are no images
	if($self->{count}==0) {
		return;
	}
	
	my $refreshMe = 0;
	if (defined($opts{refresh}) and (($opts{refresh} eq "yes") or ($opts{refresh} == 1))) {
		$refreshMe = 1;
	}

	#$refreshMe = 1;  # Uncomment for testing
	my $latexfilenamebase = $self->{tmppath} . $self->{filenamestart};

	my $sourcePath = $self->{sourceFile};
	my $tempFile = "${latexfilenamebase}" . $self->{count} . ".png"; # last image

	if ($refreshMe or not -e $tempFile or (stat $sourcePath)[9] > (stat $tempFile)[9]) {
		# image file doesn't exist, or source file is newer then image file
		# or we just want new images produced

		#my $old_cdir = `pwd`; # cd for running latex
		#chomp($old_cdir);
		chdir($self->{tmppath})
			|| warn "Could not move into temporary directory $self->{tmppath}";

		if (-e "$latexfilenamebase.tex") {
			unlink("$latexfilenamebase.tex") ||
				warn "Could not delete old LaTeX file";
		}

		local *LATEXME;
		open(LATEXME,">$latexfilenamebase.tex") || warn "Cannot create temporary tex file";
		print LATEXME <<'EOT';
\documentclass[12pt]{article}
\nonstopmode
\usepackage{amsmath,amsfonts,amssymb}
\def\gt{>}
\def\lt{<}

\usepackage[active,textmath,displaymath]{preview}
\begin{document}
EOT

		my $j;
		for $j (@{$self->{latexlines}}) {
			print LATEXME "\n$j\n";
		}

		print LATEXME '\end{document}'."\n";
		close(LATEXME);

		chmod(0666, "$latexfilenamebase.tex") || warn "Could not change permissions on $latexfilenamebase.tex";

		my $error_log = '/dev/null';		## by default do not log error messages
		$error_log = &Global::getErrorLog if $Global::imageDebugMode;

		$ENV{PATH} .= "$Global::extendedPath";
		my $dvipng_res = int($Global::dvipngScaling * 1000+0.5);
		my $cmdout="";
		
		# remove any old files using this name
		unlink("$self->{filenamestart}.dvi","$self->{filenamestart}.log",
					 "$self->{filenamestart}.aux","missfont.log");
					 
		$cmdout=system("$Global::externalLatexPath $self->{filenamestart}.tex >>$error_log 2>>$error_log");
		warn "$Global::externalLatexPath $self->{filenamestart}.tex >>$error_log 2>>$error_log -- FAILED in ImageGenerator returned $cmdout" if $cmdout;

		$cmdout=system("$Global::externalDvipngPath -x$dvipng_res -bgTransparent -Q$Global::dvipngShrinkFactor -mode $Global::dvipngMode -D$Global::dvipngDPI $self->{filenamestart}.dvi >>$error_log 2>>$error_log");
		warn "$Global::externalDvipngPath -x$dvipng_res -bgTransparent -Q$Global::dvipngShrinkFactor -mode $Global::dvipngMode -D$Global::dvipngDPI $self->{filenamestart}.dvi >>$error_log 2>>$error_log -- FAILED in ImageGenerator.pm returned $cmdout" if $cmdout !=256;
		
		unless ($Global::imageDebugMode) {
			unlink("$self->{filenamestart}.dvi","$self->{filenamestart}.log",
					 "$self->{filenamestart}.tex",
					 "$self->{filenamestart}.aux" 
			);
		}
		#chdir($old_cdir);
	}
}

1;
