################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::DB::Webwork;

use strict;
use warnings;
use WeBWorK::Set;
use WeBWorK::Problem;

# there should be a `use' line for each database type
use WeBWorK::DB::GDBM;

# new($invocant, $courseEnv)
# $invocant - implicitly set by caller
# $courseEnv - an instance of CourseEnvironment
sub new($$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $courseEnv = shift;
	my $dbModule = fullyQualifiedPackageName($courseEnv->{dbInfo}->{wwdb_type});
	my $self = {
		webwork_file => $courseEnv->{dbInfo}->{wwdb_file},
	};
	$self->{webwork_db} = $dbModule->new($self->{webwork_file});
	bless $self, $class;
	return $self;
}

sub fullyQualifiedPackageName($) {
	my $n = shift;
	my $package = __PACKAGE__;
	$package =~ s/([^:]*)$/$n/;
	return $package;
}

# -----

sub decode($) {
	my $string = shift;
	my %hash = $string =~ /(.*?)(?<!\\)=(.*?)(?:(?<!\\)&|$)/g;
	$hash{$_} =~ s/\\(.)/$1/ foreach (keys %hash); # unescape anything
	return %hash;
}

sub encode(@) {
	my %hash = @_;
	my $string;
	foreach (keys %hash) {
		$hash{$_} =~ s/(=|&)/\\$1/; # escape & and =
		$string .= "$_=$hash{$_}&";
	}
	chop $string; # remove final '&' from string for old code :p
	return $string;
}

# -----

# hash2set(%hash) - places selected fields from a webwork database record
#                   in a WeBWorK::Set object, which is then returned.
# %hash - a hash representing a database record
sub hash2set(%) {
	my %hash = @_;
}

# set2hash($set) - unpacks a WeBWorK::Set object and returns PART of a hash
#                  suitable for storage in the webwork database.
# $set - a WeBWorK::Set object.
sub set2hash($) {
	my $set = shift;
}

# -----

# hash@problem($problemNumber, %hash) - places selected fields from a webwork
#                                       database record in a WeBWorK::Problem
#                                       object, which is then returned.
# $problemNumber - the problem number to extract
# %hash - a hash representing a database record
sub hash2problem($%) {
	my $problemNumber = shift;
	my %hash = @_;
}

# problem2hash($problem) - unpacks a WeBWorK::Problem object and returns PART
#                          of a hash suitable for storage in the webwork
#                          database.
# $problem - a WeBWorK::Problem object
sub problem2hash($) {
	my $problem = shift;
}

1;
