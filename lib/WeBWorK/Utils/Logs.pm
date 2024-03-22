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

package WeBWorK::Utils::Logs;
use Mojo::Base 'Exporter', -signatures;

use Fcntl qw(:flock);
use Date::Format;

use WeBWorK::Utils::Files qw(surePathToFile);

our @EXPORT_OK = qw(
	writeCourseLog
	writeLog
	writeTimingLogEntry
);

# Note the $time and $logType parameters of this method are only intended to be
# used internally by this file, and so are not documented in the POD.
sub writeLog ($ce, $facility, $message, $time = time, $logType = 'webwork') {
	my ($fileType, $dirType) = ("${logType}Files", "${logType}Dirs");

	unless ($ce->{$fileType}{logs}{$facility}) {
		warn "There is no $logType log file for the $facility facility defined.\n";
		return;
	}

	surePathToFile($ce->{$dirType}{root}, $ce->{$fileType}{logs}{$facility});

	if (open my $LOG, '>>:encoding(UTF-8)', $ce->{$fileType}{logs}{$facility}) {
		flock $LOG, LOCK_EX;
		print $LOG '[', time2str('%a %b %d %H:%M:%S %Y', $time), "] $message\n";
		close $LOG;
	} else {
		warn "failed to open $ce->{$fileType}{logs}{$facility} for writing: $!";
	}

	return;
}

sub writeCourseLog ($ce, $facility, $message, $time = time) {
	writeLog($ce, $facility, $message, $time, 'course');
	return;
}

sub writeTimingLogEntry ($ce, $route, $details) {
	writeLog($ce, 'timing', "$$ " . time . " - $route [$details]");
	return;
}

1;

=head1 NAME

WeBWorK::Utils::Logs - contains utility subroutines for writing logs to files.

=head2 writeLog

Usage: C<writeLog($ce, $facility, $message)>

Write to the log file specified by C<$facility>, where C<$facility> is a key
specified in the C<$webworkFiles{logs}> hash from the course environment. A
valid C<WeBWorK::CourseEnvironment> object must be specified by C<$ce>. The
format of the message written to the log file is

    [formatted date & time] $message

=head2 writeCourseLog

Usage: C<writeCourseLog($ce, $facility, $message, $time)>

Write to the course log file specified by C<$facility>, where C<$facility> is a
key in the C<$courseFiles{logs}> hash from the course environment.  A valid
C<$WeBWorK::CourseEnvironment> object must be specified in C<$ce>.  The C<$time>
argument is optional, and the current time will be used if it is not provided.
The format of the message written to the log file is

    [formatted date & time] $message

=head2 writeTimingLogEntry

Usage: C<writeTimingLogEntry($ce, $route, $details)>

Write to the timing log.  A valid C<$WeBWorK::CourseEnvironment> object must be
specified in C<$ce>.  The C<$route> should be the URL path for the current
route.  The format of the message written to the log file is

    [formatted date & time] processID unixTime - $route [$details]

Note that the C<$details> argument should not be wrapped in brackets since that
will be done by this method.

=cut
