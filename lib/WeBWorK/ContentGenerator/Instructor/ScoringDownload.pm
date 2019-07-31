################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/ScoringDownload.pm,v 1.7 2006/07/12 04:36:07 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor::ScoringDownload;
use base qw(WeBWorK::ContentGenerator::Instructor);
use WeBWorK::ContentGenerator::Instructor::FileManager;

=head1 NAME
 
WeBWorK::ContentGenerator::Instructor::ScoringDownload - Download scoring data files

=cut

use strict;
use warnings;

sub pre_header_initialize {
	my ($self) = @_;
	my $r          = $self->r;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $scoringDir = $ce->{courseDirs}->{scoring};
	my $file       = $r->param('getFile');
	my $user       = $r->param('user');
	

 # the parameter 'getFile" needs to be sanitized. (see bug #3793 )
 # See checkName in FileManager.pm for a more complete sanitization.
  	if ($authz->hasPermissions($user, "score_sets")) {
 		unless ( $file eq  WeBWorK::ContentGenerator::Instructor::FileManager::checkName($file) ) {  #
			$self->addbadmessage($r->maketext("Your file name is not valid! "));
		    $self->addbadmessage($r->maketext("A file name cannot begin with a dot, it cannot be empty, it cannot contain a " .
				 "directory path component and only the characters -_.a-zA-Z0-9 and space are allowed.")
			); 
 		} else {
 			$self->reply_with_file("text/comma-separated-values", "$scoringDir/$file", $file, 0); 
 			# 0==don't delete file after downloading
 		}	
 	} else {
		$self->addbadmessage("You do not have permission to access scoring data.");
	}
}

1;

__END__

# FIXME replace all crap with a call to reply_with_file
# FIXME and then maybe merge that functionality into Scoring.pm
sub header {
	my ($self)     = @_;
	my $r          = $self->r;
	my $ce         = $r->ce;
	my $scoringDir = $ce->{courseDirs}->{scoring};
	my $file       = $r->param('getFile');
	if (-f "$scoringDir/$file") {
		$r->content_type('text/comma-separated-values');
		$r->header_out("Content-Disposition" => "attachment; filename=$file;");
		$r->send_http_header();
		return OK;
	} else {
		$self->{noContent} = 1;
		return NOT_FOUND;
	}
}

sub content {
	my ($self)     = @_;
	my $r          = $self->r;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $scoringDir = $ce->{courseDirs}->{scoring};
	my $user       = $r->param('user');
	
	if (!$authz->hasPermissions($user, "score_sets")) {
		print "You do not have permission to access scoring data";
	} else {
		my $file = $r->param('getFile');
		open my $fh, "<:utf8", "$scoringDir/$file";
		print while (<$fh>);
		close $fh;
	}
}

1;
