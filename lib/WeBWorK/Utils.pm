################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Utils.pm,v 1.37 2003/12/09 01:12:30 sh002i Exp $
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
use Date::Format;
use Date::Parse;
use Errno;
use File::Path qw(rmtree);

use constant MKDIR_ATTEMPTS => 10;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	runtime_use
	readFile
	readDirectory
	formatDateTime
	parseDateTime
	writeLog
	writeCourseLog
	writeTimingLogEntry
	list2hash
	max
	dbDecode
	dbEncode
	decodeAnswers
	encodeAnswers
	ref2string
	sortByName
	makeTempDirectory
	removeTempDirectory
	pretty_print_rh
	cryptPassword
	dequote
);

sub runtime_use($) {
	return unless @_;
	eval "package Main; require $_[0]; import $_[0]";
	die $@ if $@;
}

#sub backtrace {
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

sub readFile($) {
	my $fileName = shift;
	local $/ = undef; # slurp the whole thing into one string
	open my $dh, "<", $fileName
		or die "failed to read file $fileName: $!";
	my $result = <$dh>;
	close $dh;
	return $result;
}

sub readDirectory($) {
	my $dirName = shift;
	opendir my $dh, $dirName
		or die "Failed to read directory $dirName: $!";
	my @result = readdir $dh;
	close $dh;
	return @result;
}

sub formatDateTime($) {
	my $dateTime = shift;
	# "standard" WeBWorK date/time format (for set definition files):
	# %m 	month number, starting with 01
	# %d 	numeric day of the month, with leading zeros (eg 01..31)
	# %y	year (2 digits)
	# %I 	hour, 12 hour clock, leading 0's)
	# %M 	minute, leading 0's
	# %P 	am or pm (Yes %p and %P are backwards :)
	#return time2str("%m/%d/%y %I:%M%P", $dateTime); 
	return time2str("%m/%d/%y at %I:%M%P", $dateTime);
}

sub parseDateTime($) {
	my $string = shift;
	# need to bring our string from  "%m/%d/%y at %I:%M%P" to "%m/%d/%y %I:%M%P" format.
	$string =~ s/\bat\b/ /;
	return str2time($string);
}

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

sub list2hash {
	map {$_ => "0"} @_;
}

sub max {
	my $soFar;
	foreach my $item (@_) {
		$soFar = $item unless defined $soFar;
		if ($item > $soFar) {
			$soFar = $item;
		}
	}
	return defined $soFar ? $soFar : 0;
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
	my $string;
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

sub refBaseType($) {
	my $ref = shift;
	$ref =~ m/(\w+)\(/; # this might not be robust...
	return $1;
}

# p. 101, Camel, 3rd ed.
# The <=> and cmp operators return -1 if the left operand is less than the
# right operand, 0 if they are equal, and +1 if the left operand is greater
# than the right operand.

sub sortByName {
	my ($field, @items) = @_;
	return sort {
		my @aParts = split m/(?<=\D)(?=\d)|(?<=\d)(?=\D)/, $a->$field;
		my @bParts = split m/(?<=\D)(?=\d)|(?<=\d)(?=\D)/, $b->$field;
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

sub pretty_print_rh {
	my $rh = shift;
	foreach my $key (sort keys %{$rh})  {
		warn "  $key => ",$rh->{$key},"\n";
	}
}

sub cryptPassword {
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

1;
