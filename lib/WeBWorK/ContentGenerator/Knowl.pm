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

package WeBWorK::ContentGenerator::Knowl;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Knowl - Allows a user to access and modify their knowl information

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;

sub content{
	my($self) = @_;
    my $r = $self->r;
	my $effectiveUser = $r->param("effectiveUser");
	my $word = $r->param("word");
	my $definition = $r->param("definition");
	#Splits multiple knowls into an array.
	my @words = split/@/, $word;
	my @defs = split/@/, $definition;
	#Creates new key for database hash.
	#my $wordSize = scalar @words;
	#my $defSize = scalar @defs; 
	#Create Hash table(Database) with key = "effectiveUser word" and value = definition.
	my %database;
	my $dbKey;
	#Read plain text file and fill in hash table.
	my $filename = "/opt/webwork/courses/knowlDB.txt";
	if(-e $filename){
		open(my $fh, "<:encoding(UTF-8)", $filename);
		while(my $row = <$fh>){
			chomp $row;
			($dbKey, $definition) = split/``/, $row;
			$database{$dbKey} = $definition;
		}
	}
	#Overwrites common key in hash with new key and definition.
	foreach my $i (0..$#words){
		$dbKey = $effectiveUser." " .$words[$i];
		$definition = $defs[$i];
		$database{$dbKey} = $definition;
	}
	# Search for keys in hash
	my $search = $r->param("search");
	my @searches = split/@/, $search;
	#my $searchSize = scalar @searches;
	print "{";
	my $count = 0;
	foreach my $i (0..$#searches){
		$dbKey = $effectiveUser." ".$searches[$i];
		if($count != 0){
			print ", ";
		}
		# Print the value if the search yields results
		if (exists $database{$dbKey}){
			# Escape the backslash
			#$parts[$i] =~ s/\\/\\\\/g;
			#$parts[$i] =~ s/\\/\\\\/g;
			# Escape the double-quote
			#$parts[$i] =~ s/\"/\\\"/g;
			#$parts[$i] =~ s/\"/\\\"/g;
			print "\"".$searches[$i]."\": \"".$database{$dbKey}."\"";
			$count = $count + 1;
		}
	}
	print "}";



	#Write database hash to plain text file if there were changes.
	open(my $fh1, '>', $filename) or die "Could not open '$filename' $!";
	for $dbKey(sort keys%database){
		print $fh1 $dbKey . "``". $database{$dbKey}. "\n";
	}
	close $fh1;

}

sub pre_header_initialize{
	
}


  

1;
