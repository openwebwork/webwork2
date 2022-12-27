################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::Instructor::Config;
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Config - Config

=cut

use strict;
use warnings;

use WeBWorK::CourseEnvironment;
use WeBWorK::ConfigObject::text;
use WeBWorK::ConfigObject::timezone;
use WeBWorK::ConfigObject::time;
use WeBWorK::ConfigObject::number;
use WeBWorK::ConfigObject::boolean;
use WeBWorK::ConfigObject::permission;
use WeBWorK::ConfigObject::list;
use WeBWorK::ConfigObject::checkboxlist;
use WeBWorK::ConfigObject::popuplist;

# Configuation data
# It is organized by section.  The allowable types are
#  'Text' for a text string,
#  'Number' for a number,
#  'List' for a list of text strings,
#  'Permission' for a permission value,
#  'Boolean' for variables which really hold 0/1 values as flags,
#  'TimeZone' for a time zone,
#  'Time' for a time,
#  'CheckboxList' for variables that hold a list of values which can be independently picked yes/no as checkboxes,
#  'PopupList' for variables that hold a list of values to be selected from.

# Write contents to outputFilePath and return error messages if any.
sub writeFile {
	my ($outputFilePath, $contents) = @_;
	if (open my $OUTPUTFILE, '>:encoding(UTF-8)', $outputFilePath) {
		print $OUTPUTFILE $contents;
		close $OUTPUTFILE;
	} else {
		return (
			"I could not open $outputFilePath",
			'We will not be able to make configuration changes unless the permissions '
				. 'are set so that the web server can write to this file.'
		);
	}

	return;
}

# Make a new config object from data
sub objectify {
	my ($self, $data) = @_;
	return "WeBWorK::ConfigObject::$data->{type}"->new($data, $self);
}

sub generate_navigation_tabs {
	my ($self, $current_tab, @tab_names) = @_;
	my $r    = $self->r;
	my $tabs = $r->c;
	for my $tab (0 .. (scalar(@tab_names) - 1)) {
		if ($current_tab eq "tab$tab") {
			push(@$tabs, $r->tag('span', class => 'nav-link active', $r->maketext($tab_names[$tab])));
		} else {
			push(
				@$tabs,
				$r->link_to(
					$r->maketext($tab_names[$tab]) =>
						$self->systemLink($r->urlpath, params => { section_tab => "tab$tab" }),
					class => 'nav-link'
				)
			);
		}
	}
	return $r->tag('nav', class => 'config-tabs nav nav-pills justify-content-center my-4', $tabs->join(''));
}

sub getConfigValues {
	my ($self, $ce) = @_;
	my $configValues = $ce->{ConfigValues};

	# Get the list of theme folders in the theme directory and remove . and .. and 'layouts'.
	my $themeDir = $ce->{webworkDirs}{themes};
	opendir(my $dh, $themeDir) || die "can't opendir $themeDir: $!";
	my $themes = [ grep { !/^\.{1,2}$/ && $_ ne 'layouts' } sort readdir($dh) ];

	# get list of localization dictionaries
	my $localizeDir = $ce->{webworkDirs}{localize};
	opendir(my $dh2, $localizeDir) || die "can't opendir $localizeDir: $!";
	my %seen      = ();    # find the languages in the localize direction
	my $languages = [
		grep     { !$seen{$_}++ }                      # remove duplicate items
			map  { $_ =~ s/\.[pm]o$//r }               # get rid of suffix
			grep {/\.mo$|\.po$/} sort readdir($dh2)    #look at only .mo and .po files

	];

	# insert the anonymous array of theme folder names into configValues
	# FIXME?  Is there a reason this is an array? Couldn't we replace this
	# with a hash and conceptually simplify this routine? MEG
	my $modifyThemes = sub {
		my $item = shift;
		if (ref($item) =~ /HASH/ and $item->{var} eq 'defaultTheme') {
			$item->{values} = $themes;
		}
	};
	my $modifyLanguages = sub {
		my $item = shift;
		if (ref($item) =~ /HASH/ and $item->{var} eq 'language') {
			$item->{values} = $languages;
		}
	};
	foreach my $oneConfig (@$configValues) {
		foreach my $hash (@$oneConfig) {
			&$modifyThemes($hash);
			&$modifyLanguages($hash);
		}
	}

	return $configValues;
}

async sub pre_header_initialize {
	my ($self)       = @_;
	my $r            = $self->r;
	my $ce           = $r->ce;
	my $configValues = $self->getConfigValues($ce);
	# Get a course environment without course.conf
	$self->{default_ce} = WeBWorK::CourseEnvironment->new({ %WeBWorK::SeedCE, });

	$self->{ce_file_dir} = $ce->{courseDirs}{root};

	# Get a copy of the course environment which does not have simple.conf loaded
	my $ce3 = WeBWorK::CourseEnvironment->new({
		%WeBWorK::SeedCE,
		courseName          => $ce->{courseName},
		web_config_filename => 'noSuchFilePlease'
	});
	if ($r->param('make_changes')) {
		my $fileoutput = "#!perl
# This file is automatically generated by WeBWorK's web-based
# configuration module.  Do not make changes directly to this
# file.  It will be overwritten the next time configuration
# changes are saved.\n\n";

		# Get the number of the current tab
		my $tab = $r->param('section_tab') || 'tab0';
		$tab =~ s/tab//;
		# We completely rewrite the simple configuration file, so we need to go through all sections.
		for my $configSection (@{$configValues}) {
			my @configSectionArray = @{$configSection};
			shift @configSectionArray;
			for my $con (@configSectionArray) {
				my $conobject = $self->objectify($con);
				if ($tab) {
					# This tab is hidden so use the current course environment value.
					$fileoutput .= $conobject->save_string($con->get_value($ce3), 1);
				} else {
					# We reached the tab with entry objects
					$fileoutput .= $conobject->save_string($con->get_value($ce3));
				}
			}
			$tab--;
		}
		my @write_result = writeFile("$self->{ce_file_dir}/simple.conf", $fileoutput);
		if (@write_result) {
			$self->addbadmessage($r->c(@write_result)->join($r->tag('br')));
		} else {
			$self->addgoodmessage($r->maketext('Changes saved'));
		}
	}

	return;
}

1;
