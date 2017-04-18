################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/ProblemSets.pm,v 1.94 2010/01/31 02:31:04 apizer Exp $
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

package WeBWorK::ContentGenerator::ProblemEdit;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::ProbleEdit - Allows a user to save/restore state for a problem

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;

sub content{
        my($self) = @_;
        my $r = $self->r;
        my $isSaveState = $r->param("isSave");
	my $problemPart = $r->param("problemPart");

	#Replaces .pg file extension with .json and adds the problemPart
        my $filePath = $r->param("filePath");
	my $fileSuffix = "xx".$problemPart."xx";
	$filePath =~ s{\.[^.]*(?:\.pg)?$}{$fileSuffix.json};
		
	# Get the JSON string and split it into an array, which will be printed into the JSON file
        if($isSaveState eq "yes"){
		my $JSONString = $r->param("JSON");
		my @parts = split(/``/, $JSONString);
		open(OUTFILE, ">", $filePath) or die "JSON file does not exist!";
		print OUTFILE "{";
		for(my $i = 0; $i < @parts; $i++){
			if($i != 0){
				print OUTFILE ", ";
			}
			my @pair = split(/~~/, $parts[$i]);
			print OUTFILE "\"".$pair[0]."\": \"".$pair[1]."\"";
		}
		print OUTFILE "}";
		close(OUTFILE);
	}
	# Get the state for restoring
	else{
		print "{";
		# Print the JSON for the form
		if(-e $filePath){
			open(my $fileHandler, "<", $filePath) or die "Could not open file '".$filePath."'";
			while(my $line = <$fileHandler>){
				chomp $line;
				print $line;
			}
			close($fileHandler);
		}
		else{
		}
		print "}";
	}
}

sub pre_header_initialize{
	my($self) = @_;
        my $r = $self->r;
	
	
}


  

1;
