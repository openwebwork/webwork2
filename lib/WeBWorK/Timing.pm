################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Timing.pm,v 1.10 2004/06/23 00:33:41 sh002i Exp $
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
 
 # Enable timing
 $WeBWorK::Timing::Enable = 1;
 
 # Log to a file instead of STDERR
 $WeBWorK::Timing::Logfile = "/path/to/timing.log";
 
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

################################################################################

=head1 CONFIGURATION VARIABLES

=over

=item $Enabled

If true, timing messages will be output. If false, they will be ignored.

=cut

our $Enabled = 0  unless defined $Enabled;

=item $Logfile

If non-empty, timing output will be sent to the file named rather than STDERR.

=cut

our $Logfile = "" unless defined $Logfile;

=back

=cut

################################################################################

=head1 CONSTRUCTOR

=over

=item new($task)

C<new> creates a new timing object, with the task given in $task.

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

=back

=cut

################################################################################

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
	
	if ($Enabled) {
	    local($|=1); #flush after each print
		my $fh;
		if ($Logfile ne "") { 
			if (open my $tmpFH, ">>", $Logfile) {
				$fh = $tmpFH;
			} else {
				warn "Failed to open timing log '$Logfile' in append mode: $!";
				$fh = *STDERR;
			}
		} else {
			$fh = *STDERR;
		}
		
		my $id = $self->{id};
		my $task = $self->{task};
		my $now = gettimeofday();
		
		my $diff = sprintf("%.6f", 0);
		if ($self->{start}) {
			my $start = sprintf("%.6f", $self->{start});
			print $fh "TIMING $$ $id $start ($diff) $task: START\n";
		} else {
			my $ctime = sprintf("%.6f", $self->{ctime});
			print $fh "TIMING $$ $id $ctime ($diff) $task: START (assumed)\n";
		}
		
		if ($self->{steps}) {
			my @steps = @{$self->{steps}};
			foreach my $step (@steps) {
				my ($time, $data) = @$step;
				$time = sprintf("%.6f", $time);
				my $start = sprintf("%.6f", $self->{start});
				my $diff  = sprintf("%.6f", $time-$start);
				print $fh "TIMING $$ $id $time ($diff) $task: $data\n";
			}
		}
		
		if ($self->{stop}) {
			my $stop = sprintf("%.6f", $self->{stop});
			my $start = sprintf("%.6f", $self->{start});
			my $diff = sprintf("%.6f", $stop-$start);
			print $fh "TIMING $$ $id $stop ($diff) $task: END\n";
		} else {
			$now = sprintf("%.6f", $now);
			my $start = sprintf("%.6f", $self->{start});
			my $diff = sprintf("%.6f", $now-$start);
			print $fh "TIMING $$ $id $now ($diff) $task: END (assumed)\n";
		}
	}
	
	$self->{saved} = 1;
}

sub DESTROY {
	my ($self) = shift;
	
	$self->save unless $self->{saved};
}

=back

=cut

################################################################################

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=head1 SEE ALSO

The F<timing> utility can be used to parse and sort log output.

=cut

1;
