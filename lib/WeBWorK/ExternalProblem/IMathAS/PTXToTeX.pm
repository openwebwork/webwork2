package WeBWorK::ExternalProblem::IMathAS::PTXToTeX;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::ExternalProblem::IMathAS::PTXToTeX - Convert a fragment of PreTeXt to LaTeX for PG hardcopy.

=head1 DESCRIPTION

This module converts a fragment of PreTeXt, such as the statement of an
exercise, to LaTeX that can be used in the hardcopy of a PG problem.

This is not a general converter from PreTeXt to LaTeX.  It converts the
elements that are listed below, which are the ones that are needed for the
statement of a simple exercise.  Any other element is left out, but the text
that it contains is kept.  It is not for a whole PreTeXt document.  It knows
nothing of divisions, figures, cross references, and so on.  Use PreTeXt itself
for those.

The elements that are converted are

=over

=item C<p>

A paragraph.

=item C<m> and C<me>

Inline mathematics and displayed mathematics.  The PreTeXt macros C<\amp>,
C<\lt>, and C<\gt> are changed to the characters that they are for.

=item C<fillin>

An answer blank.  This becomes an C<\answerRule> command as for other answer
rules of PG, so the result is for PG hardcopy and not for LaTeX in general.
The C<name> attribute is the name of the answer, and the C<characters>
attribute is the width.

=item C<ol>, C<ul>, and C<li>

Lists.  The C<marker> attribute of an C<ol> element can be used.  For example,
C<marker="A."> gives the labels A., B., C., and so on.  Lists can be nested.

=item C<tabular>, C<row>, and C<cell>

A table.  All cells are centered and have borders.  Attributes of these
elements are not used.

=item C<em>, C<i>, C<var>, C<alert>, C<term>, C<strong>, C<b>, C<u>, C<c>,
C<sup>, C<sub>, and C<q>

Emphasis, bold, underlined, and verbatim text, superscripts and subscripts, and
quotations.

=item C<br>

A line break.

=item C<image>

This becomes text that says that there is an image that is not shown.

=item Elements for characters

These are C<percent>, C<ampersand>, C<hash>, C<dollar>, C<underscore>,
C<lbrace>, C<rbrace>, C<lbracket>, C<rbracket>, C<less>, C<greater>, C<tilde>,
C<circumflex>, C<backslash>, C<asterisk>, C<ndash>, C<mdash>, C<ellipsis>,
C<nbsp>, C<lq>, C<rq>, C<lsq>, and C<rsq>.

=back

Text that is not in mathematics is escaped so that characters that are special
to LaTeX are shown as they are.

=head1 FUNCTIONS

=head2 ptx_to_tex

    my $tex = ptx_to_tex($ptx);

Returns the LaTeX for the PreTeXt fragment C<$ptx>.

=cut

our @EXPORT_OK = qw(ptx_to_tex);

sub ptx_to_tex ($ptx) {
	# Things that are not to be changed further are kept here and put back at the end.
	my @kept;
	my $keep = sub { push(@kept, shift); return "\x{0}$#kept\x{0}" };

	my $math = sub {
		my $tex = shift;
		$tex =~ s/\\amp\b/&/g;
		$tex =~ s/\\lt\b/</g;
		$tex =~ s/\\gt\b/>/g;
		$tex =~ s/&lt;/</g;
		$tex =~ s/&gt;/>/g;
		$tex =~ s/&amp;/&/g;
		return $tex;
	};
	$ptx =~ s{<m>(.*?)</m>}{$keep->('\\(' . $math->($1) . '\\)')}gse;
	$ptx =~ s{<me>(.*?)</me>}{$keep->('\\[' . $math->($1) . '\\]')}gse;

	$ptx =~ s{<fillin\b([^>]*?)/?>(?:\s*</fillin>)?}{
		my $attributes = $1;
		my ($name)  = $attributes =~ /\bname="([^"]*)"/;
		my ($width) = $attributes =~ /\bcharacters="(\d+)"/;
		$keep->('{\\answerRule[' . ($name // '') . ']{' . ($width && $width > 3 ? $width : 3) . '}}');
	}gsex;

	my %characters = (
		percent    => '\\%',
		ampersand  => '\\&',
		hash       => '\\#',
		dollar     => '\\$',
		underscore => '\\_',
		lbrace     => '\\{',
		rbrace     => '\\}',
		lbracket   => '[',
		rbracket   => ']',
		less       => '\\textless{}',
		greater    => '\\textgreater{}',
		tilde      => '\\textasciitilde{}',
		circumflex => '\\textasciicircum{}',
		backslash  => '\\textbackslash{}',
		asterisk   => '*',
		ndash      => '--',
		mdash      => '---',
		ellipsis   => '\\ldots{}',
		nbsp       => '~',
		lq         => '``',
		rq         => "''",
		lsq        => '`',
		rsq        => "'"
	);
	$ptx =~ s{<(\w+)\s*/>}{defined $characters{$1} ? $keep->($characters{$1}) : "<$1/>"}ge;
	$ptx =~ s/\x{A0}/ /g;

	# Each tabular element needs to know how many columns it has.
	$ptx =~ s{<tabular\b[^>]*>(.*?)</tabular>}{
		my $rows    = $1;
		my $columns = 1;
		for ($rows =~ m{<row\b[^>]*>(.*?)</row>}gs) {
			my $cells = () = /<cell\b/g;
			$columns = $cells if $cells > $columns;
		}
		qq{<tabular columns="$columns">$rows</tabular>};
	}gsex;

	# Escape the text that is not in an element.
	my %special = (
		'\\' => '\\textbackslash{}',
		'~'  => '\\textasciitilde{}',
		'^'  => '\\textasciicircum{}',
		'<'  => '\\textless{}',
		'>'  => '\\textgreater{}',
		map { $_ => "\\$_" } ('{', '}', '&', '%', '$', '#', '_')
	);
	my $escape = sub {
		my $text = shift;
		$text =~ s/&lt;/</g;
		$text =~ s/&gt;/>/g;
		$text =~ s/&quot;/"/g;
		$text =~ s/&apos;/'/g;
		$text =~ s/&amp;/&/g;
		$text =~ s/([\\~^<>{}&%\$#_])/$special{$1}/g;
		return $text;
	};

	my %wrap = (
		em     => '\\emph{',
		i      => '\\emph{',
		var    => '\\emph{',
		alert  => '\\textbf{',
		term   => '\\textbf{',
		strong => '\\textbf{',
		b      => '\\textbf{',
		u      => '\\underline{',
		c      => '\\texttt{',
		sup    => '\\textsuperscript{',
		sub    => '\\textsubscript{'
	);

	my $tex = '';
	my (@lists, $cell);
	while ($ptx =~ m{\G(?:<(/?)(\w+)\b([^>]*?)(/?)>|([^<]+))}gs) {
		my ($closing, $element, $attributes, $empty, $text) = ($1, $2, $3, $4, $5);
		if (defined $text) {
			$tex .= $escape->($text);
		} elsif ($element eq 'p') {
			$tex .= "\n\n";
		} elsif ($element eq 'ol' || $element eq 'ul') {
			if ($closing) {
				pop @lists;
				$tex .= "\n\\end{itemize}\n";
			} else {
				my ($marker) = $attributes =~ /\bmarker="([^"]*)"/;
				push(@lists, { marker => $element eq 'ol' ? $marker // '1.' : undef, count => 0 });
				$tex .= "\n\\begin{itemize}\n";
			}
		} elsif ($element eq 'li') {
			next if $closing || !@lists;
			my $list = $lists[-1];
			if (defined $list->{marker}) {
				my $number = $list->{count}++;
				my $label  = $list->{marker};
				$label        =~ s/A/chr(ord('A') + $number % 26)/e
					|| $label =~ s/a/chr(ord('a') + $number % 26)/e
					|| $label =~ s/1/$number + 1/e;
				$tex .= "\\item[$label] ";
			} else {
				$tex .= '\\item ';
			}
		} elsif ($element eq 'tabular') {
			if ($closing) {
				$tex .= "\\end{tabular}\n\\end{center}\n";
			} else {
				my ($columns) = $attributes =~ /\bcolumns="(\d+)"/;
				$tex .= "\n\\begin{center}\n\\begin{tabular}{|" . ('c|' x ($columns // 1)) . "}\n\\hline\n";
			}
		} elsif ($element eq 'row') {
			if ($closing) { $tex .= " \\\\ \\hline\n" }
			else          { $cell = 0 }
		} elsif ($element eq 'cell') {
			$tex .= ' & ' if !$closing && $cell++;
		} elsif ($element eq 'q') {
			$tex .= $closing ? "''" : '``';
		} elsif ($element eq 'br') {
			$tex .= "\\newline\n" unless $closing;
		} elsif ($element eq 'image') {
			$tex .= '[An image that is not shown here.]' unless $closing;
		} elsif ($wrap{$element}) {
			$tex .= $closing ? '}' : $wrap{$element};
		}
		# Any other element (such as url) is left out, but what it contains is kept.
	}

	$tex =~ s/\x{0}(\d+)\x{0}/$kept[$1]/g;
	# A blank line is not allowed in a cell of a table.
	$tex =~ s{(\\begin\{tabular\}.*?\\end\{tabular\})}{$1 =~ s/\n\s*\n/\n/gr}gse;
	$tex =~ s/[ \t]+$//gm;
	$tex =~ s/\n{3,}/\n\n/g;
	$tex =~ s/^\s+|\s+$//g;
	return $tex;
}

1;
