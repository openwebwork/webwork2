package WeBWorK::Localize;
use parent 'Locale::Maketext';

use strict;
use warnings;

use File::Spec;
use Locale::Maketext::Lexicon;

use WeBWorK::Utils qw(x);

Locale::Maketext::Lexicon->import({
	'i-default' => ['Auto'],
	'*'         => [ Gettext => File::Spec->catfile("$ENV{WEBWORK_ROOT}/lib/WeBWorK/Localize", '*.[pm]o') ],
	_decode     => 1,
	_encoding   => undef,
});
*tense = sub { \$_[1] . ((\$_[2] eq 'present') ? 'ing' : 'ed') };

# This subroutine is shared with the safe compartment in PG to
# allow maketext() to be used in PG problems and macros.
sub getLoc {
	my $lang = shift;
	my $lh   = WeBWorK::Localize->get_handle($lang);
	return sub { $lh->maketext(@_) };
}

sub getLangHandle {
	my $lang = shift;
	return WeBWorK::Localize->get_handle($lang);
}

# This is like [quant] but it doesn't write the number.
#  usage: [quant,_1,<singular>,<plural>,<optional zero>]
sub plural {
	my ($handle, $num, @forms) = @_;

	return ''        if @forms == 0;
	return $forms[2] if @forms > 2 && $num == 0;

	# Normal case:
	return $handle->numerate($num, @forms);
}

# This is like [quant] but it also has a negative case. (The one usage in the code interprets this as unlimited.)
#  usage: [negquant,_1,<negative case>,<singular>,<plural>,<optional zero>]
sub negquant {
	my ($handle, $num, @forms) = @_;

	return $num if @forms == 0;

	my $negcase = shift @forms;
	return $negcase if $num < 0;

	return $forms[2] if @forms > 2 && $num == 0;
	return $handle->numf($num) . ' ' . $handle->numerate($num, @forms);
}

our %Lexicon = (
	'_AUTO' => 1,

	'_ONE_COLUMN' => x('One Column'),

	'_TWO_COLUMNS' => x('Two Columns'),

	'_PERMISSIONS' => [
		x('guest'), x('student'),   x('login_proctor'), x('grade_proctor'),
		x('ta'),    x('professor'), x('admin'),         x('nobody')
	],

	'_STATUS' => [ x('Enrolled'), x('Audit'), x('Drop'), x('Proctor') ],
);

# Override the Locale::Maketext::_compile method. The only real difference is that this override
# method does not call "use strict" in the code eval. Thus it can be used in the safe zone.
sub _compile {
	my ($handle, $string_to_compile) = @_;

	# The while regex is more expensive than this check on strings that don't need a compile.
	# This op causes a ~2% speed hit for strings that need compile and a 250% speed improvement
	# on strings that don't need compiling.
	return \"$string_to_compile" if $string_to_compile !~ m/[\[~\]]/ms;

	my @code;
	my (@c)        = ('');    # "chunks" -- scratch.
	my $call_count = 0;
	my $big_pile   = '';
	{
		my $in_group = 0;     # start out outside a group
		my ($m, @params);     # scratch

		while (
			$string_to_compile =~    # Iterate over chunks.
			m/(
				[^\~\[\]]+  # non-~[] stuff (Capture everything else here)
				|
				~.          # ~[, ~], ~~, ~other
				|
				\[          # [ presumably opening a group
				|
				\]          # ] presumably closing a group
				|
				~           # terminal ~ ?
				|
				$
			)/xgs
			)
		{
			if ($1 eq '[' || $1 eq '') {
				# Whether this is "[" or end, force processing of any preceding literal.
				if ($in_group) {
					if ($1 eq '') {
						$handle->_die_pointing($string_to_compile, 'Unterminated bracket group');
					} else {
						$handle->_die_pointing($string_to_compile, 'You can\'t nest bracket groups');
					}
				} else {
					$in_group = 1 if ($1 ne '');

					die "How come \@c is empty?? in <$string_to_compile>" unless @c;    # sanity
					if (length $c[-1]) {
						# Now actually processing the preceding literal
						$big_pile .= $c[-1];
						if (
							$Locale::Maketext::USE_LITERALS && (
								(ord('A') == 65)
								? $c[-1] !~ m/[^\x20-\x7E]/s
								# ASCII very safe chars
								: $c[-1] !~ m/[^ !"\#\$%&'()*+,\-.\/0-9:;<=>?\@A-Z[\\\]^_`a-z{|}~\x07]/s
								# EBCDIC very safe chars
							)
							)
						{
							# Normal case -- all very safe chars
							$c[-1] =~ s/'/\\'/g;
							push @code, q{ '} . $c[-1] . "',\n";
							$c[-1] = '';    # reuse this slot
						} else {
							$c[-1] =~ s/\\\\/\\/g;
							push @code, ' $c[' . $#c . "],\n";
							push @c,    '';                      # new chunk
						}
					}
					# else just ignore the empty string.
				}

			} elsif ($1 eq ']') {
				# Close group -- go back in-band
				if ($in_group) {
					$in_group = 0;

					# And now process the group...

					if (!length($c[-1]) || $c[-1] =~ m/^\s+$/s) {
						$c[-1] = '';    # Reset out chunk
						next;
					}

					($m, @params) = split(/,/, $c[-1], -1);

					# A bit of a hack -- we've turned "~,"'s into DELs, so turn them into real commas here.
					if (ord('A') == 65) {
						# ASCII, etc
						for ($m, @params) {tr/\x7F/,/}
					} else {
						# EBCDIC (1047, 0037, POSIX-BC)
						for ($m, @params) {tr/\x07/,/}
					}

					# Special-case handling of some method names:
					if ($m eq '_*' || $m =~ m/^_(-?\d+)$/s) {
						# Treat [_1,...] as [,_1,...], etc.
						unshift @params, $m;
						$m = '';
					} elsif ($m eq '*') {
						$m = 'quant';    # "*" for "times": "4 cars" is 4 times "cars"
					} elsif ($m eq '#') {
						$m = 'numf';     # "#" for "number": [#,_1] for "the number _1"
					}

					# Most common case: a simple, legal-looking method name.
					if ($m eq '') {
						# 0-length method name means to just interpolate:
						push @code, ' (';
					} elsif ($m =~ /^\w+$/s
						&& !$handle->{'blacklist'}{$m}
						&& (!defined $handle->{'whitelist'} || $handle->{'whitelist'}{$m}))
					{
						# Exclude anything fancy and restrict to the whitelist/blacklist.
						push @code, ' $_[0]->' . $m . '(';
					} else {
						# TODO: Implement something? Or just too icky to consider?
						$handle->_die_pointing(
							$string_to_compile,
							"Can't use \"$m\" as a method name in bracket group",
							2 + length($c[-1])
						);
					}

					pop @c;    # we don't need that chunk anymore
					++$call_count;

					for my $p (@params) {
						if ($p eq '_*') {
							# Meaning: all parameters except $_[0]
							$code[-1] .= ' @_[1 .. $#_], ';
							# and yes, that does the right thing for all @_ < 3
						} elsif ($p =~ m/^_(-?\d+)$/s) {
							# _3 meaning $_[3]
							$code[-1] .= '$_[' . (0 + $1) . '], ';
						} elsif (
							$Locale::Maketext::USE_LITERALS && (
								(ord('A') == 65)
								? $p !~ m/[^\x20-\x7E]/s
								# ASCII very safe chars
								: $p !~ m/[^ !"\#\$%&'()*+,\-.\/0-9:;<=>?\@A-Z[\\\]^_`a-z{|}~\x07]/s
								# EBCDIC very safe chars
							)
							)
						{
							# Normal case: a literal containing only safe characters
							$p =~ s/'/\\'/g;
							$code[-1] .= q{'} . $p . q{', };
						} else {
							# Stow it on the chunk-stack, and just refer to that.
							push @c,    $p;
							push @code, ' $c[' . $#c . '], ';
						}
					}
					$code[-1] .= "),\n";

					push @c, '';
				} else {
					$handle->_die_pointing($string_to_compile, q{Unbalanced ']'});
				}

			} elsif (substr($1, 0, 1) ne '~') {
				# It's stuff not containing "~" or "[" or "]", i.e., a literal blob.
				my $text = $1;
				$text =~ s/\\/\\\\/g;
				$c[-1] .= $text;
			} elsif ($1 eq '~~') {
				$c[-1] .= '~';
			} elsif ($1 eq '~[') {
				$c[-1] .= '[';
			} elsif ($1 eq '~]') {
				$c[-1] .= ']';
			} elsif ($1 eq '~,') {
				if ($in_group) {
					# This is a hack, based on the assumption that no one will actually
					# want a DEL inside a bracket group.  Let's hope that's it's true.
					if (ord('A') == 65) {
						# ASCII etc
						$c[-1] .= "\x7F";
					} else {
						# EBCDIC (cp 1047, 0037, POSIX-BC)
						$c[-1] .= "\x07";
					}
				} else {
					$c[-1] .= '~,';
				}
			} elsif ($1 eq '~') {
				# This is possible only at string end, it seems.
				$c[-1] .= '~';
			} else {
				# It's a "~X" where X is not a special character.
				# Consider it a literal ~ and X.
				my $text = $1;
				$text =~ s/\\/\\\\/g;
				$c[-1] .= $text;
			}
		}
	}

	if ($call_count) {
		undef $big_pile;    # Well, nevermind that.
	} else {
		# It's all literals! So don't bother with the eval. Return a SCALAR reference.
		return \$big_pile;
	}

	die q{Last chunk isn't null??} if @c && length $c[-1];    # sanity
	if (@code == 0) {
		# Not possible?
		return \'';
	} elsif (@code > 1) {
		# Most cases, presumably!
		unshift @code, "join '',\n";
	}
	unshift @code, "sub {\n";
	push @code, "}\n";

	my $sub = eval(join '', @code);
	die "$@ while eval-ling " . join('', @code) if $@;        # Should be impossible.

	return $sub;
}

1;
