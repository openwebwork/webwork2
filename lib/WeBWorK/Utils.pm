package WeBWorK::Utils;
use base qw(Exporter);

use strict;
use warnings;
use Date::Format;
use Date::Parse;

our @EXPORT    = ();
our @EXPORT_OK = qw(runtime_use readFile formatDate hash2string array2string);

sub runtime_use($) {
	return unless @_;
	eval "require $_[0]; import $_[0]";
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
	$string = shift;
	return str2time $string;
}

sub hash2string {
	my $hr = shift;
	my $indent = shift || 0;
	my $result;
	foreach (keys %$hr) {
		$result .= "\t"x$indent . "{$_} =";
		if (ref $hr->{$_} eq 'HASH') {
			$result .= "\n";
			$result .= hash2string($hr->{$_}, $indent+1);
		} elsif (ref $hr->{$_} eq 'ARRAY') {
			$result .= "\n";
			$result .= array2string($hr->{$_}, $indent+1);
		} else {
			$result .= " " . $hr->{$_} . "\n";
		}
	}
	return $result;
}

sub array2string {
	my $ar = shift;
	my $indent = shift || 0;
	my $result;
	foreach (0 .. @$ar-1) {
		$result .= "\t"x$indent . "[$_] =";
		if (ref $ar->[$_] eq 'HASH') {
			$result .= "\n";
			$result .= hash2string($ar->[$_], $indent+1);
		} elsif (ref $ar->[$_] eq 'ARRAY') {
			$result .= "\n";
			$result .= array2string($ar->[$_], $indent+1);
		} else {
			$result .= " " . $ar->[$_] . "\n";
		}
	}
	return $result;
}

=pod
sub pretty_print_rh {
    my $r_input = shift;
    my $out = '';
    if ( not ref($r_input) ) {
    	$out = $r_input;    # not a reference
    } elsif (is_hash_ref($r_input)) {
	    local($^W) = 0;
		$out .= "<TABLE border = \"2\" cellpadding = \"3\" BGCOLOR = \"#FFFFFF\">";
		foreach my $key (sort keys %$r_input ) {
			$out .= "<tr><TD> $key</TD><TD>=&gt;</td><td>&nbsp;".pretty_print_rh($r_input->{$key}) . "</td></tr>";
		}
		$out .="</table>";
	} elsif (is_array_ref($r_input) ) {
		my @array = @$r_input;
		$out .= "( " ;
		while (@array) {
			$out .= pretty_print_rh(shift @array) . " , ";
		}
		$out .= " )"; 
	} elsif (ref($r_input) eq 'CODE') {
		$out = "$r_input";
	} else {
		$out = $r_input;
	}
		$out;
}

sub is_hash_ref {
	my $in =shift;
	my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__} = sub {CORE::die(@_) };
	my $out = eval{  %{   $in  }  };
	$out = ($@ eq '') ? 1 : 0;
	$@='';
	$SIG{__DIE__} = $save_SIG_die_trap;
	$out;
}
sub is_array_ref {
	my $in =shift;
	my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__} = sub {CORE::die(@_) };
	my $out = eval{  @{   $in  }  };
	$out = ($@ eq '') ? 1 : 0;
	$@='';
	$SIG{__DIE__} = $save_SIG_die_trap;
	$out;
}
=cut

1;
