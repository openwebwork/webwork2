################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Logout.pm,v 1.7 2003/12/09 01:12:31 sh002i Exp $
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

package WeBWorK::ContentGenerator::Logout;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Logout - invalidate key and display logout message.

=cut

use strict;
use warnings;
use CGI qw();

sub pre_header_initialize {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $cookie = Apache::Cookie->new($r,
		-name => "WeBWorKAuthentication",
		-value => "",
		-expires => "-1D",
		-domain => $r->hostname,
		-path => $ce->{webworkURLRoot},
		-secure => 0,
	);
	$r->headers_out->set("Set-Cookie" => $cookie->as_string);
}

sub title {
	return "Logout";
}

sub links {
	return "";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $userName = $r->param("user");
	
	eval { $db->deleteKey($userName) };
	if ($@) {
		print CGI::p("Something went wrong while logging out of WeBWorK: $@");
	}
	
	print CGI::p("You have been logged out of WeBWorK.");
	print CGI::start_form(-method=>"POST", -action=>"$root/$courseName/");
	print CGI::hidden("user", $userName);
	print CGI::hidden("force_passwd_authen", 1);
	print CGI::p({-align=>"center"}, CGI::submit("submit", "Log In Again"));
	print CGI::end_form();
	
	return "";
}

# This content generator is NOT logged in.
sub if_loggedin($$) {
	my ($self, $arg) = (@_);
	
	return !$arg;
}

1;
