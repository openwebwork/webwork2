################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Test.pm,v 1.16 2006/07/25 23:02:12 sh002i Exp $
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

package WeBWorK::ContentGenerator::Test;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Test - Test area for monkeying around with stuff.

=cut

use strict;
use warnings;

#use CGI;
use WeBWorK::CGI;
#use WeBWorK::CGIParamShim;
use WeBWorK::Utils qw/undefstr/;

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	$self->{pwd} = $r->param("pwd") || "helloworld";
	
	print CGI::p(
		"REQUEST_METHOD is $ENV{REQUEST_METHOD}", CGI::br(),
		"CONTENT_TYPE is $ENV{CONTENT_TYPE}", CGI::br(),
		"CONTENT_LENGTH is $ENV{CONTENT_LENGTH}",
	);
	
	use Data::Dumper;
	print CGI::pre(CGI::escapeHTML(Dumper($CGI::Q)));
	
	#print CGI::start_form(-method=>"POST", -action=>$r->uri);
	my $start_form = CGI::start_form(
		-method=>"POST",
		-action=>$r->uri,
		#-enctype=>'application/x-www-form-urlencoded',
		-enctype=>'multipart/form-data',
	);
	print CGI::pre(CGI::escapeHTML($start_form));
	print $start_form;
	print $self->hidden_authen_fields;
	
	print CGI::p("before action:" . CGI::br()
		. " \$r->param('pwd')=" . (defined $r->param('pwd') ? $r->param('pwd') : "UNDEF") . CGI::br()
		. " CGI::param('pwd')=" . (defined CGI::param('pwd') ? CGI::param('pwd') : "UNDEF") . CGI::br()
		. " \$CGI::Q->{pwd}=" . (defined $CGI::Q->{pwd} ? "@{$CGI::Q->{pwd}}" : "UNDEF") . CGI::br()
		. " \$self->{pwd}=" . (defined $self->{pwd} ? $self->{pwd} : "UNDEF"));
	
	if (defined $r->param("submit") and $r->param("submit") eq "ChangePWD") {
		$self->{pwd} = $r->param("new_pwd");
		print CGI::p("pwd change requested, new pwd is ", $self->{pwd});
	}
	
	print "new_pwd: ", CGI::textfield({name=>"new_pwd",value=>$self->{pwd}}), CGI::br();
	
	print CGI::p("after action:" . CGI::br()
		. " \$r->param('pwd')=" . (defined $r->param('pwd') ? $r->param('pwd') : "UNDEF") . CGI::br()
		. " CGI::param('pwd')=" . (defined CGI::param('pwd') ? CGI::param('pwd') : "UNDEF") . CGI::br()
		. " \$CGI::Q->{pwd}=" . (defined $CGI::Q->{pwd} ? "@{$CGI::Q->{pwd}}" : "UNDEF") . CGI::br()
		. " \$self->{pwd}=" . (defined $self->{pwd} ? $self->{pwd} : "UNDEF"));
	
	my $hidden_pwd = CGI::hidden({name=>"pwd",value=>$self->{pwd}});
	print CGI::p("hidden field is being passed value=>".$self->{pwd}, CGI::br(),
		"hidden field is ", CGI::pre(CGI::escapeHTML($hidden_pwd)));
	print $hidden_pwd;
	
	print CGI::submit({name=>"submit",value=>"Refresh"});
	print CGI::submit({name=>"submit",value=>"ChangePWD"});
	
	print CGI::end_form();
	
	return "";	
}

1;
