loadMacros(
  "unionImage.pl",
  "unionTables.pl",
);

$bHTML = '\begin{rawhtml}';
$eHTML = '\end{rawhtml}';

sub protectHTML {
    my $string = shift;
    $string =~ s/&/\&amp;/g;
    $string =~ s/</\&lt;/g;
    $string =~ s/>/\&gt;/g;
    $string;
}

sub _parserUtils_init {}

1;

