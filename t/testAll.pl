use strict;
use warnings;
use TAP::Harness;

my %args = (
    verbosity => 1,
    lib => ['../lib'],
);

my $harness = TAP::Harness->new(\%args);

my @tests = ['./unit_tests/parse_classlist_test.pl'];

$harness->runtests(@tests);
