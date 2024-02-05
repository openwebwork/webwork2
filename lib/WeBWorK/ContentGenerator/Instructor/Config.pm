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
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Config - Config

=cut

use XML::LibXML;

use WeBWorK::CourseEnvironment;
use WeBWorK::ConfigObject::text;
use WeBWorK::ConfigObject::timezone;
use WeBWorK::ConfigObject::time;
use WeBWorK::ConfigObject::number;
use WeBWorK::ConfigObject::boolean;
use WeBWorK::ConfigObject::permission;
use WeBWorK::ConfigObject::permission_checkboxlist;
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
sub writeFile ($outputFilePath, $contents) {
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
sub objectify ($c, $data) {
	return "WeBWorK::ConfigObject::$data->{type}"->new($data, $c);
}

sub generate_navigation_tabs ($c, $current_tab, @tab_names) {
	my $tabs = $c->c;
	for my $tab (0 .. (scalar(@tab_names) - 1)) {
		if ($current_tab eq "tab$tab") {
			push(@$tabs, $c->tag('span', class => 'nav-link active', $c->maketext($tab_names[$tab])));
		} else {
			push(
				@$tabs,
				$c->link_to(
					$c->maketext($tab_names[$tab]) =>
						$c->systemLink($c->url_for, params => { section_tab => "tab$tab" }),
					class => 'nav-link'
				)
			);
		}
	}
	return $c->tag('nav', class => 'config-tabs nav nav-pills justify-content-center my-4', $tabs->join(''));
}

sub getConfigValues ($c, $ce) {
	my $configValues = $ce->{ConfigValues};

	# Get the list of theme folders in the theme directory and remove . and .. and 'layouts'.
	my $themeDir = $ce->{webworkDirs}{themes};
	opendir(my $dh, $themeDir) || die "can't opendir $themeDir: $!";
	my $themes = [ grep { !/^\.{1,2}$/ && $_ ne 'layouts' } sort readdir($dh) ];

	# Get the list of all site hardcopy theme files
	opendir(my $dhS, $ce->{webworkDirs}{hardcopyThemes}) || die "can't opendir $ce->{webworkDirs}{hardcopyThemes}: $!";
	my $hardcopyThemesSite = [ grep {/\.xml$/} (sort readdir($dhS)) ];
	my @files;
	if (opendir(my $dhC, $ce->{courseDirs}{hardcopyThemes})) {
		@files = grep { /\.xml$/ && !/^\./ } sort readdir($dhC);
	}
	my @hardcopyThemesCourse;
	for my $hardcopyTheme (@files) {
		eval {
			# check that file is valid XML
			my $themeTree = XML::LibXML->load_xml(location => "$ce->{courseDirs}{hardcopyThemes}/$hardcopyTheme");
			push(@hardcopyThemesCourse, $hardcopyTheme);
		};
	}
	# get unique file names, merging lists from site and course folders
	my $hardcopyThemes = [
		sort(do {
			my %seen;
			grep { !$seen{$_}++ } (@$hardcopyThemesSite, @hardcopyThemesCourse);
		})
	];
	# get enabled site themes plus all course themes
	my $hardcopyThemesAvailable = [
		sort(do {
			my %seen;
			grep { !$seen{$_}++ } (@{ $ce->{hardcopyThemes} }, @hardcopyThemesCourse);
		})
	];

	# get list of localization dictionaries
	my $localizeDir = $ce->{webworkDirs}{localize};
	opendir(my $dh2, $localizeDir) || die "can't opendir $localizeDir: $!";
	my %seen      = ();    # find the languages in the localize direction
	my $languages = [
		grep { !$seen{$_}++ }                      # remove duplicate items
		map  { $_ =~ s/\.[pm]o$//r }               # get rid of suffix
		grep {/\.mo$|\.po$/} sort readdir($dh2)    #look at only .mo and .po files

	];

	# insert the anonymous array of theme names into configValues
	# FIXME?  Is there a reason this is an array? Couldn't we replace this
	# with a hash and conceptually simplify this routine? MEG
	my $modifyThemes = sub {
		my $item = shift;
		if (
			ref($item) =~ /HASH/
			&& ($item->{var} =~
				/^(defaultTheme|hardcopyThemesSite|hardcopyThemes|hardcopyTheme|hardcopyThemePGEditor)$/)
			)
		{
			$item->{values} = $themes if ($item->{var} eq 'defaultTheme');
			$item->{values} = $hardcopyThemesAvailable
				if ($item->{var} eq 'hardcopyTheme' || $item->{var} eq 'hardcopyThemePGEditor');
			$item->{values} = $hardcopyThemesSite if ($item->{var} eq 'hardcopyThemes');
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

	if (!$ce->{LTIVersion}) {
		# If LTI authentication is not enabled for this course, then remove the LTI tab.
		$configValues = [ grep { $_->[0] ne 'LTI' } @$configValues ];
	} else {
		# Remove the LTI settings for the LTI version that is not enabled for this course.
		for my $oneConfig (@$configValues) {
			next unless $oneConfig->[0] eq 'LTI';
			$oneConfig = [
				grep {
					ref($_) ne 'HASH' || $_->{var} !~ /^LTI\{v1p[13]\}/ || $_->{var} =~ /^LTI\{$ce->{LTIVersion}\}/
				} @$oneConfig
			];
			last;
		}
	}

	return $configValues;
}

sub pre_header_initialize ($c) {
	my $ce           = $c->ce;
	my $configValues = $c->getConfigValues($ce);
	# Get a course environment without course.conf
	$c->{default_ce} = WeBWorK::CourseEnvironment->new;

	$c->{ce_file_dir} = $ce->{courseDirs}{root};

	# Get a copy of the course environment which does not have simple.conf loaded
	my $ce3 = WeBWorK::CourseEnvironment->new({
		courseName          => $ce->{courseName},
		web_config_filename => 'noSuchFilePlease'
	});
	if ($c->param('make_changes')) {
		my $fileoutput = "#!perl
# This file is automatically generated by WeBWorK's web-based
# configuration module.  Do not make changes directly to this
# file.  It will be overwritten the next time configuration
# changes are saved.\n\n";

		# Get the number of the current tab
		my $tab = $c->param('section_tab') || 'tab0';
		$tab =~ s/tab//;
		# We completely rewrite the simple configuration file, so we need to go through all sections.
		for my $configSection (@{$configValues}) {
			my @configSectionArray = @{$configSection};
			shift @configSectionArray;
			for my $con (@configSectionArray) {
				my $conobject = $c->objectify($con);
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
		my @write_result = writeFile("$c->{ce_file_dir}/simple.conf", $fileoutput);
		if (@write_result) {
			$c->addbadmessage($c->c(@write_result)->join($c->tag('br')));
		} else {
			$c->addgoodmessage($c->maketext('Changes saved'));
		}
	}

	return;
}

1;
