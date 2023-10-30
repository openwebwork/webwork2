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

# This subroutine is used to pass a language handle to job queue tasks
# so that tasks can use maketext.
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

1;
