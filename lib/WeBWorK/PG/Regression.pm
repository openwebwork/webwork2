#!/usr/bin/perl -w

package Regression;

$VERSION = 0.1;

use strict;

################################################################
use constant TINY => 1e-8;
use constant DEBUGGING => 0;
################################################################
=pod

=head1 NAME

  Regression.pm - 		weighted linear regression package (line+plane fitting)

=head1 DESCRIPTION

Regression.pm is a multivariate linear regression package.  That is,
it estimates the c coefficients for a line-fit of the type

y= b(0)*x(0) + b(1)*x1 + b(2)*x2 + ... + b(k)*xk

given a data set of N observations, each with k independent x variables and
one y variable.  Naturally, N must be greater than k---and preferably
considerably greater.  Any reasonable undergraduate statistics book will
explain what a regression is.  Most of the time, the user will provide a
constant ('1') as x(0) for each observation in order to allow the regression
package to fit an intercept.

=head1 USAGE

If the sample data for (x1, x2, y) includes ($x1[$i], $x2[$i], $y[$i]) for 0<=$i<=5, type

$reg = Regression->new( 3, "y", [ "const", "x1", "x2" ] );

for($i=0; $i<6; $i++){
	$reg->include( $y[$i], [ 1.0, $x1[$i], $x2[$i] ] );
}

@coeff= $reg->theta();

$b0 = $coeff[0][0]; 
$b1 = $coeff[0][1]; 
$b2 = $coeff[0][2];

=head1 ALGORITHM

=head2 Original Algorithm (ALGOL-60):

	W.  M.  Gentleman, University of Waterloo, "Basic Description
	For Large, Sparse Or Weighted Linear Least Squares Problems
	(Algorithm AS 75)," Applied Statistics (1974) Vol 23; No. 3

=head2 INTERNALS

R=Rbar is an upperright triangular matrix, kept in normalized
form with implicit 1's on the diagonal.  D is a diagonal scaling
matrix.  These correspond to "standard Regression usage" as

                X' X  = R' D R

A backsubsitution routine (in thetacov) allows to invert the R
matrix (the inverse is upper-right triangular, too!). Call this
matrix H, that is H=R^(-1).

	  (X' X)^(-1) = [(R' D^(1/2)') (D^(1/2) R)]^(-1)
	  = [ R^-1 D^(-1/2) ] [ R^-1 D^(-1/2) ]'



=head2 Remarks

This algorithm is the statistical "standard." Insertion of a new
observation can be done one obs at any time (WITH A WEIGHT!),
and still only takes a low quadratic time.  The storage space
requirement is of quadratic order (in the indep variables). A
practically infinite number of observations can easily be
processed!

=head1 AUTHOR

Naturally, Gentleman invented this algorithm.  Adaptation by ivo
welch. Alan Miller (alan@dmsmelb.mel.dms.CSIRO.AU) pointed out
nicer ways to compute the R^2.

=head1 Subroutines

=cut
################################################################


#### let's start with handling of missing data ("nan" or "NaN")

my $nan= "NaN";
sub isNaN { 
  if ($_[0] !~ /[0-9nan]/) { die "definitely not a number in NaN: '$_[0]'"; }
  return ($_[0]=~ /NaN/i) || ($_[0] != $_[0]);
}


################################################################

=pod

=head2 new

receives the number of variables on each observations (i.e., an integer) and
returns the blessed data structure.  Also takes an optional name for this
regression to remember, as well as a reference to a k*1 array of names for
the X coefficients.

=cut

################################################################
sub new {
  my $classname= shift(@_);
  my $K= shift(@_); # the number of variables
  my $regname= shift(@_) || "with no name";

  if (!defined($K)) { die "Regression->new needs at least one argument for the number of variables"; }
  if ($K<=1) { die "Cannot run a regression without at least two variables."; }

  sub zerovec {
    my @rv;
    for (my $i=0; $i<=$_[0]; ++$i) { $rv[$i]=0; } 
    return \@rv;
  }

  bless {
	 k => $K,
	 regname => $regname,
	 xnames => shift(@_),

	 # constantly updated
	 n => 0,
	 sse => 0,
	 syy => 0,
	 sy => 0,
	 wghtn => 0,
	 d => zerovec($K),
	 thetabar => zerovec($K),
	 rbarsize => ($K+1)*$K/2+1,
	 rbar => zerovec(($K+1)*$K/2+1),

	 # other constants
	 neverabort => 0,

	 # computed on demand
	 theta => undef,
	 sigmasq => undef,
	 rsq => undef,
	 adjrsq => undef
	}, $classname;
}

################################################################

=pod

=head2 dump

is used for debugging.

=cut

################################################################
sub dump {
  my $this= $_[0];
  print "****************************************************************\n";
  print "Regression '$this->{regname}'\n";
  print "****************************************************************\n";
  sub print1val {
    no strict;
    print "$_[1]($_[2])=\t". ((defined($_[0]->{ $_[2] }) ? $_[0]->{ $_[2] } : "intentionally undef"));

    my $ref=$_[0]->{ $_[2] };

    if (ref($ref) eq 'ARRAY') {
      my $arrayref= $ref;
      print " $#$arrayref+1 elements:\n";
      if ($#$arrayref>30) {
	print "\t";
	for(my $i=0; $i<$#$arrayref+1; ++$i) { print "$i='$arrayref->[$i]';"; }
	print "\n";
      }
      else {
	for(my $i=0; $i<$#$arrayref+1; ++$i) { print "\t$i=\t'$arrayref->[$i]'\n"; }
      }
    }
    elsif (ref($ref) eq 'HASH') {
      my $hashref= $ref;
      print " ".scalar(keys(%$hashref))." elements\n";
      while (my ($key, $val) = each(%$hashref)) {
	print "\t'$key'=>'$val';\n";
      }
    }
    else {
      print " [was scalar]\n"; }
  }

  while (my ($key, $val) = each(%$this)) {
    $this->print1val($key, $key);
  }
  print "****************************************************************\n";
}

################################################################
=pod

=head2 print

prints the estimated coefficients, and R^2 and N.

=cut
################################################################
sub print {
  my $this= $_[0];
  print "****************************************************************\n";
  print "Regression '$this->{regname}'\n";
  print "****************************************************************\n";

  my $theta= $this->theta();

  for (my $i=0; $i< $this->k(); ++$i) {
    print "Theta[$i".(defined($this->{xnames}->[$i]) ? "='$this->{xnames}->[$i]'":"")."]= ".sprintf("%12.4f", $theta->[$i])."\n";
  }
  print "R^2= ".sprintf("%.3f", $this->rsq()).", N= ".$this->n()."\n";
  print "****************************************************************\n";
}


################################################################
=pod

=head2 include

receives one new observation.  Call is

  $blessedregr->include( $yvariable, [ $x1, $x2, $x3 ... $xk ], 1.0 );

where 1.0 is an (optional) weight.  Note that inclusion with a
weight of -1 can be used to delete an observation.

The function returns the number of observations so far included.

=cut
################################################################
sub include {
  my $this = shift();
  my $yelement= shift();
  my $xrow= shift();
  my $weight= shift() || 1.0;

  # omit observations with missing observations;
  if (!defined($yelement)) { die "Internal Error: yelement is undef"; }
  if (isNaN($yelement)) { return $this->{n}; }

  my @xcopy;
  for (my $i=1; $i<=$this->{k}; ++$i) { 
    if (!defined($xrow->[$i-1])) { die "Internal Error: xrow [ $i-1 ] is undef"; }
    if (isNaN($xrow->[$i-1])) { return $this->{n}; }
    $xcopy[$i]= $xrow->[$i-1];
  }

  $this->{syy}+= ($weight*($yelement*$yelement));
  $this->{sy}+= ($weight*($yelement));
  if ($weight>=0.0) { ++$this->{n}; } else { --$this->{n}; }

  $this->{wghtn}+= $weight;

  for (my $i=1; $i<=$this->{k};++$i) {
    if ($weight==0.0) { return $this->{n}; }
    if (abs($xcopy[$i])>(TINY)) {
      my $xi=$xcopy[$i];

      my $di=$this->{d}->[$i];
      my $dprimei=$di+$weight*($xi*$xi);
      my $cbar= $di/$dprimei;
      my $sbar= $weight*$xi/$dprimei;
      $weight*=($cbar);
      $this->{d}->[$i]=$dprimei;
      my $nextr=int( (($i-1)*( (2.0*$this->{k}-$i))/2.0+1) );
      if (!($nextr<=$this->{rbarsize}) ) { die "Internal Error 2"; }
      my $xk;
      for (my $kc=$i+1;$kc<=$this->{k};++$kc) {
	$xk=$xcopy[$kc]; $xcopy[$kc]=$xk-$xi*$this->{rbar}->[$nextr];
	$this->{rbar}->[$nextr]= $cbar * $this->{rbar}->[$nextr]+$sbar*$xk;
	++$nextr;
      }
      $xk=$yelement; $yelement-= $xi*$this->{thetabar}->[$i];
      $this->{thetabar}->[$i]= $cbar*$this->{thetabar}->[$i]+$sbar*$xk;
    }
  }
  $this->{sse}+=$weight*($yelement*$yelement);

  # indicate that Theta is garbage now
  $this->{theta}= undef;
  $this->{sigmasq}= undef; $this->{rsq}= undef; $this->{adjrsq}= undef;

  return $this->{n};
}



################################################################

=pod

=head2 theta

estimates and returns the vector of coefficients.

=cut
################################################################

sub theta {
  my $this= shift();

  if (defined($this->{theta})) { return $this->{theta}; }

  if ($this->{n} < $this->{k}) { return undef; }
  for (my $i=($this->{k}); $i>=1; --$i) {
    $this->{theta}->[$i]= $this->{thetabar}->[$i];
    my $nextr= int (($i-1)*((2.0*$this->{k}-$i))/2.0+1);
    if (!($nextr<=$this->{rbarsize})) { die "Internal Error 3"; }
    for (my $kc=$i+1;$kc<=$this->{k};++$kc) {
      $this->{theta}->[$i]-=($this->{rbar}->[$nextr]*$this->{theta}->[$kc]);
      ++$nextr;
    }
  }

  my $ref= $this->{theta}; shift(@$ref); # we are counting from 0

  # if in a scalar context, otherwise please return the array directly
  return $this->{theta};
}

################################################################
=pod

=head2 rsq, adjrsq, sigmasq, ybar, sst, k, n

These functions provide common auxiliary information.  rsq, adjrsq,
sigmasq, sst, and ybar have not been checked but are likely correct.
The results are stored for later usage, although this is somewhat
unnecessary because the computation is so simple anyway.

=cut

################################################################

sub rsq {
  my $this= shift();
  return $this->{rsq}= 1.0- $this->{sse} / $this->sst();
}

sub adjrsq {
  my $this= shift();
  return $this->{adjrsq}= 1.0- (1.0- $this->rsq())*($this->{n}-1)/($this->{n} - $this->{k});
}

sub sigmasq {
  my $this= shift();
  return $this->{sigmasq}= ($this->{n}<=$this->{k}) ? "Inf" : ($this->{sse}/($this->{n} - $this->{k}));
}

sub ybar {
  my $this= shift();
  return $this->{ybar}= $this->{sy}/$this->{wghtn};
}

sub sst {
  my $this= shift();
  return $this->{sst}= ($this->{syy} - $this->{wghtn}*($this->ybar())**2);
}

sub k {
  my $this= shift();
  return $this->{k};
}
sub n {
  my $this= shift();
  return $this->{n};
}


################################################################
=pod

=head1 DEBUGGING = SAMPLE USAGE CODE

The sample code included with this package demonstrates regression usage.
To execute it, just set the constant DEBUGGING at the script head to 1, and
do

  perl Regression.pm

The printout should be

  ****************************************************************
  Regression 'sample regression'
  ****************************************************************
  Theta[0='const']=       0.2950
  Theta[1='someX']=       0.6723
  Theta[2='someY']=       1.0688
  R^2= 0.808, N= 4
  ****************************************************************

=cut
################################################################

if (DEBUGGING) {
  package main;

  my $reg= Statistics::Regression->new( 3, "sample regression", [ "const", "someX", "someY" ] );
  $reg->include( 2.0, [ 1.0, 3.0, -1.0 ] );
  $reg->include( 1.0, [ 1.0, 5.0, 2.0 ] );
  $reg->include( 20.0, [ 1.0, 31.0, 0.0 ] );
  $reg->include( 15.0, [ 1.0, 11.0, 2.0 ] );
  
#  $reg->print();   or: my $coefs= $reg->theta(); print @coefs; print $reg->rsq;
# my $coefs= $reg->theta(); print $coeff[0];
}

################################################################
=pod

=head1 BUGS/PROBLEMS

=over 4

=item Missing

This package lacks routines to compute the standard errors of
the coefficients.  This requires access to a matrix inversion
package, and I do not have one at my disposal.  If you want to
add one, please let me know.

=item Perl Problem

perl is unaware of IEEE number representations.  This makes it a
pain to test whether an observation contains any missing
variables (coded as 'NaN' in Regression.pm).

=item Others

I am a novice perl programmer, so this is probably ugly code.  However, it
does seem to work, and I could not find anything equivalent on cpan.

=back

=head1 INSTALLATION and DOCUMENTATION

Installation consists of moving the file 'Regression.pm' into a subdirectory
Statistics of your modules path (e.g., /usr/lib/perl5/site_perl/5.6.0/). 

The documentation was produced from the module:

pod2html -noindex -title "perl weighted least squares regression package" Regression.pm > Regression.html

The documentation was slightly modified by Maria Voloshina, University of Rochester.

=head1 LICENSE

This module is released for free public use under a GPL license.

(C) Ivo Welch, 2001.

=cut

################################################################
1;
