################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Login.pm,v 1.22 2004/03/17 08:16:35 sh002i Exp $
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

package WeBWorK::ContentGenerator::FixDB;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::FixDB - prompt the user to fix a broken database.

=cut

use strict;
use warnings;
use CGI::Pretty qw();

sub title {
	return "Fix Database";
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $authz = $r->authz;
	
	my $can_fix = $authz->hasPermissions($r->param("user"), "fix_course_databases");
	my $fix_database = $r->param("fix");
	
	if ($fix_database and $can_fix) {
		# fix database
		my ($dbOK, @dbMessages) = $db->hashDatabaseOK(1); # 1 == fix
		
		# no problems found? weird. maybe it'll go away.
		if ($dbOK) {
			print CGI::p("The following problems were corrected:");
			print CGI::ul(CGI::li(\@dbMessages));
			
			print CGI::startform({-method=>"POST", -action=>$r->uri});
			
			# preserve the form data posted to the requested URI
			my @fields_to_print = grep { $_ ne "fix" } $r->param;
			print $self->hidden_fields(@fields_to_print);
			
			print CGI::submit(-name=>"continue", -value=>"Continue");
			print CGI::endform();
		} else {
			print CGI::p("Failed to fix the following problems this course's database:");
			print CGI::ul(CGI::li(\@dbMessages));
			print CGI::p("You cannot use this course with WeBWorK 2 until fixing the database.");
			
			print CGI::startform({-method=>"POST", -action=>$r->uri});
			
			# preserve the form data posted to the requested URI
			my @fields_to_print = grep { $_ ne "fix" } $r->param;
			print $self->hidden_fields(@fields_to_print);
			
			print CGI::submit(-name=>"fix", -value=>"Fix Database");
			print CGI::endform();
		}
	} else {
		# check only, don't fix
		my ($dbOK, @dbMessages) = $db->hashDatabaseOK(0); # 0 == don't fix
		
		# no problems found? weird. maybe it'll go away.
		if ($dbOK) {
			return CGI::p("FixDB was called, but no problems were found. Try reloading the page.");
		} else {
			print CGI::p("Problems were found in this course's database:");
			print CGI::ul(CGI::li(\@dbMessages));
			print CGI::p("You cannot use this course with WeBWorK 2 until fixing the database.");
			
			if ($can_fix) {
				print CGI::startform({-method=>"POST", -action=>$r->uri});
				
				# preserve the form data posted to the requested URI
				my @fields_to_print = grep { $_ ne "fix" } $r->param;
				print $self->hidden_fields(@fields_to_print);
				
				print CGI::submit(-name=>"fix", -value=>"Fix Database");
				print CGI::endform();
			} else {
				print CGI::p("You do not have permission to fix course databases.");
			}
		}
	}
	
	return "";
}

1;
