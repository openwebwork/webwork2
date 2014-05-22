#!/local/bin/perl

my $string = "/Library/subjects/Calculus - single variable/chapters/Applications of differentiation/sections/Increasing/decreasing functions and local extrema/problems";
my $re = m/\/Library\/subjects\/(.+)\/chapters\/(.+)\/sections\/(.+)\/problems/;

my $re2 = m/\/Library\/subjects/;
my $string2 = "/Library/subjects";

if ($string =~ $re) {
	print "yeah!";

} else {
	print "nae!";
}