################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::Utils;
use base qw(Exporter);

=head1 NAME

WeBWorK::Utils - useful utilities used by other WeBWorK modules.

=cut

use strict;
use warnings;
use Date::Format;
use Date::Parse;
use DB; # DeBug, not DataBase

our @EXPORT    = ();
our @EXPORT_OK = qw(
	runtime_use
	backtrace
	readFile
	formatDateTime
	parseDateTime
	writeLog
	writeTimingLogEntry
	list2hash
	max
	readDirectory
	dbDecode
	dbEncode
	decodeAnswers
	encodeAnswers
	ref2string
	sortByName
);

sub runtime_use($) {
	return unless @_;
	eval "package Main; require $_[0]; import $_[0]";
	die $@ if $@;
}

sub backtrace {
	my ($style) = @_;
	$style = "warn" unless $style;
	my @bt = DB->backtrace;
	shift @bt; # Remove "backtrace" from the backtrace;
	if ($style eq "die") {
		die join "\n", @bt;
	} elsif ($style eq "warn") {
		warn join "\n", @bt;
	} elsif ($style eq "print") {
		print join "\n", @bt;
	} elsif ($style eq "return") {
		return @bt;
	}
}

sub readFile($) {
	my $fileName = shift;
	local *INPUTFILE;
	open INPUTFILE, "<", $fileName
		or die "Failed to read $fileName: $!";
	local $/ = undef;
	my $result = <INPUTFILE>;
	close INPUTFILE;
	return $result;
}

sub readDirectory($) {
	my ($dirname) = @_;
	
	opendir my $dirhandle, $dirname or die "couldn't open directory $dirname: $!";
	my @contents = readdir $dirhandle;
	closedir $dirhandle;
	return @contents;
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
	return time2str("%m/%d/%y %I:%M%P", $dateTime);
}

sub parseDateTime($) {
	my $string = shift;
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

sub pretty_print_rh {
	my $rh = shift;
	foreach my $key (sort keys %{$rh})  {
		warn "  $key => ",$rh->{$key},"\n";
	}
}
1;
