#!/usr/bin/perl -w
#
# Fraction object
# Keeps track of two variables- numerator and denominator.
# Has subroutines for basic arithmatic functions, for anything 
# more complicated, it can return a scalar value of 
# numerator/denominator.
# VS 7/20/2000


=head3 Fraction

  This object is designed to ease the use of fractions

=head4 Variables and Methods

	Variables

		numerator	#numerator of fraction
		denominator	#denominator of fraction

	Arithmetic Methods	#these will all accept a scalar value or 
				#another fraction as an argument

		plus		#returns the sum of the fraction and argument
		minus		#returns fraction minus argument
		subtractFrom	#returns argument minus fraction
		divBy		#returns fraction divided by argument
		divInto		#returns argument divided by fraction
		times		#returns fraction times argument
		compare		#returns <, =, or > for the relation of fraction to argument

			pow		#returns fraction raised to argument, a given integer power


	Other methods
		
		reduce		#reduces to lowest terms, and makes sure denominator is positive
		scalar		#returns the scalar value numerator/denominator
		print		#prints the fraction
		print_mixed	#prints the fractionas a mixed number
		print_inline	#prints the fraction like this 2/3


=head4 Synopsis

	The fraction object stores two variables, numerator and denominator.  The basic
arithmatic methods listed above can be performed on a fraction, and it can return its own
scalar value for use with functions expecting a scalar (ie, sqrt($frac->scalar) ).  


=cut


BEGIN {
	be_strict();
}

package Fraction;


my %fields = (
	numerator	=>	undef,
	denominator	=>	undef,
);


sub new {

	my $class = shift;
	my @input = @_;
	my $num; 
	my $denom;

	unless (@_ == 1 or @_ == 2) {
		warn "Invalid number of arguments to create new Fraction.  Use the form new Fraction(numerator,
		denominator) or new Fraction(value) to send a single scalar.";
		}

	# if we've been given a scalar as input:
	# this will ensure that the numerator is a whole number.  If it is not, this will
	# multiply by 10 until it is a whole number, keeping track of the appropriate denominator.
	# The loop conditional checks that the difference between the number and its int value 
	# is less than .000000001, NOT that they are equal.  Because of imprecisions with floating
	# point numbers, checking for equality will NOT work in many cases.

 	if (@_ == 1) {
		my $tempDenom = 1;
		while ($input[0] - int($input[0]) > .000000001) {$input[0] *= 10; $tempDenom *= 10;}
		$num = $input[0];
		$denom = $tempDenom;
 	}
 
 	else { $num = $input[0]; $denom = $input[1]; }
	

	my $self = {
		_permitted	=>	\%fields,
		numerator	=>	$num,
		denominator	=>	$denom,
	};
	
	bless $self, $class;
	
	return $self;
}

sub AUTOLOAD {
	my $self = shift;
	
	my $type = ref($self) or die "$self is not an object";

	# $AUTOLOAD is sent in by Perl and is the full name of the object (i.e. main::blah::blah_more)
	my $name = $Fraction::AUTOLOAD;
	$name =~ s/.*://; #strips fully-qualified portion

	unless ( exists $self->{'_permitted'}->{$name} ) { die "Can't find '$name' field in object of class '$type'";}
                                
	if (@_) {
		return $self->{$name} = shift; #set the variable to the first parameter
	} else {
		return $self->($name); #if no parameters just return the value
	}
}

sub DESTROY {
	# doing nothing about destruction, hope that isn't dangerous
}


###################################################################################
# Basic Arithmetic Methods
# Each returns a new Fraction appropriate to the operation

sub plus {
	my $self = shift;
	my $input = shift;
	
	$input = new Fraction($input*100, 100) unless (ref($input) eq "Fraction");

	my $lcm = $self->lcm($self->{denominator}, $input->{denominator});
	my $scaleA = $lcm/$self->{denominator};
	my $scaleB = $lcm/$input->{denominator};

	my $num = $self->{numerator}*$scaleA + $input->{numerator}*$scaleB;

	my $frac = new Fraction($num, $lcm);
	$frac->reduce;
	$frac;
}

sub minus {
	my $self = shift;
	my $input = shift;

	$input = new Fraction($input*100, 100) unless (ref($input) eq "Fraction");

	my $lcm = $self->lcm($self->{denominator}, $input->{denominator});
	my $scaleA = $lcm/$self->{denominator};
	my $scaleB = $lcm/$input->{denominator};

	my $num = $self->{numerator}*$scaleA - $input->{numerator}*$scaleB;
        
	my $frac = new Fraction($num, $lcm);
	$frac->reduce;
	$frac;
}

sub subtractFrom {
	my $self = shift;
	my $input = shift;  

	$input = new Fraction($input*100, 100) unless (ref($input) eq "Fraction");
         
	my $lcm = $self->lcm($self->{denominator}, $input->{denominator});
	my $scaleA = $lcm/$self->{denominator};
	my $scaleB = $lcm/$input->{denominator};

	my $num = $input->{numerator}*$scaleB - $self->{numerator}*$scaleA;

	my $frac = new Fraction($num, $lcm);
	$frac->reduce;
	$frac;
}

sub divInto {
	my $self = shift;
	my $input = shift;  

	$input = new Fraction($input*100, 100) unless (ref($input) eq "Fraction");
         
	my $num = $input->{numerator}*$self->{denominator};
	my $denom = $input->{denominator}*$self->{numerator};

	my $frac = new Fraction($num, $denom);
	$frac->reduce;
	$frac;
}

sub divBy {
	my $self = shift;
	my $input = shift;

	$input = new Fraction($input*100, 100) unless (ref($input) eq "Fraction");
        
	my $num = $self->{numerator}*$input->{denominator};
	my $denom = $input->{numerator}*$self->{denominator};
                            
	my $frac = new Fraction($num, $denom);
	$frac->reduce;
	$frac;
}       

sub times {
	my $self = shift;
	my $input = shift;

	$input = new Fraction($input*100, 100) unless (ref($input) eq "Fraction");
        
	my $num = $self->{numerator}*$input->{numerator};
	my $denom = $self->{denominator}*$input->{denominator};

	my $frac = new Fraction($num, $denom);
	$frac->reduce;
	$frac;
}

sub pow {
	
	my $self = shift;
	my $input = shift;

	if($input == 0) { # 0 power, always return 1
		if($self->{numerator} == 0) {
			warn "Indeterminant form, 0^0, in Fraction power";
		}
		return new Fraction(1,0);
	}

	my ($n, $d);
	
	if($input<0) {
		$d = $self->{numerator};
		$n = $self->{denominator};
		if($d==0) {
			warn "Computing 1/0 in Fraction";
		}
		$input = -$input;
	} else {
		$n = $self->{numerator};
		$d = $self->{denominator};
	}
	my $g = $self->gcd($n, $d);
	if($d<0) {$g = -$g;}
	$n /= $g;
	$d /= $g;

	return new Fraction($n**$input,	$d**$input);

}

#########################################################################
# Other User-Accessed Methods


# returns a string denoting relation-- < = or >
# a string is returned for ease of use in writing problems
sub compare {
	my $self = shift;
	my $input = shift;

	$input = $input->scalar if (ref($input) eq "Fraction");

	my $relation = undef;
	$relation = "<" if ($self->scalar < $input);
	$relation = "=" if ($self->scalar == $input);
	$relation = ">" if ($self->scalar > $input);

	$relation;
}


# returns the scalar value of numerator/denominator
sub scalar {
	my $self = shift;
	my $scalar = $self->{numerator}/$self->{denominator};
	
	$scalar;
}


# reduces a fraction to lowest terms, and makes denominator positive
sub reduce {
	
	my $self = shift;	
	my $gcd = $self->gcd($self->{numerator}, $self->{denominator});
	if($self->{denominator}<0) {$gcd = -$gcd;}
	
	$self->{numerator} = $self->{numerator}/$gcd;
	$self->{denominator} = $self->{denominator}/$gcd;
}


# standard print method.  Outputs string containing fraction displayed (in math mode
# if needed).
sub print {
	my $self = shift;
	my $out;

	# if it's a whole number, just print the number
	if ($self->{denominator} == 1) {
		$out = $self->{numerator};
	}
	# positive fraction: print out in plain math mode
	elsif ($self->scalar > 0) {
		$out = "\\ensuremath{ \\frac{$self->{numerator}}{$self->{denominator}} }";
	}
	# negative fraction: print out negative sign and then absolute value in 
	# fraction form, avoiding parenthesis around the negative portion.
	else {
		my $foo = -$self->{numerator}; 
		$out = "\\ensuremath{ -\\frac{$foo}{$self->{denominator}} }";
	}
	
	$out;
}

# forces printing of a mixed number, if applicable.
sub print_mixed {
	my $self = shift;
	my $out;
	
	# if it's not an improper, just pass on to the regular print method
	if ($self->{numerator} < $self->{denominator} ) { $out = $self->print; }

	# otherwise print out the mixed number strong.  This does not alter the
	# actual value of the fraction in any way.
	else {
		my $tempNum = $self->{numerator};
		my $tempDenom = $self->{denominator};
		my $coeff = int($tempNum/$tempDenom);
		$tempNum = $tempNum % $tempDenom;

		$out = "\\ensuremath{ -$coeff \\frac{abs($tempNum)}{abs($tempDenom)} }" if ($self->scalar < 0);
		$out = "\\ensuremath{ $coeff \\frac{$tempNum}{$tempDenom} }" if ($self->scalar > 0);
		$out = $coeff if ($tempNum == 0);
	}
	
	$out;
}


# prints fraction as 4 or 5/3 as needed
sub print_inline {
	my $self = shift;
	my $out;

	# if it's a whole number, just print the number
	if ($self->{denominator} == 1) {
		$out = $self->{numerator};
	}
	# print as 5/3
	else {
		$out = "$self->{numerator}/$self->{denominator}";
	}
	
	$out;
}

# these methods are simply so that in a problem, the user may access the variables without 
# worrying about braces, that is, use $frac->denominator instead of $frac->{denominator}
sub numerator {
	my $self = shift;
	return $self->{numerator};
}

sub denominator {
	my $self = shift;
	return $self->{denominator};
}

########################################################################
# Internal Methods

# Least Common Multiple
# Used in arithmatic methods to convert two fractions to common denominator
# takes in two scalar values and returns their lcm
sub lcm {
	my $self = shift;
        my $a = shift;
        my $b = shift;  
 
        #reorder such that $a is the smaller number
        if ($a > $b) {
                my $temp = $a;
                $a = $b;
                $b = $temp;
        }

        my $lcm = 0;
        my $curr = $b;
                        
        while($lcm == 0) {
                $lcm = $curr if ($curr % $a == 0);
                $curr += $b;
        }
 
        $lcm;
}



# Helper function for reduce
# takes in two scalar values and uses the Euclidean Algorithm to return the 
# greatest common denominator 
sub gcd {   

	my $self = shift;
        my $a = abs(shift);	#absolute values because this will yeild the same gcd,
        my $b = abs(shift);	#but allows use of the mod operation

	if ($a < $b) {
		my $temp = $a;
		$a = $b;
		$b = $temp;
	}

	return $a if $b == 0;

	my $q = int($a/$b);
	my $r = $a % $b;

	return $b if $r == 0;

	my $tempR = $r;
	
	while ($r != 0) {

		#keep track of what $r was in the last loop, as this is the value 
		#we will want when $r is set to 0
		$tempR = $r;

		$a = $b;
		$b = $r;
		$q = $a/$b;
		$r = $a % $b;

	}

	$tempR;
}


1;
