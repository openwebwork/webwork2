#!/usr/math/bin/perl -wx

#  Fun.pm
# methods:
# 	new Fun($rule,$graphRef)
# 		If $rule is a subroutine then a function object is created, 
#        with default data. If the graphRef is present the function is
#       installed into the
#		graph and the domain is reset to the graphRef's domain. 		
# 		If the $rule is another function object then a copy of that function is 
# 		made with all of its data  and it is installed in the graphRef if that is present.
#		In this case the domain of the function is not affected by the domain of the graphRef.
# 	initial data
# 		@domain = ($tstart, $tstop)   the domain of the function     	-- initially (-1,1)
# 		steps						  the number of steps in drawing 	-- initially 20
# 		color						  the pen color to draw with		-- initially 'red'
#		weight						  the width of the pen in pixels	--	initially 2
# 		rule						  reference to a subroutine
# 									  	which calculates the function	-- initially null
# 		graph						  reference to the enclosing graph  -- initially $ref or else null

# What will the domain of new Fun($rule, $graphRef) be?
#			It will be the same as $rule if $rule is actually another function object
#					ELSE	   	the same as the domain of $graphRef if that is present
#					ELSE		the interval (-1,1)
# 	public access methods:    
# 		domain
# 		steps
# 		color
# 		rule
#		weight
;

=head1 NAME

	Fun

=head1 SYNPOSIS

	use Carp;
	use GD;
	use WWPlot;
	use Fun;
	$fn = new Fun( rule_reference);
	$fn = new Fun( rule_reference , graph_reference);
	$fn = new Fun ( x_rule_ref, y_rule_ref );
	$fn = new Fun ( x_rule_ref, y_rule_ref, graph_ref );

=head1 DESCRIPTION

This module defines a parametric or non-parametric function object.  The function object is designed to
be inserted into a graph object defined by WWPlot.  

The following functions are provided:



=head2	new  (non-parametric version)

=over 4	

=item	$fn = new Fun( rule_reference);

rule_reference is a reference to a subroutine which accepts a numerical value and returns a numerical value.
The Fun object will draw the graph associated with this subroutine.  
For example: $rule = sub { my $x= shift; $x**2};  will produce a plot of the x squared.
The new method returns a reference to the function object.

=item	$fn = new Fun( rule_reference , graph_reference);

The function is also placed into the printing queue of the graph object pointed to by graph_reference and the 
domain of the function object is set to the domain of the graph.

=back

=head2 	new  (parametric version)	

=over 4	

=item	$fn = new Fun ( x_rule_ref, y_rule_ref );

A parametric function object is created where the subroutines refered to by x_rule_ref and y_rule_ref define
the x and y outputs in terms of the input t.  

=item	$fn = new Fun ( x_rule_ref, y_rule_ref, graph_ref );

This variant inserts the parametric function object into the graph object referred to by graph_ref.  The domain
of the function object is not adjusted.  The domain's default value is (-1, 1).

=back

=head2 Properites

	All of the properties are set using the construction $new_value = $fn->property($new_value) 
	and read using $current_value = $fn->property()

=over 4	

=item tstart, tstop, steps

The domain of the function is (tstart, tstop).  steps is the number of subintervals
used in graphing the function.

=item color

The color used to draw the function is specified by a word such as 'orange' or 'yellow'. 
C<$fn->color('blue')> sets the drawing color to blue.  The RGB values for the color are defined in the graph
object in which the function is drawn.  If the color, e.g. 'mauve', is not defined by the graph object
then the function is drawn using the color 'default_color' which is always defined (and usually black).

=item x_rule

A reference to the subroutine used to calculate the x value of the graph.  This is set to the identity function (x = t )
when using the function object in non-parametric mode.

=item y_rule

A reference to the subroutine used to calculate the y value of the graph.

=item weight

The width in pixels of the pen used to draw the graph. The pen is square.

=back

=head2 Actions which affect more than one property.

=over 4

=item rule 

This defines a non-parametric function. 

	$fn->rule(sub {my $x =shift; $x**2;} ) 
	
	is equivalent to
	
	$fn->x_rule(sub {my $x = shift; $x;});
	$fn->y_rule(sub {my $x = shift; $x**2;);
	
	$fn->rule() returns the reference to the y_rule.

=item domain

$array_ref = $fn->domain(-1,1) sets tstart to -1 and tstop to 1 and 
returns a reference to an array containing this pair of numbers.


=item draw

$fn->draw($graph_ref) draws the function in the graph object pointed to by $graph_ref. If one of
the points bounding a subinterval is undefined then that segment is not drawn.  This usually does the "right thing" for
functions which have simple singularities.

The graph object must
respond to the methods below.  The draw call is mainly for internal use by the graph object. Most users will not
call it directly.

=over 4	

=item   $graph_ref->{colors} 

a hash containing the defined colors

=item $graph_ref ->im       

a GD image object

=item $graph_ref->lineTo(x,y, color_number)

draw line to the point (x,y) from the current position using the specified color.  To obtain the color number
use a construction such as C<$color_number = $graph_ref->{colors}{'blue'};>

=item $graph_ref->lineTo(x,y,gdBrushed)

draw line to the point (x,y) using the pattern set by SetBrushed (see GD documentation)

=item $graph_ref->moveTo(x,y)

set the current position to (x,y)

=back    

=back

=cut

BEGIN {
	be_strict(); # an alias for use strict.  This means that all global variable must contain main:: as a prefix.
}

package Fun;


#use "WWPlot.pm";
#Because of the way problem modules are loaded 'use' is disabled.





@Fun::ISA = qw(WWPlot);
# import gdBrushed from GD.  It unclear why, but a good many global methods haven't been imported.
sub gdBrushed {
	&GD::gdBrushed();
}

my $GRAPH_REFERENCE = "WWPlot";   
my $FUNCTION_REFERENCE = "Fun";

my %fields =(
		tstart		=>	-1,  # (tstart,$tstop) constitutes the domain
		tstop		=>	1,
		steps  		=>  50,
		color		=>  'blue',
		x_rule      => \&identity,
		y_rule      => \&identity,
		weight		=>	2,  # line thickness
);


sub new {
	my $class 				=	shift;
#	my ($rule,$graphRef)	=   @_;

	my $self 			= { 
				_permitted	=>	\%fields,
				%fields,
	};
	
	bless $self, $class;
	$self -> _initialize(@_);
	return $self;
}

sub identity {  # the identity function
	shift;
}
sub rule  { # non-parametric functions are defined using rule; use x_rule and y_rule to define parametric functions
	my $self = shift;
	my $rule = shift;
	my $out;
	if ( defined($rule)  ){
		$self->x_rule (\&identity);
		$self->y_rule($rule);
		$out = $self->y_rule;
	} else {
		$out = $self->y_rule
	}
	$out;
}

sub _initialize {     
	my	$self 	= 	shift;
	my  ($xrule,$yrule, $rule,$graphRef);
	my @input = @_;
	if (ref($input[$#input]) eq $GRAPH_REFERENCE ) {
		$graphRef = pop @input;  # get the last argument if it refers to a graph.  
		$graphRef->fn($self);     # Install this function in the graph.
	} 
  
    if ( @input == 1 ) {                 # only one argument left -- this is a non parametric function
        $rule = $input[0];
		if ( ref($rule) eq $FUNCTION_REFERENCE ) {  # clone another function
			my $k;
			foreach $k (keys %fields) {
				$self->{$k} = $rule->{$k};
			}
		} else {
			$self->rule($rule);                     
			if (ref($graphRef) eq $GRAPH_REFERENCE) { # use graph to initialize domain
				$self->domain($graphRef->xmin,$graphRef->xmax);
			}
		}
	} elsif (@input == 2 ) {   #  two arguments -- parametric functions
			$self->x_rule($input[0]);
			$self->y_rule($input[1]);
		
	} else {
		wwerror("$0:Fun.pm:_initialize:", "Can't call function with more than two arguments", "");
	}
	
}

sub draw {
    my $self = shift;  # this function 
	my $g = shift;   # the graph containing the function.
	my $color;   # get color scheme from graph
	if ( defined( $g->{'colors'}{$self->color} )  ) {
		$color = $g->{'colors'}{$self->color}; 
	} else {
		$color = $g->{'colors'}{'default_color'};  # what you do if the color isn't there
	}
	my $brush = new GD::Image($self->weight,$self->weight);
	my $brush_color = $brush->colorAllocate($g->im->rgb($color));  # transfer color
	$g->im->setBrush($brush);
 	my $stepsize = ( $self->tstop - $self->tstart )/$self->steps;
  	
    my ($t,$x,$i,$y);
    my $x_prev = undef;
    my $y_prev = undef;	
    foreach $i (0..$self->steps) {
    		$t=$stepsize*$i + $self->tstart;
    		$x=&{$self->x_rule}( $t );;
    		$y=&{$self->y_rule}( $t );
    		if (defined($x) && defined($x_prev) && defined($y) && defined($y_prev) ) {
    			$g->lineTo($x, $y, gdBrushed);
    		} else {
    			$g->moveTo($x, $y) if defined($x) && defined($y);
    		}
    		$x_prev = $x;
    		$y_prev = $y;
		}
}

sub domain {
	my $self =shift;
	my $tstart = shift;
	my $tstop  = shift;
	if (defined($tstart) && defined($tstop) ) {
		$self->tstart($tstart);
		$self->tstop($tstop);
	}
		[$self->tstart,$self->tstop];	
}


sub DESTROY {
	# doing nothing about destruction, hope that isn't dangerous
}

1;
