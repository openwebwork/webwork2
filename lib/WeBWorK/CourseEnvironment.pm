################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

 my $timeout = $courseEnv->{sessionTimeout};
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
use feature 'state';

use Carp;
use Opcode qw(empty_opset);

use WeBWorK::WWSafe;
use WeBWorK::Utils::Files qw(readFile);
use WeBWorK::Debug;

=head1 CONSTRUCTION

=over

=item new($seedVars)

C<$seedVars> is an optional argument.  If provided it must be a reference to a
hash containing scalar variables with which to seed the course environment. It
may contain values for the keys C<webwork_dir>, C<pg_dir>, C<courseName>, and
C<web_config_filename>.

If C<webwork_dir> or C<pg_dir> are not given in C<$seedVars> they will be taken
from the C<%WeBWorK::SeedCE> hash.  If they are still not found in that hash,
then they will be taken from the system environment variables C<WEBWORK_ROOT>
and C<PG_ROOT>.

The C<new> method finds the file F<conf/defaults.config> relative to the
C<webwork_dir> directory. After reading this file, it uses the
C<$courseFiles{environment}> variable, if present, to locate the course
environment file. If found, the file is read and added to the environment.

=cut

sub new {
	my ($invocant, $seedVars) = @_;
	my $class = ref($invocant) || $invocant;

	$seedVars //= {};
	croak __PACKAGE__ . ": The only argument for new must be a hash reference.\n" unless ref($seedVars) eq 'HASH';

	# Get the webwork_dir and pg_dir from the SeedCE or the environment if not set.
	$seedVars->{webwork_dir} //= $WeBWorK::SeedCE{webwork_dir} // $ENV{WEBWORK_ROOT};
	$seedVars->{pg_dir}      //= $WeBWorK::SeedCE{pg_dir}      // $ENV{PG_ROOT};

	$seedVars->{courseName} ||= '___';    # prevents extraneous error messages

	# The following line is a work around for a bug that occurs on some systems.  See
	# https://rt.cpan.org/Public/Bug/Display.html?id=77916 and
	# https://github.com/openwebwork/webwork2/pull/2098#issuecomment-1619812699.
	my %dummy = %+;

	my @warnings;
	my $outer_sig_warn = $SIG{__WARN__};
	local $SIG{__WARN__} = sub { push(@warnings, $_[0]); };

	my $safe = WeBWorK::WWSafe->new;
	$safe->permit('rand');

	# seed course environment with initial values
	while (my ($var, $val) = each %$seedVars) {
		$val //= '';
		$safe->reval("\$$var = '$val';");
	}

	# Compile the "include" function with all opcodes available.
	my $include = q[ sub include {
		my ($file) = @_;
		state @dieMessages;
		my $fullPath = "] . $seedVars->{webwork_dir} . q[/$file";
		# This regex matches any string that begins with "../",
		# ends with "/..", contains "/../", or is "..".
		if ($fullPath =~ m!(?:^|/)\.\.(?:/|$)!) {
			die "Included file $file has potentially insecure path: contains \"..\"";
		} else {
			local @INC = ();
			local $SIG{__DIE__} = sub { push(@dieMessages, $_[0]) };
			my $result = do $fullPath;
			if (@dieMessages) {
				die pop @dieMessages;
			} elsif ($@) {
				die "Failed to compile include file $fullPath: $@";
			} elsif ($!) {
				die "Failed to read include file $fullPath (has it been created from the corresponding .dist file?): $!";
			} elsif (!$result) {
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
	if (-r "$seedVars->{webwork_dir}/conf/defaults.config") {
		$globalEnvironmentFile = "$seedVars->{webwork_dir}/conf/defaults.config";
	} else {
		croak "Cannot read global environment file $globalEnvironmentFile";
	}

	# read and evaluate the global environment file
	my $globalFileContents = readFile($globalEnvironmentFile);
	$safe->share_from('main', [qw(%ENV)]);
	$safe->reval($globalFileContents);

	# if that evaluation failed, we can't really go on...
	# we need a global environment!
	if ($@) {
		# Make sure any warnings that occurred are passed back to the global warning handler.
		local $SIG{__WARN__} = ref($outer_sig_warn) eq 'CODE' ? $outer_sig_warn : 'DEFAULT';
		warn $_ for @warnings;
		croak "Could not evaluate global environment file $globalEnvironmentFile: $@";
	}

	# determine location of courseEnvironmentFile and simple configuration file
	# pull it out of $safe's symbol table ad hoc
	# (we don't want to do the hash conversion yet)
	no strict 'refs';
	my $courseEnvironmentFile = ${ *{ ${ $safe->root . "::" }{courseFiles} } }{environment};
	my $courseWebConfigFile   = $seedVars->{web_config_filename}
		|| ${ *{ ${ $safe->root . "::" }{courseFiles} } }{simpleConfig};
	use strict 'refs';

	# make sure the course environment file actually exists (it might not if we don't have a real course)
	# before we try to read it
	if (-r $courseEnvironmentFile) {
		# read and evaluate the course environment file
		# if readFile failed, we don't bother trying to reval
		my $courseFileContents = eval { readFile($courseEnvironmentFile) };       # catch exceptions
		$@ or $safe->reval($courseFileContents);
		my $courseWebConfigContents = eval { readFile($courseWebConfigFile) };    # catch exceptions
		$@ or $safe->reval($courseWebConfigContents);
	}

	# Pass any warnings that occurred back to the global warning handler.
	local $SIG{__WARN__} = ref($outer_sig_warn) eq 'CODE' ? $outer_sig_warn : 'DEFAULT';
	warn $_ for @warnings;

	# get the safe compartment's namespace as a hash
	no strict 'refs';
	my %symbolHash = %{ $safe->root . "::" };
	use strict 'refs';

	# convert the symbol hash into a hash of regular variables.
	my $self = {};
	foreach my $name (keys %symbolHash) {
		# weed out internal symbols
		next if $name =~ /^(INC|_.*|__ANON__|main::|include)$/;
		# pull scalar, array, and hash values for this symbol
		my $scalar = ${ *{ $symbolHash{$name} } };
		my @array  = @{ *{ $symbolHash{$name} } };
		my %hash   = %{ *{ $symbolHash{$name} } };
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
	# now that we know the name of the pg_dir we can get the pg VERSION file
	my $PG_version_file = $self->{'pg_dir'} . "/VERSION";

	# Try a fallback location
	if (!-r $PG_version_file) {
		$PG_version_file = $self->{'webwork_dir'} . "/../pg/VERSION";
	}
	# #	We'll get the pg version here and read it into the safe symbol table
	if (-r $PG_version_file) {
		my $PG_version_file_contents = readFile($PG_version_file) // '';
		$safe->reval($PG_version_file_contents);

		no strict 'refs';
		my %symbolHash2 = %{ $safe->root . "::" };
		use strict 'refs';
		$self->{PG_VERSION} = ${ *{ $symbolHash2{PG_VERSION} } };
	} else {
		$self->{PG_VERSION} = "unknown";
		warn "Cannot read PG version file $PG_version_file";
	}

	bless $self, $class;

	# here is where we can do evil things to the course environment *sigh*
	# anything changed has to be done here. after this, CE is considered read-only
	# anything added must be prefixed with an underscore.

	# create reverse-lookup hash mapping status abbreviations to real names
	$self->{_status_abbrev_to_name} = {
		map {
			my $name = $_;
			map { $_ => $name } @{ $self->{statuses}{$name}{abbrevs} }
		}
			keys %{ $self->{statuses} }
	};

	# Make sure that this is set in case it is not defined in site.conf.
	$self->{pg_htdocs_url} //= '/pg_files';

	# Fixup for courses that still have an underscore, 'heb', 'zh_hk', or 'en_us' saved in their settings files.
	$self->{language} =~ s/_/-/g;
	$self->{language} = 'he-IL' if $self->{language} eq 'heb';
	$self->{language} = 'zh-HK' if $self->{language} eq 'zh-hk';
	$self->{language} = 'en'    if $self->{language} eq 'en-us';

	# now that we're done, we can go ahead and return...
	return $self;
}

=back

=head1 ACCESS

The course environment is a hash and variables in the course environment can be
accessed via its hash keys.  For example:

    $ce->{someKey}{someOtherKey};

=head1 METHODS

=head2 status_abbrev_to_name

Usage: C<< $ce->status_abbrev_to_name($status_abbrev) >>

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

=head2 status_name_to_abbrevs

Usage: C<< $ce->status_name_to_abbrevs($status_name) >>

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
	return @{ $ce->{statuses}{$status_name}{abbrevs} };
}

=head2 status_has_behavior

Usage: C<< $ce->status_has_behavior($status_name, $behavior) >>

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
			my $num_matches = grep { $_ eq $behavior } @{ $ce->{statuses}{$status_name}{behaviors} };
			return $num_matches > 0;
		} else {
			return 0;    # no behaviors
		}
	} else {
		warn "status '$status_name' not found in \%statuses -- assuming no behaviors.\n";
		return 0;
	}
}

=head2 status_abbrev_has_behavior

Usage: C<< status_abbrev_has_behavior($status_abbrev, $behavior) >>

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

=head2 two_factor_authentication_enabled

Usage: C<< $ce->two_factor_authentication_enabled >>

Returns true if two factor authentication is enabled for this course.

=cut

sub two_factor_authentication_enabled {
	my $ce = shift;
	return 0                                                           if $ce->{external_auth};
	return grep { $_ eq $ce->{courseName} } @{ $ce->{twoFA}{enabled} } if (ref($ce->{twoFA}{enabled}) eq 'ARRAY');
	return 1 if $ce->{twoFA}{enabled} ^ $ce->{twoFA}{enabled} && $ce->{courseName} eq $ce->{twoFA}{enabled};
	return 0 if $ce->{twoFA}{enabled} ^ $ce->{twoFA}{enabled};
	return $ce->{twoFA}{enabled};
}

1;
