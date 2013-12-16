package WeBWorK::GeneralUtils;
use base qw(Exporter);

### this is a number of subrotines from the webwork2 version of WeBWorK::Utils


use strict;
use warnings;
use DateTime;
use DateTime::TimeZone;
use Date::Parse;
use Date::Format;


our @EXPORT    = ();
our @EXPORT_OK = qw(parseDateTime decodeAnswers encodeAnswers writeCourseLog writeLog writeTimingLogEntry readDirectory 
		readFile runtime_use cryptPassword);



################################################################################
# Date/time processing
################################################################################

=head2 Date/time processing

=over

=item $dateTime = parseDateTime($string, $display_tz)

Parses $string as a datetime. If $display_tz is given, $string is assumed to be
in that timezone. Otherwise, the server's timezone is used. The result,
$dateTime, is an integer UNIX datetime (epoch) in the server's timezone.

=cut

# This is a modified version of the subroutine of the same name from WeBWorK
# 1.9.05's scripts/FILE.pl (v1.13). It has been modified to understand time
# zones. The time zone specification must appear at the end of the string and be
# preceded by whitespace. The return value is a list consisting of the following
# elements:
# 
#     ($second, $minute, $hour, $day, $month, $year, $zone)
# 
# $second, $minute, $hour, $day, and $month are zero-indexed. $year is the
# number of years since 1900. $zone is a string (hopefully) representing the
# time zone.
# 
# Error handling has also been improved. Exceptions are now thrown for errors,
# and more information is given about the nature of errors.
# 
sub unformatDateAndTime {
	my ($string) = @_;
	my $orgString = $string;
	
	$string =~ s|^\s+||;
	$string =~ s|\s+$||;
	$string =~ s|at| at |i; ## OK if forget to enter spaces or use wrong case
	$string =~ s|AM| AM|i;	## OK if forget to enter spaces or use wrong case
	$string =~ s|PM| PM|i;	## OK if forget to enter spaces or use wrong case
	$string =~ s|,| at |;	## start translating old form of date/time to new form
	
	# case where the at is missing: MM/DD/YYYY at HH:MM AMPM ZONE
	unformatDateAndTime_error($orgString, "The 'at' appears to be missing.")
		if $string =~ m|^\s*[\/\d]+\s+[:\d]+|;
	
	my ($date, $at, $time, $AMPM, $TZ) = split /\s+/, $string;
	
	unformatDateAndTime_error($orgString, "The date and/or time appear to be missing.", $date, $time, $AMPM, $TZ)
		unless defined $date and defined $at and defined $time;
	
	# deal with military time
	unless ($time =~ /:/) {
		{  ##bare block for 'case" structure
			$time =~ /(\d\d)(\d\d)/;
			my $tmp_hour = $1;
			my $tmp_min = $2;
			if ($tmp_hour eq '00') {$time = "12:$tmp_min"; $AMPM = 'AM';last;}
			if ($tmp_hour eq '12') {$time = "12:$tmp_min"; $AMPM = 'PM';last;}
			if ($tmp_hour < 12) {$time = "$tmp_hour:$tmp_min"; $AMPM = 'AM';last;}
			if ($tmp_hour < 24) {
				$tmp_hour = $tmp_hour - 12;
				$time = "$tmp_hour:$tmp_min";
				$AMPM = 'PM';
			}
		}  ##end of bare block for 'case" structure

	}
	
	# default value for $AMPM
	$AMPM = "AM" unless defined $AMPM;
 	
	my ($mday, $mon, $year, $wday, $yday, $sec, $pm, $min, $hour);
	$sec=0;
	$time =~ /^([0-9]+)\s*\:\s*([0-9]*)/;
	$min=$2;
	$hour = $1;
	unformatDateAndTime_error($orgString, "Hour must be in the range [1,12].", $date, $time, $AMPM, $TZ)
		if $hour < 1 or $hour > 12;
	unformatDateAndTime_error($orgString, "Minute must be in the range [0-59].", $date, $time, $AMPM, $TZ)
		if $min < 0 or $min > 59;
	$pm = 0;
	$pm = 12 if ($AMPM =~/PM/ and $hour < 12);
	$hour += $pm;
	$hour = 0 if ($AMPM =~/AM/ and $hour == 12);
	$date =~  m|([0-9]+)\s*/\s*([0-9]+)/\s*([0-9]+)|;
	$mday =$2;
	$mon=($1-1);
	unformatDateAndTime_error($orgString, "Day must be in the range [1,31].", $date, $time, $AMPM, $TZ)
		if $mday < 1 or $mday > 31;
	unformatDateAndTime_error($orgString, "Month must be in the range [1,12].", $date, $time, $AMPM, $TZ)
		if $mon < 0 or $mon > 11;
	$year=$3;
	$wday="";
	$yday="";
	return ($sec, $min, $hour, $mday, $mon, $year, $TZ);
}

sub unformatDateAndTime_error {
	
	if (@_ > 2) {
		my ($orgString, $error, $date, $time, $AMPM, $TZ) = @_;
		$date = "(undefined)" unless defined $date;
		$time = "(undefined)" unless defined $time;
		$AMPM = "(undefined)" unless defined $AMPM;
		$TZ   = "(undefined)" unless defined $TZ;
		die "Incorrect date/time format \"$orgString\": $error\n",
			"Correct format is MM/DD/YY at HH:MM AMPM ZONE\n",
			"\tdate = $date\n",
			"\ttime = $time\n",
			"\tampm = $AMPM\n",
			"\tzone = $TZ\n";
	} else {
		my ($orgString, $error) = @_;
		die "Incorrect date/time format \"$orgString\": $error\n",
			"Correct format is MM/DD/YY at HH:MM AMPM ZONE\n";
	}
}

sub parseDateTime($;$) {
	my ($string, $display_tz) = @_;
	warn "time zone not defined".caller() unless defined($display_tz);
	$display_tz ||= "local";
	$display_tz = verify_timezone($display_tz);


	# use WeBWorK 1 date parsing routine
	my ($second, $minute, $hour, $day, $month, $year, $zone) = unformatDateAndTime($string);
	my $zone_str = defined $zone ? $zone : "UNDEF";
	#warn "\tunformatDateAndTime: $second $minute $hour $day $month $year $zone_str\n";
	
	# DateTime expects month 1-12, not 0-11
	$month++;
	
	# Do what Time::Local does to ambiguous years
	{
		my $ThisYear     = (localtime())[5]; # FIXME: should be relative to $string's timezone
		my $Breakpoint   = ($ThisYear + 50) % 100;
		my $NextCentury  = $ThisYear - $ThisYear % 100;
		   $NextCentury += 100 if $Breakpoint < 50;
		my $Century      = $NextCentury - 100;
		my $SecOff       = 0;
		
		if ($year >= 1000) {
			# leave alone
		} elsif ($year < 100 and $year >= 0) {
			$year += ($year > $Breakpoint) ? $Century : $NextCentury;
			$year += 1900;
		} else {
			$year += 1900;
		}
	}
	
	my $epoch;
	
	if (defined $zone and $zone ne "") {
		if (DateTime::TimeZone->is_valid_name($zone)) {
			#warn "\t\$zone is valid according to DateTime::TimeZone\n";
			
			my $dt = new DateTime(
				year      => $year,
				month     => $month,
				day       => $day,
				hour      => $hour,
				minute    => $minute,
				second    => $second,
				time_zone => $zone,
			);
			#warn "\t\$dt = ", $dt->strftime(DATE_FORMAT), "\n";
			
			$epoch = $dt->epoch;
			#warn "\t\$dt->epoch = $epoch\n";
		} else {
			#warn "\t\$zone is invalid according to DateTime::TimeZone, so we ask Time::Zone\n";
			
			# treat the date/time as UTC
			my $dt = new DateTime(
				year      => $year,
				month     => $month,
				day       => $day,
				hour      => $hour,
				minute    => $minute,
				second    => $second,
				time_zone => "UTC",
			);
			#warn "\t\$dt = ", $dt->strftime(DATE_FORMAT), "\n";
			
			# convert to an epoch value
			my $utc_epoch = $dt->epoch
				or die "Date/time '$string' not representable as an epoch. Get more bits!\n";
			#warn "\t\$utc_epoch = $utc_epoch\n";
			
			# get offset for supplied timezone and utc_epoch
			my $offset = tz_offset($zone, $utc_epoch) or die "Time zone '$zone' not recognized.\n";
			#warn "\t\$zone is valid according to Time::Zone (\$offset = $offset)\n";
			
			#$epoch = $utc_epoch + $offset;
			##warn "\t\$epoch = \$utc_epoch + \$offset = $epoch\n";
			
			$dt->subtract(seconds => $offset);
			#warn "\t\$dt - \$offset = ", $dt->strftime(DATE_FORMAT), "\n";
			
			$epoch = $dt->epoch;
			#warn "\t\$epoch = $epoch\n";
		}
	} else {
		#warn "\t\$zone not supplied, using \$display_tz\n";
		
		my $dt = new DateTime(
			year      => $year,
			month     => $month,
			day       => $day,
			hour      => $hour,
			minute    => $minute,
			second    => $second,
			time_zone => $display_tz,
		);
		#warn "\t\$dt = ", $dt->strftime(DATE_FORMAT), "\n";
		
		$epoch = $dt->epoch;
		#warn "\t\$epoch = $epoch\n";
	}
	
	return $epoch;
}


our $BASE64_ENCODED = 'base64_encoded:';  
#  use constant BASE64_ENCODED = 'base64_encoded;
#  was not evaluated in the matching and substitution
#  statements


sub decodeAnswers($) {
	my $serialized = shift;
	return unless defined $serialized and $serialized;
	my $array_ref = eval{ Storable::thaw($serialized) };
	if ($@) {
		# My hope is that this next warning is no longer needed since there are few legacy base64 days and the fix seems transparent.
		# warn "problem fetching answers -- possibly left over from base64 days. Not to worry -- press preview or submit and this will go away  permanently for this question.   $@";
		return ();
	} else {
		return @{$array_ref};
	}
}

sub encodeAnswers(\%\@) {
	my %hash = %{shift()};
	my @order = @{shift()};
	my @ordered_hash = ();
	foreach my $key (@order) {
		push @ordered_hash, $key, $hash{$key};
	}
	return Storable::nfreeze( \@ordered_hash);

}


################################################################################
# Logging
################################################################################

sub writeLog($$@) {
	my ($ce, $facility, @message) = @_;
	unless ($ce->{webworkFiles}->{logs}->{$facility}) {
		warn "There is no log file for the $facility facility defined.\n";
		return;
	}
	my $logFile = $ce->{webworkFiles}->{logs}->{$facility};
	surePathToFile($ce->{webworkDirs}->{root}, $logFile);
	local *LOG;
	if (open LOG, ">>", $logFile) {
		print LOG "[", time2str("%a %b %d %H:%M:%S %Y", time), "] @message\n";
		close LOG;
	} else {
		warn "failed to open $logFile for writing: $!";
	}
}

sub writeCourseLog($$@) {
	my ($ce, $facility, @message) = @_;
	unless ($ce->{courseFiles}->{logs}->{$facility}) {
		warn "There is no course log file for the $facility facility defined.\n";
		return;
	}
	my $logFile = $ce->{courseFiles}->{logs}->{$facility};
	surePathToFile($ce->{courseDirs}->{root}, $logFile);
	local *LOG;
	if (open LOG, ">>", $logFile) {
		print LOG "[", time2str("%a %b %d %H:%M:%S %Y", time), "] @message\n";
		close LOG;
	} else {
		warn "failed to open $logFile for writing: $!";
	}
}

# $ce - a WeBWork::CourseEnvironment object
# $function - fully qualified function name
# $details - any information, do not use the characters '[' or ']'
# $beginEnd - the string "begin", "intermediate", or "end"
# use the intermediate step begun or completed for INTERMEDIATE
# use an empty string for $details when calling for END
# Information printed in format:
# [formatted date & time ] processID unixTime BeginEnd $function  $details
sub writeTimingLogEntry($$$$) {
	my ($ce, $function, $details, $beginEnd) = @_;
	$beginEnd = ($beginEnd eq "begin") ? ">" : ($beginEnd eq "end") ? "<" : "-";
	writeLog($ce, "timing", "$$ ".time." $beginEnd $function [$details]");
}


sub cryptPassword($) {
	my ($clearPassword) = @_;
	my $salt = join("", ('.','/','0'..'9','A'..'Z','a'..'z')[rand 64, rand 64]);
	my $cryptPassword = crypt($clearPassword, $salt);
	return $cryptPassword;
}


################################################################################
# Filesystem interaction
################################################################################

=head2 Filesystem interaction

=over

=cut

# Convert Windows and Mac (classic) line endings to UNIX line endings in a string.
# Windows uses CRLF, Mac uses CR, UNIX uses LF. (CR is ASCII 15, LF if ASCII 12)
sub force_eoln($) {
	my ($string) = @_;
	$string =~ s/\015\012?/\012/g;
	return $string;
}

sub readFile($) {
	my $fileName = shift;
	local $/ = undef; # slurp the whole thing into one string
	open my $dh, "<", $fileName
		or die "failed to read file $fileName: $!";
	my $result = <$dh>;
	close $dh;
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

# A very useful macro for making sure that all of the directories to a file have
# been constructed.
sub surePathToFile($$) {
	# constructs intermediate directories enroute to the file 
	# the input path must be the path relative to this starting directory
	my $start_directory = shift;
	my $path = shift;
	my $delim = "/"; 
	unless ($start_directory and $path ) {
		warn "missing directory<br> surePathToFile  start_directory   path ";
		return '';
	}
	# use the permissions/group on the start directory itself as a template
	my ($perms, $groupID) = (stat $start_directory)[2,5];
	# warn "&urePathToTmpFile: perms=$perms groupID=$groupID\n";
	
	# if the path starts with $start_directory (which is permitted but optional) remove this initial segment
	$path =~ s|^$start_directory|| if $path =~ m|^$start_directory|;

	
	# find the nodes on the given path
        my @nodes = split("$delim",$path);
	
	# create new path
	$path = $start_directory; #convertPath("$tmpDirectory");
	
	while (@nodes>1) {  # the last node is the file name
		$path = $path . shift (@nodes) . "/"; #convertPath($path . shift (@nodes) . "/");
		#FIXME  this make directory command may not be fool proof.
		unless (-e $path) {
			mkdir($path, $perms)
				or warn "Failed to create directory $path with start directory $start_directory ";
		}

	}
	
	$path = $path . shift(@nodes); #convertPath($path . shift(@nodes));
	return $path;
}


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
	my $package = (caller)[0]; # import into caller's namespace
	
	my $import_string;
	if (@import_list == 1 and ref $import_list[0] eq "ARRAY" and @{$import_list[0]} == 0) {
		$import_string = "";
	} else {
		# \Q = quote metachars \E = end quoting
		$import_string = "import $module " . join(",", map { qq|"\Q$_\E"| } @import_list);
	}
	eval "package $package; require $module; $import_string";
	die $@ if $@;
}



1;