################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-1307 The WeBWorK Project, http://openwebwork.sf.net/
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


###########################
# Utils::LibrarySTats
#
# This is an interface for getting statistics about library problems
# for display 
###########################

package WeBWorK::Utils::LibraryStats;

use base qw(Exporter);
use strict;
use warnings;
use DBI;

our @EXPORT    = ();
our @EXPORT_OK = qw();

sub new {
    my $class = shift;
    my $ce = shift;

    my $dbh = DBI->connect(
	$ce->{problemLibrary_db}->{dbsource},
	$ce->{problemLibrary_db}->{user},
	$ce->{problemLibrary_db}->{passwd},
	    {
		PrintError => 0,
		RaiseError => 1,
	    },
	);
    my $selectstm = $dbh->prepare("SELECT * FROM OPL_local_statistics WHERE source_file = ?");
    
    my $self = { dbh => $dbh,
		 selectstm => $selectstm,
    };

    bless($self,$class);
    return $self;
}

sub getLocalStats {
    my $self = shift;
    my $source_file = shift;

    my $selectstm = $self->{selectstm};
    
    $selectstm->execute($source_file) 
	or die $selectstm->errstr;

    my $result = $selectstm->fetchrow_arrayref();
    
    if ($result) {
	return {source_file => $source_file,
		students_attempted => $$result[1],
		average_attempts => $$result[2],
		average_status => $$result[3],
	};
    } else {
	return {source_file => $source_file};
    }
}
    
1;
