################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::PG::ImageGenerator;

=head1 NAME

WeBWorK::PG::ImageGenerator - create an object for holding bits of math
for LaTeX, and then to process them later.

=head1 SYNPOSIS

 my $imgen = new ImageGenerator; #create a image generator
 
 $imgen->initialize(\%envir); # provide basic data in preparation of image collection
 
 $imgen->add(string); # add a new LaTeX string to be processed.
                      # Should be in math mode with \( or \[
                      # It returns the html tag

 $imgen->getCount(); # Returns the number of images which have been added
 $imgen->tmpurl();   # Returns the beginning of the html path
 
 $imgen->render(); # Generates the images.  By default, we reuse old
                   # images when reasonable, unless passed a flag
                   # refresh=>'yes' (or 1)

=cut

use strict;
use warnings;

=head1 METHODS

=over

=item new

	Creates the ImageGenerator object.

=back

=cut

sub new {
	my $class = shift;
	my $self = {
		latexlines => [],
		count => 0,
		tmppath => "",
		tmpURLstart=>"",
		filenamestart=> ""
	};
	
	bless $self, $class;
}

sub initialize {
	my $self = shift;
	my $envir = shift; # pointer to problem envirment hash
	
	my $problemnum = $envir->{'probNum'};
	my $studname = $envir->{'studentLogin'};
	my $psvn = $envir->{'psvn'};
	my $setname = $envir->{'setNumber'};
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

sub getCount {
	my $self = shift;
	return($self->{count});
}

sub tmpurl {
	my $self = shift;
	return("$self->{tmpURLstart}/$self->{filenamestart}");
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
