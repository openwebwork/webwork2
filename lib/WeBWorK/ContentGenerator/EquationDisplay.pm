################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/EquationDisplay.pm,v 1.6 2006/07/12 01:23:54 gage Exp $
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

package WeBWorK::ContentGenerator::EquationDisplay;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME


WeBWorK::ContentGenerator::EquationDisplay -- create .png version of TeX equations.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::PG::ImageGenerator;

sub display_equation {
	my ($self, $str) = @_;
	
	my $imageTag = $self->{image_gen}->add($str, 'inline');
	$self->{image_gen}->render();
	return $imageTag;
}

################################################################################
# template escape handlers
################################################################################

sub initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	$self->{image_gen} = WeBWorK::PG::ImageGenerator->new(
		tempDir  => $ce->{webworkDirs}->{tmp}, # global temp dir
		latex	 => $ce->{externalPrograms}->{latex},
		dvipng   => $ce->{externalPrograms}->{dvipng},
		useCache => 1,
		cacheDir => $ce->{webworkDirs}->{equationCache},
		cacheURL => $ce->{webworkURLs}->{equationCache},
		cacheDB  => $ce->{webworkFiles}->{equationCacheDB},
	);
	
	my $equationStr = $r->param('eq');
	$self->{equationStr} = $equationStr if defined $equationStr;
	$self->{typesetStr}  = $self->display_equation($equationStr) if $equationStr;
}

#sub path {
#	my ($self, $args) = @_;
#	
#	my $ce = $self->{ce};
#	my $root = $ce->{webworkURLs}->{root};
#	my $courseName = $ce->{courseName};
#	return $self->pathMacro($args,
#		"Home" => "$root",
#		$courseName => "$root/$courseName",
#		"Feedback" => "",
#	);
#}
#
#sub title {
#	return "Equation";
#}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	
	#######################################
	# Initial data for the textarea field where the equation is entered
	#######################################
	my $initial_str = "Enter equation here";
	$initial_str = $r->param('eq') if $self->{equationStr};
	
	#######################################
	# Prepare to display the typeset image and
	# the HTML code that links to the source image.
	# The HTML code is linked also to the image address
	# This requires digging out the link from the string returned
	# by display_equation and ImageGenerator.
	# The server name and port are included in the new url.
	#######################################
	my $typesetStr = (defined $self->{typesetStr})?$self->{typesetStr}:'';
	
	#### add the host name to the string
	my $hostName = $r->hostname;
	my $port     = $r->get_server_port;
	$hostName    .= ":$port";
	$typesetStr =~ s|src="|src="http://$hostName|;
	
	my $typeset2Str = $typesetStr;
	$typeset2Str =~ s/</&lt;/g;
	$typeset2Str =~ s/>/&gt;/g;
	
	my $sourceHref = $typesetStr;
	$sourceHref =~ /"([^"]*)"/;
	$sourceHref = $1;
	
	#######################################
	# Print the page
	#######################################
	return join( "",
		"Copy the location of this image (or drag and drop) into your editing area:",
		CGI::br(),
		$typeset2Str,
		CGI::br(),
		$typesetStr,
		CGI::start_form(-method=>'POST', -action=>$r->uri),
		$self->hidden_authen_fields,
		CGI::textarea( "eq", $initial_str, 5, 40),
		CGI::submit('typeset', 'typeset'),
		CGI::end_form(),
	);
}

1;
