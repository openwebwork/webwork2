################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Feedback.pm,v 1.18 2003/12/09 01:12:30 sh002i Exp $
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
use WeBWorK::PG::ImageGenerator;
=head1 NAME


WeBWorK::ContentGenerator::EquationDisplay -- create .png version of TeX equations.

=cut

# *** feedback should be exempt from authentication, so that people can send
# feedback from the login page!

use strict;
use warnings;
use Data::Dumper;
use CGI qw();
use Mail::Sender;
use Text::Wrap qw(wrap);

# request paramaters used
# 
# user
# key
# module
# set (if from ProblemSet or Problem)
# problem (if from Problem)
# displayMode (if from Problem)
# showOldAnswers (if from Problem)
# showCorrectAnswers (if from Problem)
# showHints (if from Problem)
# showSolutions (if from Problem)

# state data sent
# 
# user object for current user
# permission level of current user
# current session key
# which ContentGenerator module called Feedback?
# set object for current set (if from ProblemSet or Problem)
# problem object for current problem (if from Problem)
# display options (if from Problem)
sub initialize {
	my ($self,@components) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $envir = $ce->{envir};
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
	$self->{typesetStr} = $self->display_equation($equationStr) if $equationStr;


}
sub display_equation {
	my $self = shift;
	my $str = shift;
	my $imageTag = $self->{image_gen}->add($str,'inline');
	$self->{image_gen}->render();
	return $imageTag;
}
sub path {
	my ($self, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		"Feedback" => "",
	);
}

sub title {
	return "Equation";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	

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
	return join( "", "Copy the location of this image (or drag and drop) into your editing area:",
	                 CGI::br(),
	                 $typeset2Str,
	                 CGI::br(),
	                 $typesetStr,
	                 CGI::start_form(-method=>'POST',-action=>$r->uri),
	                 $self->hidden_authen_fields,
					 CGI::textarea( "eq",$initial_str,5,40),
					 CGI::submit('typeset','typeset'),
	
					 CGI::end_form(),
	)
}



sub hidden_state_fields($) {
	my $self = shift;
	my $r = $self->{r};
	
	print CGI::hidden("$_", $r->param("$_"))
		foreach (qw(module set problem displayMode showOldAnswers
		            showCorrectAnswers showHints showSolutions));
}

1;
