################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $ $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

# TODO

# background on rendered parts
# search for files by regex name
# get "similar" files by chardiff

package WeBWorK::ContentGenerator::Instructor::Compare;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Compare - Compare problems

=cut

use strict;
use warnings;

#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Form;
use WeBWorK::Utils qw(readDirectory max);
use WeBWorK::Utils::Tasks qw(renderProblems);

require WeBWorK::Utils::ListingDB;



#sub pre_header_initialize {
#	 my ($self) = @_;
#	 my $r = $self->r;
#}

sub body {
	my ($self) = @_;

	my $r = $self->r;
	my $ce = $r->ce;							# course environment
	my $db = $r->db;							# database
	my $j;												# garden variety counter

	my $userName = $r->param('user');

	my $user = $db->getUser($userName); # checked
	die "record for user $userName (real user) does not exist."
		unless defined $user;

	### Check that this is a professor
	my $authz = $r->authz;
	unless ($authz->hasPermissions($userName, "modify_problem_sets")) {
		print "User $userName returned " .
			$authz->hasPermissions($user, "modify_problem_sets") .
			" for permission";
		return(CGI::div({class=>'ResultsWithError'},
		  CGI::em("You are not authorized to access the Instructor tools.")));
	}

	my $path1 = $r->param('path1') || '';
	my $path2 = $r->param('path2') || '';
	if ($r->param('clear')) {
		$path1 = '';
		$path2 = '';
	}
	my @pathlist = ();
	push @pathlist, $path1 if $path1;
	push @pathlist, $path2 if $path2;
	my @rendered = renderProblems(r=> $r,
																user => $user,
																problem_list => \@pathlist,
																displayMode => 'images');

	##########	Extract information computed in pre_header_initialize
	print CGI::start_form({-method=>"POST", -action=>$r->uri, -name=>'mainform'}),
		$self->hidden_authen_fields;
	print CGI::p('File 1: ', CGI::textfield(-name=>"path1",
																					-default=>"$path1",
																					-override=>1, -size=>90));
	print CGI::p('File 2: ', CGI::textfield(-name=>"path2",
																					-default=>"$path2",
																					-override=>1, -size=>90));
	print CGI::p(CGI::submit(-name=>"show_me",
													 -value=>"Show Files"));
	print CGI::p(CGI::submit(-name=>"clear",
													 -value=>"Clear"));
	print CGI::end_form(), "\n";

	for $j (@rendered) {
		print '<hr size="5" color="blue" />';
		if ($j->{flags}->{error_flag}) {
			print CGI::p('Error');
		} else {
			print $j->{body_text}
		}
	}
	print '<hr size="5" color="blue" />';
	if (scalar(@pathlist)>1) {
		print CGI::h2('Diff output');
		my $use_hdiff = 1;
		if($use_hdiff) {
			# If you have hdiff installed, you can get colorized diffs
			my $diffout = `hdiff -t " " -c "File 1" -C "File 2" -N $ce->{courseDirs}->{templates}/$pathlist[0] $ce->{courseDirs}->{templates}/$pathlist[1]`;
			print $diffout;
		} else { 
			# Here we call diff.  Basic version first
			my $diffout = `diff -u $ce->{courseDirs}->{templates}/$pathlist[0] $ce->{courseDirs}->{templates}/$pathlist[1]`;
			print "\n<pre>\n";
			print $diffout;
			print "</pre>\n";
		}
	}

	return "";	
}


=head1 AUTHOR

Written by John Jones, jj (at) asu.edu.

=cut



1;
