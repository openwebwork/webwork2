################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::Timing;

=head1 NAME

WeBWorK::Timing - Log timing data.

=cut

use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);

our $TASK_COUNT = 0; # number of tasks processed in this child process

sub new {
	my ($invocant, $task) = @_;
	my $self = {
		id    => $TASK_COUNT++,
		task  => $task,
		ctime => scalar gettimeofday(),
	};
	return bless $self, ref $invocant || $invocant
}

sub start {
	my ($self) = @_;
	$self->{start} = gettimeofday();
}

sub continue {
	my ($self, $data) = @_;
	push @{$self->{steps}}, [ scalar gettimeofday(), $data ];
}

sub finish {
	my ($self) = @_;
	$self->{finish} = gettimeofday();
}

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
	
	if ($self->{finish}) {
		my $finish = sprintf("%.6f", $self->{finish});
		print STDERR "TIMING $$ $id $finish $task: FINISH\n";
	} else {
		$now = sprintf("%.6f", $now);
		print STDERR "TIMING $$ $id $now $task: FINISH (assumed)\n";
	}
}

1;
