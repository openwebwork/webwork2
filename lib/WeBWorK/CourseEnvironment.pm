################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/CourseEnvironment.pm,v 1.23 2003/12/09 01:12:30 sh002i Exp $
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

WeBWorK::CourseEnvironment - Read configuration information from global.conf
and course.conf files.

=cut

use strict;
use warnings;
use Safe;
use WeBWorK::Utils qw(readFile);
use Opcode qw(empty_opset);

# new($invocant, $webworkRoot, $webworkURLRoot, $pgRoot, $courseName)
# $invocant             implicitly set by caller
# $webworkRoot          directory that contains the WeBWorK distribution
# $webworkURLRoot       URL that points to the WeBWorK system
# $pgRoot               directory that contains the PG distribution
# $courseName		name of the course being used
sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $webworkRoot = shift;
	my $webworkURLRoot = shift;
	my $pgRoot = shift;
	my $courseName = shift || "";
	my $safe = Safe->new;
	
	# set up some defaults that the environment files will need
	$safe->reval("\$webworkRoot = '$webworkRoot'");
	$safe->reval("\$webworkURLRoot = '$webworkURLRoot'");
	$safe->reval("\$pgRoot = '$pgRoot'");
	$safe->reval("\$courseName = '$courseName'");
	
	# Compile the "include" function with all opcodes available.
	my $include = q[ sub include {
		my ($file) = @_;
		my $fullPath = "].$webworkRoot.q[/$file";
		# This regex matches any string that begins with "../",
		# ends with "/..", contains "/../", or is "..".
		if ($fullPath =~ m!(?:^|/)\.\.(?:/|$)!) {
			die "Included file $file has potentially insecure path: contains \"..\"";
		} else {
			local @INC = ();
			unless (my $result = do $fullPath) {
				# FIXME: "do" is misbehaving: if there's a syntax error, $@
				# should be set to the error string, but it's not getting set.
				# $! is set to an odd error message "Broken pipe" or something.
				# On the command line, both $! and $@ are set in the case of a
				# syntax error. This just means that errors will be confusing.
				$! and die "Failed to read include file $fullPath: $! (has it been created from the corresponding .dist file?)";
				$@ and die "Failed to compile include file $fullPath: $@";
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
	my $globalEnvironmentFile = "$webworkRoot/conf/global.conf";
	
	# read and evaluate the global environment file
	my $globalFileContents = readFile($globalEnvironmentFile);
	$safe->reval($globalFileContents);
	
	# if that evaluation failed, we can't really go on...
	# we need a global environment!
	$@ and die "Could not evaluate global environment file $globalEnvironmentFile: $@";
	
	# determine location of courseEnvironmentFile
	# pull it out of $safe's symbol table ad hoc
	# (we don't want to do the hash conversion yet)
	no strict 'refs';
	my $courseEnvironmentFile = ${*{${$safe->root."::"}{courseFiles}}}{environment};
	use strict 'refs';
	
	# read and evaluate the course environment file
	# if readFile failed, we don't bother trying to reval
	my $courseFileContents = eval { readFile($courseEnvironmentFile) }; # catch exceptions
	$@ or $safe->reval($courseFileContents);
	
	# get the safe compartment's namespace as a hash
	no strict 'refs';
	my %symbolHash = %{$safe->root."::"};
	use strict 'refs';
	
	# convert the symbol hash into a hash of regular variables.
	my $self = {};
	foreach my $name (keys %symbolHash) {
		# weed out internal symbols
		next if $name =~ /^(INC|_|__ANON__|main::)$/;
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
	return $self;
}

1;

__END__

=head1 SYNOPSIS

	use WeBWorK::CourseEnvironment;
	$courseEnv = WeBWorK::CourseEnvironment->new($webworkRoot, $courseName);
	
	$timeout = $courseEnv->{sessionKeyTimeout};
	$mode    = $courseEnv->{pg}->{options}->{displayMode};
	# etc...

=head1 DESCRIPTION

The WeBWorK::CourseEnvironment module reads the system-wide F<global.conf> and
course-specific F<course.conf> files used by WeBWorK to calculate and store
settings needed throughout the system. The F<.conf> files are perl source files
that can contain any code allowed under the default safe compartment opset.
After evaluation of both files, any package variables are copied out of the
safe compartment into a hash. This hash becomes the course environment.

=head1 CONSTRUCTION

=over

=item new (ROOT, COURSE)

The C<new> method finds the file F<conf/global.conf> relative to the given ROOT
directory. After reading this file, it uses the C<$courseFiles{environment}>
variable, if present, to locate the course environment file. If found, the file
is read and added to the environment.

=back

=head1 ACCESS

There are no formal accessor methods. However, since the course environemnt is
a hash of hashes and arrays, is exists as the self hash of an instance
variable:

	$courseEnvironment->{someKey}->{someOtherKey};

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=cut
