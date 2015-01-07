#!/usr/local/bin/perl -w 

# Copyright (C) 2002 Michael Gage 

###############################################################################
# Web service which translates TeX to pdf or to HTML
###############################################################################

#use lib '/home/gage/webwork/pg/lib';
#use lib '/home/gage/webwork/webwork-modperl/lib';

package WebworkWebservice::MathTranslators;
use WebworkWebservice;
use base qw(WebworkWebservice); 

use strict;
use sigtrap;
use Carp;
use WWSafe;
#use Apache;
use WeBWorK::PG::Translator;
use WeBWorK::PG::IO;
use Benchmark;
use MIME::Base64 qw( encode_base64 decode_base64);



our $WW_DIRECTORY = $WebworkWebservice::WW_DIRECTORY;
our $PG_DIRECTORY = $WebworkWebservice::PG_DIRECTORY;
our $COURSENAME   = $WebworkWebservice::COURSENAME;
our $HOST_NAME    = $WebworkWebservice::HOST_NAME;

our $ce           =$WebworkWebservice::SeedCE;
# create a local course environment for some course
    $ce           = WeBWorK::CourseEnvironment->new({webwork_dir=>$WW_DIRECTORY, courseName=> $COURSENAME});



my $debugOn 	=	1; 
my $PASSWORD 	= 	$WebworkWebservice::PASSWORD;


my $TEMPDIRECTORY 				= 	$ce->{webworkDirs}->{htdocs_temp};
my $TEMP_BASE_URL 				= 	$ce->{webworkURLs}->{htdocs_temp};
my $externalLatexPath 			= 	$ce->{externalPrograms}->{latex};
# my $externalDvipsPath 			= 	$Global::externalDvipsPath;
my $externalpdflatexPath 		= 	$ce->{externalPrograms}->{pdflatex};;
# my $externalGsPath 				= 	$Global::externalGsPath;


# variables formerly set in Global
	$Global::tmp_directory_permission = 0775; 
	$Global::numericalGroupID='100';  # group ID for wwdev

my $tmp_directory_permission 	= 	$Global::tmp_directory_permission; 
my $numericalGroupID			=	$Global::numericalGroupID;  # group ID for webadmin

sub tex2pdf {
	my $self    =   shift;
	my $rh 		= 	shift;
	local($|)	=	1;
	my $out 	= 	{};
	unless ($rh->{pw} eq $PASSWORD ) {
		$out->{error}	=	404;
		return($out);
	}
	#obtain the path to the file
	my $filePath 		= 	$rh->{fileName};
	my @pathElements 	= 	split("/", $filePath);
	
	# grab the last element as the fileName
	#remove the extension from the file name
	my $fileName 	= 	pop @pathElements;    
 	$fileName 		=~ 	s/\.pg$//;
 	
 	#Create the full url and the full directory path -- If pathElements is empty this can give an extra //? Should I worry? maybe
	my $url 			 = 	$TEMP_BASE_URL. join("/",@pathElements);
	$url				.= 	'/' unless $url =~ m|/$|;   # only add / if it is needed.
	$url				.= 	"$fileName.pdf";
	my $texFileBasePath  = 	$TEMPDIRECTORY.join("/",@pathElements); 
	$texFileBasePath 	.=	'/' unless $texFileBasePath =~ m|/$|;
	$texFileBasePath 	.= "$fileName";
	
	# create the intermediate directories if they don't exists
	# create a dummy .pdf file
	surePathToTmpFile2($texFileBasePath.'.pdf');
#	my $filePermission = '0775';
#	chmod("$filePermission","$texFileBasePath.pdf") 
#	     or die "Can't change file permissions on $texFileBasePath.pdf to $filePermission";
	
	# Decode and cleanup the tex string
	my $texString = decode_base64(  $rh->{'texString'});
	#Make sure the line endings are correct
	$texString=~s/\r\n/\n/g;
	$texString=~s/\r/\n/g;
	
	# Make sure that TeX is run in batchmode so that the tex program doesn't hang on errors
	$texString = "\\batchmode\n".$texString;  # force errors to log.
	
	# Remove any old files
	unlink("$texFileBasePath.tex","$texFileBasePath.dvi","$texFileBasePath.log","$texFileBasePath.aux",
	       "$texFileBasePath.ps","$texFileBasePath.pdf");
	# Create the texfile of the problem.
	local(*TEX);
	open(TEX,"> $texFileBasePath.tex") or die "Can't open $texFileBasePath.tex to store tex code";
	local($/)=undef;
	print TEX $texString;
	close(TEX);	
	
	
	# my $dviCommandLine = "$externalLatexPath $texFileBasePath.tex";# >/dev/null 2>/dev/null";
	# my $psCommandLine = "$externalDvipsPath -o $texFileBasePath.ps $texFileBasePath.dvi >/dev/null";# 2>/dev/null";
	# my $pdfCommandLine = "$externalGsPath -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=$texFileBasePath.pdf -c save pop -f $texFileBasePath.ps";
	# print "dviCommandLine:  $dviCommandLine\n";
	# print "psCommandLine:   $psCommandLine\n";
	# print "pdfCommandLine:  $pdfCommandLine\n";
    #print "execute pdflatex", `$externalpdflatexPath $texFileBasePath.tex`, "\n";
    #print "done $externalpdflatexPath   $texFileBasePath.tex\n";
	# Change to the working directory and create the pdf files.
	my $wd = $TEMPDIRECTORY.join("/",@pathElements); # working directory
	# print "---cd $wd &&  $externalpdflatexPath $fileName.tex\n";
	
	system "cd $wd &&  $externalpdflatexPath $fileName.tex >>$fileName.log";
	chmod 0777, "$texFileBasePath.pdf";
	unless ($debugOn) {
		unlink("$texFileBasePath.tex","$texFileBasePath.log","$texFileBasePath.aux",
	       );
	}
 	return({pdfURL => $url});




}

sub surePathToTmpFile2 {  # constructs intermediate directories if needed beginning at ${Global::htmlDirectory}tmp/
               # the input path must be either the full path, or the path relative to this tmp sub directory
         my $path      = shift;
         my $delim    = getDirDelim();
         my $tmpDirectory = $TEMPDIRECTORY;
    # if the path starts with $tmpDirectory (which is permitted but optional) remove this initial segment
    print "Original path $path\n";
        $path =~ s|^$tmpDirectory|| if $path =~ m|^$tmpDirectory|;
        $path = convertPath($path);
        print "Creating path to $path using $delim\n";
    # find the nodes on the given path
        my @nodes     = split("$delim",$path);
    # create new path
        $path   = convertPath("$tmpDirectory");
		print  "Creating path: $path\n ";
        while (@nodes>1 ) {
            
            $path = convertPath($path . shift (@nodes) ."/");
            print  "Creating path: $path\n ";
            unless (-e $path) {
            #   system("mkdir $path");
                createDirectory($path,$tmp_directory_permission, $numericalGroupID) ||
                die "Failed to create directory $path";

            }

        }
        $path = convertPath($path . shift(@nodes));
        print  "Creating path: $path\n ";
       # system(qq!echo "" > $path! );

$path;

}


sub pretty_print_rh {
	my $rh = shift;
	my $out = "";
	my $type = ref($rh);
	if ( ref($rh) =~/HASH/ ) {
 		foreach my $key (sort keys %{$rh})  {
 			$out .= "  $key => " . pretty_print_rh( $rh->{$key} ) . "\n";
 		}
	} elsif ( ref($rh) =~ /SCALAR/ ) {
		$out = "scalar reference ". ${$rh};
	} elsif ( ref($rh) =~/Base64/ ) {
		$out .= "base64 reference " .$$rh;
	} else {
		$out =  $rh;
	}
	if (defined($type) ) {
		$out .= "type = $type \n";
	}
	return $out;
}


1;
