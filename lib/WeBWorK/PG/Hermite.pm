#!/usr/bin/perl -w

use strict;
use Carp;

=head1 NAME

	Hermite.pm

=head1 SYNPOSIS

      Usage:
                $obj = new Hermit(\@x_values, \y_valuses \@yp_values);
		
		#get and set methods
                $ra_x_values = $obj -> ra_x(\@x_values);
		$ra_y_values = $obj -> ra_y;
		$ra_yp_values = $obj -> ra_yp;
		
		$obj -> initialize;           # calculates the approximation
		
		#get methods
		$rf_function                  = $obj -> rf_f;
		$rf_function_derivative       = $obj -> rf_fp;
		$rf_function_2nd_derivative   = $obj -> rf_fpp;
		
		$rh_critical_points           =$obj -> rh_critical_points
		$rh_inflection_points         =$obj -> rh_inflection_points
                



=head1 DESCRIPTION

This module defines an object containing a Hermite spline approximation to a function.
  The approximation
consists of a piecewise cubic polynomial which agrees with the original 
function and its first derivative at
the node points.

This is useful for creating on the fly graphics.  Care must be taken to use a small 
number of points spaced reasonably far apart, preferably 
points with alternating slopes, since this will minimize 
the number of extraneous critical points
introduced.  Too many points will introduce many small variations and 
a large number of extraneous critical points.

There are even more extraneous inflections points.  
This parameter is probably not very useful.   A different
approximation scheme needs to be used.

=cut


# an object that contains a cubic hermite spline

package Hermite;


sub new {
    my $class = shift;
    my ($ra_x,$ra_y,$ra_yp) = @_;
    my $self = {
	         ra_x				=>  [],
		 ra_y				=>  [],
		 ra_yp				=>  [],
		 rf_f				=>  0,   # refers to a subroutine for the function
		 rf_fp				=>  0,   # refers to a subroutine for the derivative of the function
		 rf_fpp				=>  0,   # refers to a subroutine for the second derivative of the function
		 rh_critical_points		=>  {},
		 rh_inflection_points		=>  {},
		 rh_maximum_points		=>  {},
		 rh_minimum_points		=>  {},
    };
    bless $self, $class;
    $self->define($ra_x,$ra_y,$ra_yp) if ref($ra_x) eq 'ARRAY' and ref($ra_y) eq 'ARRAY' and ref($ra_yp) eq 'ARRAY';
    $self;
}

sub define{
    my $self   = shift;
    my $ra_x  = shift;
    my $ra_y  = shift;
    my $ra_yp = shift;
    $self->ra_x($ra_x);
    $self->ra_y($ra_y);
    $self->ra_yp($ra_yp);
    
    $self -> initialize();
    ($self->{x_ref},$self->{y_ref}, $self->{yp_ref} )
}

sub initialize {
    my $self = shift;
    # define the functions rf_f
    
    $self -> {rf_f} = hermite_spline($self -> {ra_x}, $self -> {ra_y}, $self -> {ra_yp} );
#     # define the function  rf_fp
     $self -> {rf_fp} = hermite_spline_p($self -> {ra_x}, $self -> {ra_y}, $self -> {ra_yp} );
#     # define the function  rf_fp
     $self -> {rf_fpp} = hermite_spline_pp($self -> {ra_x}, $self -> {ra_y}, $self -> {ra_yp} );
#     # define the critical points
     %{$self -> {rh_critical_points}} = critical_points($self -> {ra_x}, $self -> {ra_y}, $self -> {ra_yp},
                                                     $self -> { rf_f },
						     );
#     # define the inflection_points
     %{$self -> {rh_inflection_points}} = inflection_points($self -> {ra_x}, $self -> {ra_y}, $self -> {ra_yp} ,
                                                     $self -> { rf_f },
						     );
#     # define the maximum points
    
    # define the minimum points
    
}

# fix up these accesses to do more checking
sub ra_x {
    my $self = shift;
    my $ra_x  = shift;
    @{$self->{ra_x}} = @$ra_x if ref($ra_x) eq 'ARRAY';
    $self->{ra_x};
    
}

sub ra_y {
    my $self = shift;
    my $ra_y  = shift;
    @{$self->{ra_y}} = @$ra_y if ref($ra_y) eq 'ARRAY';
    $self->{ra_y};
}

sub ra_yp {
    my $self = shift;
    my $ra_yp  = shift;
    @{$self->{ra_yp}} = @$ra_yp if ref($ra_yp) eq 'ARRAY';
    $self->{ra_yp};
}

sub rf_f {
    my $self = shift;
    my $rf_f =shift;
    $self ->{rf_f} = $rf_f if defined( $rf_f );
    $self ->{rf_f};  
}
sub rf_fp {
    my $self = shift;
    my $rf_fp =shift;
    $self ->{rf_fp} = $rf_fp if defined( $rf_fp );
    $self ->{rf_fp};    
}
sub rf_fpp {
    my $self = shift;
    my $rf_fpp =shift;
    $self ->{rf_fpp} = $rf_fpp if defined( $rf_fpp );
    $self ->{rf_fpp};  
}

sub rh_critical_points {
    my $self = shift;
    $self -> { rh_critical_points};
}

sub rh_inflection_points {
    my $self = shift;
    $self -> { rh_inflection_points};
}

##Internal subroutines


sub critical_points{
    my $ra_x = shift;
    my $ra_y =shift;
    my $ra_yp = shift;
    my $rf_hermite_fun =shift;
    my %critical_points = ();
    my $last_index = @$ra_x -2;
    foreach my $i (0 .. $last_index ) {
        internal_critical_points($ra_x->[$i],   $ra_y->[$i],   $ra_yp->[$i],
	                         $ra_x->[$i+1], $ra_y->[$i+1], $ra_yp->[$i+1],
				 \%critical_points,$rf_hermite_fun);
    }
    %critical_points;
}

sub inflection_points{
    my $ra_x = shift;
    my $ra_y =shift;
    my $ra_yp = shift;
    my $rf_hermite_fun =shift;
    my %inflection_points = ();
    my $last_index = @$ra_x -2;
    foreach my $i (0 .. $last_index ) {
        internal_inflection_points($ra_x->[$i],   $ra_y->[$i],   $ra_yp->[$i],
	                         $ra_x->[$i+1], $ra_y->[$i+1], $ra_yp->[$i+1],
				 \%inflection_points,$rf_hermite_fun);
    }
    %inflection_points;
}
sub internal_critical_points{
    my ($x0,$l,$lp, $x1,$r,$rp, $rh_roots ,$rf_function) = @_;
     #data for one segment of the hermite spline
     
     # coefficients for the approximating polynomial
     
     my @a = (   $l,
                  $lp,
		  -$lp/2 + (3*(-$lp - 2*($l - $r) - $rp))/2 + $rp/2,
		  $lp + 2*($l - $r) + $rp
               );

    my ($root1, $root2, $z1,$z2);
    if ( $a[3] == 0 ) {
	if ( $a[2] == 0 ) {
	} else {
	    $root1 = -$a[1]/( 2*$a[2] );
	    if ( 0 <= $root1 and $root1 < 1) {
		$z1 = $root1*($x1-$x0) + $x0;
		
	        $rh_roots -> {$z1} = &$rf_function($z1);    
	    }
	}
   } else {
	my $discriminent = (4*$a[2]**2 - 12*$a[1]*$a[3]);

	
	if ( $discriminent >= 0 ) {
	    $discriminent = $discriminent**0.5;
	    $root1 = (-2*$a[2] - $discriminent )/( 6*$a[3] );
	    $root2 = (-2*$a[2] + $discriminent )/( 6*$a[3] );
	    $z1 = $root1*($x1-$x0) + $x0;
	    $z2 = $root2*($x1-$x0) + $x0;
	    $rh_roots -> {$z1} = &$rf_function($z1) if  0 <= $root1 and $root1 < 1;
	    $rh_roots -> {$z2} = &$rf_function($z1) if  0 <= $root2 and $root2 < 1;
	}
    }  
}

sub internal_inflection_points {
    my ($x0,$l,$lp,,$x1,$r,$rp,$rh_roots,$rf_function) = @_;
     #data for one segment of the hermite spline
     
     # coefficients for the approximating polynomial
     
     my @a = (   $l,
                  $lp,
		  -$lp/2 + (3*(-$lp - 2*($l - $r) - $rp))/2 + $rp/2,
		  $lp + 2*($l - $r) + $rp
               );    
    if ($a[3] == 0 ) {
    } else {
	my $root1 = -$a[2]/( 3*$a[3] );
	my $z1 = $root1*($x1-$x0) + $x0;
	$rh_roots -> {$z1} = &$rf_function($z1) if  0 <= $root1 and $root1 < 1;
    }
    
}



sub cubic_hermite {
    my ( $x0, $y0,$yp0, $x1, $y1, $yp1 ) = @_;
    my @a;
    my $width = $x1 - $x0;
    $yp0 = $yp0*$width;  # normalize to unit width
    $yp1 = $yp1*$width;

    $a[0] = $y0; 
    $a[1] = $yp0;
    $a[2] = -3*$y0 - 2*$yp0 +3*$y1 -$yp1;
    $a[3] = 2*$y0 + $yp0 - 2*$y1 +$yp1;
    
    my $f = sub {
                        my $x = shift;
                        #normalize to unit width
			$x = ( $x - $x0 )/$width;
			( ($a[3]*$x + $a[2]) * $x + $a[1] )*$x + $a[0];
			
                };
    $f;        
}

sub cubic_hermite_p {
    my ( $x0, $y0,$yp0, $x1, $y1, $yp1 )=@_;
    my @a;
    my $width = $x1 - $x0;
    $yp0 = $yp0*$width;  # normalize to unit width
    $yp1 = $yp1*$width;

    $a[0] = $y0; 
    $a[1] = $yp0;
    $a[2] = -3*$y0 - 2*$yp0 +3*$y1 -$yp1;
    $a[3] = 2*$y0 + $yp0 - 2*$y1 +$yp1;
    
    my $fp = sub {
                        my $x = shift;
                        #normalize to unit width
			$x = ( $x - $x0 )/$width;
			( (3*$a[3]*$x + 2*$a[2]) * $x + $a[1] )/$width ;
                };
		

			
     $fp;
		
}    

sub cubic_hermite_pp {
    my ( $x0, $y0,$yp0, $x1, $y1, $yp1 ) = @_;
    my @a;
    my $width = $x1 - $x0;
    $yp0 = $yp0*$width;  # normalize to unit width
    $yp1 = $yp1*$width;

    $a[0] = $y0; 
    $a[1] = $yp0;
    $a[2] = -3*$y0 - 2*$yp0 +3*$y1 -$yp1;
    $a[3] = 2*$y0 + $yp0 - 2*$y1 +$yp1;
    

		
    my $fpp = sub {
                        my $x = shift;
                        #normalize to unit width
			$x = ( $x - $x0 )/$width;
			 (6*$a[3]*$x + 2*$a[2])/$width**2 ;
                };
			
    $fpp;
}  



sub hermite_spline {
	my ($xref, $yref, $ypref) = @_;
	my @xvals  = @$xref;
	my @yvals  = @$yref;
	my @ypvals = @$ypref;
	my $x0 = shift @xvals;
	my $y0 = shift @yvals;
	my $yp0 = shift @ypvals;
	my ($x1,$y1,$yp1);
	my @polys;  #calculate a hermite polynomial evaluator for each region
	
	while (@xvals) {
		$x1 = shift @xvals;
		$y1 = shift @yvals;
		$yp1 = shift @ypvals;
		
		push @polys, cubic_hermite($x0, $y0, $yp0 , $x1, $y1 , $yp1);
		$x0  = $x1;
		$y0  = $y1;
		$yp0 = $yp1;
	}
	
	
	my $hermite_spline_function = sub {
		my $x = shift;
		my $y;
		my $fun;
		my @xvals = @$xref;
		my @fns = @polys;
		return &{$fns[0]} ($x) if $x == $xvals[0]; #handle left most endpoint
		
		while (@xvals && $x > $xvals[0]) {  # find the function for this range of x
			shift(@xvals);
			$fun = shift(@fns);
		}
		
		# now that we have the left hand of the input
		#check first that x isn't out of range to the left or right
		if (@xvals  && defined($fun) )  {
			$y =&$fun($x);
		}
		$y;
	};
	$hermite_spline_function;
}

sub hermite_spline_p {
	my ($xref, $yref, $ypref) = @_;
	my @xvals  = @$xref;
	my @yvals  = @$yref;
	my @ypvals = @$ypref;
	my $x0 = shift @xvals;
	my $y0 = shift @yvals;
	my $yp0 = shift @ypvals;
	my ($x1,$y1,$yp1);
	my @polys;  #calculate a hermite polynomial evaluator for each region
	while (@xvals) {
		$x1 = shift @xvals;
		$y1 = shift @yvals;
		$yp1 = shift @ypvals;
		push @polys, cubic_hermite_p($x0, $y0, $yp0 , $x1, $y1 , $yp1);
		$x0  = $x1;
		$y0  = $y1;
		$yp0 = $yp1;
	}
	
	
	my $hermite_spline_function_p = sub {
		my $x = shift;
		my $y;
		my $fun;
		my @xvals = @$xref;
		my @fns = @polys;
		return $y=&{$fns[0]} ($x) if $x == $xvals[0]; #handle left most endpoint
		
		while (@xvals && $x > $xvals[0]) {  # find the function for this range of x
			shift(@xvals);
			$fun = shift(@fns);
		}
		
		# now that we have the left hand of the input
		#check first that x isn't out of range to the left or right
		if (@xvals  && defined($fun) )  {
			$y =&$fun($x);
		}
		$y;
	};
	$hermite_spline_function_p;
}
sub hermite_spline_pp {
	my ($xref, $yref, $ypref) = @_;
	my @xvals  = @$xref;
	my @yvals  = @$yref;
	my @ypvals = @$ypref;
	my $x0 = shift @xvals;
	my $y0 = shift @yvals;
	my $yp0 = shift @ypvals;
	my ($x1,$y1,$yp1);
	my @polys;  #calculate a hermite polynomial evaluator for each region
	while (@xvals) {
		$x1 = shift @xvals;
		$y1 = shift @yvals;
		$yp1 = shift @ypvals;
		push @polys, cubic_hermite_pp($x0, $y0, $yp0 , $x1, $y1 , $yp1);
		$x0  = $x1;
		$y0  = $y1;
		$yp0 = $yp1;
	}
	
	
	my $hermite_spline_function_pp = sub {
		my $x = shift;
		my $y;
		my $fun;
		my @xvals = @$xref;
		my @fns = @polys;
		return $y=&{$fns[0]} ($x) if $x == $xvals[0]; #handle left most endpoint
		
		while (@xvals && $x > $xvals[0]) {  # find the function for this range of x
			shift(@xvals);
			$fun = shift(@fns);
		}
		
		# now that we have the left hand of the input
		#check first that x isn't out of range to the left or right
		if (@xvals  && defined($fun) )  {
			$y =&$fun($x);
		}
		$y;
	};
	$hermite_spline_function_pp;
}


1;
