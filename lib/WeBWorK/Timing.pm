################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
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
	
	my $id = $self->{id};
	my $task = $self->{task};
	my $now = gettimeofday();
	
	if ($self->{start}) {
		my $start = sprintf("%.6f", $self->{start});
		print STDERR "TIMING $$ $id $start $task: START\n";
	} else {
		my $ctime = sprintf("%.6f", $self->{ctime});
		print STDERR "TIMING $$ $id $ctime $task: START (assumed)\n";
	}
	
	if ($self->{steps}) {
		my @steps = @{$self->{steps}};
		foreach my $step (@steps) {
			my ($time, $data) = @$step;
			$time = sprintf("%.6f", $time);
			print STDERR "TIMING $$ $id $time $task: $data\n";
		}
	}
	
	if ($self->{stop}) {
		my $stop = sprintf("%.6f", $self->{stop});
		print STDERR "TIMING $$ $id $stop $task: END\n";
	} else {
		$now = sprintf("%.6f", $now);
		print STDERR "TIMING $$ $id $now $task: END (assumed)\n";
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
