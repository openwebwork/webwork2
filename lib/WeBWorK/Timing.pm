################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Timing.pm,v 1.8 2003/12/09 01:12:30 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::Timing;

=head1 NAME

WeBWorK::Timing - Log timing data.

head1 SYNOPSIS

 use WeBWorK::Timing;
 
 my $timer = WeBWorK::Timing->new("do some processesing");
 $timer->start;
 do_some_processing();
 $timer->continue("
 do_some_more_processing();
 $timer->stop;
 $timer->save;
 
 my $timer0 = WeBWorK::Timing->new("main task");
 my $timer1 = WeBWorK::Timing->new("subtask 1");
 my $timer2 = WeBWorK::Timing->new("subtask 1");
 
 $timer0->start;
 $timer1->start;
 sub_task(1);
 $timer1->stop;
 $timer2->start;
 sub_task(2);
 $timer2->stop;
 $timer0->stop;

 # timing data is saved when objects go out of scope

=cut

use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);

our $TASK_COUNT = 0; # number of tasks processed in this child process
# You can customize the output to go to some file besides STDERR (usually ErrorLog for Apache)
our $TIMING_LOG = '';

#our $TIMING_LOG = '/home/gage/webwork/webwork-modperl/logs/timing.log';
=head1 CONSTRUCTOR

=over

=item new($task)

C<new> creates a new timing object, with the task given in $task.

=back

=cut

sub new {
	my ($invocant, $task) = @_;
	my $self = {
		id    => $TASK_COUNT++,
		task  => $task,
		ctime => scalar gettimeofday(),
		saved => 0,
	};
	return bless $self, ref $invocant || $invocant
}

=head1 METHODS

=over

=item start(), begin()

Marks the current time as the start time for the task.

=cut

sub start {
	my ($self) = @_;
	$self->{start} = gettimeofday();
}

sub begin { shift->start(@_); }

=item continue($data)

Stores the current time as an intermediate time, associated with the string
given in $data.

=cut

sub continue {
	my ($self, $data) = @_;
	push @{$self->{steps}}, [ scalar gettimeofday(), $data ];
}

=item stop(), finish(), end()

Marks the current time as the stop time for the task.

=cut

sub stop {
	my ($self) = @_;
	$self->{stop} = gettimeofday();
}

sub finish { shift->stop(@_); }
sub end    { shift->stop(@_); }

=item save()

Writes the timing data for this task to the standard error stream. If save is
not called explicitly, it is called when the object goes out of scope.

=cut

sub save {
	my ($self) = @_;
	local(*TIMING);
	if ($TIMING_LOG =~ /\S/) { 
		open(TIMING, ">>$TIMING_LOG") || die "Can't open timing log: $TIMING_LOG";
	} else {
		*TIMING = *STDERR;
	} 
		
	my $id = $self->{id};
	my $task = $self->{task};
	my $now = gettimeofday();
	
	my $diff = sprintf("%.6f", 0);
	if ($self->{start}) {
		my $start = sprintf("%.6f", $self->{start});
		print TIMING "TIMING $$ $id $start ($diff) $task: START\n";
	} else {
		my $ctime = sprintf("%.6f", $self->{ctime});
		print TIMING "TIMING $$ $id $ctime ($diff) $task: START (assumed)\n";
	}
	
	if ($self->{steps}) {
		my @steps = @{$self->{steps}};
		foreach my $step (@steps) {
			my ($time, $data) = @$step;
			$time = sprintf("%.6f", $time);
			my $start = sprintf("%.6f", $self->{start});
			my $diff  = sprintf("%.6f", $time-$start);
			print TIMING "TIMING $$ $id $time ($diff) $task: $data\n";
		}
	}
	
	if ($self->{stop}) {
		my $stop = sprintf("%.6f", $self->{stop});
		my $start = sprintf("%.6f", $self->{start});
		my $diff  = sprintf("%.6f", $stop-$start);
		print TIMING "TIMING $$ $id $stop ($diff) $task: END\n";
	} else {
		$now = sprintf("%.6f", $now);
		my $start = sprintf("%.6f", $self->{start});
		my $diff  = sprintf("%.6f", $now-$start);
		print TIMING "TIMING $$ $id $now ($diff) $task: END (assumed)\n";
	}
	
	$self->{saved} = 1;
}

sub DESTROY {
	my ($self) = shift;
	
	$self->save unless $self->{saved};
}

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=head1 BUGS

Currently outputs to STDERR instead of something more graceful.

=head1 SEE ALSO

The F<timing> utility can be used to parse and sort log output.

=cut

1;
