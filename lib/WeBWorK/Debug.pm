################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::Debug;
use parent qw(Exporter);

use strict;
use warnings;

use Date::Format;
use Time::HiRes qw/gettimeofday/;
use WeBWorK::Utils qw/undefstr/;

our @EXPORT = qw(debug);

=head1 NAME

WeBWorK::Debug - Print (or don't print) debugging output.

head1 SYNOPSIS

 use WeBWorK::Debug;

 # Enable debugging
 $WeBWorK::Debug::Enabled = 1;

 # Log to a file instead of STDERR
 $WeBWorK::Debug::Logfile = "/path/to/debug.log";

 # log some debugging output
 debug("Generated 5 widgets.");

=head1 CONFIGURATION VARIABLES

=over

=item $Enabled

If true, debugging messages will be output. If false, they will be ignored.

=cut

our $Enabled = $Enabled // 0;

=item $Logfile

If non-empty, debugging output will be sent to the file named rather than STDERR.

=cut

our $Logfile = $Logfile // '';

=item $DenySubroutineOutput

If defined, prevent subroutines matching the following regular expression from
logging.

=cut

our $DenySubroutineOutput;

=item $AllowSubroutineOutput

If defined, allow only subroutines matching the following regular expression to
log.

=cut

our $AllowSubroutineOutput;

=back

=head1 FUNCTIONS

=over

=item debug(@messages)

Write @messages to the debugging log.

=cut

sub debug {
	my @message = @_;

	if ($Enabled) {
		@message = undefstr('###UNDEF###', @message);

		my ($package, $filename, $line, $subroutine) = caller(1);
		return if defined $AllowSubroutineOutput and not $subroutine =~ m/$AllowSubroutineOutput/;
		return if defined $DenySubroutineOutput  and $subroutine     =~ m/$DenySubroutineOutput/;

		my ($sec, $msec) = gettimeofday;
		my $date         = time2str("%a %b %d %H:%M:%S.$msec %Y", $sec);
		my $finalMessage = "[$date] $subroutine: " . join('', @message);
		$finalMessage .= "\n" unless $finalMessage =~ m/\n$/;

		if ($WeBWorK::Debug::Logfile ne '') {
			if (open my $fh, '>>:encoding(UTF-8)', $Logfile) {
				print $fh $finalMessage;
				close $fh;
			} else {
				warn "Failed to open debug log '$Logfile' in append mode: $!";
				print STDERR $finalMessage;
			}
		} else {
			print STDERR $finalMessage;
		}
	}

	return;
}

=back

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=cut

1;
