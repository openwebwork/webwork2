
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

package WeBWorK::Utils;
use parent qw(Exporter);

=head1 NAME

WeBWorK::Utils - Utility methods used by other WeBWorK modules.

=cut

use strict;
use warnings;

use DateTime;
use DateTime::TimeZone;
use Date::Parse;
use Date::Format;
use File::Copy;
use File::Spec::Functions qw(canonpath);
use Fcntl qw(:flock);
use Time::Zone;
use MIME::Base64 qw(encode_base64 decode_base64);
use Errno;
use File::Path qw(rmtree);
use Storable;
use Carp;
use Storable qw(nfreeze thaw);
use JSON;
use Email::Sender::Transport::SMTP;

use open IO => ':encoding(UTF-8)';

use constant MKDIR_ATTEMPTS => 10;

use constant JITAR_MASK =>
	[ hex 'FF000000', hex '00FC0000', hex '0003F000', hex '00000F00', hex '000000F0', hex '0000000F' ];
use constant JITAR_SHIFT => [ 24, 18, 12, 8, 4, 0 ];

our @EXPORT_OK = qw(
	after
	before
	between
	constituency_hash
	cryptPassword
	decodeAnswers
	decode_utf8_base64
	dequote
	encodeAnswers
	encode_utf8_base64
	fix_newlines
	fisher_yates_shuffle
	formatDateTime
	getDefaultSetDueDate
	list2hash
	listFilesRecursive
	makeTempDirectory
	min
	max
	nfreeze_base64
	not_blank
	parseDateTime
	path_is_subdir
	pretty_print_rh
	readDirectory
	createDirectory
	readFile
	ref2string
	removeTempDirectory
	runtime_use
	sortAchievements
	sortByName
	surePathToFile
	timeToSec
	trim_spaces
	format_set_name_internal
	format_set_name_display
	thaw_base64
	undefstr
	writeCourseLog
	writeCourseLogGivenTime
	writeLog
	writeTimingLogEntry
	wwRound
	getTestProblemPosition
	is_restricted
	grade_set
	grade_gateway
	grade_all_sets
	jitar_id_to_seq
	seq_to_jitar_id
	is_jitar_problem_hidden
	is_jitar_problem_closed
	jitar_problem_adjusted_status
	jitar_problem_finished
	prob_id_sort
	role_and_above
	fetchEmailRecipients
	processEmailMessage
	createEmailSenderTransportSMTP
	generateURLs
	getAssetURL
	x
);

=head1 METHODS

=cut

################################################################################
# Lowlevel thingies
################################################################################

# This is like use, except it happens at runtime. You have to quote the module name and put a
# comma after it if you're specifying an import list. Also, to specify an empty import list (as
# opposed to no import list) use an empty arrayref instead of an empty array.
#
#   use Xyzzy;               =>    runtime_use "Xyzzy";
#   use Foo qw/pine elm/;    =>    runtime_use "Foo", qw/pine elm/;
#   use Foo::Bar ();         =>    runtime_use "Foo::Bar", [];

sub runtime_use($;@) {
	my ($module, @import_list) = @_;
	my $package = (caller)[0];    # import into caller's namespace

	my $import_string;
	if (@import_list == 1 and ref $import_list[0] eq "ARRAY" and @{ $import_list[0] } == 0) {
		$import_string = "";
	} else {
		# \Q = quote metachars \E = end quoting
		$import_string = "import $module " . join(",", map {qq|"\Q$_\E"|} @import_list);
	}
	eval "package $package; require $module; $import_string";
	die $@ if $@;
}

#sub backtrace($) {
#	my ($style) = @_;
#	$style = "warn" unless $style;
#	my @bt = DB->backtrace;
#	shift @bt; # Remove "backtrace" from the backtrace;
#	if ($style eq "die") {
#		die join "\n", @bt;
#	} elsif ($style eq "warn") {
#		warn join "\n", @bt;
#	} elsif ($style eq "print") {
#		print join "\n", @bt;
#	} elsif ($style eq "return") {
#		return @bt;
#	}
#}

################################################################################
# Filesystem interaction
################################################################################

=head2 Filesystem interaction

=cut

# Convert Windows and Mac (classic) line endings to UNIX line endings in a string.
# Windows uses CRLF, Mac uses CR, UNIX uses LF. (CR is ASCII 15, LF if ASCII 12)
sub force_eoln($) {
	my ($string) = @_;
	$string = $string // '';
	$string =~ s/\015\012?/\012/g;
	return $string;
}

sub readFile($) {
	my $fileName = shift;
	# debugging code: found error in CourseEnvironment.pm with this
	# 	if ($fileName =~ /___/ or $fileName =~ /the-course-should-be-determined-at-run-time/) {
	# 		print STDERR "File $fileName not found.\n Usually an unnecessary call to readFile from\n",
	# 		join("\t ", caller()), "\n";
	# 		return();
	# 	}
	local $/ = undef;    # slurp the whole thing into one string
	my $result = '';     # need this initialized because the file (e.g. simple.conf) may not exist
	if (-r $fileName) {
		eval {
			# CODING WARNING:
			# if (open my $dh, "<", $fileName){
			# will cause a utf8 "\xA9" does not map to Unicode warning if © is in latin-1 file
			# use the following instead
			if (open my $dh, "<:raw", $fileName) {
				$result = <$dh>;
				Encode::decode("UTF-8", $result) or die "failed to decode $fileName";
				close $dh;
			} else {
				print STDERR "File $fileName cannot be read.";    # this is not a fatal error.
			}
		};
		if ($@) {
			print STDERR "reading $fileName:  error in Utils::readFile: $@\n";
		}
		my $prevent_error_message = utf8::decode($result)
			or warn join("",
				"Non-fatal warning: file $fileName contains at least one character code which ",
				"is not valid in UTF-8. (The copyright sign is often a culprit -- use '&amp;copy;' instead.)\n",
				"While this is not fatal you should fix it\n");
		# FIXME
		# utf8::decode($result) raises an error about the copyright sign
		# decode_utf8 and Encode::decode_utf8 do not -- which is doing the right thing?
	}
	# returns the empty string if the file cannot be read
	return force_eoln($result);
}

sub readDirectory($) {
	my $dirName = shift;
	opendir my $dh, $dirName
		or die "Failed to read directory $dirName: $!";
	my @result = readdir $dh;
	close $dh;
	return @result;
}

=head3 createDirectory

    createDirectory($dirName, $permission, $numgid)

Creates a directory with the given name, permission bits, and group ID.

=cut

sub createDirectory {
	my ($dirName, $permission, $numgid) = @_;

	$permission //= 0770;
	my $errors = '';
	mkdir($dirName, $permission)
		or $errors .= "Can't do mkdir($dirName, $permission): $!\n" . caller(3);
	chmod($permission, $dirName)
		or $errors .= "Can't do chmod($permission, $dirName): $!\n" . caller(3);
	unless ($numgid == -1) {
		chown(-1, $numgid, $dirName)
			or $errors .= "Can't do chown(-1,$numgid,$dirName): $!\n" . caller(3);
	}
	if ($errors) {
		warn $errors;
		return 0;
	} else {
		return 1;
	}
}

=head3 listFilesRecusive

    listFilesRecusive($dir, $match_qr, $prune_qr, $match_full, $prune_full)

Traverses the directory tree rooted at C<$dir>, returning a list of files, named
pipes, and sockets matching the regular expression C<$match_qr>. Directories
matching the regular expression C<$prune_qr> are not visited.

C<$match_full> and C<$prune_full> are boolean values that indicate whether
C<$match_qr> and C<$prune_qr>, respectively, should be applied to the bare
directory entry (false) or to the path to the directory entry relative to
C<$dir>.

The method returns a list of paths relative to C<$dir>.

=cut

sub listFilesRecursiveHelper($$$$$$);

sub listFilesRecursive($;$$$$) {
	my ($dir, $match_qr, $prune_qr, $match_full, $prune_full) = @_;
	return listFilesRecursiveHelper($dir, "", $match_qr, $prune_qr, $match_full, $prune_full);
}

sub listFilesRecursiveHelper($$$$$$) {
	my ($base_dir, $curr_dir, $match_qr, $prune_qr, $match_full, $prune_full) = @_;

	my $full_dir = "$base_dir/$curr_dir";

	my @dir_contents = readDirectory($full_dir);

	my @matches;

	foreach my $dir_entry (@dir_contents) {
		my $full_path = "$full_dir/$dir_entry";

		# determine whether the entry is a directory or a file, taking into account the
		my $is_dir;
		my $is_file;
		if (-l $full_path) {
			my $link_target = "$full_dir/" . readlink $full_path;
			if ($link_target) {
				$is_dir  = -d $link_target;
				$is_file = !$is_dir && -f $link_target || -p $link_target || -S $link_target;
			} else {
				warn "Couldn't resolve symlink $full_path: $!";
			}
		} else {
			$is_dir  = -d $full_path;
			$is_file = !$is_dir && -f $full_path || -p $full_path || -S $full_path;
		}

		if ($is_dir) {
			# standard things to skip
			next if $dir_entry eq ".";
			next if $dir_entry eq "..";

			# skip unreadable directories (and broken symlinks, incidentally)
			unless (-r $full_path) {
				warn "Directory/symlink $full_path not readable";
				next;
			}

			# check $prune_qr
			my $subdir = ($curr_dir eq "") ? $dir_entry : "$curr_dir/$dir_entry";
			if (defined $prune_qr) {
				my $prune_string = $prune_full ? $subdir : $dir_entry;
				next if $prune_string =~ m/$prune_qr/;
			}

			# everything looks good, time to recurse!
			push @matches, listFilesRecursiveHelper($base_dir, $subdir, $match_qr, $prune_qr, $match_full, $prune_full);
		} elsif ($is_file) {
			my $file         = ($curr_dir eq "") ? $dir_entry : "$curr_dir/$dir_entry";
			my $match_string = $match_full       ? $file      : $dir_entry;
			if (not defined $match_string or $match_string =~ m/$match_qr/) {
				push @matches, $file;
			}
		} else {
			# otherwise, it's a character device or a block device, and i don't
			# suppose we want anything to do with those ;-)
		}
	}

	return @matches;
}

# A very useful macro for making sure that all of the directories to a file have
# been constructed.
sub surePathToFile($$) {
	# constructs intermediate directories enroute to the file
	# the input path must be the path relative to this starting directory
	my $start_directory = shift;
	my $path            = shift;
	my $delim           = "/";
	unless ($start_directory and $path) {
		warn "missing directory<br> surePathToFile  start_directory   path ";
		return '';
	}
	# use the permissions/group on the start directory itself as a template
	my ($perms, $groupID) = (stat $start_directory)[ 2, 5 ];
	# warn "&urePathToTmpFile: perms=$perms groupID=$groupID\n";

	# if the path starts with $start_directory (which is permitted but optional) remove this initial segment
	$path =~ s|^$start_directory|| if $path =~ m|^$start_directory|;

	# find the nodes on the given path
	my @nodes = split("$delim", $path);

	# create new path
	$path = $start_directory;    #convertPath("$tmpDirectory");

	while (@nodes > 1) {         # the last node is the file name
		$path = $path . shift(@nodes) . "/";    #convertPath($path . shift (@nodes) . "/");
												#FIXME  this make directory command may not be fool proof.
		unless (-e $path) {
			mkdir($path, $perms)
				or warn "Failed to create directory $path with start directory $start_directory ";
		}

	}

	$path = $path . shift(@nodes);    #convertPath($path . shift(@nodes));
	return $path;
}

sub makeTempDirectory($$) {
	my ($parent, $basename) = @_;
	# Loop until we're able to create a directory, or it fails for some
	# reason other than there already being something there.
	my $triesRemaining = MKDIR_ATTEMPTS;
	my ($fullPath, $success);
	do {
		my $suffix = join "", map { ('A' .. 'Z', 'a' .. 'z', '0' .. '9')[ int rand 62 ] } 1 .. 8;
		$fullPath = "$parent/$basename.$suffix";
		$success  = mkdir $fullPath;
	} until ($success or not $!{EEXIST});
	die "Failed to create directory $fullPath: $!"
		unless $success;
	return $fullPath;
}

sub removeTempDirectory($) {
	my ($dir) = @_;
	rmtree($dir, 0, 0);
}

=head3 path_is_subdir

    path_is_subdir($path, $dir, $allow_relative)

Ensures that C<$path> refers to a location "inside" C<$dir>. If
C<$allow_relative> is true and C<$path> is not absolute, it is assumed to be
relative to C<$dir>.

The method of checking is rather rudimentary at the moment. First, upreferences
("..") are disallowed in C<$path>, then it is checked to make sure that some
prefix of it matches C<$dir>.

If either of these checks fails, a false value is returned. Otherwise, a true
value is returned.

=cut

sub path_is_subdir($$;$) {
	my ($path, $dir, $allow_relative) = @_;

	unless ($path =~ /^\//) {
		if ($allow_relative) {
			$path = "$dir/$path";
		} else {
			return 0;
		}
	}

	$path = canonpath($path);
	$path .= "/" unless $path =~ m|/$|;
	return 0 if $path =~ m#(^\.\.$|^\.\./|/\.\./|/\.\.$)#;

	$dir = canonpath($dir);
	$dir .= "/" unless $dir =~ m|/$|;
	return 0 unless $path =~ m|^$dir|;

	return 1;
}

################################################################################
# Date/time processing
################################################################################

=head2 Date/time processing

=head3 parseDateTime

    parseDateTime($string, $display_tz)

Parses C<$string> into an epoch. The format of C<$string> must be
C<MM/DD/YYYY at HH:MM AMPM ZONE>. There is some forgiveness for spaces, and a
comma is allowed in place of "at".  If C<$display_tz> is given, C<$string> is
assumed to be in that timezone. Otherwise, the server's local timezone is used.

Note that this method is only used for parsing dates when set definition files
are imported, and should NEVER be used for anything else ever again.  If it is
desired to use a human readable string to save a date then use the ISO date time
format that can be reliably parsed, and do NOT use this method.

=cut

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
sub unformatDateAndTime {
	my ($string) = @_;
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

sub parseDateTime {
	my ($string, $display_tz) = @_;

	$display_tz ||= 'local';
	$display_tz = verify_timezone($display_tz);

	my ($second, $minute, $hour, $day, $month, $year, $zone) = unformatDateAndTime($string);

	# DateTime expects the month to be in the range from 1 to 12, not from 0 to 11.
	++$month;

	# Do what Time::Local does to ambiguous years
	{
		my $ThisYear    = (localtime())[5];              # FIXME: should be relative to $string's timezone
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

	my $dt = new DateTime(
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
			$dt = new DateTime(
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

=head3 formatDateTime

    formatDateTime($date_time, $format_string, $timezone, $locale)

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

=cut

sub formatDateTime {
	my ($date_time, $format_string, $timezone, $locale) = @_;

	# Set defaults.
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

=head3 getDefaultSetDueDate

This returns the default due date for a set which is two weeks from the current
time with the time of day set to be C<$pg{timeAssignDue}>, and is in the course
timezone set by C<$siteDefaults{timezone}>. A valid course environment object is
the only required parameter.

=cut

sub getDefaultSetDueDate {
	my $ce = shift;

	my ($hour, $minute, $ampm) = $ce->{pg}{timeAssignDue} =~ m/\s*(\d+)\s*:\s*(\d+)\s*(am|pm|AM|PM)?\s*/;
	$hour   //= 0;
	$minute //= 0;
	$hour += 12 if $ampm && $ampm =~ m/pm|PM/;

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

=head3 verify_timezone

    verify_timezone($display_tz)

If C<$display_tz> is not a legal time zone then replace it with America/New_York
and issue warning.

=cut

sub verify_timezone {
	my $display_tz = shift;
	return $display_tz if DateTime::TimeZone->is_valid_name($display_tz);
	warn qq!$display_tz is not a legal time zone name. Fix it on the Course Configuration page. !
		. qq!<a href="http://en.wikipedia.org/wiki/List_of_zoneinfo_time_zones">View list of time zones.</a>!;
	return 'America/New_York';
}

=head3 timeToSec

    timeToSec($time)

Makes a stab at converting a time (with a possible unit) into a number of
seconds.

=cut

sub timeToSec($) {
	my $t = shift();
	if ($t =~ /^(\d+)\s+(\S+)\s*$/) {
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
	} elsif ($t =~ /^(\d+)$/) {
		return $t;
	} else {
		warn("Unrecognized time interval: $t\n");
		return 0;
	}
}

=head3 before

    before($time, $now)

True if C<$now> is less than C<$time>. If C<$now> is not specified, the current
time is used.

=cut

sub before { return (@_ == 2) ? $_[1] < $_[0] : time < $_[0] }

=head3 after

    after($time, $now)

True if C<$now> is greater than C<$time>. If C<$now> is not specified, the
current time is used.

=cut

sub after { return (@_ == 2) ? $_[1] > $_[0] : time > $_[0] }

=head3 between

    between($start, $end, $now)

True if C<$now> is greater than or equal to C<$start> and less than or equal to
C<$end>.  If C<$now> is not specified, the current time is used.

=cut

sub between { my $t = (@_ == 3) ? $_[2] : time; return $t >= $_[0] && $t <= $_[1] }

################################################################################
# Logging
################################################################################

sub writeLog {
	my ($ce, $facility, @message) = @_;
	unless ($ce->{webworkFiles}{logs}{$facility}) {
		warn "There is no log file for the $facility facility defined.\n";
		return;
	}
	my $logFile = $ce->{webworkFiles}{logs}{$facility};
	surePathToFile($ce->{webworkDirs}{root}, $logFile);
	if (open my $LOG, '>>:encoding(UTF-8)', $logFile) {
		flock $LOG, LOCK_EX;
		print $LOG "[", time2str("%a %b %d %H:%M:%S %Y", time), "] @message\n";
		close $LOG;
	} else {
		warn "failed to open $logFile for writing: $!";
	}
	return;
}

sub writeCourseLog {
	my ($ce, $facility, @message) = @_;
	writeCourseLogGivenTime($ce, $facility, time, @message);
	return;
}

sub writeCourseLogGivenTime {
	my ($ce, $facility, $myTime, @message) = @_;
	unless ($ce->{courseFiles}{logs}{$facility}) {
		warn "There is no course log file for the $facility facility defined.\n";
		return;
	}
	my $logFile = $ce->{courseFiles}{logs}{$facility};
	surePathToFile($ce->{courseDirs}{root}, $logFile);
	if (open my $LOG, '>>:encoding(UTF-8)', $logFile) {
		flock $LOG, LOCK_EX;
		print $LOG "[", time2str("%a %b %d %H:%M:%S %Y", $myTime), "] @message\n";
		close $LOG;
	} else {
		warn "failed to open $logFile for writing: $!";
	}
	return;
}

# $ce - a WeBWork::CourseEnvironment object
# $function - fully qualified function name
# $details - any information, do not use the characters '[' or ']'
# $beginEnd - the string "begin", "intermediate", or "end"
# use the intermediate step begun or completed for INTERMEDIATE
# use an empty string for $details when calling for END
# Information printed in format:
# [formatted date & time ] processID unixTime BeginEnd $function  $details
sub writeTimingLogEntry {
	my ($ce, $function, $details, $beginEnd) = @_;
	$beginEnd = ($beginEnd eq "begin") ? ">" : ($beginEnd eq "end") ? "<" : "-";
	writeLog($ce, "timing", "$$ " . time . " $beginEnd $function [$details]");
	return;
}

################################################################################
# Data munging
################################################################################
## Utility function to trim whitespace off the start and end of its input
sub trim_spaces {
	my $in = shift;
	return '' unless $in;    # skip blank spaces
	$in =~ s/^\x{FEFF}//;    # fix UTF-8 with BOM
	$in =~ s/^\s*|\s*$//g;
	return ($in);
}

# fix non-unix line endings
sub fix_newlines {
	return shift =~ s/\r\n?/\n/gr;
}

# This is for formatting set names input via text inputs in the user interface for internal use.  Set names are allowed
# to be input with spaces, but internally spaces are not allowed and are converted to underscores.
sub format_set_name_internal {
	return ($_[0] =~ s/^\s*|\s*$//gr) =~ s/ /_/gr;
}

# This formats set names for display, converting underscores back into spaces.
sub format_set_name_display {
	return $_[0] =~ s/_/ /gr;
}

sub list2hash(@) {
	map { $_ => "0" } @_;
}

sub refBaseType($) {
	my $ref = shift;
	$ref =~ m/(\w+)\(/;    # this might not be robust...
	return $1;
}

sub ref2string($;$);

sub ref2string($;$) {
	my $ref        = shift;
	my $dontExpand = shift || {};
	my $refType    = ref $ref;
	my $result;
	if ($refType and not $dontExpand->{$refType}) {
		my $baseType = refBaseType($ref);
		$result .= '<font size="1" color="grey">' . $refType;
		$result .= " ($baseType)" if $baseType and $refType ne $baseType;
		$result .= ":</font><br>";
		$result .= '<table border="1" cellpadding="2">';
		if ($baseType eq "HASH") {
			my %hash = %$ref;
			foreach (sort keys %hash) {
				$result .= '<tr valign="top">';
				$result .= "<td>$_</td>";
				$result .= "<td>" . ref2string($hash{$_}, $dontExpand) . "</td>";
				$result .= "</tr>";
			}
		} elsif ($baseType eq "ARRAY") {
			my @array = @$ref;
			# special case for Problem, Set, and User objects, which are defined
			# using lists and contain a @FIELDS package variable:
			no strict 'refs';
			my @FIELDS = eval { @{ $refType . "::FIELDS" } };
			use strict 'refs';
			undef @FIELDS unless scalar @FIELDS == scalar @array and not $@;
			foreach (0 .. $#array) {
				$result .= '<tr valign="top">';
				$result .= "<td>$_</td>";
				$result .= "<td>" . $FIELDS[$_] . "</td>" if @FIELDS;
				$result .= "<td>" . ref2string($array[$_], $dontExpand) . "</td>";
				$result .= "</tr>";
			}
		} elsif ($baseType eq "SCALAR") {
			my $scalar = $$ref;
			$result .= '<tr valign="top">';
			$result .= "<td>$scalar</td>";
			$result .= "</tr>";
		} else {
			# perhaps a coderef? in any case, i don't feel like dealing with it!
			$result .= '<tr valign="top">';
			$result .= "<td>$ref</td>";
			$result .= "</tr>";
		}
		$result .= "</table>";
	} else {
		$result .= defined $ref ? $ref : '<font color="red">undef</font>';
	}
}
our $BASE64_ENCODED = 'base64_encoded:';
#  use constant BASE64_ENCODED = 'base64_encoded;
#  was not evaluated in the matching and substitution
#  statements

sub OLDdecodeAnswers($) {
	my $serialized = shift;
	return unless defined $serialized and $serialized;
	my $array_ref = eval { Storable::thaw($serialized) };
	if ($@ or !defined $array_ref) {
# My hope is that this next warning is no longer needed since there are few legacy base64 days and the fix seems transparent.
# warn "problem fetching answers -- possibly left over from base64 days. Not to worry -- press preview or submit and this will go away  permanently for this question.   $@";
		return ();
	} else {
		return @{$array_ref};
	}
}

sub decodeAnswers($) {
	my $serialized = shift;
	return unless defined $serialized and $serialized;
	if ($serialized =~ /^\[/ && $serialized =~ /\]$/) {
		# Assuming this is JSON encoded
		my @array_data = @{ from_json($serialized) };
		return @array_data;
	} else {
		# Fall back to old Storable::thaw based code
		return OLDdecodeAnswers($serialized);
	}
}

sub decode_utf8_base64 {
	return Encode::decode("UTF-8", decode_base64(shift));
}

sub OLD_encodeAnswers(\%\@) {
	my %hash         = %{ shift() };
	my @order        = @{ shift() };
	my @ordered_hash = ();
	foreach my $key (@order) {
		push @ordered_hash, $key, $hash{$key};
	}
	return Storable::nfreeze(\@ordered_hash);
}

sub encodeAnswers(\%\@) {
	my %hash         = %{ shift() };
	my @order        = @{ shift() };
	my @ordered_hash = ();
	foreach my $key (@order) {
		push @ordered_hash, $key, $hash{$key};
	}
	return to_json(\@ordered_hash);
}

sub encode_utf8_base64 {
	return encode_base64(Encode::encode("UTF-8", shift));
}

sub nfreeze_base64 {
	return encode_base64(nfreeze(shift));
}

sub thaw_base64 {
	my $string = shift;
	my $result;

	eval { $result = thaw(decode_base64($string)); };

	if ($@) {
		warn("Deleting corrupted achievement data.");
		return {};
	} else {
		return $result;
	}

}

sub min {
	my @items = @_;
	my $min   = (shift @items) // 0;
	for my $item (@items) {
		$min = $item if ($item < $min);
	}
	return $min;
}

sub max {
	my @items = @_;
	my $max   = (shift @items) // 0;
	for my $item (@items) {
		$max = $item if ($item > $max);
	}
	return $max;
}

sub wwRound(@) {
	# usage wwRound($places,$float)
	# return $float rounded up to number of decimal places given by $places
	my $places = shift;
	my $float  = shift;
	my $factor = 10**$places;
	return int($float * $factor + 0.5) / $factor;
}

sub pretty_print_rh($) {
	my $rh = shift;
	foreach my $key (sort keys %{$rh}) {
		warn "  $key => ", $rh->{$key}, "\n";
	}
}

# If you modify the code of cryptPassword, please also make the change
# in bin/crypt_passwords_in_classlist.pl, which has a copy of this
# routine so it can easily be used without needed access to a WW webwork2
# directory.
sub cryptPassword($) {
	my ($clearPassword) = @_;
	#Use an SHA512 salt with 16 digits
	my $salt = '$6$';
	for (my $i = 0; $i < 16; $i++) {
		$salt .= ('.', '/', '0' .. '9', 'A' .. 'Z', 'a' .. 'z')[ rand 64 ];
	}

	my $cryptPassword = crypt(trim_spaces($clearPassword), $salt);
	return $cryptPassword;
}

# from the Perl Cookbook, first edition, page 25:
sub dequote($) {
	local $_ = shift;
	my ($white, $leader);    # common whitespace and common leading string
	if (/^\s*(?:([^\w\s]+)(\s*).*\n)(?:\s*\1\2?.*\n)+$/) {
		($white, $leader) = ($2, quotemeta($1));
	} else {
		($white, $leader) = (/^(\s+)/, '');
	}
	s/^\s*?$leader(?:$white)?//gm;
	return $_;
}

sub undefstr($@) {
	map { defined $_ ? $_ : $_[0] } @_[ 1 .. $#_ ];
}

# shuffle an array in place
# Perl Cookbook, Recipe 4.17. Randomizing an Array
sub fisher_yates_shuffle {
	my $array = shift;
	my $i;
	for ($i = @$array; --$i;) {
		my $j = int rand($i + 1);
		next if $i == $j;
		@$array[ $i, $j ] = @$array[ $j, $i ];
	}
}

sub constituency_hash {
	my $hash = {};
	@$hash{@_} = ();
	return $hash;
}

################################################################################
# Sorting
################################################################################

# p. 101, Camel, 3rd ed.
# The <=> and cmp operators return -1 if the left operand is less than the
# right operand, 0 if they are equal, and +1 if the left operand is greater
# than the right operand.
#
# FIXME: I've added the ability to do multiple field sorts, below; I'm
#    leaving this code, commented out, in case there's a good reason to
#    revert to this and do multiple field sorts differently.  -glr 2007/03/05
# sub sortByName($@) {
# 	my ($field, @items) = @_;
# 	return sort {
# 		my @aParts = split m/(?<=\D)(?=\d)|(?<=\d)(?=\D)/, defined $field ? $a->$field : $a;
# 		my @bParts = split m/(?<=\D)(?=\d)|(?<=\d)(?=\D)/, defined $field ? $b->$field : $b;
# 		while (@aParts and @bParts) {
# 			my $aPart = shift @aParts;
# 			my $bPart = shift @bParts;
# 			my $aNumeric = $aPart =~ m/^\d*$/;
# 			my $bNumeric = $bPart =~ m/^\d*$/;

# 			# numbers should come before words
# 			return -1 if     $aNumeric and not $bNumeric;
# 			return +1 if not $aNumeric and     $bNumeric;

# 			# both have the same type
# 			if ($aNumeric and $bNumeric) {
# 				next if $aPart == $bPart; # check next pair
# 				return $aPart <=> $bPart; # compare numerically
# 			} else {
# 				next if $aPart eq $bPart; # check next pair
# 				return $aPart cmp $bPart; # compare lexicographically
# 			}
# 		}
# 		return +1 if @aParts; # a has more sections, should go second
# 		return -1 if @bParts; # a had fewer sections, should go first
# 	} @items;
# }

sub sortByName($@) {
	my ($field, @items) = @_;

	my %itemsByIndex = ();
	if (ref($field) eq 'ARRAY') {
		foreach my $item (@items) {
			my $key = '';
			foreach (@$field) {
				$key .= $item->$_;    # in this case we assume
			}    #    all entries in @$field
			$itemsByIndex{$key} = $item;    #  are defined.
		}
	} else {
		%itemsByIndex = map { (defined $field) ? $_->$field : $_ => $_ } @items;
	}

	my @sKeys = sort {
		my @aParts = split m/(?<=\D)(?=\d)|(?<=\d)(?=\D)/, $a;
		my @bParts = split m/(?<=\D)(?=\d)|(?<=\d)(?=\D)/, $b;

		while (@aParts and @bParts) {
			my $aPart    = shift @aParts;
			my $bPart    = shift @bParts;
			my $aNumeric = $aPart =~ m/^\d*$/;
			my $bNumeric = $bPart =~ m/^\d*$/;

			# numbers should come before words
			return -1 if $aNumeric     and not $bNumeric;
			return +1 if not $aNumeric and $bNumeric;

			# both have the same type
			if ($aNumeric and $bNumeric) {
				next if $aPart == $bPart;    # check next pair
				return $aPart <=> $bPart;    # compare numerically
			} else {
				next if $aPart eq $bPart;    # check next pair
				return $aPart cmp $bPart;    # compare lexicographically
			}
		}
		return +1 if @aParts;    # a has more sections, should go second
		return -1 if @bParts;    # a had fewer sections, should go first
	} (keys %itemsByIndex);

	return map { $itemsByIndex{$_} } @sKeys;
}

################################################################################
# Sort Achievements by number and then by id
################################################################################

sub sortAchievements {
	my @Achievements = @_;

	# First sort by achievement id

	@Achievements = sort { uc($a->{achievement_id}) cmp uc($b->{achievement_id}) } @Achievements;

	# Next sort by number if there are numbers, otherwise sort by
	# category.

	@Achievements = sort { ($a->number || 0) <=> ($b->number || 0) } @Achievements;

	@Achievements = sort {
		if ($a->number && $b->number) {
			return $a->number <=> $b->number;
		} elsif ($a->{category} eq $b->{category}) {
			return 0;
		} elsif ($a->{category} eq "secret" or $b->{category} eq "level") {
			return -1;
		} elsif ($a->{category} eq "level" or $b->{category} eq "secret") {
			return 1;
		} else {
			return $a->{category} cmp $b->{category};
		}
	} @Achievements;

	return @Achievements;

}

################################################################################
# Validate strings and labels
################################################################################

sub not_blank ($) {    # check that a string exists and is not blank
	my $str = shift;
	return (defined($str) and $str =~ /\S/);
}

# Given $problem which should be a problem version, getTestProblemPosition returns the 0 based problem number for the
# problem on the test, and the 1 based page number for the page on the test that the problem is on.
sub getTestProblemPosition {
	my ($db, $problem) = @_;

	my $set            = $db->getMergedSetVersion($problem->user_id, $problem->set_id, $problem->version_id);
	my @problemNumbers = $db->listProblemVersions($set->user_id, $set->set_id, $set->version_id);

	my $problemNumber = 0;

	if ($set->problem_randorder) {
		# Find the test problem order using the set psvn for the seed in the same way that the GatewayQuiz module does.
		my @problemOrder = (0 .. $#problemNumbers);
		my $pgrand       = PGrandom->new;
		$pgrand->srand($set->psvn);
		my $count = 0;
		while (@problemOrder) {
			my $index = splice(@problemOrder, int($pgrand->rand(scalar(@problemOrder))), 1);
			if ($problemNumbers[$index] == $problem->problem_id) {
				$problemNumber = $count;
				last;
			}
			++$count;
		}
	} else {
		($problemNumber) = grep { $problemNumbers[$_] == $problem->problem_id } 0 .. $#problemNumbers;
	}

	my $pageNumber;

	# Update startProb and endProb for multipage tests
	if ($set->problems_per_page) {
		$pageNumber = ($problemNumber + 1) / $set->problems_per_page;
		$pageNumber = int($pageNumber) + 1 if int($pageNumber) != $pageNumber;
	} else {
		$pageNumber = 1;
	}

	return ($problemNumber, $pageNumber);
}

sub is_restricted {
	my ($db, $set, $studentName) = @_;

	# all sets open after the due date
	return () if after($set->due_date());

	my $setID = $set->set_id();
	my @needed;

	if ($set->restricted_release) {
		my @proposed_sets  = split(/\s*,\s*/, $set->restricted_release);
		my $required_score = sprintf("%.2f", $set->restricted_status || 0);

		my @good_sets;
		foreach (@proposed_sets) {
			push @good_sets, $_ if $db->existsGlobalSet($_);
		}

		foreach my $restrictor (@good_sets) {
			my $r_score        = 0;
			my $restrictor_set = $db->getGlobalSet($restrictor);

			if ($restrictor_set->assignment_type =~ /gateway/) {
				my @versions =
					$db->getSetVersionsWhere({ user_id => $studentName, set_id => { like => $restrictor . ',v%' } });
				foreach (@versions) {
					my $v_score = grade_set($db, $_, $studentName, 1);

					$r_score = $v_score if ($v_score > $r_score);
				}
			} else {
				$r_score = grade_set($db, $restrictor_set, $studentName, 0);
			}

			# round to evade machine rounding error
			$r_score = sprintf("%.2f", $r_score);
			if ($r_score < $required_score) {
				push @needed, $restrictor;
			}
		}
	}
	return unless @needed;
	return @needed;
}

# Takes in $db, $set, $studentName, $setIsVersioned and returns ($totalCorrect, $total) or the percentage correct.
sub grade_set {
	my ($db, $set, $studentName, $setIsVersioned, $wantProblemDetails) = @_;

	my $totalRight = 0;
	my $total      = 0;

	# This information is also accumulated if $wantProblemDetails is true.
	my $problem_scores             = [];
	my $problem_incorrect_attempts = [];

	# DBFIXME: To collect the problem records, we have to know which merge routines to call.  Should this really be an
	# issue here?  That is, shouldn't the database deal with it invisibly by detecting what the problem types are?
	my @problemRecords =
		$setIsVersioned
		? $db->getAllMergedProblemVersions($studentName, $set->set_id, $set->version_id)
		: $db->getAllMergedUserProblems($studentName, $set->set_id);

	# For jitar sets we only use the top level problems.
	if ($set->assignment_type && $set->assignment_type eq 'jitar') {
		my @topLevelProblems;
		for my $problem (@problemRecords) {
			my @seq = jitar_id_to_seq($problem->problem_id);
			push @topLevelProblems, $problem if $#seq == 0;
		}

		@problemRecords = @topLevelProblems;
	}

	if ($wantProblemDetails) {
		# Sort records.  For gateway/quiz assignments we have to be careful about the order in which the problems are
		# displayed, because they may be in a random order.
		if ($set->problem_randorder) {
			my @newOrder;
			my @probOrder = (0 .. $#problemRecords);
			# Reorder using the set psvn for the seed in the same way that the GatewayQuiz module does.
			my $pgrand = PGrandom->new();
			$pgrand->srand($set->psvn);
			while (@probOrder) {
				my $i = int($pgrand->rand(scalar(@probOrder)));
				push(@newOrder, splice(@probOrder, $i, 1));
			}
		  # Now $newOrder[i] = pNum - 1, where pNum is the problem number to display in the ith position on the test for
		  # sorting. Invert this mapping.
			my %pSort = map { $problemRecords[ $newOrder[$_] ]->problem_id => $_ } (0 .. $#newOrder);

			@problemRecords = sort { $pSort{ $a->problem_id } <=> $pSort{ $b->problem_id } } @problemRecords;
		} else {
			# Sort records
			@problemRecords = sort { $a->problem_id <=> $b->problem_id } @problemRecords;
		}
	}

	for my $problemRecord (@problemRecords) {
		my $status = $problemRecord->status || 0;

		# Get the adjusted jitar grade for top level problems if this is a jitar set.
		$status = jitar_problem_adjusted_status($problemRecord, $db) if $set->assignment_type eq 'jitar';

		# Clamp the status value between 0 and 1.
		$status = 0 if $status < 0;
		$status = 1 if $status > 1;

		if ($wantProblemDetails) {
			push(@$problem_scores,             $problemRecord->attempted ? 100 * wwRound(2, $status) : '&nbsp;.&nbsp;');
			push(@$problem_incorrect_attempts, $problemRecord->num_incorrect || 0);
		}

		my $probValue = $problemRecord->value;
		$probValue = 1 unless defined $probValue && $probValue ne '';    # FIXME: Set defaults here?
		$total      += $probValue;
		$totalRight += $status * $probValue;
	}

	if (wantarray) {
		return ($totalRight, $total, $problem_scores, $problem_incorrect_attempts);
	} else {
		return $total ? $totalRight / $total : 0;
	}
}

# Takes in $db, $set, $setName, $studentName,
# and returns ($totalCorrect,$total) or the percentage correct
# for the highest scoring gateway

sub grade_gateway {
	my ($db, $set, $setName, $studentName) = @_;

	my @versionNums = $db->listSetVersions($studentName, $setName);

	my $bestTotalRight = 0;
	my $bestTotal      = 0;

	if (@versionNums) {
		for my $i (@versionNums) {
			my $versionedSet = $db->getSetVersion($studentName, $setName, $i);

			my ($totalRight, $total) = grade_set($db, $versionedSet, $studentName, 1);
			if ($totalRight > $bestTotalRight) {
				$bestTotalRight = $totalRight;
				$bestTotal      = $total;
			}
		}
	}

	if (wantarray) {
		return ($bestTotalRight, $bestTotal);
	} else {
		return 0 unless $bestTotal;
		return $bestTotalRight / $bestTotal;
	}
}

# Takes in $db, $studentName,
# and returns ($totalCorrect,$total) or the percentage correct
# for all sets in the course

sub grade_all_sets {
	my ($db, $studentName) = @_;

	my @setIDs     = $db->listUserSets($studentName);
	my @userSetIDs = map { [ $studentName, $_ ] } @setIDs;
	my @userSets   = $db->getMergedSets(@userSetIDs);

	my $courseTotal      = 0;
	my $courseTotalRight = 0;

	foreach my $userSet (@userSets) {
		next unless (after($userSet->open_date()));
		if ($userSet->assignment_type() =~ /gateway/) {

			my ($totalRight, $total) = grade_gateway($db, $userSet, $userSet->set_id, $studentName);
			$courseTotalRight += $totalRight;
			$courseTotal      += $total;
		} else {
			my ($totalRight, $total) = grade_set($db, $userSet, $studentName, 0);

			$courseTotalRight += $totalRight;
			$courseTotal      += $total;
		}
	}

	if (wantarray) {
		return ($courseTotalRight, $courseTotal);
	} else {
		return 0 unless $courseTotal;
		return $courseTotalRight / $courseTotal;
	}

}

#takes a tree sequence and returns the jitar id
#  This id is specially crafted signed 32 bit integer of the form, in binary
#  SAAAAAAABBBBBBCCCCCCDDDDEEEEFFFF
#  Here A is the level 1 index, B is the level 2 index, and
#  C, D, E and F are the indexes for levels 3 through 6.
#
#  Note:  Level 1 can contain indexes up to 125.  Levels 2 and 3 can contain
#         indxes up to 63.  For levels 4 through
#         six you are limited to 15.

sub seq_to_jitar_id {
	my @seq = @_;

	die("Jitar index 1 must be between 1 and 125")
		unless (defined($seq[0]) && $seq[0] < 126);

	my $id = $seq[0];
	my $ind;

	my @JITAR_SHIFT = @{ JITAR_SHIFT() };

	#shift first index to first two bytes
	$id = $id << $JITAR_SHIFT[0];

	#look for second and third index
	for (my $i = 1; $i < 3; $i++) {
		if (defined($seq[$i])) {
			$ind = $seq[$i];
			die("Jitar index " . ($i + 1) . " must be less than 63")
				unless $ind < 63;

			#shift index and or it with id to put it in right place
			$ind = $ind << $JITAR_SHIFT[$i];
			$id  = $id | $ind;
		}
	}

	#look for remaining 3 index's
	for (my $i = 3; $i < 6; $i++) {
		if (defined($seq[$i])) {
			$ind = $seq[$i];
			die("Jitar index " . ($i + 1) . " must be less than 16")
				unless $ind < 16;

			#shift index and or it with id to put it in right place
			$ind = $ind << $JITAR_SHIFT[$i];
			$id  = $id | $ind;
		}
	}

	return $id;
}

# Takes a jitar_id and returns the tree sequence
#  Jitar id's have the format described above.
sub jitar_id_to_seq {
	my $id = shift;
	my $ind;
	my @seq;

	my @JITAR_SHIFT = @{ JITAR_SHIFT() };
	my @JITAR_MASK  = @{ JITAR_MASK() };

	for (my $i = 0; $i < 6; $i++) {
		$ind = $id;
		#use a mask to isolate only the bits we want for this index
		# and shift them to get the index
		$ind = $ind & $JITAR_MASK[$i];
		$ind = $ind >> $JITAR_SHIFT[$i];

		#quit if we dont have a nonzero index
		last unless $ind;

		$seq[$i] = $ind;
	}

	return @seq;
}

# Takes in ($db, $userID, $setID, $problemID) and returns 1 if the
# problem is hidden.  The problem is hidden if the number of attempts
# on the parent problem is greater than att_to_open_children, or if the user
# has run out of attempts.  Everything is opened up after the due date

sub is_jitar_problem_hidden {
	my ($db, $userID, $setID, $problemID) = @_;

	die "Not enough arguments.  Use is_jitar_problem_hidden(db,userID,setID,problemID)"
		unless ($db && $userID && $setID && $problemID);

	my $mergedSet = $db->getMergedSet($userID, $setID);

	unless ($mergedSet) {
		warn "Couldn't get set $setID for user $userID from the database";
		return 0;
	}

	# only makes sense for jitar sets
	return 0 unless ($mergedSet->assignment_type eq 'jitar');

	# the set opens everything up after the due date.
	return 0 if (after($mergedSet->due_date));

	my @idSeq       = jitar_id_to_seq($problemID);
	my @parentIDSeq = @idSeq;

	unless ($#parentIDSeq != 0) {
		#this means we are at a top level problem and this check doesnt make sense
		return 0;
	}

	pop @parentIDSeq;
	while (@parentIDSeq) {

		my $parentProbID = seq_to_jitar_id(@parentIDSeq);

		my $userParentProb = $db->getMergedProblem($userID, $setID, $parentProbID);

		unless ($userParentProb) {
			warn "Couldn't get problem $parentProbID for user $userID and set $setID from the database";
			return 0;
		}

		# the child problems are closed unless the number of incorrect attempts is above the
		# attempts to open children, or if they have exausted their max_attempts
		# if att_to_open_children is -1 we just use max attempts
		# if max_attempts is -1 then they are always less than max attempts
		if (
			(
				$userParentProb->att_to_open_children == -1
				|| $userParentProb->num_incorrect() < $userParentProb->att_to_open_children()
			)
			&& ($userParentProb->max_attempts == -1
				|| $userParentProb->num_incorrect() < $userParentProb->max_attempts())
			)
		{
			return 1;
		}
		pop @parentIDSeq;
	}

	# if we get here then all of the parents are open so the problem is open.
	return 0;
}

# takes in ($db, $ce, $userID, $setID, $problemID) and returns 1 if the jitar problem is closed
# jitar problems are closed if the restrict_prob_progression variable is set on the set
# and if the previous problem is closed, or hasn't been finished yet.
# The first problem in a level is always open.

sub is_jitar_problem_closed {
	my ($db, $ce, $userID, $setID, $problemID) = @_;

	die "Not enough arguments.  Use is_jitar_problem_closed(db,userID,setID,problemID)"
		unless ($db && $ce && $userID && $setID && $problemID);

	my $mergedSet = $db->getMergedSet($userID, $setID);

	unless ($mergedSet) {
		warn "Couldn't get set $setID for user $userID from the database";
		return 0;
	}

	# return 0 unless we are a restricted jitar set
	return 0 unless ($mergedSet->assignment_type eq 'jitar' && $mergedSet->restrict_prob_progression());

	# the set opens everything up after the due date.
	return 0 if (after($mergedSet->due_date));

	my $prob;
	my $id;
	my @idSeq     = jitar_id_to_seq($problemID);
	my @parentSeq = @idSeq;

	# problems are automatically closed if their parents are closed
	#this means we cant find a previous problem to test against so we are open as long as the parent is open
	pop(@parentSeq);

	#if we can't get a parent problem then this is a top level problem and we
	# we just check the previous.
	if (@parentSeq) {
		$id = seq_to_jitar_id(@parentSeq);
		if (is_jitar_problem_closed($db, $ce, $userID, $setID, $id)) {
			return 1;
		}
	}

	# if the parent is open then we are open if the previous
	# problem has been "completed" or, if we are the first problem in this level

	do {
		$idSeq[$#idSeq]--;

		# in this case we are the first problem in the level
		if ($idSeq[$#idSeq] == 0) {
			return 0;
		}

		$id = seq_to_jitar_id(@idSeq);
	} until ($db->existsUserProblem($userID, $setID, $id));

	$prob = $db->getMergedProblem($userID, $setID, $id);

	# we have to test against the target status in case the student
	# is working in the reduced scoring period
	my $targetStatus = 1;
	if ($ce->{pg}{ansEvalDefaults}{enableReducedScoring}
		&& $mergedSet->enable_reduced_scoring
		&& after($mergedSet->reduced_scoring_date))
	{
		$targetStatus = $ce->{pg}{ansEvalDefaults}{reducedScoringValue};
	}

	if (abs(jitar_problem_adjusted_status($prob, $db) - $targetStatus) < .001
		|| jitar_problem_finished($prob, $db))
	{

		# either the previous problem is 100% or is finished
		return 0;
	} else {

		#in this case the previous problem is hidden
		return 1;
	}

}

# returns the adjusted status for a jitar problem.
# this is either the problems status or it is the greater of the
# status and the score generated by taking the weighted average of all
# child problems that have the "counts_parent_grade" flag set

sub jitar_problem_adjusted_status {
	my ($userProblem, $db) = @_;

	#this is goign to happen often enough that the check saves time
	return 1 if $userProblem->status == 1;

	my @problemSeq = jitar_id_to_seq($userProblem->problem_id);

	my @problemIDs = $db->listUserProblems($userProblem->user_id, $userProblem->set_id);

	my @weights;
	my @scores;

ID: foreach my $id (@problemIDs) {
		my @seq = jitar_id_to_seq($id);

		#check and see if this is a child
		# it has to be one level deper
		next unless $#seq == $#problemSeq + 1;

		# and it has to equal @seq up to the penultimate index
		for (my $i = 0; $i <= $#problemSeq; $i++) {
			next ID unless $seq[$i] == $problemSeq[$i];
		}

		#check to see if this counts towards the parent grade
		my $problem = $db->getMergedProblem($userProblem->user_id, $userProblem->set_id, $id);

		die "Couldn't get problem $id for user "
			. $userProblem->user_id
			. " and set "
			. $userProblem->set_id
			. " from the database"
			unless $problem;

		# skip if it doesnt
		next unless $problem->counts_parent_grade();

		# if it does count then add its adjusted status to the grading array
		push @weights, $problem->value;
		push @scores,  jitar_problem_adjusted_status($problem, $db);
	}

	# if no children count towards the problem grade return status
	return $userProblem->status unless (@weights && @scores);

	# if children do count then return the larger of the two (?)
	my $childScore  = 0;
	my $totalWeight = 0;
	for (my $i = 0; $i <= $#scores; $i++) {
		$childScore  += $scores[$i] * $weights[$i];
		$totalWeight += $weights[$i];
	}

	$childScore = $childScore / $totalWeight;

	if ($childScore > $userProblem->status) {
		return $childScore;
	} else {
		return $userProblem->status;
	}
}

# returns 1 if the given problem is "finished"  This happens when the problem attempts have
# been maxed out, and the attempts of any children with the "counts_to_parent_grade" also
# have their attemtps maxed out.  (In other words if the grade can't be raised any more)

sub jitar_problem_finished {
	my ($userProblem, $db) = @_;

	# the problem is open if you can still make attempts and you dont have a 100%
	return 0
		if (
			$userProblem->status < 1
			&& ($userProblem->max_attempts == -1
				|| $userProblem->max_attempts > ($userProblem->num_correct + $userProblem->num_incorrect))
		);

	# find children
	my @problemSeq = jitar_id_to_seq($userProblem->problem_id);

	my @problemIDs = $db->listUserProblems($userProblem->user_id, $userProblem->set_id);

ID: foreach my $id (@problemIDs) {
		my @seq = jitar_id_to_seq($id);

		#check and see if this is a child
		next unless $#seq == $#problemSeq + 1;
		for (my $i = 0; $i <= $#problemSeq; $i++) {
			next ID unless $seq[$i] == $problemSeq[$i];
		}

		#check to see if this counts towards the parent grade
		my $problem = $db->getMergedProblem($userProblem->user_id, $userProblem->set_id, $id);

		die "Couldn't get problem $id for user "
			. $userProblem->user_id
			. " and set "
			. $userProblem->set_id
			. " from the database"
			unless $problem;

		# if this doesn't count then we dont need to worry about it
		next unless $problem->counts_parent_grade();

		#if it does then see if the problem is finished
		# if it isn't then the parent isnt finished either.
		return 0 unless jitar_problem_finished($problem, $db);

	}

	# if we got here then the problem is finished
	return 1;
}

# Sorts problem ID's so that all just-in-time like ids are at the bottom
# of the list in order and other problems

sub prob_id_sort_comparator {

	my @seqa = split(/\./, $a);
	my @seqb = split(/\./, $b);

	# go through problem number sequence
	for (my $i = 0; $i <= $#seqa; $i++) {
		# if at some point two numbers are different return the comparison.
		# e.g. 2.1.3 vs 1.2.6
		if ($seqa[$i] != $seqb[$i]) {
			return $seqa[$i] <=> $seqb[$i];
		}

		# if all of the values are equal but b is shorter then it comes first
		# i.e. 2.1.3 vs 2.1
		if ($i == $#seqb) {
			return 1;
		}
	}

	# if all of the values are equal and a and b are the same length then equal
	# otherwise a was shorter than b so a comes first.
	if ($#seqa == $#seqb) {
		return 0;
	} else {
		return -1;
	}
}

sub prob_id_sort {
	return sort prob_id_sort_comparator @_;
}

# Get the array of all permission levels at or above a given level
sub role_and_above {
	my ($userRoles, $role) = @_;
	my $role_array = [$role];
	for my $userRole (keys %$userRoles) {
		push @$role_array, $userRole if ($userRoles->{$userRole} > $userRoles->{$role});
	}
	return $role_array;
}

# Requires a ContentGenerator object, and a permission type.
# If the optional sender argument is provided, then filter on the section of the given sender.
sub fetchEmailRecipients {
	my ($c, $permissionType, $sender) = @_;
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;

	my @recipients;
	push(@recipients, @{ $ce->{mail}{feedbackRecipients} }) if ref($ce->{mail}{feedbackRecipients}) eq 'ARRAY';

	return @recipients unless $permissionType && defined $ce->{permissionLevels}{$permissionType};

	my $roles =
		ref $ce->{permissionLevels}{$permissionType} eq 'ARRAY'
		? $ce->{permissionLevels}{$permissionType}
		: role_and_above($ce->{userRoles}, $ce->{permissionLevels}{$permissionType});
	my @rolePermissionLevels = map { $ce->{userRoles}{$_} } grep { defined $ce->{userRoles}{$_} } @$roles;
	return @recipients unless @rolePermissionLevels;

	my $user_ids = [ map { $_->user_id } $db->getPermissionLevelsWhere({ permission => \@rolePermissionLevels }) ];

	push(
		@recipients,
		map { $_->rfc822_mailbox } $db->getUsersWhere({
			user_id       => $user_ids,
			email_address => { '!=', undef },
			$ce->{feedback_by_section}
				&& defined $sender
				&& defined $sender->section ? (section => $sender->section) : (),
		})
	);

	return @recipients;
}

sub processEmailMessage {
	my ($text, $user_record, $STATUS, $merge_data, $for_preview) = @_;

	# User macros that can be used in the email message
	my $SID        = $user_record->student_id;
	my $FN         = $user_record->first_name;
	my $LN         = $user_record->last_name;
	my $SECTION    = $user_record->section;
	my $RECITATION = $user_record->recitation;
	my $EMAIL      = $user_record->email_address;
	my $LOGIN      = $user_record->user_id;

	# Get record from merge data.
	my @COL = defined($merge_data->{$SID}) ? @{ $merge_data->{$SID} } : ();
	unshift(@COL, '');    # This makes COL[1] the first column.

	# For safety, only evaluate special variables.
	my $msg = $text;
	$msg =~ s/\$SID/$SID/g;
	$msg =~ s/\$LN/$LN/g;
	$msg =~ s/\$FN/$FN/g;
	$msg =~ s/\$STATUS/$STATUS/g;
	$msg =~ s/\$SECTION/$SECTION/g;
	$msg =~ s/\$RECITATION/$RECITATION/g;
	$msg =~ s/\$EMAIL/$EMAIL/g;
	$msg =~ s/\$LOGIN/$LOGIN/g;

	if (defined $COL[1]) {
		$msg =~ s/\$COL\[(\-?\d+)\]/$COL[$1]/g;
	} else {
		$msg =~ s/\$COL\[(\-?\d+)\]//g;
	}

	$msg =~ s/\r//g;

	if ($for_preview) {
		my @preview_COL = @COL;
		shift @preview_COL;    # Shift of the added empty string for preview.
		return $msg,
			join(' ',
				'', (map { "COL[$_]" . '&nbsp;' x (3 - length $_) } 1 .. $#COL),
				'<br>', (map { $_ =~ s/\s/&nbsp;/gr } map { sprintf('%-8.8s', $_); } @preview_COL));
	} else {
		return $msg;
	}
}

# This function abstracts the process of creating a transport layer for SendMail.
# It is used in Feedback.pm, SendMail.pm and Utils/ProblemProcessing.pm (for JITAR messages).
sub createEmailSenderTransportSMTP {
	my $ce = shift;
	return Email::Sender::Transport::SMTP->new({
		host => $ce->{mail}{smtpServer},
		ssl  => $ce->{mail}{tls_allowed} // 0,
		defined $ce->{mail}->{smtpPort} ? (port => $ce->{mail}{smtpPort}) : (),
		timeout => $ce->{mail}{smtpTimeout},
	});
}

# Requires a CG object.
# The following optional parameters may be passed:
# set_id: A problem set name
# problem_id: Number of a problem in the set
# url_type:  This should a string with the value 'relative' or 'absolute' to
# return a single URL, or undefined to return an array containing both URLs
# this subroutine could be expanded to.

sub generateURLs {
	my $c        = shift;
	my %params   = @_;
	my $db       = $c->db;
	my $userName = $c->param('user');

	# generate context URLs
	my $emailableURL;
	my $returnURL;
	if ($userName) {
		my $routePath;
		my @args;
		if (defined $params{set_id} && $params{set_id} ne '') {
			if ($params{problem_id}) {
				$routePath = $c->url_for('problem_detail', setID => $params{set_id}, problemID => $params{problem_id});
				@args      = qw/displayMode showOldAnswers showCorrectAnswers showHints showSolutions/;
			} else {
				$routePath = $c->url_for('problem_list', setID => $params{set_id});
			}
		} else {
			$routePath = $c->url_for('set_list');
		}
		$emailableURL = $c->systemLink(
			$routePath,
			authen      => 0,
			params      => [ 'effectiveUser', @args ],
			use_abs_url => 1,
		);
		$returnURL = $c->systemLink($routePath, params => [@args]);
	} else {
		$emailableURL = '(not available)';
		$returnURL    = '';
	}
	if ($params{url_type}) {
		if ($params{url_type} eq 'relative') {
			return $returnURL;
		} else {
			return $emailableURL;    # could include other types of URL here...
		}
	} else {
		return ($emailableURL, $returnURL);
	}
}

my $staticWWAssets;
my $staticPGAssets;
my $thirdPartyWWDependencies;
my $thirdPartyPGDependencies;

sub readJSON {
	my $fileName = shift;

	return unless -r $fileName;

	open(my $fh, "<:encoding(UTF-8)", $fileName) or die "FATAL: Unable to open '$fileName'!";
	local $/;
	my $data = <$fh>;
	close $fh;

	return JSON->new->decode($data);
}

sub getThirdPartyAssetURL {
	my ($file, $dependencies, $baseURL, $useCDN) = @_;

	for (keys %$dependencies) {
		if ($file =~ /^node_modules\/$_\/(.*)$/) {
			if ($useCDN && $1 !~ /mathquill/) {
				return
					"https://cdn.jsdelivr.net/npm/$_\@"
					. substr($dependencies->{$_}, 1) . '/'
					. ($1 =~ s/(?:\.min)?\.(js|css)$/.min.$1/gr);
			} else {
				return "$baseURL/$file?version=" . ($dependencies->{$_} =~ s/#/@/gr);
			}
		}
	}
	return;
}

# Get the URL for static assets.
sub getAssetURL {
	my ($ce, $file, $isThemeFile) = @_;

	# Load the static files list generated by `npm install` the first time this method is called.
	unless ($staticWWAssets) {
		my $staticAssetsList = "$ce->{webworkDirs}{htdocs}/static-assets.json";
		$staticWWAssets = readJSON($staticAssetsList);
		unless ($staticWWAssets) {
			warn "ERROR: '$staticAssetsList' not found or not readable!\n"
				. "You may need to run 'npm install' from '$ce->{webworkDirs}{htdocs}'.";
			$staticWWAssets = {};
		}
	}

	unless ($staticPGAssets) {
		my $staticAssetsList = "$ce->{pg_dir}/htdocs/static-assets.json";
		$staticPGAssets = readJSON($staticAssetsList);
		unless ($staticPGAssets) {
			warn "ERROR: '$staticAssetsList' not found or not readable!\n"
				. "You may need to run 'npm install' from '$ce->{pg_dir}/htdocs'.";
			$staticPGAssets = {};
		}
	}

	# Load the package.json files the first time this method is called.
	unless ($thirdPartyWWDependencies) {
		my $packageJSON = "$ce->{webworkDirs}{htdocs}/package.json";
		my $data        = readJSON($packageJSON);
		warn "ERROR: '$packageJSON' not found or not readable!\n" unless $data && defined $data->{dependencies};
		$thirdPartyWWDependencies = $data->{dependencies} // {};
	}

	unless ($thirdPartyPGDependencies) {
		my $packageJSON = "$ce->{pg_dir}/htdocs/package.json";
		my $data        = readJSON($packageJSON);
		warn "ERROR: '$packageJSON' not found or not readable!\n" unless $data && defined $data->{dependencies};
		$thirdPartyPGDependencies = $data->{dependencies} // {};
	}

	# Check to see if this is a third party asset file in node_modules (either in webwork2/htdocs or pg/htdocs).
	# If so, then either serve it from a CDN if requested, or serve it directly with the library version
	# appended as a URL parameter.
	if ($file =~ /^node_modules/) {
		my $wwFile = getThirdPartyAssetURL(
			$file, $thirdPartyWWDependencies,
			$ce->{webworkURLs}{htdocs},
			$ce->{options}{thirdPartyAssetsUseCDN}
		);
		return $wwFile if $wwFile;

		my $pgFile =
			getThirdPartyAssetURL($file, $thirdPartyPGDependencies, $ce->{pg_htdocs_url},
				$ce->{options}{thirdPartyAssetsUseCDN});
		return $pgFile if $pgFile;
	}

	# If a right-to-left language is enabled (Hebrew or Arabic) and this is a css file that is not a third party asset,
	# then determine the rtl variant file name.  This will be looked for first in the asset lists.
	my $rtlfile =
		($ce->{language} =~ /^(he|ar)/ && $file !~ /node_modules/ && $file =~ /\.css$/)
		? $file =~ s/\.css$/.rtl.css/r
		: undef;

	if ($isThemeFile) {
		# If the theme directory is the default location, then the file is in the static assets list.
		# Otherwise just use the given file name.
		if ($ce->{webworkDirs}{themes} =~ /^$ce->{webworkDirs}{htdocs}\/themes$/) {
			$rtlfile = "themes/$ce->{defaultTheme}/$rtlfile" if defined $rtlfile;
			$file    = "themes/$ce->{defaultTheme}/$file";
		} else {
			return "$ce->{webworkURLs}{themes}/$ce->{defaultTheme}/$file";
		}
	}

	# First check to see if this is a file in the webwork htdocs location with a rtl variant.
	return "$ce->{webworkURLs}{htdocs}/$staticWWAssets->{$rtlfile}"
		if defined $rtlfile && defined $staticWWAssets->{$rtlfile};

	# Next check to see if this is a file in the webwork htdocs location.
	return "$ce->{webworkURLs}{htdocs}/$staticWWAssets->{$file}" if defined $staticWWAssets->{$file};

	# Now check to see if this is a file in the pg htdocs location with a rtl variant.
	return "$ce->{pg_htdocs_url}/$staticPGAssets->{$rtlfile}"
		if defined $rtlfile && defined $staticPGAssets->{$rtlfile};

	# Next check to see if this is a file in the pg htdocs location.
	return "$ce->{pg_htdocs_url}/$staticPGAssets->{$file}" if defined $staticPGAssets->{$file};

	# If the file was not found in the lists, then assume it is in the webwork htdocs location, and use the given file
	# name.  If it is actually in the pg htdocs location, then the Mojolicious rewrite will send it there.
	return "$ce->{webworkURLs}{htdocs}/$file";
}

# This is a dummy function used to mark strings for localization

sub x {
	return @_;
}

1;
