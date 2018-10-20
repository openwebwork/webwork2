################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/Apache/AuthenWeBWorK.pm,v 1.2 2006/06/28 16:19:57 sh002i Exp $
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

package Apache::AuthenWeBWorK;

=head1 NAME

Apache::AuthenWeBWorK - Authenticate against WeBWorK::Authen framework.

=head1 CONFIGURATION

 PerlSetVar authen_webwork_root /path/to/webwork2
 PerlSetVar authen_webwork_course "some-course-id"
 PerlSetVar authen_webwork_module "WeBWorK::Authen::something"

=cut

use strict;
use warnings;
#use Apache::Constants qw(:common);
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);
use Apache2::Access ();
use Apache2::RequestUtil ();

use WeBWorK::Debug;
use WeBWorK::Request;
use WeBWorK::ContentGenerator;
use WeBWorK::DB;
use WeBWorK::Authz;
use WeBWorK::Utils qw/runtime_use/;

################################################################################

=head1 APACHE AUTHEN HANDLER

=over

=item handler($r)

=cut

sub handler($) {
	my ($apache) = @_;
	my $r = new WeBWorK::Request($apache);
	
	my ($res, $sent_pw) = $r->get_basic_auth_pw;
	return $res unless $res == Apache2::Const::OK;
	
	my $webwork_root = $r->dir_config('authen_webwork_root');
	my $webwork_course = $r->dir_config('authen_webwork_course');
	
	return fail($r, "authen_webwork_root not set")
		unless defined $webwork_root and $webwork_root ne "";
	return fail($r, "authen_webwork_course not set")
		unless defined $webwork_course and $webwork_course ne "";
	
	# FIXME most of this build-up code is yoinked from lib/WeBWorK.pm
	# needs to be factored out somehow
	# (for example, the authen module selection code probably belongs in a factory)
	
	my $ce = eval { new WeBWorK::CourseEnvironment({
		webwork_dir => $webwork_root,
		courseName => $webwork_course,
	}) };
	$@ and return fail($r, "failed to initialize the course environment: $@");
	$r->ce($ce);
	
	my $authz = new WeBWorK::Authz($r);
	$r->authz($authz);
	
	# figure out which authentication module to use
	my $user_authen_module;
	my $proctor_authen_module;
	if (ref $ce->{authen}{user_module} eq "HASH") {
		if (exists $ce->{authen}{user_module}{$ce->{dbLayoutName}}) {
			$user_authen_module = $ce->{authen}{user_module}{$ce->{dbLayoutName}};
		} else {
			$user_authen_module = $ce->{authen}{user_module}{"*"};
		}
	} else {
		$user_authen_module = $ce->{authen}{user_module};
	}
	
	runtime_use $user_authen_module;
	my $authen = $user_authen_module->new($r);
	$r->authen($authen);
	
	my $db = new WeBWorK::DB($ce->{dbLayout});
	$r->db($db);
	
	# now, here's the problem... WeBWorK::Authen looks at $r->params directly, whereas we
	# need to look at $user and $sent_pw. this is a perfect opportunity for a mixin, i think.
	my $authenOK;
	{
		no warnings 'redefine';
		local *WeBWorK::Authen::get_credentials   = \&Authen::WeBWorK::HTTPBasic::get_credentials;
		local *WeBWorK::Authen::maybe_send_cookie = \&Authen::WeBWorK::HTTPBasic::noop;
		local *WeBWorK::Authen::maybe_kill_cookie = \&Authen::WeBWorK::HTTPBasic::noop;
		local *WeBWorK::Authen::set_params        = \&Authen::WeBWorK::HTTPBasic::noop;
		
		$authenOK = $authen->verify;
	}
	
	
	debug("verify said: '$authenOK'");
	
	if ($authenOK) {
		debug("this will work!!!");
		#return OK;
		return Apache2::Const::OK;
	} else {
		#return AUTH_REQUIRED;
		return Apache2::Const::HTTP_UNAUTHORIZED;
	}
}

sub fail {
	my ($r, $msg) = @_;
		$r->note_basic_auth_failure;
		$r->log_reason($msg, $r->filename);
		#return AUTH_REQUIRED;
		return Apache2::Const::HTTP_UNAUTHORIZED;
}

=back

=cut

package Authen::WeBWorK::HTTPBasic;

use strict;
use warnings;
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);
use Apache2::Access ();
use Apache2::RequestUtil ();
#use Apache::Constants qw(:common);
use WeBWorK::Debug;

sub get_credentials {
	my ($self) = @_;
	my $r = $self->{r};
	
	my ($res, $sent_pw) = $r->get_basic_auth_pw;
	#return unless $res == OK;
	return unless $res == Apache2::Const::OK;
	my $user_id = $r->user;
	#my $user_id = $r->connection->user;
	
	#if (defined $r->connection->user) {
	if (defined $r->user) {
		$self->{user_id} = $r->user;
		$self->{password} = $sent_pw;
		$self->{credential_source} = "http_basic";
		return 1;
	}
}

sub noop {}

1;
