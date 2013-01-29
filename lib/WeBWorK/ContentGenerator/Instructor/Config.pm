################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/Config.pm,v 1.10 2007/07/26 18:53:06 sh002i Exp $
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
#  convert more html to CGI:: calls
#  put some formatting in css and in ur.css
#  add type to deal with boxes around problem text
#  maybe add a type to deal with files like ur.css and templates (where
#    a copy of the old file gets created for the course and then the
#    user can modify it).

# The main package starts lower down.  First we define different
# types of config objects.

# Each config object might want to override the methods display_value,
# entry_widget, and save_string

########################### config object defaults
package configobject;

use strict;
use warnings;

sub new {
	my $class = shift;
	my $self = shift;
	$self->{Module} = shift;
	bless $self, $class;
	return $self;
}

# Only input is a value to display, and should produce an html string
sub display_value {
	my ($self, $val) = @_;
	return $val;
}

# Stringified version for comparison (with html param return value)
sub comparison_value {
	my ($self, $val) = @_;
	return $self->display_value($val);
}

sub convert_newval_source {
	my ($self, $newvalsource) = @_;
    my $inlinevarname = WeBWorK::ContentGenerator::Instructor::Config::inline_var($self->{var});
    my $newval;
    if($newvalsource =~ /widget/) {
        $newval = $self->{Module}->{r}->param($newvalsource);
    } else {
        $newval = $self->comparison_value(eval('$self->{Module}->{r}->ce->'.
			$inlinevarname));
    }
	return($newval);
}

# Bit of text to put in the configuration file.  The result should
# be an assignment which is executable by perl.  oldval will be the
# value of the perl variable, and newval will be whatever an entry
# widget produces
sub save_string {
	my ($self, $oldval, $newvalsource) = @_;
	my $varname = $self->{var};
	my $newval = $self->convert_newval_source($newvalsource);
	my $displayoldval = $self->display_value($oldval);
	return '' if($displayoldval eq $newval);
	return('$'. $varname . " = '$newval';\n");
}

# A widget to interact with the user
sub entry_widget {
	my ($self, $name, $default) = @_;
	my $width = $self->{width} || 15;
	return CGI::textfield(
		-name => $name,
		-value => $default,
		-size => $width,
	);
}

# This produces the documentation string and image link to more
# documentation.  It is the same for all config types.
sub what_string {
	my $self = shift;
	my $r = $self->{Module}->r;
	return(CGI::td(
		CGI::a({href=>$self->{Module}->systemLink(
			$r->urlpath->new(type=>'instructor_config',
				args=>{courseID => $r->urlpath->arg("courseID")}),
				params=>{show_long_doc=>1,
					var_name=>"$self->{var}"}),
			target=>"_blank"},
			CGI::img({src=>$r->{ce}->{webworkURLs}->{htdocs}.
				"/images/question_mark.png",
				border=>"0", alt=>"$self->{var}", 
				style=>"float: right; padding-left: 0.1em;"})
		) .
		$self->{doc} 
	));
}

########################### configtext
package configtext;
@configtext::ISA = qw(configobject);

sub save_string {
	my ($self, $oldval, $newvalsource) = @_;
	my $varname = $self->{var};
	my $newval = $self->convert_newval_source($newvalsource);
	my $displayoldval = $self->comparison_value($oldval);
	return '' if($displayoldval eq $newval);
	# Remove quotes from the string, we will have a new type for text with quotes
	$newval =~ s/['"`]//g; #`"'geditsucks
	return('$'. $varname . " = '$newval';\n");
}

########################### confignumber
package confignumber;
@confignumber::ISA = qw(configobject);

sub save_string {
	my ($self, $oldval, $newvalsource) = @_;
	my $varname = $self->{var};
	my $newval = $self->convert_newval_source($newvalsource);
	my $displayoldval = $self->comparison_value($oldval);
	# Remove quotes from the string, we will have a new type for text with quotes
	$newval =~ s/['"`]//g; #`"'geditsucks
	my $newval2 = eval($newval);
	if($@) {
		$self->{Module}->addbadmessage("Syntax error in numeric value '$newval' for variable \$$self->{var}.  Reverting to the system default value.");
		return '';
	}
	return '' if($displayoldval == $newval2);
	return('$'. $varname . " = $newval;\n");
}

########################### configboolean
package configboolean;
@configboolean::ISA = qw(configobject);

sub display_value {
	my ($self, $val) = @_;
	return 'True' if $val;
	return 'False';
}

sub save_string {
	my ($self, $oldval, $newvalsource) = @_;
	my $varname = $self->{var};
	my $newval = $self->convert_newval_source($newvalsource);
	my $displayoldval = $self->comparison_value($oldval);
	return '' if($displayoldval eq $newval);
	return('$'. $varname . " = " . ($newval eq 'True' ? 1 : 0) .";\n");
}

sub entry_widget {
	my ($self, $name, $default) = @_;
	
	return CGI::popup_menu(
		-name => $name,
		-default => ($default ? 'True' : 'False'),
		-values => ['True', 'False'],
	);
}


########################### configpermission
package configpermission;
@configpermission::ISA = qw(configobject);

# This tries to produce a string from a permission number.  If you feed it
# a string, that's what you get back.
sub display_value {
	my ($self, $val) = @_;
	return 'nobody' if not defined($val);
	my %userRoles = %{$self->{Module}->{r}->{ce}->{userRoles}};
	my %reverseUserRoles = reverse %userRoles;
	return $reverseUserRoles{$val} if defined($reverseUserRoles{$val});
	return $val;
}

sub save_string {
	my ($self, $oldval, $newvalsource) = @_;
	my $varname = $self->{var};
	my $newval = $self->convert_newval_source($newvalsource);
	my $displayoldval = $self->comparison_value($oldval);
	return '' if($displayoldval eq $newval);
	my $str = '$'. $varname . " = '$newval';\n";
	$str = '$'. $varname . " = undef;\n" if $newval eq 'nobody';
	return($str);
}

sub entry_widget {
	my ($self, $name, $default) = @_;
	my $ce = $self->{Module}->{r}->{ce};
	my $permHash = {};
	my %userRoles = %{$ce->{userRoles}};
	$userRoles{nobody} = 99999999; # insure that nobody comes at the end
	my %reverseUserRoles = reverse %userRoles;

	# the value of a permission can be undefined (for nobody),
	# a standard permission number, or some other number
	if(not defined($default)) {
		$default = 'nobody';
	}

	my @values = sort { $userRoles{$a} <=> $userRoles{$b} } keys %userRoles;
	return CGI::popup_menu(-name=>$name, -values => \@values,
		-default=>$default);
}

########################### configlist
package configlist;
@configlist::ISA = qw(configobject);

sub display_value {
	my ($self, $val) = @_;
	return '&nbsp;' if not defined($val);
	my $str = join(','.CGI::br(), @{$val});
	$str = '&nbsp;' if $str !~  /\S/;
	return $str;
}

sub comparison_value {
	my ($self, $val) = @_;
	$val = [] if not defined($val);
	my $str = join(',', @{$val});
	return($str);
}

sub save_string {
	my ($self, $oldval, $newvalsource) = @_;
	my $newval = $self->convert_newval_source($newvalsource);
	my $varname = $self->{var};
	$oldval = $self->comparison_value($oldval);
	return '' if($oldval eq $newval);
	my $str = '';

	$oldval =~ s/^\s*(.*)\s*$/$1/;
	$newval =~ s/^\s*(.*)\s*$/$1/;
	$oldval =~ s/[\s,]+/,/sg;
	$newval =~ s/[\s,]+/,/sg;
	return '' if($newval eq $oldval);
	# ok we really have a new value, now turn it back into a string
	my @parts = split ',', $newval;
	map { $_ =~ s/['"`]//g } @parts; #`"'geditsucks
	@parts = map { "'". $_ ."'" } @parts;
	$str = join(',', @parts);
	$str = '$'. $varname . " = [$str];\n";
	return($str);
}

sub entry_widget {
	my ($self, $name, $default) = @_;

	$default = [] if not defined($default);
	my $str = join(', ', @{$default});
	$str = '' if $str !~ /\S/;
	return CGI::textarea(
		-name => $name,
		-rows => 4,
		-value => $str,
		-columns => 25,
	);
}

########################### configcheckboxlist
package configcheckboxlist;
@configcheckboxlist::ISA = qw(configobject);

sub display_value {
	my ($self, $val) = @_;
	$val = [] if not defined($val);
	my @vals = @$val;
	return join(CGI::br(), @vals);
}

# here r->param() returns an array, so we need a custom
# version of convert_newval_source

sub convert_newval_source {
	my ($self, $newvalsource) = @_;
    my $inlinevarname = WeBWorK::ContentGenerator::Instructor::Config::inline_var($self->{var});
    my @newvals;
    if($newvalsource =~ /widget/) {
        @newvals = $self->{Module}->{r}->param($newvalsource);
    } else {
        my $newval = eval('$self->{Module}->{r}->{ce}->'. $inlinevarname);
		@newvals = @$newval;
    }
	return(@newvals);
}

# Bit of text to put in the configuration file.  The result should
sub save_string {
	my ($self, $oldval, $newvalsource) = @_;
	my $varname = $self->{var};
	my @newvals = $self->convert_newval_source($newvalsource);
	if($self->{min} and (scalar(@newvals) < $self->{min})) {
		$self->{Module}->addbadmessage("You need to select at least $self->{min} display mode.");
		if($newvalsource =~ /widget/) {
			return $self->save_string($oldval, 'current'); # try to return the old saved value
		} else {
			return '' ; # the previous saved value was empty, reset to system default
		}
	}
	$oldval = $self->comparison_value($oldval);
	my $newval =  $self->comparison_value(\@newvals);
	return '' if($oldval eq $newval);
	@newvals = map { "'".$_."'" } @newvals;
	my $str = join(',', @newvals);
	$str = '$'. $varname . " = [$str];\n";
	return($str);
}

sub comparison_value {
	my ($self, $val) = @_;
	$val = [] if not defined($val);
	my $str = join(',', @{$val});
	return($str);
}

sub entry_widget {
	my ($self, $name, $default) = @_;
	return CGI::checkbox_group(
		-name => $name,
		-value => $self->{values},
		-default => $default,
		-columns=>1
	);
}

########################### configpopuplist
package configpopuplist;
@configpopuplist::ISA = qw(configobject);

sub display_value {
	my ($self, $val) = @_;
	$val = 'ur' if not defined($val);
	return join(CGI::br(), $val);
}

# here r->param() returns an array, so we need a custom
# version of convert_newval_source

# sub convert_newval_source {
# 	my ($self, $newvalsource) = @_;
#     my $inlinevarname = WeBWorK::ContentGenerator::Instructor::Config::inline_var($self->{var});
#     my @newvals;
#     if($newvalsource =~ /widget/) {
#         @newvals = $self->{Module}->{r}->param($newvalsource);
#     } else {
#         my $newval = eval('$self->{Module}->{r}->{ce}->'. $inlinevarname);
# 		@newvals = @$newval;
#     }
# 	return(@newvals);
# }

sub save_string {
	my ($self, $oldval, $newvalsource) = @_;
	my $varname = $self->{var};
	my $newval = $self->convert_newval_source($newvalsource);
	my $displayoldval = $self->comparison_value($oldval);
	return '' if($displayoldval eq $newval);
	return('$'. $varname . " = " . "'$newval';\n");
}

# sub comparison_value {
# 	my ($self, $val) = @_;
# 	$val = 'ur' if not defined($val);
# 	my $str = join(',', @{$val});
# 	return($str);
# }

sub entry_widget {
	my ($self, $name, $default) = @_;
	return CGI::popup_menu(
		-name => $name,
		-values => $self->{values},
		-default => $default,

	);
}

########### Main Config Package starts here

package WeBWorK::ContentGenerator::Instructor::Config;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Config - Config

=cut

use strict;
use warnings;

use CGI qw(-nosticky );
use WeBWorK::CourseEnvironment;

# Load the configuration parts defined in Constants.pm 

#our $ConfigValues = [] unless defined $ConfigValues;

# Configuation data
# It is organized by section.  The allowable types are 
#  'text' for a text string,
#  'list' for a list of text strings,
#  'permission' for a permission value, 
#  'boolean' for variables which really hold 0/1 values as flags.

# write contents to outputFilePath and return error messages if any
sub writeFile {
	my $outputFilePath = shift;
	my $contents = shift;
	my $writeFileErrors;
	eval {                                                          
		local *OUTPUTFILE;
		if( open OUTPUTFILE, ">", $outputFilePath) {
			print OUTPUTFILE $contents;
			close OUTPUTFILE;
		} else {
			$writeFileErrors = "I could not open $outputFilePath".
				CGI::br() . CGI::br().
				"We will not be able to make configuration changes unless the permissions are set so that the web server can write to this file.";
		}
	};  # any errors are caught in the next block

	$writeFileErrors = $@ if $@;
	return($writeFileErrors);
}

# Make a new config object from data

sub objectify {
	my ($self, $data) = @_;
	return "config$data->{type}"->new($data,$self);
}


# Take var string from ConfigValues and prepare it for $ce->...
sub inline_var {
	my $varstring = shift;
	return '{'.$varstring.'}' if $varstring =~ /^\w+$/;
	$varstring =~ s/^(\w+)/{$1}->/;
	return($varstring);
}

sub print_navigation_tabs {
	my ($self, $current_tab, @tab_names) = @_;
	my $r = $self->r;
	my $str = '';
	for my $tab (0..(scalar(@tab_names)-1)) {
		if($current_tab eq "tab$tab") {
			$tab_names[$tab] = $tab_names[$tab];
		} else {
			$tab_names[$tab] = CGI::a({href=>$self->systemLink($r->urlpath, params=>{section_tab=>"tab$tab"})}, $tab_names[$tab]);
		}
	}
	print CGI::p() .
		'<div align="center">' . join('&nbsp;|&nbsp;', @tab_names) .'</div>'.
		CGI::p();
}

sub getConfigValues {
	my $ce = shift;
	my $ConfigValues = $ce->{ConfigValues};
	
	# get the list of theme folders in the theme directory and remove . and ..
	my $themeDir = $ce->{webworkDirs}{themes};
	opendir(my $dh, $themeDir) || die "can't opendir $themeDir: $!";
	my $themes =[grep {!/^\.{1,2}$/} sort readdir($dh)];
	

	# get list of localization dictionaries
	my $localizeDir = $ce->{webworkDirs}{localize};
	opendir(my $dh2, $localizeDir) || die "can't opendir $localizeDir: $!";
	my %seen=();  # find the languages in the localize direction
	my $languages =[ grep {!$seen{$_} ++}        # remove duplicate items
			     map {$_=~s/\...$//; $_}        # get rid of suffix 
                 grep {/\.mo$|\.po$/; } sort readdir($dh2) #look at only .mo and .po files
              
                ]; 
	# insert the anonymous array of theme folder names into ConfigValues
	my $modifyThemes = sub { my $item=shift; if (ref($item)=~/HASH/ and $item->{var} eq 'defaultTheme' ) { $item->{values} =$themes } };

	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			&$modifyThemes($hash);
		}
	}
	
	$ConfigValues;
}
	
sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $ConfigValues = getConfigValues($ce);
	# Get a course environment without course.conf
	$self->{default_ce} = WeBWorK::CourseEnvironment->new({
		%WeBWorK::SeedCE,
	});

	$self->{ce_file_dir} = $ce->{courseDirs}->{root};

	# Get a copy of the course environment which does not have simple.conf loaded
	my $ce3 = eval {
		new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $ce->{courseName},
			web_config_filename => 'noSuchFilePlease',
		})
	};
	if($r->param("make_changes")) {
		my $widget_count = 0;
		my $fileoutput = "#!perl
# This file is automatically generated by WeBWorK's web-based
# configuration module.  Do not make changes directly to this
# file.  It will be overwritten the next time configuration
# changes are saved.\n\n";

		# Get the number of the current tab
		my $tab = $r->param('section_tab') || 'tab0';
		$tab =~ s/tab//;
		# We completely rewrite the simple configuration file
		# so we need to go through all sections
		for my $configSection (@{$ConfigValues}) {
			my @configSectionArray = @{$configSection};
			shift @configSectionArray;
			for my $con (@configSectionArray) {
				my $conobject = $self->objectify($con);
				if($tab) { # This tab is not being shown
					my $oldval = eval('$ce3->'.inline_var($con->{var}));
					$fileoutput .= $conobject->save_string($oldval, 'current');
				} else { # We reached the tab with entry objects
					$fileoutput .= $conobject->save_string(eval('$ce3->'.inline_var($con->{var})), "widget$widget_count");
					$widget_count++;
				}
			}
			$tab--;
		}
		my $write_result = writeFile($self->{ce_file_dir}."/simple.conf", $fileoutput);
		if ($write_result) {
			$self->addbadmessage($write_result);
		} else {
			$self->addgoodmessage("Changes saved.");
		}
	}
}

sub body {
	my ($self) = @_;

	my $r = $self->r;
	my $ce = $r->ce;		# course environment
	my $db = $r->db;		# database
	my $ConfigValues = getConfigValues($ce);
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

	if ($r->param('show_long_doc')) {
		my $docstring;
		for my $consec (@$ConfigValues) {
			my @configSectionArray = @$consec;
			shift @configSectionArray;
			for my $con (@configSectionArray) {
				$docstring = $con->{doc2} || $con->{doc}
					if($con->{var} eq $r->param('var_name'));
			}
		}
		print CGI::h2("Variable Documentation: ". CGI::code('$'.$r->param('var_name'))),
			CGI::p(),
			CGI::blockquote( $docstring );
		return "";
	}

	my $default_ce = $self->{default_ce};
	# Get the current course environment again in case we just saved changes
	my $ce4 = eval {
		new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $ce->{courseName},
		})
	};

	my $widget_count = 0;
	if(scalar(@$ConfigValues) == 0) {
		print CGI::p("The configuration module did not find the data
it needs to function.  Have your site administrator check that Constants.pm
is up to date.");
		return "";
	}

	# Start tabs at the top
	my $current_tab = $r->param('section_tab') || 'tab0';
	my @tab_names = map { $_->[0] } @{$ConfigValues};
	$self->print_navigation_tabs($current_tab, @tab_names);

	print CGI::startform({method=>"post", action=>$r->uri, name=>"configform"});
	print $self->hidden_authen_fields();
	print CGI::hidden(-name=> 'section_tab', -value=> $current_tab);

	my $tabnumber = $current_tab;
	$tabnumber =~ s/tab//;
	my @configSectionArray = @{$ConfigValues->[$tabnumber]};
	my $configTitle = shift @configSectionArray;
	print CGI::p(CGI::div({-align=>'center'}, CGI::b($configTitle)));

	print CGI::start_table({-border=>"1"});
	print '<tr>'.CGI::th('What'). CGI::th('Default') .CGI::th('Current');
	for my $con (@configSectionArray) {
		my $conobject = $self->objectify($con);
		print "\n<tr>";
		print $conobject->what_string;
		print CGI::td({-align=>"center"}, $conobject->display_value(eval('$default_ce->'.inline_var($con->{var}))));
		print CGI::td($conobject->entry_widget("widget$widget_count", eval('$ce4->'.inline_var($con->{var}))));
		print '</tr>';
		$widget_count++;
	}
	print CGI::end_table();
	print CGI::p(CGI::submit(-name=>'make_changes', -value=>'Save Changes'));
	print CGI::end_form();


	return "";	
}


=head1 AUTHOR

Written by John Jones, jj (at) asu.edu.

=cut



1;
