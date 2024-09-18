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

package WeBWorK::Utils::DateTime;
use Mojo::Base 'Exporter', -signatures;

use DateTime;
use DateTime::TimeZone;
use Time::Zone qw(tz_offset);

our @EXPORT_OK = qw(
	before
	between
	after
	formatDateTime
	getDefaultSetDueDate
	parseDateTime
	timeToSec
);

sub before ($time, $now = time) { return $now < $time }

sub between ($start, $end, $now = time) { return $now >= $start && $now <= $end }

sub after ($time, $now = time) { return $now > $time }

sub formatDateTime ($date_time = 0, $format_string = 'datetime_format_short', $timezone = 'local', $locale = undef) {
	# Set defaults (note this must be done in addition to the defaults above because undef can be explicitly passed).
	$format_string ||= 'datetime_format_short';
	$date_time     ||= 0;
	$timezone      ||= 'local';

	$timezone = verify_timezone($timezone);

	my $dt = DateTime->from_epoch(epoch => $date_time, time_zone => $timezone, $locale ? (locale => $locale) : ());

	# If $format_string is a method of $dt->locale then call format_cldr on its return value.
	# Otherwise assume it is a locale string meant for strftime.
	if ($dt->locale->can($format_string)) {
		return $dt->format_cldr($dt->locale->$format_string);
	} else {
		return $dt->strftime($format_string);
	}
}

sub getDefaultSetDueDate ($ce) {
	my ($hour, $minute, $ampm) = $ce->{pg}{timeAssignDue} =~ m/\s*(\d+)\s*:\s*(\d+)\s*(am|pm|AM|PM)?\s*/;
	$hour   //= 0;
	$minute //= 0;
	$hour += 12 if $ampm && $ampm =~ m/pm|PM/ && $hour != 12;
	$hour = 0   if $ampm && $ampm =~ m/am|AM/ && $hour == 12;

	my $dt = DateTime->from_epoch(epoch => time + 2 * 60 * 60 * 24 * 7);

	return DateTime->new(
		year      => $dt->year,
		month     => $dt->month,
		day       => $dt->day,
		hour      => $hour,
		minute    => $minute,
		second    => 0,
		time_zone => $ce->{siteDefaults}{timezone}
	)->epoch;
}

sub parseDateTime ($string, $display_tz = 'local') {
	$display_tz ||= 'local';
	$display_tz = verify_timezone($display_tz);

	my ($second, $minute, $hour, $day, $month, $year, $zone) = unformatDateAndTime($string);

	# DateTime expects the month to be in the range from 1 to 12, not from 0 to 11.
	++$month;

	# Do what Time::Local does to ambiguous years
	{
		my $ThisYear    = (localtime)[5];                # FIXME: should be relative to $string's timezone
		my $Breakpoint  = ($ThisYear + 50) % 100;
		my $NextCentury = $ThisYear - $ThisYear % 100;
		$NextCentury += 100 if $Breakpoint < 50;
		my $Century = $NextCentury - 100;
		my $SecOff  = 0;

		if ($year >= 1000) {
			# leave alone
		} elsif ($year < 100 && $year >= 0) {
			$year += ($year > $Breakpoint) ? $Century : $NextCentury;
			$year += 1900;
		} else {
			$year += 1900;
		}
	}

	# Determine the best possible time-zone string to use in the (first) call to DateTime()
	my $tz_to_use = $display_tz;

	my $is_valid_zone_name = 1;    # If later set to 0, then try the "offset" approach.
	if (defined $zone && $zone ne '') {
		$is_valid_zone_name = DateTime::TimeZone->is_valid_name($zone);
		$tz_to_use          = $is_valid_zone_name ? $zone : 'UTC';
	}

	my $dt = DateTime->new(
		year      => $year,
		month     => $month,
		day       => $day,
		hour      => $hour,
		minute    => $minute,
		second    => $second,
		time_zone => $tz_to_use,
	);

	if (!$is_valid_zone_name) {
		# "UTC" was used and so attempt to apply a timezone offset, or fall back to using the display timezone.
		if (my $offset = tz_offset($zone, $dt->epoch)) {
			$dt->subtract(seconds => $offset);
		} else {
			warn "Time zone '$zone' not recognized. Falling back to parsing "
				. "using $display_tz instead of applying an offset from UTC.\n";
			$dt = DateTime->new(
				year      => $year,
				month     => $month,
				day       => $day,
				hour      => $hour,
				minute    => $minute,
				second    => $second,
				time_zone => $display_tz,
			);
		}
	}

	return $dt->epoch;
}

# This is a modified version of the subroutine of the same name from WeBWorK
# 1.9.05's scripts/FILE.pl (v1.13). It has been modified to understand time
# zones. The time zone specification must appear at the end of the string and be
# preceded by white space. The return value is a list consisting of the following
# elements:
#
#     ($second, $minute, $hour, $day, $month, $year, $zone)
#
# $second, $minute, $hour, $day, and $month are zero-indexed. $year is the
# number of years since 1900. $zone is a string (hopefully) representing the
# time zone.
sub unformatDateAndTime ($string) {
	my $origString = $string;

	$string =~ s/^\s*|\s*$//g;
	$string =~ s/\s*at\s*/ at /i;
	$string =~ s/\s*AM/ AM/i;
	$string =~ s/\s*PM/ PM/i;
	$string =~ s/\s*,\s*/ at /;

	# Case where "at" is missing
	die qq{The "at" appears to be missing in "$origString".\n} unless $string =~ m/at/;

	my ($date, $at, $time, $AMPM, $TZ) = split /\s+/, $string;

	die qq{The date or time appears to be missing in "$origString".\n}
		unless defined $date && defined $at && defined $time;

	# Deal with military time
	unless ($time =~ /:/) {
		$time =~ /(\d\d)(\d\d)/;
		my $tmp_hour = $1;
		my $tmp_min  = $2;
		if    ($tmp_hour eq '00') { $time     = "12:$tmp_min";        $AMPM = 'AM'; }
		elsif ($tmp_hour eq '12') { $time     = "12:$tmp_min";        $AMPM = 'PM'; }
		elsif ($tmp_hour < 12)    { $time     = "$tmp_hour:$tmp_min"; $AMPM = 'AM'; }
		elsif ($tmp_hour < 24)    { $tmp_hour = $tmp_hour - 12;       $time = "$tmp_hour:$tmp_min"; $AMPM = 'PM'; }
	}

	# Default value for $AMPM
	$AMPM //= 'AM';

	my $sec = 0;

	$time =~ /^([0-9]+)\s*\:\s*([0-9]*)/;
	my $min  = $2;
	my $hour = $1;
	die qq{The hour in "$origString" must be in the range from 1 to 12.\n}   if $hour < 1 || $hour > 12;
	die qq{The minute in "$origString" must be in the range from 0 to 59.\n} if $min < 0  || $min > 59;

	$hour += $AMPM =~ /PM/ && $hour < 12 ? 12 : 0;
	$hour = 0 if ($AMPM =~ /AM/ && $hour == 12);

	$date =~ m|([0-9]+)\s*/\s*([0-9]+)/\s*([0-9]+)|;
	my $mday = $2;
	my $mon  = $1 - 1;
	my $year = $3;
	die qq{The day in "$origString" must be in the range from 1 to 31.\n}   if $mday < 1 || $mday > 31;
	die qq{The month in "$origString" must be in the range from 1 to 12.\n} if $mon < 0  || $mon > 11;

	return ($sec, $min, $hour, $mday, $mon, $year, $TZ);
}

sub timeToSec ($time) {
	if ($time =~ /^(\d+)\s+(\S+)\s*$/) {
		my ($val, $unit) = ($1, $2);
		if ($unit =~ /month/i || $unit =~ /mon/i) {
			$val *= 18144000;    # this assumes 30 days/month
		} elsif ($unit =~ /week/i || $unit =~ /wk/i) {
			$val *= 604800;
		} elsif ($unit =~ /day/i || $unit =~ /dy/i) {
			$val *= 86400;
		} elsif ($unit =~ /hour/i || $unit =~ /hr/i) {
			$val *= 3600;
		} elsif ($unit =~ /minute/i || $unit =~ /min/i) {
			$val *= 60;
		} elsif ($unit =~ /second/i || $unit =~ /sec/i || $unit =~ /^s$/i) {
			# do nothing
		} else {
			warn("Unrecognized time unit $unit.\nAssuming seconds.\n");
		}
		return $val;
	} elsif ($time =~ /^(\d+)$/) {
		return $time;
	} else {
		warn("Unrecognized time interval: $time\n");
		return 0;
	}
}

sub verify_timezone ($display_tz) {
	return $display_tz if DateTime::TimeZone->is_valid_name($display_tz);
	warn qq!$display_tz is not a legal time zone name. Fix it on the Course Configuration page. !
		. qq!<a href="http://en.wikipedia.org/wiki/List_of_zoneinfo_time_zones">View list of time zones.</a>!;
	return 'America/New_York';
}

1;

=head1 NAME

WeBWorK::Utils::DateTime - contains utility subroutines for dealing with dates
and times.

=head2 before

Usage: C<before($time, $now)>

True if C<$now> is less than C<$time>. If C<$now> is not specified, the current
time is used.

=head2 between

Usage: C<between($start, $end, $now)>

True if C<$now> is greater than or equal to C<$start> and less than or equal to
C<$end>.  If C<$now> is not specified, the current time is used.

=head2 after

Usage: C<after($time, $now)>

True if C<$now> is greater than C<$time>. If C<$now> is not specified, the
current time is used.

=head2 formatDateTime

Usage: C<formatDateTime($date_time, $format_string, $timezone, $locale)>

Formats a C<$date_time> epoch into a string in the format defined by
C<$format_string>. If C<$format_string> is not provided, the default WeBWorK
date/time format is used.  If C<$format_string> is a method of the
C<< $dt->locale >> instance, then C<format_cldr> is used, and otherwise
C<strftime> is used. The available patterns for $format_string can be found at
L<DateTime/strftime Patterns>. The available methods for the C<< $dt->locale >>
instance are documented at L<DateTime::Locale::FromData>. If C<$timezone> is
given, then the formatted string that is returned is in the specified timezone.
If C<$locale> is provided, the string returned will be in the format of that
locale. If C<$locale> is not provided, Perl defaults to using C<en-US>.

If this method is used directly, then the C<$timezone> and C<$locale> should
generally be set from the course environment, and the defaults set in this
method not used.

=head2 getDefaultSetDueDate

This returns the default due date for a set which is two weeks from the current
time with the time of day set to be C<$pg{timeAssignDue}>, and is in the course
timezone set by C<$siteDefaults{timezone}>. A valid course environment object is
the only required parameter.

=head2 parseDateTime

Usage: C<parseDateTime($string, $display_tz)>

Parses C<$string> into an epoch. The format of C<$string> must be
C<MM/DD/YYYY at HH:MM AMPM ZONE>. There is some forgiveness for spaces, and a
comma is allowed in place of "at".  If C<$display_tz> is given, C<$string> is
assumed to be in that timezone. Otherwise, the server's local timezone is used.

Note that this method is only used for parsing dates when set definition files
are imported, and should NEVER be used for anything else ever again.  If it is
desired to use a human readable string to save a date then use the ISO date time
format that can be reliably parsed, and do NOT use this method.

=head2 timeToSec

Usage: C<timeToSec($time)>

Makes a stab at converting a time (with a possible unit) into a number of
seconds.

=head2 verify_timezone

Usage: C<verify_timezone($display_tz)>

If C<$display_tz> is not a legal time zone then replace it with America/New_York
and issue warning.

Note that this method is not exported, and can only be used internally by this
package.

=cut
