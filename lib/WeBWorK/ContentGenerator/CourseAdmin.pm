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
use WeBWorK::Utils::CourseManagement qw(addCourse deleteCourse listCourses);

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
	
	print CGI::p({style=>"text-align: center"},
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"add_course"})}, "Add Course"),
		#" | ",
		#CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"rename_course"})}, "Rename Course"),
		" | ",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"delete_course"})}, "Delete Course"),
	);
	
	print CGI::hr();
	
	my $subDisplay = $r->param("subDisplay");
	if (defined $subDisplay) {
	
		if ($subDisplay eq "add_course") {
			if (defined $r->param("add_course")) {
				my @errors = $self->add_course_validate;
				if (@errors) {
					print CGI::div({class=>"ResultsWithError"},
						CGI::p("Please correct the following errors and try again:"),
						CGI::ul(CGI::li(\@errors)),
					);
					$self->add_course_form;
				} else {
					$self->do_add_course;
				}
			} else {
				$self->add_course_form;
			}
		}
		
		elsif ($subDisplay eq "delete_course") {
			if (defined $r->param("delete_course")) {
				# validate or confirm
				my @errors = $self->delete_course_validate;
				if (@errors) {
					print CGI::div({class=>"ResultsWithError"},
						CGI::p("Please correct the following errors and try again:"),
						CGI::ul(CGI::li(\@errors)),
					);
					$self->delete_course_form;
				} else {
					$self->delete_course_confirm;
				}
			} elsif (defined $r->param("confirm_delete_course")) {
				# validate and delete
				my @errors = $self->delete_course_validate;
				if (@errors) {
					print CGI::div({class=>"ResultsWithError"},
						CGI::p("Please correct the following errors and try again:"),
						CGI::ul(CGI::li(\@errors)),
					);
					$self->delete_course_form;
				} else {
					$self->do_delete_course;
				}
			} else {
				# form only
				$self->delete_course_form;
			}
		}
		
	}
	
	return "";
}

sub add_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $add_courseID          = $r->param("add_courseID") || "";
	my $add_dbLayout          = $r->param("add_dbLayout") || "";
	my $add_sql_host          = $r->param("add_sql_host") || "";
	my $add_sql_port          = $r->param("add_sql_port") || "";
	my $add_sql_username      = $r->param("add_sql_username") || "";
	my $add_sql_password      = $r->param("add_sql_password") || "";
	my $add_sql_database      = $r->param("add_sql_database") || "";
	my $add_sql_wwhost        = $r->param("add_sql_wwhost") || "";
	my $add_gdbm_globalUserID = $r->param("add_gdbm_globalUserID") || "";
	my $add_initial_userID    = $r->param("add_initial_userID") || "";
	my $add_initial_password  = $r->param("add_initial_password") || "";
	
	my @dbLayouts = sort keys %{ $ce->{dbLayouts} };
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		"COURSENAME",
	);
	
	my $dbi_source = do {
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
		$source;
	};
	
	print CGI::h2("Add Course");
	
	print CGI::start_form("POST", $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p("Specify a name for the new course.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Course Name:"),
			CGI::td(CGI::textfield("add_courseID", $add_courseID, 25)),
		),
	);
	
	print CGI::p("Select a database layout below. Some database layouts require additional information.");
	
	#print CGI::start_Tr();
	#print CGI::th({class=>"LeftHeader"}, "Database Layout:");
	#print CGI::start_td();
	
	foreach my $dbLayout (@dbLayouts) {
		print CGI::start_table({class=>"FormLayout"});
		
		# we generate singleton radio button tags ourselves because it's too much of a pain to do it with CGI.pm
		print CGI::Tr(
			CGI::td({style=>"text-align: right"},
				'<input type="radio" name="add_dbLayout" value="' . $dbLayout . '"'
				. ($add_dbLayout eq $dbLayout ? " checked" : "") . ' />',
			),
			CGI::td($dbLayout),
		);
		
		print CGI::start_Tr();
		print CGI::td(); # for indentation :(
		print CGI::start_td();
		
		if ($dbLayout eq "sql") {
			print CGI::p(
				"The SQL settings you enter below must match the settings in the DBI source",
				" specification ", CGI::tt($dbi_source), ". Replace ", CGI::tt("COURSENAME"),
				" with the course name you entered above."
			);
			print CGI::start_table({class=>"FormLayout"});
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Server Host:"),
				CGI::td(
					CGI::textfield("add_sql_host", $add_sql_host, 25),
					CGI::br(),
					CGI::small("Leave blank to use the default host."),
				),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Server Port:"),
				CGI::td(
					CGI::textfield("add_sql_port", $add_sql_port, 25),
					CGI::br(),
					CGI::small("Leave blank to use the default port."),
				),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Admin Username:"),
				CGI::td(CGI::textfield("add_sql_username", $add_sql_username, 25)),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Admin Password:"),
				CGI::td(CGI::password_field("add_sql_password", $add_sql_password, 25)),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Database Name:"),
				CGI::td(CGI::textfield("add_sql_database", $add_sql_database, 25)),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "WeBWorK Host:"),
				CGI::td(
					CGI::textfield("add_sql_wwhost", $add_sql_wwhost || "localhost", 25),
					CGI::br(),
					CGI::small("If the SQL server does not run on the same host as WeBWorK, enter the host name of the WeBWorK server as seen by the SQL server."),
				),
			);
			print CGI::end_table();
		} elsif ($dbLayout eq "gdbm") {
			print CGI::start_table({class=>"FormLayout"});
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "GDBM Global User ID:"),
				CGI::td(CGI::textfield("add_gdbm_globalUserID", $add_gdbm_globalUserID || "professor", 25)),
			);
			print CGI::end_table();
		}
		
		print CGI::end_td();
		print CGI::end_Tr();
		print CGI::end_table();
	}
	
	
	print CGI::p("To add an initial user to the new course, enter a user ID and password below. If you do not do so, you will not be able to log into the course.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Professor User ID:"),
			CGI::td(CGI::textfield("add_initial_userID", $add_initial_userID || "professor", 25)),
		),
		CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Professor Password:"),
			CGI::td(CGI::password_field("add_initial_password", $add_initial_password, 25)),
		),
	);
	
	print CGI::p({style=>"text-align: center"}, CGI::submit("add_course", "Add Course"));
	
	print CGI::end_form();
}

sub add_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $add_courseID          = $r->param("add_courseID") || "";
	my $add_dbLayout          = $r->param("add_dbLayout") || "";
	my $add_sql_host          = $r->param("add_sql_host") || "";
	my $add_sql_port          = $r->param("add_sql_port") || "";
	my $add_sql_username      = $r->param("add_sql_username") || "";
	my $add_sql_password      = $r->param("add_sql_password") || "";
	my $add_sql_database      = $r->param("add_sql_database") || "";
	my $add_sql_wwhost        = $r->param("add_sql_wwhost") || "";
	my $add_gdbm_globalUserID = $r->param("add_gdbm_globalUserID") || "";
	my $add_initial_userID    = $r->param("add_initial_userID") || "";
	my $add_initial_password  = $r->param("add_initial_password") || "";
	
	my @errors;
	
	if ($add_courseID eq "") {
		push @errors, "You must specify a course name.";
	}
	
	if ($add_dbLayout eq "") {
		push @errors, "You must select a database layout.";
	} else {
		if (exists $ce->{dbLayouts}->{$add_dbLayout}) {
			if ($add_dbLayout eq "sql") {
				push @errors, "You must specify the SQL admin username." if $add_sql_username eq "";
				push @errors, "You must specify the SQL admin password." if $add_sql_password eq "";
				push @errors, "You must specify the SQL confirm_delete_course." if $add_sql_database eq "";
				push @errors, "You must specify the WeBWorK host." if $add_sql_wwhost eq "";
			} elsif ($add_dbLayout eq "gdbm") {
				push @errors, "You must specify the GDBM global user ID." if $add_gdbm_globalUserID eq "";
			}
		} else {
			push @errors, "The database layout $add_dbLayout doesn't exist.";
		}
	}
	
	if ($add_initial_userID ne "") {
		push @errors, "You must specify a professor password." if $add_initial_password eq "";
	}
	
	return @errors;
}

sub do_add_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $add_courseID          = $r->param("add_courseID") || "";
	my $add_dbLayout          = $r->param("add_dbLayout") || "";
	my $add_sql_host          = $r->param("add_sql_host") || "";
	my $add_sql_port          = $r->param("add_sql_port") || "";
	my $add_sql_username      = $r->param("add_sql_username") || "";
	my $add_sql_password      = $r->param("add_sql_password") || "";
	my $add_sql_database      = $r->param("add_sql_database") || "";
	my $add_sql_wwhost        = $r->param("add_sql_wwhost") || "";
	my $add_gdbm_globalUserID = $r->param("add_gdbm_globalUserID") || "";
	my $add_initial_userID    = $r->param("add_initial_userID") || "";
	my $add_initial_password  = $r->param("add_initial_password") || "";
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$add_courseID,
	);
	
	my %dbOptions;
	if ($add_dbLayout eq "sql") {
		$dbOptions{host}     = $add_sql_host if $add_sql_host ne "";
		$dbOptions{port}     = $add_sql_port if $add_sql_port ne "";
		$dbOptions{username} = $add_sql_username;
		$dbOptions{password} = $add_sql_password;
		$dbOptions{database} = $add_sql_database;
		$dbOptions{wwhost}   = $add_sql_wwhost;
	}
	
	my @users;
	if ($add_initial_userID ne "") {
		 my $User = $db->newUser(
			user_id => $add_initial_userID,
			status => "C",
		 );
		 my $Password = $db->newPassword(
			user_id => $add_initial_userID,
			password => cryptPassword($add_initial_password),
		 );
		 my $PermissionLevel = $db->newPermissionLevel(
			user_id => $add_initial_userID,
			permission => "10",
		 );
		 push @users, [ $User, $Password, $PermissionLevel ];
	}
	
	eval {
		addCourse(
			courseID => $add_courseID,
			ce => $ce2,
			courseOptions => { dbLayoutName => $add_dbLayout },
			dbOptions => \%dbOptions,
			users => \@users,
		);
	};
	
	if ($@) {
		my $error = $@;
		print CGI::div({class=>"ResultsWithError"},
			CGI::p("An error occured while creating the course $add_courseID:"),
			CGI::tt(CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p("Successfully created the course $add_courseID"),
		);
		my $newCoursePath = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",
			courseID => $add_courseID);
		my $newCourseURL = $self->systemLink($newCoursePath, authen => 0);
		print CGI::div({style=>"text-align: center"},
			CGI::a({href=>$newCourseURL}, "Log into $add_courseID"),
		);
	}
}

################################################################################

sub delete_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	my $delete_sql_host     = $r->param("delete_sql_host")     || "";
	my $delete_sql_port     = $r->param("delete_sql_port")     || "";
	my $delete_sql_username = $r->param("delete_sql_username") || "";
	my $delete_sql_password = $r->param("delete_sql_password") || "";
	my $delete_sql_database = $r->param("delete_sql_database")    || "";
	
	my @courseIDs = listCourses($ce);
	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		my $tempCE = WeBWorK::CourseEnvironment->new(
			$ce->{webworkDirs}->{root},
			$ce->{webworkURLs}->{root},
			$ce->{pg}->{directories}->{root},
			$courseID,
		);
		$courseLabels{$courseID} = "$courseID (" . $tempCE->{dbLayoutName} . ")";
	}
	
	print CGI::h2("Delete Course");
	
	print CGI::start_form("POST", $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p("Select a course to delete.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Course Name:"),
			CGI::td(
				CGI::scrolling_list(
					-name => "delete_courseID",
					-values => \@courseIDs,
					-default => $delete_courseID,
					-size => 10,
					-multiple => 0,
					-labels => \%courseLabels,
				),
			),
		),
	);
	
	print CGI::p(
		"If the course's database layout (indicated in parentheses above) is "
		. CGI::b("sql") . ", supply the SQL connections information requested below."
	);
	
	print CGI::start_table({class=>"FormLayout"});
	print CGI::Tr(
		CGI::th({class=>"LeftHeader"}, "SQL Server Host:"),
		CGI::td(
			CGI::textfield("delete_sql_host", $delete_sql_host, 25),
			CGI::br(),
			CGI::small("Leave blank to use the default host."),
		),
	);
	print CGI::Tr(
		CGI::th({class=>"LeftHeader"}, "SQL Server Port:"),
		CGI::td(
			CGI::textfield("delete_sql_port", $delete_sql_port, 25),
			CGI::br(),
			CGI::small("Leave blank to use the default port."),
		),
	);
	print CGI::Tr(
		CGI::th({class=>"LeftHeader"}, "SQL Admin Username:"),
		CGI::td(CGI::textfield("delete_sql_username", $delete_sql_username, 25)),
	);
	print CGI::Tr(
		CGI::th({class=>"LeftHeader"}, "SQL Admin Password:"),
		CGI::td(CGI::password_field("delete_sql_password", $delete_sql_password, 25)),
	);
	print CGI::Tr(
		CGI::th({class=>"LeftHeader"}, "SQL Database Name:"),
		CGI::td(CGI::textfield("delete_sql_database", $delete_sql_database, 25)),
	);
	print CGI::end_table();
	
	print CGI::p({style=>"text-align: center"}, CGI::submit("delete_course", "Delete Course"));
	
	print CGI::end_form();
}

sub delete_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	my $delete_sql_host     = $r->param("delete_sql_host")     || "";
	my $delete_sql_port     = $r->param("delete_sql_port")     || "";
	my $delete_sql_username = $r->param("delete_sql_username") || "";
	my $delete_sql_password = $r->param("delete_sql_password") || "";
	my $delete_sql_database = $r->param("delete_sql_database") || "";
	
	my @courseIDs = listCourses($ce);
	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		my $tempCE = WeBWorK::CourseEnvironment->new(
			$ce->{webworkDirs}->{root},
			$ce->{webworkURLs}->{root},
			$ce->{pg}->{directories}->{root},
			$courseID,
		);
		$courseLabels{$courseID} = "$courseID (" . $tempCE->{dbLayoutName} . ")";
	}
	
	my @errors;
	
	if ($delete_courseID eq "") {
		push @errors, "You must specify a course name.";
	} elsif ($delete_courseID eq $urlpath->arg("courseID")) {
		push @errors, "You cannot delete the course you are currently using.";
	}
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$delete_courseID,
	);
	
	if ($ce2->{dbLayoutName} eq "sql") {
		push @errors, "You must specify the SQL admin username." if $delete_sql_username eq "";
		push @errors, "You must specify the SQL admin password." if $delete_sql_password eq "";
		push @errors, "You must specify the SQL database name." if $delete_sql_database eq "";
	}
	
	return @errors;
}

sub delete_course_confirm {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	print CGI::h2("Delete Course");
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	my $delete_sql_host     = $r->param("delete_sql_host")     || "";
	my $delete_sql_port     = $r->param("delete_sql_port")     || "";
	my $delete_sql_database = $r->param("delete_sql_database") || "";
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$delete_courseID,
	);
	
	if ($ce2->{dbLayoutName} eq "sql") {
		print CGI::p("Are you sure you want to delete the course " . CGI::b($delete_courseID)
		. "? All course files and data and the following database will be destroyed."
		. " There is no undo available.");
		
		print CGI::table({class=>"FormLayout"},
			CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Server Host:"),
				CGI::td($delete_sql_host || "system default"),
			),
			CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Server Port:"),
				CGI::td($delete_sql_port || "system default"),
			),
			CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Database Name:"),
				CGI::td($delete_sql_database),
			),
		);
	} else {
		print CGI::p("Are you sure you want to delete the course " . CGI::b($delete_courseID)
			. "? All course files and data will be destroyed. There is no undo available.");
	}
	
	print CGI::start_form("POST", $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	print $self->hidden_fields(qw/delete_courseID delete_sql_host delete_sql_port delete_sql_username delete_sql_password delete_sql_database/);
	
	print CGI::p({style=>"text-align: center"},
		CGI::submit("decline_delete_course", "Don't delete"),
		"&nbsp;",
		CGI::submit("confirm_delete_course", "Delete"),
	);
	
	print CGI::end_form();
}

sub do_delete_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	my $delete_sql_host     = $r->param("delete_sql_host")     || "";
	my $delete_sql_port     = $r->param("delete_sql_port")     || "";
	my $delete_sql_username = $r->param("delete_sql_username") || "";
	my $delete_sql_password = $r->param("delete_sql_password") || "";
	my $delete_sql_database = $r->param("delete_sql_database") || "";
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$delete_courseID,
	);
	
	my %dbOptions;
	if ($ce2->{dbLayoutName} eq "sql") {
		$dbOptions{host}     = $delete_sql_host if $delete_sql_host ne "";
		$dbOptions{port}     = $delete_sql_port if $delete_sql_port ne "";
		$dbOptions{username} = $delete_sql_username;
		$dbOptions{password} = $delete_sql_password;
		$dbOptions{database} = $delete_sql_database;
	}
	
	eval {
		deleteCourse(
			courseID => $delete_courseID,
			ce => $ce2,
			dbOptions => \%dbOptions,
		);
	};
	
	if ($@) {
		my $error = $@;
		print CGI::div({class=>"ResultsWithError"},
			CGI::p("An error occured while deleting the course $delete_courseID:"),
			CGI::tt(CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p("Possibly deleted the course $delete_courseID. (We need better error checking in deleteCourse().)"),
		);
		
		print CGI::start_form("POST", $r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		
		print CGI::p({style=>"text-align: center"}, CGI::submit("decline_delete_course", "OK"),);
		
		print CGI::end_form();
	}
}

1;
