package WeBWorK::Utils;
use base qw(Exporter);

use strict;
use warnings;
use Date::Format;
use Date::Parse;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	runtime_use
	readFile
	formatDateTime
	parseDateTime
	ref2string
	hash2string
	array2string
);

sub runtime_use($) {
	return unless @_;
	eval "package Main; require $_[0]; import $_[0]";
	die $@ if $@;
}

sub readFile($) {
	my $fileName = shift;
	open INPUTFILE, "<", $fileName
		or die "Failed to read $fileName: $!";
	local $/ = undef;
	my $result = <INPUTFILE>;
	close INPUTFILE;
	return $result;
}

sub formatDateTime($) {
	my $dateTime = shift;
	# "standard" WeBWorK date/time format:
	# %m 	month number, starting with 01
	# %d 	numeric day of the month, with leading zeros (eg 01..31)
	# %y	year (2 digits)
	# %I 	hour, 12 hour clock, leading 0's)
	# %M 	minute, leading 0's
	# %P 	am or pm (Yes %p and %P are backwards :)
	return time2str "%m/%d/%y %I:%M%P", $dateTime;
}

sub parseDateTime($) {
	my $string = shift;
	return str2time $string;
}

# -----

sub ref2string($;$);
sub ref2string($;$) {
	my $ref = shift;
	my $dontExpand = shift || {};
	my $refType = ref $ref;
	my $result;
	if ($refType and not $dontExpand->{$refType}) {
		my $baseType = refBaseType($ref);
		$result .= '<font size="1" color="grey">' . $refType;
		$result .= " ($baseType)" if $refType ne $baseType;
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
			foreach (0 .. $#array) {
				$result .= '<tr valign="top">';
				$result .= "<td>$_</td>";
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
	local $SIG{__DIE__} = 'IGNORE';
	return "CODE"   if eval { $_ = \&$ref; 1 };
	return "HASH"   if eval { $_ = %$ref; 1 };
	return "ARRAY"  if eval { $_ = @$ref; 1 };
	return "SCALAR" if eval { $_ = $$ref; 1 };
	return 0;
}

# -----

#sub hash2string($;$$) {
#	my $hr = shift;
#	my $table = shift || 0;
#	my $indent = shift || 0;
#	my $result = $table ? '<table border="1">' : "";
#	foreach my $key (keys %$hr) {
#		my $value = $hr->{$key};
#		$result .= $table
#			? "<tr><td>$key</td>"
#			: "\t"x$indent . "{$key} =";
#		if (ref $value eq 'HASH') {
#			$result .= $table ? "<td>" : "\n";
#			$result .= hash2string($value, $table, $indent+1);
#			$result .= $table ? "</td>" : "";
#		} elsif (ref $value eq 'ARRAY') {
#			$result .= $table ? "<td>" : "\n";
#			$result .= array2string($value, $table, $indent+1);
#			$result .= $table ? "</td>" : "";
#		} elsif (defined $value) {
#			$result .= $table
#				? "<td>$value</td>"
#				: " $value\n";
#		} else {
#			$result .= $table ? "" : "\n";
#		}
#		$result .= $table ? "</tr>" : "";
#	}
#	$result .= "</table>";
#	return $result;
#}
#
#sub array2string($;$$) {
#	my $ar = shift;
#	my $table = shift || 0;
#	my $indent = shift || 0;
#	my $result = $table ? '<table border="1">' : "";
#	foreach my $index (0 .. @$ar-1) {
#		my $value = $ar->[$index];
#		$result .= $table
#			? "<tr><td>$index</td>"
#			: "\t"x$indent . "[$index] =";
#		if (ref $value eq 'HASH') {
#			$result .= $table ? "<td>" : "\n";
#			$result .= hash2string($value, $table, $indent+1);
#			$result .= $table ? "</td>" : "";
#		} elsif (ref $value eq 'ARRAY') {
#			$result .= $table ? "<td>" : "\n";
#			$result .= array2string($value, $table, $indent+1);
#			$result .= $table ? "</td>" : "";
#		} elsif (defined $value) {
#			$result .= $table
#				? "<td>$value</td>"
#				: " $value\n";
#		} else {
#			$result .= $table ? "" : "\n";
#		}
#		$result .= $table ? "</tr>" : "";
#	}
#	$result .= "</table>";
#	return $result;
#}
#
#sub isHashRef($) {
#	my $ref = shift;
#	local $SIG{__DIE__} = 'IGNORE';
#	$_ = eval{ %$ref };
#	return not defined $@;
#}
#
#sub isArrayRef($) {
#	my $ref = shift;
#	local $SIG{__DIE__} = 'IGNORE';
#	$_ = eval{ @$ref };
#	return not defined $@;
#}

1;
