################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Skeleton.pm,v 1.2 2004/03/15 21:13:06 sh002i Exp $
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

package WeBWorK::ContentGenerator::CourseAdmin;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::CourseAdmin - Add, rename, and delete courses.

=cut

use strict;
use warnings;
use CGI::Pretty qw();
use Data::Dumper;
use WeBWorK::Utils qw(cryptPassword);
use WeBWorK::Utils::CourseManagement qw(addCourse);

# SKEL: If you need to do any processing before the HTTP header is sent, do it
# in this method:
# 
#sub pre_header_initialize {
#	my ($self) = @_;
#	
#	# Do your processing here! Don't print or return anything -- store data in
#	# the self hash for later retrieveal.
#}

# SKEL: To emit your own HTTP header, uncomment this:
# 
#sub header {
#	my ($self) = @_;
#	
#	# Generate your HTTP header here.
#	
#	# If you return something, it will be used as the HTTP status code for this
#	# request. The Apache::Constants module might be useful for gerating status
#	# codes. If you don't return anything, the status code "OK" will be used.
#	return "";
#}

# SKEL: If you need to do any processing after the HTTP header is sent, but before
# any template processing occurs, or you need to calculate values that will be
# used in multiple methods, do it in this method:
# 
#sub initialize {
#	my ($self) = @_;
#	
#	# Do your processing here! Don't print or return anything -- store data in
#	# the self hash for later retrieveal.
#}

# SKEL: If you need to add tags to the document <HEAD>, uncomment this method:
# 
#sub head {
#	my ($self) = @_;
#	
#	# You can print head tags here, like <META>, <SCRIPT>, etc.
#	
#	return "";
#}

# SKEL: To fill in the "info" box (to the right of the main body), use this
# method:
# 
#sub info {
#	my ($self) = @_;
#	
#	# Print HTML here.
#	
#	return "";
#}

# SKEL: To provide navigation links, use this method:
# 
#sub nav {
#	my ($self, $args) = @_;
#	
#	# See the documentation of path() and pathMacro() in
#	# WeBWorK::ContentGenerator for more information.
#	
#	return "";
#}

# SKEL: For a little box for display options, etc., use this method:
# 
#sub options {
#	my ($self) = @_;
#	
#	# Print HTML here.
#	
#	return "";
#}

# SKEL: For a list of sibling objects, use this method:
# 
#sub siblings {
#	my ($self, $args) = @_;
#	
#	# See the documentation of siblings() and siblingsMacro() in
#	# WeBWorK::ContentGenerator for more information.
#	# 
#	# Refer to implementations in ProblemSet and Problem.
#	
#	return "";
#}

# SKEL: Okay, here's the body. Most of your stuff will go here:
# 
sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	print CGI::h2("Create a new course");
	
	my $add_step_max = 4; # the step that actually creates the course
	
	my $add_step = $r->param("add_step") || 0;
	
	my $new_courseID          = $r->param("new_courseID");
	my $new_dbLayout          = $r->param("new_dbLayout");
	my $new_skipDBCreation    = $r->param("new_skipDBCreation");
	my $new_sql_host          = $r->param("new_sql_host");
	my $new_sql_port          = $r->param("new_sql_port");
	my $new_sql_username      = $r->param("new_sql_username");
	my $new_sql_password      = $r->param("new_sql_password");
	my $new_sql_database      = $r->param("new_sql_database");
	my $new_sql_wwhost        = $r->param("new_sql_wwhost");
	my $new_gdbm_globalUserID = $r->param("new_gdbm_globalUserID");
	my $new_initial_userID    = $r->param("new_initial_userID");
	my $new_initial_password  = $r->param("new_initial_password");
	
	# "back up" if certain fields aren't filled in
	
	if ($add_step > 0) {
		$add_step = 0 if $new_courseID eq "" or $new_dbLayout eq "";
	}
	
	if ($add_step > 1 and not $new_skipDBCreation) {
		if ($new_dbLayout eq "sql") {
			$add_step = 1 if $new_sql_username eq "" or $new_sql_password eq ""
					or $new_sql_database eq "" or $new_sql_wwhost eq "";
		} elsif ($new_dbLayout eq "gdbm") {
			$add_step = 1 if $new_gdbm_globalUserID eq "";
		}
	}
	
	if ($add_step > 2) {
		$add_step = 2 if $new_initial_userID ne "" and $new_initial_password eq "";
	}
	
	my $ce2;
	if ($new_courseID) {
		$ce2 = WeBWorK::CourseEnvironment->new(
			$ce->{webworkDirs}->{root},
			$ce->{webworkURLs}->{root},
			"FAKE_PG_ROOT", # heh, there's no way to get the PG root out... damn.
			$new_courseID,
		);
	}
	
	if ($add_step >= 0 and $add_step < $add_step_max) {
		print CGI::start_form("POST", $r->uri);
		print $self->hidden_authen_fields;
		print CGI::hidden("add_step", 1);
		print CGI::table({class=>"FormLayout"},
			CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "Course Name:"),
				CGI::td(
					CGI::textfield(
						-name  => "new_courseID",
						-value => defined $new_courseID ? $new_courseID : "",
						-size  => 50,
					),
				),
			),
			CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "Database Layout:"),
				CGI::td(
					CGI::popup_menu(
						-name    => "new_dbLayout", 
						-values  => [ sort keys %{ $ce->{dbLayouts} } ],
						-default => defined $new_dbLayout ? $new_dbLayout : "",
					),
				),
			),
			CGI::Tr({class=>"ButtonRow"},
				CGI::td({colspan=>2},
					CGI::submit(
						-name => "create_course",
						-value => ($add_step > 0 ? "Change" : "Continue"),
					),
				),
			),
		);
		print CGI::end_form();
	}
	
	if ($add_step >= 1 and $add_step < $add_step_max) {
		print CGI::hr();
		
		print CGI::start_form("POST", $r->uri);
		print $self->hidden_authen_fields;
		print CGI::hidden("add_step", 2);
		
		print CGI::hidden("new_courseID", $new_courseID);
		print CGI::hidden("new_dbLayout", $new_dbLayout);
		print CGI::hidden("new_skipDBCreation", $new_skipDBCreation);
		
		# there are specific things we're doing per database layout:
		if ($new_dbLayout eq "sql") {
			{
				# find the most common SQL source (stolen from CourseManagement.pm)
				my %sources;
				foreach my $table (keys %{ $ce2->{dbLayouts}->{sql} }) {
					$sources{$ce2->{dbLayouts}->{sql}->{$table}->{source}}++;
				}
				my $source;
				if (keys %sources > 1) {
					foreach my $curr (keys %sources) {
						$source = $curr if @{ $sources{$curr} } > @{ $sources{$source} };
					}
				} else {
					($source) = keys %sources;
				}
				
				print CGI::p(
					CGI::checkbox(
						-name    => "new_skipDBCreation",
						-checked => $new_skipDBCreation,
						-value   => "1",
						-label   => "Skip database creation",
					),
					CGI::br(),
					"If this is selected, you need not fill in the SQL settings below. However, you must create the database manually before creating this course.",
				);
				
				# print instructions
				print CGI::p("The SQL settings you enter below must match the settings in this DBI source specification:");
				print CGI::p({style=>"text-align:center"}, CGI::tt($source));
				if (keys %sources > 1) {
					print CGI::p("Note that there is more than one DBI source in this database layout. Only tables using the most common source (above) will be created.");
				}
			}
			
			print CGI::start_table({class=>"FormLayout"});
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Server Host:"),
				CGI::td(
					CGI::textfield(
						-name  => "new_sql_host",
						-value => defined $new_sql_host ? $new_sql_host : "",
						-size  => 50,
					),
					CGI::br(),
					CGI::small("Leave blank to use the default host."),
				),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Server Port:"),
				CGI::td(
					CGI::textfield(
						-name  => "new_sql_port",
						-value => defined $new_sql_port ? $new_sql_port : "",
						-size  => 50,
					),
					CGI::br(),
					CGI::small("Leave blank to use the default port."),
				),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Admin Username:"),
				CGI::td(
					CGI::textfield(
						-name  => "new_sql_username",
						-value => defined $new_sql_username ? $new_sql_username : "",
						-size  => 50,
					),
				),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Admin Password:"),
				CGI::td(
					CGI::password_field(
						-name  => "new_sql_password",
						-value => defined $new_sql_password ? $new_sql_password : "",
						-size  => 50,
					),
				),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Database Name:"),
				CGI::td(
					CGI::textfield(
						-name  => "new_sql_database",
						-value => defined $new_sql_database ? $new_sql_database : "",
						-size  => 50,
					),
				),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "WeBWorK Host:"),
				CGI::td(
					CGI::textfield(
						-name  => "new_sql_wwhost",
						-value => defined $new_sql_wwhost ? $new_sql_wwhost : "localhost",
						-size  => 50,
					),
					CGI::br(),
					CGI::small("If the SQL server does not run on the same host as WeBWorK, enter the host name of the WeBWorK server as seen by the SQL server."),
				),
			);
		} elsif ($new_dbLayout eq "gdbm") {
			print CGI::start_table({class=>"FormLayout"});
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "GDBM Global User ID:"),
				CGI::td(
					CGI::textfield(
						-name  => "new_gdbm_globalUserID",
						-value => defined $new_gdbm_globalUserID ? $new_gdbm_globalUserID : "global_user",
						-size  => 50,
					),
				),
			);
		}
		
		
		print CGI::Tr({class=>"ButtonRow"},
			CGI::td({colspan=>2},
				CGI::submit(
					-name => "add_course",
					-value => ($add_step > 1 ? "Change" : "Continue"),
				),
			),
		);
		print CGI::end_table();
		print CGI::end_form();
	}
	
	if ($add_step >= 2 and $add_step < $add_step_max) {
		print CGI::hr();
		
		print CGI::start_form("POST", $r->uri);
		print $self->hidden_authen_fields;
		print CGI::hidden("add_step", 4);
		
		print CGI::hidden("new_courseID",          $new_courseID);
		print CGI::hidden("new_dbLayout",          $new_dbLayout);
		print CGI::hidden("new_skipDBCreation",    $new_skipDBCreation);
		print CGI::hidden("new_sql_host",          $new_sql_host);
		print CGI::hidden("new_sql_port",          $new_sql_port);
		print CGI::hidden("new_sql_username",      $new_sql_username);
		print CGI::hidden("new_sql_password",      $new_sql_password);
		print CGI::hidden("new_sql_database",      $new_sql_database);
		print CGI::hidden("new_sql_wwhost",        $new_sql_wwhost);
		print CGI::hidden("new_gdbm_globalUserID", $new_gdbm_globalUserID);
		
		print CGI::start_table({class=>"FormLayout"});
		print CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Professor User ID:"),
			CGI::td(
				CGI::textfield(
					-name  => "new_initial_userID",
					-value => defined $new_initial_userID ? $new_initial_userID : "professor",
					-size  => 50,
				),
				CGI::br(),
				CGI::small("Leave blank to skip user creation."),
			),
		);
		print CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Professor Password:"),
			CGI::td(
				CGI::password_field(
					-name  => "new_initial_password",
					-value => defined $new_initial_password ? $new_initial_password : "",
					-size  => 50,
				),
			),
		);
		print CGI::Tr({class=>"ButtonRow"},
			CGI::td({colspan=>2},
				CGI::submit(
					-name => "add_course",
					-value => ($add_step > 1 ? "Change" : "Continue"),
				),
			),
		);
		print CGI::end_table();
		print CGI::end_form();
	}
	
	if ($add_step >= 3 and $add_step < $add_step_max) {
		print CGI::hr();
		
		print CGI::start_form("POST", $r->uri);
		print $self->hidden_authen_fields;
		print CGI::hidden("add_step", 4);
		
		print CGI::hidden("new_courseID",          $new_courseID);
		print CGI::hidden("new_dbLayout",          $new_dbLayout);
		print CGI::hidden("new_skipDBCreation",    $new_skipDBCreation);
		print CGI::hidden("new_sql_host",          $new_sql_host);
		print CGI::hidden("new_sql_port",          $new_sql_port);
		print CGI::hidden("new_sql_username",      $new_sql_username);
		print CGI::hidden("new_sql_password",      $new_sql_password);
		print CGI::hidden("new_sql_database",      $new_sql_database);
		print CGI::hidden("new_sql_wwhost",        $new_sql_wwhost);
		print CGI::hidden("new_gdbm_globalUserID", $new_gdbm_globalUserID);
		print CGI::hidden("new_initial_userID",    $new_initial_userID);
		print CGI::hidden("new_initial_password",  $new_initial_password);
		
		print CGI::p("Ready to create the new course. Click ", CGI::b("Create"), "below to do so:");
		print CGI::submit(
			-name => "create_course",
			-value => "Create",
		);
	}
	
	if ($add_step == $add_step_max) {
		# we're creating the course
		
		my %dbOptions;
		if ($new_dbLayout eq "sql") {
			$dbOptions{host}     = $new_sql_host if $new_sql_host ne "";
			$dbOptions{port}     = $new_sql_port if $new_sql_port ne "";
			$dbOptions{username} = $new_sql_username;
			$dbOptions{password} = $new_sql_password;
			$dbOptions{database} = $new_sql_database;
			$dbOptions{wwhost}   = $new_sql_wwhost;
		}
		
		my @users;
		if ($new_initial_userID ne "") {
			 my $User = $db->newUser(
			 	user_id => $new_initial_userID,
			 	status => "C",
			 );
			 my $Password = $db->newPassword(
			 	user_id => $new_initial_userID,
			 	password => cryptPassword($new_initial_password),
			 );
			 my $PermissionLevel = $db->newPermissionLevel(
			 	user_id => $new_initial_userID,
			 	permission => "10",
			 );
			 push @users, [ $User, $Password, $PermissionLevel ];
		}
		
		eval {
			addCourse(
				courseID => $new_courseID,
				ce => $ce2,
				courseOptions => { dbLayoutName => $new_dbLayout },
				dbOptions => \%dbOptions,
				users => \@users,
			)
		};
		
		if ($@) {
			my $error = $@;
			print CGI::div({class=>"ResultsWithError"},
				CGI::p("An error occured while creating the course $new_courseID:"),
				CGI::tt(CGI::escapeHTML($error)),
			);
		} else {
			print CGI::div({class=>"ResultsWithoutError"},
				CGI::p("Successfully created the course $new_courseID"),
			);
		}
	}
	
	return "";	
}

1;
