################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/CourseEnvironment.pm,v 1.37 2007/08/10 16:37:10 sh002i Exp $
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

package WeBWorK::CourseEnvironment;

=head1 NAME

WeBWorK::CourseEnvironment - Read configuration information from defaults.config
and course.conf files.

=head1 SYNOPSIS

 use WeBWorK::CourseEnvironment;
 $ce = WeBWorK::CourseEnvironment->new({
 	webwork_url         => "/webwork2",
 	webwork_dir         => "/opt/webwork2",
 	pg_dir              => "/opt/pg",
 	webwork_htdocs_url  => "/webwork2_files",
 	webwork_htdocs_dir  => "/opt/webwork2/htdocs",
 	webwork_courses_url => "/webwork2_course_files",
 	webwork_courses_dir => "/opt/webwork2/courses",
 	courseName          => "name_of_course",
 });
 
 my $timeout = $courseEnv->{sessionKeyTimeout};
 my $mode    = $courseEnv->{pg}->{options}->{displayMode};
 # etc...

=head1 DESCRIPTION

The WeBWorK::CourseEnvironment module reads the system-wide F<defaults.config> and
course-specific F<course.conf> files used by WeBWorK to calculate and store
settings needed throughout the system. The F<.conf> files are perl source files
that can contain any code allowed under the default safe compartment opset.
After evaluation of both files, any package variables are copied out of the
safe compartment into a hash. This hash becomes the course environment.

=cut

use strict;
use warnings;
use Carp;
use WWSafe;
use WeBWorK::Utils qw(readFile);
use WeBWorK::Debug;
use Opcode qw(empty_opset);

=head1 CONSTRUCTION

=over

=item new(HASHREF)

HASHREF is a reference to a hash containing scalar variables with which to seed
the course environment. It must contain at least a value for the key
C<webworkRoot>.

The C<new> method finds the file F<conf/defaults.config> relative to the given
C<webwork_dir> directory. After reading this file, it uses the
C<$courseFiles{environment}> variable, if present, to locate the course
environment file. If found, the file is read and added to the environment.

=item new(ROOT URLROOT PGROOT COURSENAME)

A deprecated form of the constructor in which four seed variables are given
explicitly: C<webwork_dir>, C<webwork_url>, C<pg_dir>, and C<courseName>.

=cut

# NEW SYNTAX
# 
# new($invocant, $seedVarsRef)
#   $invocant       implicitly set by caller
#   $seedVarsRef    reference to hash containing scalar variables with which to
#                   seed the course environment
# 
# OLD SYNTAX
# 
# new($invocant, $webworkRoot, $webworkURLRoot, $pgRoot, $courseName)
#   $invocant          implicitly set by caller
#   $webworkRoot       directory that contains the WeBWorK distribution
#   $webworkURLRoot    URL that points to the WeBWorK system
#   $pgRoot            directory that contains the PG distribution
#   $courseName        name of the course being used
sub new {
	my ($invocant, @rest) = @_;
	my $class = ref($invocant) || $invocant;
	
	# contains scalar symbols/values with which to seed course environment
	my %seedVars;
	
	# where do we get the seed variables?
	if (ref $rest[0] eq "HASH") {
		%seedVars = %{$rest[0]};
	} else {
		debug __PACKAGE__, ": deprecated four-argument form of new() used.", caller(1),"\n", caller(2),"\n";
		$seedVars{webwork_dir}    = $rest[0];
		$seedVars{webwork_url}    = $rest[1];
		$seedVars{pg_dir}         = $rest[2];
		$seedVars{courseName}     = $rest[3];
	}
	$seedVars{courseName} = $seedVars{courseName}||"___"; # prevents extraneous error messages
	my $safe = WWSafe->new;
	$safe->permit('rand');
	# to avoid error messages make sure that courseName is defined
	$seedVars{courseName} = $seedVars{courseName}//"foobar_course";
	# seed course environment with initial values
	while (my ($var, $val) = each %seedVars) {
		$val = "" if not defined $val;
		$safe->reval("\$$var = '$val';");
	}

	# Compile the "include" function with all opcodes available.
	my $include = q[ sub include {
		my ($file) = @_;
		my $fullPath = "].$seedVars{webwork_dir}.q[/$file";
		# This regex matches any string that begins with "../",
		# ends with "/..", contains "/../", or is "..".
		if ($fullPath =~ m!(?:^|/)\.\.(?:/|$)!) {
			die "Included file $file has potentially insecure path: contains \"..\"";
		} else {
			local @INC = ();
			my $result = do $fullPath;
			if ($!) {
				die "Failed to read include file $fullPath (has it been created from the corresponding .dist file?): $!";
			} elsif ($@) {
				die "Failed to compile include file $fullPath: $@";
			} elsif (not $result) {
				die "Include file $fullPath did not return a true value.";
			}
		}
	} ];
	
	my $maskBackup = $safe->mask;
	$safe->mask(empty_opset);
	$safe->reval($include);
	$@ and die "Failed to reval include subroutine: $@";
	$safe->mask($maskBackup);
	
	# determine location of globalEnvironmentFile
	my $globalEnvironmentFile;
	if (-r "$seedVars{webwork_dir}/conf/defaults.config") {
		$globalEnvironmentFile = "$seedVars{webwork_dir}/conf/defaults.config";
	} else {
		croak "Cannot read global environment file $globalEnvironmentFile";
	}

	# read and evaluate the global environment file
	my $globalFileContents = readFile($globalEnvironmentFile);
	# warn "about to evaluate defaults.conf $seedVars{courseName}\n";
	# warn  join(" | ", (caller(1))[0,1,2,3,4] ), "\n";
	$safe->share_from('main', [qw(%ENV)]);
	$safe->reval($globalFileContents);
	# warn "end the evaluation\n";
	
	# if that evaluation failed, we can't really go on...
	# we need a global environment!
	$@ and croak "Could not evaluate global environment file $globalEnvironmentFile: $@";
	
	# determine location of courseEnvironmentFile and simple configuration file
	# pull it out of $safe's symbol table ad hoc
	# (we don't want to do the hash conversion yet)
	no strict 'refs';
	my $courseEnvironmentFile = ${*{${$safe->root."::"}{courseFiles}}}{environment};
	my $courseWebConfigFile = $seedVars{web_config_filename} ||
		${*{${$safe->root."::"}{courseFiles}}}{simpleConfig};
	use strict 'refs';
	
	# read and evaluate the course environment file
	# if readFile failed, we don't bother trying to reval
	my $courseFileContents = eval { readFile($courseEnvironmentFile) }; # catch exceptions
	$@ or $safe->reval($courseFileContents);
	my $courseWebConfigContents = eval { readFile($courseWebConfigFile) }; # catch exceptions
	$@ or $safe->reval($courseWebConfigContents);
	
	# get the safe compartment's namespace as a hash
	no strict 'refs';
	my %symbolHash = %{$safe->root."::"};
	use strict 'refs';
	
	# convert the symbol hash into a hash of regular variables.
	my $self = {};
	foreach my $name (keys %symbolHash) {
		# weed out internal symbols
		next if $name =~ /^(INC|_.*|__ANON__|main::)$/;
		# pull scalar, array, and hash values for this symbol
		my $scalar = ${*{$symbolHash{$name}}};
		my @array = @{*{$symbolHash{$name}}};
		my %hash = %{*{$symbolHash{$name}}};
		# for multiple variables sharing a symbol, scalar takes precedence
		# over array, which takes precedence over hash.
		if (defined $scalar) {
			$self->{$name} = $scalar;
		} elsif (@array) {
			$self->{$name} = \@array;
		} elsif (%hash) {
			$self->{$name} = \%hash;
		}
	}
	
	bless $self, $class;
	
	# here is where we can do evil things to the course environment *sigh*
	# anything changed has to be done here. after this, CE is considered read-only
	# anything added must be prefixed with an underscore.
	
	# create reverse-lookup hash mapping status abbreviations to real names
	$self->{_status_abbrev_to_name} = {
		map { my $name = $_; map { $_ => $name } @{$self->{statuses}{$name}{abbrevs}} }
			keys %{$self->{statuses}}
	};
	
	# now that we're done, we can go ahead and return...
	return $self;
}

=back

=head1 ACCESS

There are no formal accessor methods. However, since the course environemnt is
a hash of hashes and arrays, is exists as the self hash of an instance
variable:

	$ce->{someKey}{someOtherKey};

=head1 EXPERIMENTAL ACCESS METHODS

This is an experiment in extending CourseEnvironment to know a little more about
its contents, and perform useful operations for me.

There is a set of operations that require certain data from the course
environment. Most of these are un Utils.pm. I've been forced to pass $ce into
them, so that they can get their data out. But some things are so intrinsically
linked to the course environment that they might as well be methods in this
class.

=head2 STATUS METHODS

=over

=item status_abbrev_to_name($status_abbrev)

Given the abbreviation for a status, return the name. Returns undef if the
abbreviation is not found.

=cut

sub status_abbrev_to_name {
	my ($ce, $status_abbrev) = @_;
	if (not defined $status_abbrev or $status_abbrev eq "") {
		carp "status_abbrev_to_name: status_abbrev (first argument) must be defined and non-empty";
		return;
	}
	
	return $ce->{_status_abbrev_to_name}{$status_abbrev};
}

=item status_name_to_abbrevs($status_name)

Returns the list of abbreviations for a given status. Returns an empty list if
the status is not found.

=cut

sub status_name_to_abbrevs {
	my ($ce, $status_name) = @_;
	if (not defined $status_name or $status_name eq "") {
		carp "status_name_to_abbrevs: status_name (first argument) must be defined and non-empty";
		return;
	}
	
	return unless exists $ce->{statuses}{$status_name};
	return @{$ce->{statuses}{$status_name}{abbrevs}};
}

=item status_has_behavior($status_name, $behavior)

Return true if $status_name lists $behavior.

=cut

sub status_has_behavior {
	my ($ce, $status_name, $behavior) = @_;
	if (not defined $status_name or $status_name eq "") {
		carp "status_has_behavior: status_name (first argument) must be defined and non-empty";
		return;
	}
	if (not defined $behavior or $behavior eq "") {
		carp "status_has_behavior: behavior (second argument) must be defined and non-empty";
		return;
	}
	
	if (exists $ce->{statuses}{$status_name}) {
		if (exists $ce->{statuses}{$status_name}{behaviors}) {
			my $num_matches = grep { $_ eq $behavior } @{$ce->{statuses}{$status_name}{behaviors}};
			return $num_matches > 0;
		} else {
			return 0; # no behaviors
		}
	} else {
		warn "status '$status_name' not found in \%statuses -- assuming no behaviors.\n";
		return 0;
	}
}

=item status_abbrev_has_behavior($status_abbrev, $behavior)

Return true if the status abbreviated by $status_abbrev lists $behavior.

=cut

sub status_abbrev_has_behavior {
	my ($ce, $status_abbrev, $behavior) = @_;
	if (not defined $status_abbrev or $status_abbrev eq "") {
		carp "status_abbrev_has_behavior: status_abbrev (first argument) must be defined and non-empty";
		return;
	}
	if (not defined $behavior or $behavior eq "") {
		carp "status_abbrev_has_behavior: behavior (second argument) must be defined and non-empty";
		return;
	}
	
	my $status_name = $ce->status_abbrev_to_name($status_abbrev);
	if (defined $status_name) {
		return $ce->status_has_behavior($status_name, $behavior);
	} else {
		warn "status abbreviation '$status_abbrev' not found in \%statuses -- assuming no behaviors.\n";
	}
}

=back

=cut

1;

# perl doesn't look like line noise. line noise has way more alphanumerics.
