################################################################################
# WeBWorK Online Homework Delivery System
# Copyright <A9> 2000-2004 The WeBWorK Project, http://openwebwork.sf.net/
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

package WeBWorK::Utils::ListingDB;

use strict;
use DBI;

BEGIN
{
  require Exporter;
  use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

  $VERSION		=1.0;
  @ISA			=qw(Exporter);
  @EXPORT	=qw(
	&createListing &updateListing &deleteListing &getAllChapters &getAllSections
    &searchListings &getAllListings &getSectionListings
	);
  %EXPORT_TAGS		=();
  @EXPORT_OK		=qw();
}
use vars @EXPORT_OK;


sub getDB {
  my $ce = shift;
  my $dbinfo = $ce->{dbLayouts}->{sql}->{problem_library_classify};
  my $dbh = DBI->connect_cached($dbinfo->{source}, 
        $dbinfo->{params}->{usernameRO}, $dbinfo->{params}->{passwordRO});
  die "Cannot connect to problem library database" unless $dbh;
  return($dbh);
}

##############################################################################
# input expected: keywords,<keywords>,chapter,<chapter>,section,<section>,path,<path>,filename,<filename>,author,<author>,instituition,<instituition>,history,<history>
sub createListing
  {
    my $ce = shift;
    my %listing_data = @_; 
    my $classify_id;
    my $dbh = getDB($ce);
 #   my $dbh = WeBWorK::ProblemLibrary::DB::getDB();
    my $query = "INSERT INTO classify
		(filename,chapter,section,keywords)
		VALUES
		($listing_data{filename},$listing_data{chapter},$listing_data{section},$listing_data{keywords})";
	$dbh->do($query);    #TODO: watch out for comma delimited keywords, sections, chapters!

    $query = "SELECT id FROM classify WHERE filename = $listing_data{filename}";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    if ($sth->rows())
    {
        ($classify_id) = $sth->fetchrow_array;
    }
    else
    {
        #print STDERR "ListingDB::createListingPGfiles: $listing_data{filename} failed insert into classify table";
        return 0;
    };

    $query = "INSERT INTO pgfiles
   (
   classify_id,
   path,
   author,
   institution,
   history
   )
   VALUES
  (
   $classify_id,
   $listing_data{path},
   $listing_data{author},
   $listing_data{institution},
   $listing_data{history}
   )";
 
   $dbh->do($query);
   return 1;
  }

##############################################################################
# input expected any pair of: keywords,<keywords data>,chapter,<chapter data>,section,<section data>,filename,<filename data>,author,<author data>,instituition,<instituition data>
# returns an array of hash references
sub searchListings
{
    my $ce = shift;
    my %searchterms = @_;
    #print STDERR "ListingDB::searchListings  input array @_\n";
    my @results;
    my ($row,$key);
    my $dbh = getDB($ce);
    my $query = "SELECT c.filename, p.path
        FROM classify c, pgfiles p
        WHERE c.id = p.classify_id";
    foreach $key (keys %searchterms) {
        $query .= " AND c.$key = $searchterms{$key}";
    };
    my $sth = $dbh->prepare($query);
    $sth->execute();
    if ($sth->rows())
    {
        while (1)
        {
            $row = $sth->fetchrow_hashref();
            if (!defined($row))
            {
	            last;
            }
            else
            {
	            #print STDERR "ListingDB::searchListings(): found $row->{id}\n";
	            my $listing = $row;
	            push @results, $listing;
             }
        }
    }
    return @results;
}
##############################################################################
# returns a list of chapters
sub getAllChapters
  {
    #print STDERR "ListingDB::getAllChapters\n";
    my $ce = shift;
    my @results=();
    my ($row,$listing);
    my $query = "SELECT DISTINCT chapter FROM classify";
    my $dbh = getDB($ce);
    my $sth = $dbh->prepare($query);
    $sth->execute();
    while (1)
    {
        $row = $sth->fetchrow_array;
        if (!defined($row))
        {
            last;
        }
        else
        {
            my $listing = $row;
            push @results, $listing;
            #print STDERR "ListingDB::getAllChapters $listing\n";
         }
    }
    return @results;
  }
##############################################################################
# input chapter
# returns a list of sections
sub getAllSections
  {
    #print STDERR "ListingDB::getAllSections\n";
    my $ce = shift;
    my $chapter = shift;
    my @results=();
    my ($row,$listing);
    my $query = "SELECT DISTINCT section FROM classify
				WHERE chapter = \'$chapter\'";
    my $dbh = getDB($ce);
    my $sth = $dbh->prepare($query);
    $sth->execute();
    while (1)
    {
        $row = $sth->fetchrow_array;
        if (!defined($row))
        {
            last;
        }
        else
        {
            my $listing = $row;
            push @results, $listing;
            #print STDERR "ListingDB::getAllSections $listing\n";
         }
    }
    return @results;
  }

##############################################################################
# returns an array of hash references
sub getAllListings
{
    #print STDERR "ListingDB::getAllListings\n";
    my $ce = shift;
    my @results;
    my ($row,$key);
    my $dbh = getDB($ce);
    my $query = "SELECT c.*, p.path
        	FROM classify c, pgfiles p
    		WHERE c.pgfiles_id = p.pgfiles_id";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    while (1)
    {
        $row = $sth->fetchrow_hashref();
        if (!defined($row))
        {
            last;
        }
        else
        {
            my $listing = $row;
            push @results, $listing;
            #print STDERR "ListingDB::getAllListings $listing\n";
         }
    }
    return @results;
}
##############################################################################
# input chapter, section
# returns an array of hash references.
# if section is omitted, get all from the chapter
sub getSectionListings
  {
    #print STDERR "ListingDB::getSectionListings(chapter,section)\n";

    my $ce = shift;
    my $chap = shift;
    my $sec = shift;


    my $chapstring = '';
    if($chap) {
      $chap =~ s/'/\\'/g;
      $chapstring = " c.chapter = \'$chap\' AND ";
    }
    my $secstring = '';
    if($sec) {
      $sec =~ s/'/\\'/g;
      $secstring = " c.section = \'$sec\' AND ";
    }

    my @results; #returned
    my $query = "SELECT c.*, p.path
	FROM classify c, pgfiles p
	WHERE $chapstring $secstring c.pgfiles_id = p.pgfiles_id";
    my $dbh = getDB($ce);
    my $sth = $dbh->prepare($query);
    
    $sth->execute();
    while (1)
      {
        my $row = $sth->fetchrow_hashref();
        if (!defined($row))
        {
            last;
        }
        else
        {
            push @results, $row;
            #print STDERR "ListingDB::getSectionListings $row\n";
         }
    }
    return @results;
  }

###############################################################################
# INPUT:
#  listing id number
# RETURN:
#  1 = all ok
#
# not implemented yet
sub deleteListing
{
    my $ce = shift;
 my $listing_id = shift;
 #print STDERR "ListingDB::deleteListing(): listing == '$listing_id'\n";

 my $dbh = getDB($ce);

 return undef;

}

##############################################################################
1;

__END__

=head1 DESCRIPTION

This module provides access to the database of classify in the
system. This includes the filenames, along with the table of
search terms.

=head1 FUNCTION REFERENCE

=over 4

=item $result = createListing( %listing_data );

Creates a new listing populated with data from %listing_data. On
success, 1 is returned, 0 is returned on failure. The %listing_data
hash has the following format:
=cut

=head1 AUTHOR

Written by Bill Ziemer.
Modified by John Jones.

=cut


##############################################################################
# end of ListingDB.pm
##############################################################################
