################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2017 The WeBWorK Project, http://openwebwork.sf.net/
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

package WeBWorK::Utils::DetermineProblemLangAndDirection;
use base qw(Exporter);

=head1 NAME

WeBWorK::Utils::DetermineProblemLangAndDirection - utilities to determine
the language and text direction of a problem based on settings from the
PG flags, the course configuration variable $perProblemLangAndDirSettingMode,
and the course language.

=head1 SYNOPSIS

 use WeBWorK::Utils::DetermineProblemLangAndDirection;

=head1 DESCRIPTION

This module provides s function which determines the "recommended"
language and text direction of a problem based on settings from the                                                                         
PG flags, the course configuration variable $perProblemLangAndDirSettingMode,                                                                  and the course language.

=cut

use strict;
use warnings;
use Carp;
use WeBWorK::PG; 
use WeBWorK::Debug;

our @EXPORT    = qw(get_problem_lang_and_dir);
our @EXPORT_OK = ();


=head1 FUNCTIONS

=over

=item get_problem_lang_and_dir subroutine

 @output = get_problem_lang_and_dir( $self, $pg [,$requested_mode,$ce_lang] );

returns an array of tagname tagvalue pairs.

In some cases, the result is empty.

Use the optional arguments $requested_mode,$ce_lang when $self
does not contain a request object. This was required for the
use of this code in lib/WebworkClient.pm.

=cut

# get_problem_lang_and_dir subroutine

# used to determine the language and maybe also the dir setting for the 
# DIV tag attributes, if needed by the PROBLEM language

# Return an array of key-value pairs key1 val1 key2 val2

sub get_problem_lang_and_dir {
    my $self = shift;
    my $pg   = shift;
    
    my @result = ();
    
    # Get the value for ce_requested_mode:
    #   First check for the optional argument.
    #   Otherwise try getting from $self->r->ce->{perProblemLangAndDirSettingMode}
    #     if it is defined.
    #   If those both failed, fall back to "none".
    my $ce_requested_mode = shift;
    if ( ! defined($ce_requested_mode ) ) {
	if ( defined( $self->r ) &&
	     defined( $self->r->ce ) &&
	     defined( $self->r->ce->{perProblemLangAndDirSettingMode} ) ) {
	  $ce_requested_mode = $self->r->ce->{perProblemLangAndDirSettingMode}; # Mode requested
	} else {
	  $ce_requested_mode = "none"; # Default
	}
    }

    if ( $ce_requested_mode eq "none" ) {
	# Requested mode is "none" so no output should be made.
	return( @result );
    }
    
    # Get course-wide language setting:
    #   First check for the optional argument.
    #   Otherwise try getting from $self->r->ce->{language}
    #     if it is defined.
    #   If those both failed, fall back to "en".
    my $ce_lang = shift;

    if ( ! defined($ce_lang ) ) {
	if ( defined( $self->r ) &&
	     defined( $self->r->ce ) &&
	     defined( $self->r->ce->{language} ) ) {
	  $ce_lang = $self->r->ce->{language}; # Course wide setting
	} else {
	  $ce_lang = "en";
	}
    }

    my $ce_dir = "ltr"; # default
    
    if ( $ce_lang =~ /^he/i ) { # supports also the current "heb" option
	# Hebrew - requires RTL direction
	$ce_lang = "he";  # Hebrew - standard form
	$ce_dir  = "rtl"; # RTL
    } elsif ( $ce_lang =~ /^ar/i ) {
	# Arabic - requires RTL direction
	$ce_lang = "ar";  # Arabic
	$ce_dir  = "rtl"; # RTL
    }

    my @tmp1 = split(':',$ce_requested_mode);
    my $reqMode = $tmp1[0];
    my $reqLang = $tmp1[1];
    my $reqDir  = $tmp1[2];
    
    $reqLang = "none" if ( ! defined( $reqMode ) );
    $reqLang = ""     if ( ! defined( $reqLang ) );
    $reqDir  = ""     if ( ! defined( $reqDir  ) );
    
    if ( $reqMode eq "force" ) {
	# Requested mode is to force the LANG and DIR attributes regardless of lang data from problem PG code.
	if ( $reqLang ne "" ) {
	    push( @result, "lang", $reqLang ); # forced setting
	}
	push( @result, "dir", $reqDir ); # forced setting
	return( @result );
    }
    
    if ( $reqMode ne "auto" ) {
	# The mode setting is not valid, treat like none
	return( @result );
    }
    
    # We are now handling an "auto" setting, so want to handle data from PG
    
    my $pg_lang = "en-US"; # system default
    my $pg_dir  = "ltr";   # system default
    
    # Determine the language code to use
    if ( defined( $pg->{flags}->{language} ) ) {
	# Language set by PG
	$pg_lang = $pg->{flags}->{language};
    } else {
	# Language not set by PG, use provided default language (if set) or fall back to the system default
	if ( $reqLang ne "" ) {
	    $pg_lang = $reqLang;
	}
    }
    
    # Determine the direction code to use
    # we changed the order of precedence here.
    if ( defined( $pg->{flags}->{textdirection} ) ) {
	# Direction set by PG
	$pg_dir =  $pg->{flags}->{textdirection};
    } elsif ( defined( $pg->{flags}->{language} ) ) {
	# Direction not set by PG, 
	# but PG did set the language.
	# Fallback is to use LTR, except for Hebrew and Arabic.
	$pg_dir  = "ltr"; # correct for most languages
	if ( ( $pg->{flags}->{language} =~ /^he/i ) ||
	     ( $pg->{flags}->{language} =~ /^ar/i )    ) {
	    $pg_dir  = "rtl"; # should be correct for these languages
	}
    } elsif ( $reqDir ne "" ) {
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
    $pg_lang = lc( $pg_lang );
    $pg_dir  = lc( $pg_dir );
    $ce_lang = lc( $ce_lang );
    $ce_dir  = lc( $ce_dir );
    
    # We are ALWAYS setting this for this mode.
    push( @result, "lang", $pg_lang ); # send the problem language that was selected
    
    if ( ( $ce_dir eq "rtl" ) && # Possible hack for RTL direction courses and OPL problems
	 ( $reqDir eq "rtl" ) &&
	 ! defined( $pg->{flags}->{textdirection} ) && 	   # problem does not set the language or
	 ! defined( $pg->{flags}->{language} )         ) { #                      the text direction
	# In a RTL language course, we may really want to force LTR use for unknown problems.
	# that would best be handled by always including the language setting in RTL language
	# problems, and using a setting which falls back to LTR when there is no setting from
	# the problem (expected on OPL problems).
	
	# May want to issue a warning
	
	# Right now - we are not trying to do the following
	# push( @result, "dir", "ltr" ); # override to problem textdirection or "expected" LTR textdirection
    }

    # We are ALWAYS setting this for this mode.
    push( @result, "dir", $pg_dir ); # override to $pg_dir

    # " ce_lang $ce_lang ce_dir $ce_dir reqMain $reqMain reqLang $reqLand reqDir $reqDir result_lang $pg_lang result_dir $pg_dir ";

    return( @result );
}


=back

=cut

=head1 AUTHOR

Written by Nathan Wallach, tani (at) mathnet.technion.ac.il

=cut

1;
