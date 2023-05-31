#!/usr/bin/env perl

# This script reads the timing log and outputs timing information including
# the number and per cent of accesses taking various amount of time.
# It can give you a rough idea of how well your server id performing.
# If you have a large timing log, it can tale awhile for the script to complete processing.

# To run the script, cd to the WeBWorK logs directory (usually /opt/webwork/webwork2/logs)
# and enter the command: timing_log_check.pl

# Note that this assumes perl is locates in /usr/bin/perl (check with the command "which perl")
# and /opt/webwork/webwork2/bin/ is in your path.

open(PGFILE, 'timing.log') || warn "Can't read timing.log: $!";
my @lines = <PGFILE>;
close(PGFILE);

my $under0point1sec = 0;
my $under0point2sec = 0;
my $under0point5sec = 0;
my $under1sec       = 0;
my $under2sec       = 0;
my $under3sec       = 0;
my $under4sec       = 0;
my $under5sec       = 0;
my $under10sec      = 0;
my $over10sec       = 0;
my $nonvalid        = 0;
my $line;
my $count = 0;
my $time  = 0;

foreach $line (@lines) {
	$count++;
	$line =~ /runTime = (\d+\.\d+) sec/;
	$time = $1;
	if ($time < 0.1) {
		$under0point1sec++;
	} elsif ($time < 0.2) {
		$under0point2sec++;
	} elsif ($time < 0.5) {
		$under0point5sec++;
	} elsif ($time < 1.0) {
		$under1sec++;
	} elsif ($time < 2.0) {
		$under2sec++;
	} elsif ($time < 3.0) {
		$under3sec++;
	} elsif ($time < 4.0) {
		$under4sec++;
	} elsif ($time < 5.0) {
		$under5sec++;
	} elsif ($time < 10.0) {
		$under10sec++;
	} elsif ($time >= 10.0) {
		$over10sec++;
	} else {
		$nonvalid++;
	}
}
my $percent_under0point1sec = 0;
my $percent_under0point2sec = 0;
my $percent_under0point5sec = 0;
my $percent_under1sec       = 0;
my $percent_under2sec       = 0;
my $percent_under3sec       = 0;
my $percent_under4sec       = 0;
my $percent_under5sec       = 0;
my $percent_under10sec      = 0;
my $percent_over10sec       = 0;
my $percent_nonvalid        = 0;

$percent_under0point1sec = (int($under0point1sec / $count * 1000 + .5)) / 10;
$percent_under0point2sec = (int($under0point2sec / $count * 1000 + .5)) / 10;
$percent_under0point5sec = (int($under0point5sec / $count * 1000 + .5)) / 10;
$percent_under1sec       = (int($under1sec / $count * 1000 + .5)) / 10;
$percent_under2sec       = (int($under2sec / $count * 1000 + .5)) / 10;
$percent_under3sec       = (int($under3sec / $count * 1000 + .5)) / 10;
$percent_under4sec       = (int($under4sec / $count * 1000 + .5)) / 10;
$percent_under5sec       = (int($under5sec / $count * 1000 + .5)) / 10;
$percent_under10sec      = (int($under10sec / $count * 1000 + .5)) / 10;
$percent_over10sec       = (int($over10sec / $count * 1000 + .5)) / 10;
$percent_nonvalid        = (int($nonvalid / $count * 1000 + .5)) / 10;

print "count = $count\n";
print "under 0.1 seconds = $under0point1sec: ${percent_under0point1sec}%\n";
print "between 0.1 and 0.2 seconds = $under0point2sec: ${percent_under0point2sec}%\n";
print "between 0.2 and 0.5 seconds = $under0point5sec: ${percent_under0point5sec}%\n";
print "between 0.5 and 1.0 seconds = $under1sec: ${percent_under1sec}%\n";
print "between 1.0 and 2.0 seconds = $under2sec: ${percent_under2sec}%\n";
print "between 2.0 and 3.0 seconds = $under3sec: ${percent_under3sec}%\n";
print "between 3.0 and 4.0 seconds = $under4sec: ${percent_under4sec}%\n";
print "between 4.0 and 5.0 seconds = $under5sec: ${percent_under5sec}%\n";
print "between 5.0 and 10.0 seconds = $under10sec: ${percent_under10sec}%\n";
print "over 10.0 seconds = $over10sec: ${percent_over10sec}%\n";
print "non valid response = $nonvalid: ${percent_nonvalid}%\n";

exit(0);
