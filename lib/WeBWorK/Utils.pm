################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils.pm,v 1.59 2004/10/22 22:59:49 sh002i Exp $
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
use base qw(Exporter);

=head1 NAME

WeBWorK::Utils - useful utilities used by other WeBWorK modules.

=cut

use strict;
use warnings;
#use Apache::DB;
use DateTime;
use Date::Parse;
use Date::Format;
use Time::Zone;
#use Date::Manip;
#use DateTime::Format::DateManip;
use Errno;
use File::Path qw(rmtree);
use Carp;

use constant MKDIR_ATTEMPTS => 10;

# "standard" WeBWorK date/time format (for set definition files):
#     %m/%d/%y at %I:%M%P
# where:
#     %m = month number, starting with 01
#     %d = numeric day of the month, with leading zeros (eg 01..31)
#     %Y = year (4 digits)
#     %I = hour, 12 hour clock, leading 0's)
#     %M = minute, leading 0's
#     %P = am or pm (Yes %p and %P are backwards :)
use constant DATE_FORMAT => "%m/%d/%Y at %I:%M%P %Z";

our @EXPORT    = ();
our @EXPORT_OK = qw(
	runtime_use
	readFile
	readDirectory
	listFilesRecursive
	surePathToFile
	makeTempDirectory
	removeTempDirectory
	formatDateTime
	parseDateTime
	textDateTime
	intDateTime
	writeLog
	writeCourseLog
	writeTimingLogEntry
	list2hash
	ref2string
	decodeAnswers
	encodeAnswers
	max
	pretty_print_rh
	cryptPassword
	dequote
	undefstr
	fisher_yates_shuffle
	sortByName
);

=head1 FUNCTIONS

=cut

################################################################################
# Lowlevel thingies
################################################################################

sub runtime_use($) {
	croak "runtime_use: no module specified" unless $_[0];
	eval "package Main; require $_[0]; import $_[0]";
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

=item @matches = listFilesRecusive($dir, $match_qr, $prune_qr, $match_full, $prune_full)

Traverses the directory tree rooted at $dir, returning a list of files, named
pipes, and sockets matching the regular expression $match_qr. Directories
matching the regular expression $prune_qr are not visited.

$match_full and $prune_full are boolean values that indicate whether $match_qr
and $prune_qr, respectively, should be applied to the bare directory entry
(false) or to the path to the directory entry relative to $dir.

@matches is a list of paths relative to $dir.

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
		if (-d $full_path or -l $full_path) {
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
		} elsif (-f $full_path or -p $full_path or -S $full_path) {
			my $file = ($curr_dir eq "") ? $dir_entry : "$curr_dir/$dir_entry";
			my $match_string = $match_full ? $file : $dir_entry;
			if (not defined $match_string or $match_string =~ m/$match_qr/) {
				push @matches, $file;
			}
		}
	}
	
	return @matches;
}

# A very useful macro for making sure that all of the directories to a file have
# been constructed.
sub surePathToFile($$) {
	# constructs intermediate 
	# the input path must be the path relative to this starting directory
	my $start_directory = shift;
	my $path = shift;
	my $delim = "/"; #&getDirDelim();
	unless ($start_directory and $path ) {
		warn "missing directory<br> surePathToFile  start_directory   path ";
		return '';
	}
	# use the permissions/group on the start directory itself as a template
	my ($perms, $groupID) = (stat $start_directory)[2,5];
	#warn "&urePathToTmpFile: perms=$perms groupID=$groupID\n";
	
	# if the path starts with $start_directory (which is permitted but optional) remove this initial segment
	$path =~ s|^$start_directory|| if $path =~ m|^$start_directory|;
	#$path = convertPath($path);

	
	# find the nodes on the given path
        my @nodes = split("$delim",$path);
	
	# create new path
	$path = $start_directory; #convertPath("$tmpDirectory");
	
	while (@nodes>1) {
		$path = $path . shift (@nodes) . "/"; #convertPath($path . shift (@nodes) . "/");
		#FIXME  this make directory command may not be fool proof.
		unless (-e $path) {
			mkdir($path, $perms)
				or warn "Failed to create directory $path";
		}

	}
	
	$path = $path . shift(@nodes); #convertPath($path . shift(@nodes));
	return $path;
}

sub makeTempDirectory($$) {
	my ($parent, $basename) = @_;
	# Loop until we're able to create a directory, or it fails for some
	# reason other than there already being something there.
	my $triesRemaining = MKDIR_ATTEMPTS;
	my ($fullPath, $success);
	do {
		my $suffix = join "", map { ('A'..'Z','a'..'z','0'..'9')[int rand 62] } 1 .. 8;
		$fullPath = "$parent/$basename.$suffix";
		$success = mkdir $fullPath;
	} until ($success or not $!{EEXIST});
	die "Failed to create directory $fullPath: $!"
		unless $success;
	return $fullPath;
}

sub removeTempDirectory($) {
	my ($dir) = @_;
	rmtree($dir, 0, 0);
}

=back

=cut

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
# and more information is given abou the nature of errors.
# 
sub unformatDateAndTime {
	my ($string) = @_;
	my $orgString =$string;
	$string =~ s|^\s+||;
	$string =~ s|\s+$||;
	$string =~ s|at| at |i; ## OK if forget to enter spaces or use wrong case
	$string =~ s|AM| AM|i;	## OK if forget to enter spaces or use wrong case
	$string =~ s|PM| PM|i;	## OK if forget to enter spaces or use wrong case
	$string =~ s|,| at |;	## start translating old form of date/time to new form
    if ($string =~ m|^\s*[\/\d]+\s+[:\d]+| ) {   # case where the at is missing: MM/DD/YYYY at HH:MM AMPM ZONE
    	die "Incorrect date/time format \"$orgString\". The \"at\" appears to be missing. 
    		Correct format is MM/DD/YYYY at HH:MM AMPM ZONE (e.g.  \"03/29/2004 at 06:00am EST\")";
	}

	my($date,$at, $time,$AMPM,$TZ) = split(/\s+/,$string);
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
 
	my ($mday, $mon, $year, $wday, $yday,$sec, $pm, $min, $hour);
	$sec=0;
	$time =~ /^([0-9]+)\s*\:\s*([0-9]*)/;
	$min=$2;
	$hour = $1;
	if ($hour < 1 or $hour > 12) {
		die "Incorrect date/time format \"$orgString\". Hour must be in the range [1,12]. 
		Correct format is MM/DD/YYYY at HH:MM AMPM ZONE (e.g.  \"03/29/2004 at 06:00am EST\")
			date = $date
			time = $time
			ampm = $AMPM
			zone = $TZ\n";
	}
	if ($min < 0 or $min > 59) {
		die "Incorrect date/time format \"$orgString\". Minute must be in the range [0-59]. 
		Correct format is MM/DD/YYYY at HH:MM AMPM ZONE
			date = $date
			time = $time
			ampm = $AMPM
			zone = $TZ\n";
	}
	$pm = 0;
	$pm = 12 if ($AMPM =~/PM/ and $hour < 12);
	$hour += $pm;
	$hour = 0 if ($AMPM =~/AM/ and $hour == 12);
	$date =~  m!([0-9]+)\s*/\s*([0-9]+)/\s*([0-9]+)! ;
	$mday =$2;
	$mon=($1-1);
	if ($mday < 1 or $mday > 31) {
		die "Incorrect date/time format \"$orgString\". Day must be in the range [1,31]. 
		Correct format is MM/DD/YY at HH:MM AMPM ZONE
			date = $date
			time = $time
			ampm = $AMPM
			zone = $TZ\n";
	}
	if ($mon < 0 or $mon > 11) {
		die "Incorrect date/time format \"$orgString\". Month must be in the range [1,12]. 
		Correct format is MM/DD/YY at HH:MM AMPM ZONE
			date = $date
			time = $time
			ampm = $AMPM
			zone = $TZ\n";
	}
	$year=$3;
	$wday="";
	$yday="";
	return ($sec, $min, $hour, $mday, $mon, $year, $TZ);
}


sub parseDateTime($;$) {
	my ($string, $display_tz) = @_;
	$display_tz ||= "local";
	#warn "parseDateTime('$string', '$display_tz')\n";
	
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

=item $string = formatDateTime($dateTime, $display_tz)

Formats the UNIX datetime $dateTime in the standard WeBWorK datetime format.
$dateTime is assumed to be in the server's time zone. If $display_tz is given,
the datetime is converted from the server's timezone to the timezone specified.

=cut

sub formatDateTime($;$) {
	my ($dateTime, $display_tz) = @_;
	$display_tz ||= "local";
	#warn "formatDateTime('$dateTime', '$display_tz')\n";
	
	my $dt = DateTime->from_epoch(epoch => $dateTime, time_zone => $display_tz);
	#warn "\t\$dt = ", $dt->strftime(DATE_FORMAT), "\n";
	return $dt->strftime(DATE_FORMAT);
}

=item $string = textDateTime($string_or_dateTime)

Accepts a UNIX datetime or a formatted string, returns a formatted string.

=cut

sub textDateTime($) {
	return ($_[0] =~ m/^\d*$/) ? formatDateTime($_[0]) : $_[0];
}

=item $dateTIme = intDateTime($string_or_dateTime)

Accepts a UNIX datetime or a formatted string, returns a UNIX datetime.

=cut

sub intDateTime($) {
	return ($_[0] =~ m/^\d*$/) ?  $_[0] : parseDateTime($_[0]);
}

=back

=cut

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
sub writeTimingLogEntry($$$$) {
	my ($ce, $function, $details, $beginEnd) = @_;
	return unless defined $ce->{webworkFiles}->{logs}->{timing};
	$beginEnd = ($beginEnd eq "begin") ? ">" : ($beginEnd eq "end") ? "<" : "-";
	writeLog($ce, "timing", "$$ ".time." $beginEnd $function [$details]");
}

################################################################################
# Data munging
################################################################################

sub list2hash(@) {
	map {$_ => "0"} @_;
}

sub refBaseType($) {
	my $ref = shift;
	$ref =~ m/(\w+)\(/; # this might not be robust...
	return $1;
}

sub ref2string($;$);
sub ref2string($;$) {
	my $ref = shift;
	my $dontExpand = shift || {};
	my $refType = ref $ref;
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
			my @FIELDS = eval { @{$refType."::FIELDS"} };
			use strict 'refs';
			undef @FIELDS unless scalar @FIELDS == scalar @array and not $@;
			foreach (0 .. $#array) {
				$result .= '<tr valign="top">';
				$result .= "<td>$_</td>";
				$result .= "<td>".$FIELDS[$_]."</td>" if @FIELDS;
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
		$result .= "</table>"
	} else {
		$result .= defined $ref ? $ref : '<font color="red">undef</font>';
	}	
}

sub decodeAnswers($) {
	my $string = shift;
	return unless defined $string and $string;
	my @array = split m/##/, $string;
	$array[$_] =~ s/\\#\\/#/g foreach 0 .. $#array;
	push @array, "" if @array%2;
	return @array; # it's actually a hash ;)
}

sub encodeAnswers(\%\@) {
	my %hash = %{ shift() };
	my @order = @{ shift() };
	my $string = "";
	foreach my $name (@order) {
		my $value = defined $hash{$name} ? $hash{$name} : "";
		$name  =~ s/#/\\#\\/g; # this is a WEIRD way to escape things
		$value =~ s/#/\\#\\/g; # and it's not my fault!
		if ($value =~ m/\\$/) {
			# if the value ends with a backslash, string2hash will
			# interpret that as a normal escape sequence (not part
			# of the weird pound escape sequence) if the next
			# character is &. So we have to protect against this.
			# will adding a spcae at the end of the last answer
			# hurt anything? i don't think so...
			$value .= " ";
		}
		$string .= "$name##$value##"; # this is also not my fault
	}
	$string =~ s/##$//; # remove last pair of hashs
	return $string;
}

sub max(@) {
	my $soFar;
	foreach my $item (@_) {
		$soFar = $item unless defined $soFar;
		if ($item > $soFar) {
			$soFar = $item;
		}
	}
	return defined $soFar ? $soFar : 0;
}

sub pretty_print_rh($) {
	my $rh = shift;
	foreach my $key (sort keys %{$rh})  {
		warn "  $key => ",$rh->{$key},"\n";
	}
}

sub cryptPassword($) {
	my ($clearPassword) = @_;
	my $salt = join("", ('.','/','0'..'9','A'..'Z','a'..'z')[rand 64, rand 64]);
	my $cryptPassword = crypt($clearPassword, $salt);
	return $cryptPassword;
}

# from the Perl Cookbook, first edition, page 25:
sub dequote($) {
	local $_ = shift;
	my ($white, $leader); # common whitespace and common leading string
	if (/^\s*(?:([^\w\s]+)(\s*).*\n)(?:\s*\1\2?.*\n)+$/) {
		($white, $leader) = ($2, quotemeta($1));
	} else {
		($white, $leader) = (/^(\s+)/, '');
	}
	s/^\s*?$leader(?:$white)?//gm;
	return $_;
}

sub undefstr($@) {
	map { defined $_ ? $_ : $_[0] } @_[1..$#_];
}

# shuffle an array in place
# Perl Cookbook, Recipe 4.17. Randomizing an Array
sub fisher_yates_shuffle {
	my $array = shift;
	my $i;
	for ($i = @$array; --$i; ) {
		my $j = int rand ($i+1);
		next if $i == $j;
		@$array[$i,$j] = @$array[$j,$i];
	}
}

################################################################################
# Sorting
################################################################################

# p. 101, Camel, 3rd ed.
# The <=> and cmp operators return -1 if the left operand is less than the
# right operand, 0 if they are equal, and +1 if the left operand is greater
# than the right operand.
sub sortByName($@) {
	my ($field, @items) = @_;
	return sort {
		my @aParts = split m/(?<=\D)(?=\d)|(?<=\d)(?=\D)/, defined $field ? $a->$field : $a;
		my @bParts = split m/(?<=\D)(?=\d)|(?<=\d)(?=\D)/, defined $field ? $b->$field : $b;
		while (@aParts and @bParts) {
			my $aPart = shift @aParts;
			my $bPart = shift @bParts;
			my $aNumeric = $aPart =~ m/^\d*$/;
			my $bNumeric = $bPart =~ m/^\d*$/;

			# numbers should come before words
			return -1 if     $aNumeric and not $bNumeric;
			return +1 if not $aNumeric and     $bNumeric;

			# both have the same type
			if ($aNumeric and $bNumeric) {
				next if $aPart == $bPart; # check next pair
				return $aPart <=> $bPart; # compare numerically
			} else {
				next if $aPart eq $bPart; # check next pair
				return $aPart cmp $bPart; # compare lexicographically
			}
		}
		return +1 if @aParts; # a has more sections, should go second
		return -1 if @bParts; # a had fewer sections, should go first
	} @items;
}

1;
