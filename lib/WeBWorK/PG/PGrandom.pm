#! /usr/math/bin/perl -w


package PGrandom;


use strict;

my $multiplier = 69069;

my $translate = 1;

my $modulus = 2**32;

sub new {
	my $class 			= shift;
	my $seed			= shift;

	$seed    = 1 unless defined($seed);
	my $original_seed = $seed;
	$seed    =  mod ($multiplier * $seed + $translate, $modulus);
	my $self = { 'seed'  			=> $seed,
	             'original_seed'	=> $original_seed,  # this and the next value are largely for debugging
	             'number_of_calls'  => 1                # there is always one call to set the seed.
	};
	
	bless $self, $class;
 
 	return $self;
}
sub mod {   # for some reason perl's % doesn't seem to work for large numbers?
    my $a = shift;
    my $b = shift;
    $a - int($a/$b)*$b;
}

sub random {
	my $self  = shift;
	my $begin = shift;
	my $end   = shift;
	my $incr  = shift;
	my $out;
	$self->{'number_of_calls'}++;
	$incr     = 1 unless defined($incr);
	my $seed = $self->{'seed'};
	my $new_seed = mod ($multiplier * $seed + $translate, $modulus) ;
	$self->{'seed'} = $new_seed;
	unless ( $incr <= 0 ) {
		$out = $begin +$incr*int(  ($new_seed/($modulus))*( ($end-$begin)/$incr +1 )  )  ;
	} else { 					# if $incr is less than zero return "continuous" distribution
		$out = $begin + ($end-$begin)*$new_seed/$modulus;
	}
	$out;
		
}
sub rand {
	my $self  = shift;
	my $end   = shift;
	$end = 1 unless defined($end);
	$self->random(0,$end,0);
}

sub srand {
	my $self = shift;
	my $new_seed = shift;
	$self->{'original_seed'} = $new_seed;
    $new_seed= mod ($multiplier * $new_seed + $translate, $modulus) ;   # reset the seed
    $self->{'number_of_calls'}=1;
    $self->{'seed'} = $new_seed;
}
sub seed {  #synonym for srand
	my $self = shift;
	$self->srand(@_);
}

1;
