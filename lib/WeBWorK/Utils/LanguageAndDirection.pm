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
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::Utils::LanguageAndDirection;
use base qw(Exporter);

=head1 NAME

WeBWorK::Utils::LanguageAndDirection - utilities to determine the language and text
direction for a page based on language, or for a problem based on settings from the
PG flags, the course configuration variable $perProblemLangAndDirSettingMode, and
the course language.

=head1 SYNOPSIS

 use WeBWorK::Utils::LanguageAndDirection;

=head1 DESCRIPTION

This module provides functions to determine the language and text direction for a
page based on language, or for a problem based on settings from the PG flags, the
course configuration variable $perProblemLangAndDirSettingMode, and the course
language.

=cut

use strict;
use warnings;
use Carp;
use WeBWorK::PG;
use WeBWorK::Debug;

our @EXPORT = qw(get_lang_and_dir get_problem_lang_and_dir);
our @EXPORT_OK = ();

=head1 FUNCTIONS

=over

=item get_lang_and_dir()

Returns the LANG attribute and when needed the DIR attribute based on the language.

It selects the language based on the given language code and otherwise defaults to
lang="en-US".

When the language chosen is a known right to left language, it will also set
the DIR attribute to "rtl". Currently, only Hebrew ("heb" or "he") and
Arabic ("ar") trigger the RTL direction setting.

=cut

sub get_lang_and_dir {
	my $lang = shift;
	my $master_lang_setting = "lang=\"en-US\""; # default setting
	my $master_dir_setting  = "";               # default is NOT set

	if ($lang eq "en") {
		$master_lang_setting = "lang=\"en-US\""; # as in default
	} elsif ($lang =~ /^he/i) { # supports also the current "heb" option
		# Hebrew - requires RTL direction
		$master_lang_setting = "lang=\"he\""; # Hebrew
		$master_dir_setting  = "dir=\"rtl\""; # RTL
	} elsif ($lang =~ /^ar/i) {
		# Hebrew - requires RTL direction
		$master_lang_setting = "lang=\"ar\""; # Arabic
		$master_dir_setting  = "dir=\"rtl\""; # RTL
	} else {
		# use the language setting of the course, with NO direction setting
		$master_lang_setting = "lang=\"${lang}\"";
	}

	return "$master_lang_setting $master_dir_setting";
}

=item get_problem_lang_and_dir subroutine

 @output = get_problem_lang_and_dir($pg_flags, $requested_mode, $lang);
or
 $output = get_problem_lang_and_dir($pg_flags, $requested_mode, $lang);

Used to determine the language and maybe also the dir setting for the
DIV tag attributes, if needed by the PROBLEM language.

$pg_flags is a reference to the "flags" hash of a pg problem.

$requested_mode is optional, and if provided should be a string containing the
mode (one of "force", "auto", or ""), language code, and direction separated by
colons.  Alternately $requested_mode may be "none".  If it is "none" or
undefined the return result is empty.

$lang is also optional, and should the language code if provided.

Return a hash of key-value pairs (eg. lang => "eng", dir => "ltr") in list context,
and a string (eg. ' lang="eng" dir="ltr"') in scalar context.
In some cases, the return result is empty.

=cut

sub get_problem_lang_and_dir {
	my $pg_flags = shift;
	my $requested_mode = shift;
	my $lang = shift;

	my %result;

	# Requested mode is undefined or "none" so no output should be made.
	return (wantarray ? %result : "") if (!defined($requested_mode) || $requested_mode eq "none");

	$lang = "en" unless defined($lang);

	my $dir = "ltr"; # default

	if ($lang =~ /^he/i) { # supports also the current "heb" option
		# Hebrew - requires RTL direction
		$lang = "he";  # Hebrew - standard form
		$dir  = "rtl"; # RTL
	} elsif ($lang =~ /^ar/i) {
		# Arabic - requires RTL direction
		$lang = "ar";  # Arabic
		$dir  = "rtl"; # RTL
	}

	my @tmp1 = split(':', $requested_mode);
	my $reqMode = $tmp1[0];
	my $reqLang = $tmp1[1];
	my $reqDir  = $tmp1[2];

	$reqLang = "none" unless defined($reqMode);
	$reqLang = ""     unless defined($reqLang);
	$reqDir  = ""     unless defined($reqDir);

	if ($reqMode eq "force") {
		# Requested mode is to force the LANG and DIR attributes regardless of lang data from problem PG code.
		if ($reqLang ne "") {
			$result{lang} = $reqLang; # forced setting
		}
		$result{dir} = $reqDir; # forced setting
		return wantarray ? %result : join("", map { qq{ $_="$result{$_}"} } keys %result);
	}

	if ($reqMode ne "auto") {
		# The mode setting is not valid, treat like none
		return wantarray ? %result : "";
	}

	# We are now handling an "auto" setting, so want to handle data from PG

	my $pg_lang = "en-US"; # system default
	my $pg_dir  = "ltr";   # system default

	# Determine the language code to use
	if (defined($pg_flags->{language})) {
		# Language set by PG
		$pg_lang = $pg_flags->{language};
	} else {
		# Language not set by PG, use provided default language (if set) or fall back to the system default
		if ($reqLang ne "") {
			$pg_lang = $reqLang;
		}
	}

	# Determine the direction code to use
	# we changed the order of precedence here.
	if (defined($pg_flags->{textdirection})) {
		# Direction set by PG
		$pg_dir =  $pg_flags->{textdirection};
	} elsif (defined($pg_flags->{language})) {
		# Direction not set by PG,
		# but PG did set the language.
		# Fallback is to use LTR, except for Hebrew and Arabic.
		$pg_dir  = "ltr"; # correct for most languages
		if (($pg_flags->{language} =~ /^he/i) ||
			($pg_flags->{language} =~ /^ar/i)) {
			$pg_dir  = "rtl"; # should be correct for these languages
		}
	} elsif ($reqDir ne "") {
		# We have a request for a direction when PG did not set it
		$pg_dir = $reqDir;
	} else {
		# Direction not set by PG, nor was a default setting provided
		# and PG did NOT set the language.
		# For SetMaker, we are assuming that a problem without a PG direction
		# setting should be in LTR mode.
		$pg_dir  = "ltr"; # correct for most languages

		# Even for Arabic and Hebrew do NOT change to RTL.
		# The teacher should add the language and direction setting to
		# the PG file of the problem.
	}

	# Make these string all lowercase (just in case)
	$pg_lang = lc($pg_lang);
	$pg_dir  = lc($pg_dir);
	$lang = lc($lang);
	$dir  = lc($dir);

	# We are ALWAYS setting this for this mode.
	$result{lang} = $pg_lang; # send the problem language that was selected

	if (($dir eq "rtl") && # Possible hack for RTL direction courses and OPL problems
		($reqDir eq "rtl") &&
		! defined($pg_flags->{textdirection}) && # problem does not set the language or
		! defined($pg_flags->{language})) { # the text direction
		# In a RTL language course, we may really want to force LTR use for unknown problems.
		# that would best be handled by always including the language setting in RTL language
		# problems, and using a setting which falls back to LTR when there is no setting from
		# the problem (expected on OPL problems).

		# May want to issue a warning

		# Right now - we are not trying to do the following
		# $result{dir} = "ltr"; # override to problem textdirection or "expected" LTR textdirection
	}

	# We are ALWAYS setting this for this mode.
	$result{dir} = $pg_dir; # override to $pg_dir

	return wantarray ? %result : join("", map { qq{ $_="$result{$_}"} } keys %result);
}


=back

=cut

=head1 AUTHOR

Written by Nathan Wallach, tani (at) mathnet.technion.ac.il

=cut

1;
