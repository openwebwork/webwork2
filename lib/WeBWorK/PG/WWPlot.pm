#!/usr/math/bin/perl -w
#  this module holds the graph.  Several functions 
#  and labels may be plotted on
#  the graph.

# constructor   new WWPlot(300,400) constructs an image of width 300 by height 400 pixels
# plot->imageName gives the image's name


=head1 NAME

	WWPlot

=head1 SYNPOSIS

    use Global;
	use Carp;
	use GD;
	
	$graph = new WWPlot(400,400); # creates a graph 400 pixels by 400 pixels
	$graph->fn($fun1, $fun2);     # installs functions $fun1 and $fun2 in $graph
	$image_binary = $graph->draw();  # creates the gif/png image of the functions installed in the graph

=head1 DESCRIPTION

This module creates a graph object -- a canvas on which to draw functions, labels, and other symbols.
The graph can be drawn with an axis, with a grid, and/or with an axis with tick marks.  
The position of the axes and the granularity of the grid and tick marks can be specified.

=head2 new

	$graph = new WWPlot(400,400);

Creates a graph object 400 pixels by 400 pixels.  The size is required.




=head2 Methods and properties

=over 4

=item xmin, xmax, ymin, ymax

These determine the world co-ordinates of the graph. The constructions

	$new_xmin = $graph->xmin($new_xmin);
and
	$current_xmin = $graph->xmin();

set and read the values. 

=item fn, lb, stamps

These arrays contain references to the functions (fn), the labels (lb) and the stamped images (stamps) such
as open or closed circles which will drawn when the graph is asked to draw itself. Since each of these
objects is expected to draw itself, there is not a strong difference between the different arrays of objects.
The principle difference is the order in which they are drawn.  The axis and grids are drawn first, followed
by the functions, then the labels, then the stamps.

You can add a function with either of the commands

	@fn = $graph->fn($new_fun_ref1, $new_fun_ref2);
	@fn = $graph->install($new_fun_ref1, $new_fun_ref2);

the constructions for labels and stamps are respectively:

	@labels = $graph->lb($new_label);
	@stamps = $graph->stamps($new_stamp);

while 
	
	@functions = $graph->fn();

will give a list of the current functions (similary for labels and stamps).

Either of the  commands

	$graph->fn('reset'); 
	$graph->fn('erase');

will erase the array containing the functions and similary for the label and stamps arrays.	


=item h_axis, v_axis

	$h_axis_coordinate = $graph -> h_axis();
	$new_axis    =       $grpah -> h_axis($new_axis);

Respectively read and set the vertical coordinate value in real world coordinates where the
horizontal axis intersects the vertical one.  The same construction reads and sets the coordinate 
value for the vertical axis. The axis is drawn more darkly than the grids.

=item h_ticks, v_ticks

	@h_ticks = $graph -> h_ticks();
	@h_ticks = $graph -> h_ticks( $tick1, $tick2, $tick3, $tick4   );

reads and sets the coordinates for the tick marks along the horizontal axis.  The values
$tick1, etc are the real world coordinate values for each of the tick marks.

=item h_grid, v_grid

	@h_grid = $graph -> h_grid();
	@h_grid = $graph -> h_grid( $grid1, $grid2, $grid3, $grid4   );

reads and sets the verical coordinates for the horizontal grid lines.  The values
$grid1, etc are the real world coordinate values where the horizontal grid meets the
vertical axis.

=item draw

	$image = $graph ->draw();
	
Draws the  image of the graph.

=item size

	($horizontal_pixels, $vertical_pixels) = $graph ->size();

Reads the size of the graph image in pixels.  This cannot be reset. It is defined by
the new constructor and cannot be changed.

=item colors

	%colors =$graph->colors();

Returns the hash containing the colors known to the graph.  The keys are the names of the
colors and the values are the color indices used by the graph.

=item new_color

	$graph->new_color('white', 255,255,255);

defines a new color named white with red, green and blue densities 255.

=item im

	$GD_image = $graph->im();

Allows access to the GD image object contained in the graph object.  You can use this
to access methods defined in GD but not supported directly by WWPlot. (See the documentation
for GD.)

=item moveTo, lineTo

	$graph->moveTo($x,$y);
	$graph->lineTo($x,$y,$color);

Moves to the point ($x, $y) (defined in real world coordinates) or draws a line from the
current position to the specified point ($x, $y) using the color $color.  $color is the
name, e.g. 'white',  of the color, not an index value or RGB specification.  These are 
low level call back routines used by the function, label and stamp objects to draw themselves.


=item ii, jj

These functions translate from real world to pixel coordinates.

	$pixels_down_from_top = $graph -> jj($y);


=back

=cut

BEGIN {
	be_strict(); # an alias for use strict.  This means that all global variable must contain main:: as a prefix.
    
}
package WWPlot;


#use Exporter;
#use DynaLoader;
#use GD;

@WWPlot::ISA=undef;
$WWPlot::AUTOLOAD = undef;

@WWPlot::ISA = qw(GD);


if ( $GD::VERSION > '1.20' ) {
    	$WWPlot::use_png = 1;  # in version 1.20 and later of GD, gif's are not supported by png files are
    	                       # This only affects the draw method.
} else {
    	$WWPlot::use_png = 0;
}

my	$last_image_number=0;    #class variable.  Keeps track of how many images have been made.



my %fields = (  # initialization only!!!
	xmin   		=>  -1,
	xmax   		=>  1,
	ymin   		=>  -1,
	ymax   		=>  1,
	imageName		=>	undef,
	position	=>  undef,  #used internally in the draw routine lineTo	
);



sub new {
	my $class =shift;
	my @size = @_;   # the dimensions in pixels of the image
	my $self = { im 		=> 	new GD::Image(@size),
				'_permitted'	=>	\%fields,
				%fields,
				size		=>	[@size],
				fn			=>	[],
				fillRegion      =>      [],
				lb			=>	[],
				stamps		=>	[],
				colors 		=>	{},
				hticks		=>  [],
				vticks      =>  [],
				hgrid		=>	[],
				vgrid		=>	[],
				haxis       =>  [],
				vaxis       =>  [],
				

	};
	
	bless $self, $class;
	$self ->	_initialize;
	return $self;
}

# access methods for function list, label list and image
sub fn {
	my $self =	shift;
	
	if (@_ == 0) {
		# do nothing if input is empty
	} elsif ($_[0] eq 'reset' or $_[0] eq 'erase' ) {
		$self->{fn} = [];
	} else {
		push(@{$self->{fn}},@_) if @_;
	}
	@{$self->{fn}};
}
# access methods for fillRegion list, label list and image
sub fillRegion {
	my $self =	shift;
	
	if (@_ == 0) {
		# do nothing if input is empty
	} elsif ($_[0] eq 'reset' or $_[0] eq 'erase' ) {
		$self->{fillRegion} = [];
	} else {
		push(@{$self->{fillRegion}},@_) if @_;
	}
	@{$self->{fillRegion}};
}

sub install {  # synonym for  installing a function
	fn(@_);
}

sub lb {
	my $self =	shift;
	if (@_ == 0) {
		# do nothing if input is empty
	} elsif ($_[0] eq 'reset' or $_[0] eq 'erase' ) {
		$self->{lb} = [];
	} else {
		push(@{$self->{lb}},@_) if @_;
	}

	@{$self->{lb}};
}

sub stamps {
	my $self =	shift;
	if (@_ == 0) {
		# do nothing if input is empty
	} elsif ($_[0] eq 'reset' or $_[0] eq 'erase' ) {
		$self->{stamps} = [];
	} else {
		push(@{$self->{stamps}},@_) if @_;
	}
	
	@{$self->{stamps}};
}
sub colors {
	my $self = shift;
	$self -> {colors} ;
}

sub new_color {
	my $self = shift;
	my ($color,$r,$g,$b) = @_;
	$self->{'colors'}{$color} 	= 	$self->im->colorAllocate($r, $g, $b);
}
sub im {
	my $self = shift;
	$self->{im};
}
sub gifName {              # This is yields backwards compatibility.
    my $self = shift;
	$self->imageName(@_);
}
sub pngName {              # It is better to use the method imageName.
    my $self = shift;
	$self->imageName(@_);
}
sub size {
	my $self = shift;
	$self ->{size};
}

sub	_initialize {
	my $self 			= shift;
	    $self->{position}    = [0,0];
#	$self->{width}      = $self->{'size'}[0];    # original height and width tags match pixel dimensions
#	$self->{height}     = $self->{'size'}[1];    # of the image
	# allocate some colors
	    $self->{'colors'}{'background_color'} 	= 	$self->im->colorAllocate(255,255,255);
	    $self->{'colors'}{'default_color'} 	= 	$self->im->colorAllocate(0,0,0);
	    $self->{'colors'}{'white'} 	= 	$self->im->colorAllocate(255,255,255);
	    $self->{'colors'}{'black'} 	= 	$self->im->colorAllocate(0,0,0);
	    $self->{'colors'}{'red'} 	= 	$self->im->colorAllocate(255,0,0);      
	    $self->{'colors'}{'green'}	= 	$self->im->colorAllocate(0,255,0);
	    $self->{'colors'}{'blue'} 	= 	$self->im->colorAllocate(0,0,255);
	    $self->{'colors'}{'yellow'}	=	$self->im->colorAllocate(255,255,0);
	    $self->{'colors'}{'orange'}	=	$self->im->colorAllocate(255,100,0);
	    $self->{'colors'}{'gray'}	=	$self->im->colorAllocate(180,180,180);
	    $self->{'colors'}{'nearwhite'}	=	$self->im->colorAllocate(254,254,254);
   # obtain a new imageNumber;
       $self->{imageNumber} = ++$last_image_number;
}

# reference shapes
# closed circle
# open circle
    
#	The translation subroutines.

sub ii {
	my $self = shift;
	my $x = shift;
	return undef unless defined($x);
	my $xmax = $self-> xmax ;
	my $xmin = $self-> xmin ;
 	int( ($x - $xmin)*(@{$self->size}[0]) / ($xmax - $xmin) );
}

sub jj {
	my $self = shift;
	my $y = shift;
	return undef unless defined($y);
	my $ymax = $self->ymax; 
	my $ymin = $self->ymin;
	#print "ymax=$ymax y=$y ymin=$ymin size=",${$self->size}[1],"<BR><BR><BR><BR>";
	int( ($ymax - $y)*${$self->size}[1]/($ymax-$ymin) );
}

#  The move and draw subroutines.  Arguments are in real world coordinates.

sub lineTo {
	my $self = shift;
	my ($x,$y,$color) = @_;
	$x=$self->ii($x);
	$y=$self->jj($y);
	$color = $self->{'colors'}{$color} if $color=~/[A-Za-z]+/ && defined($self->{'colors'}{$color}) ; # colors referenced by name works here.
	$color = $self->{'colors'}{'default_color'} unless defined($color);
	$self->im->line(@{$self->position},$x,$y,$color);
	 #warn "color is $color";
	@{$self->position} = ($x,$y);
}

sub moveTo {
	my $self = shift;
	my $x=shift;
	my $y=shift;
	$x=$self->ii($x);
	$y=$self->jj($y);
	#print "moving to $x,$y<BR>";
	@{$self->position} = ( $x,$y );
}

sub v_axis {
	my $self = shift;
	@{$self->{vaxis}}=@_; # y_value, color
}
sub h_axis {
	my $self = shift;
	@{$self->{haxis}}=@_; # x_value, color
}
sub h_ticks {
	my $self = shift;
	my $nudge =2;
	push(@{$self->{hticks}},$nudge,@_); # y-value, color, tick x-values.  see save_image subroutine

}
sub v_ticks {
	my $self = shift;
	my $nudge =2;
	push(@{$self->{vticks}},$nudge,@_); # x-value, color, tick y-values.  see save_image subroutine

}
sub h_grid {
	my $self = shift;
	push(@{$self->{hgrid}}, @_ ); #color,  grid y values
}
sub v_grid {
	my $self = shift;
	push(@{$self->{vgrid}},@_ );  #color, grid x values
}
 


sub draw {
		my $self = shift;
		my $im =$self->{'im'};
		my @size = @{$self->size};
		my %colors =%{$self->colors};
		
# make the background transparent and interlaced
#    	$im->transparent($colors{'white'});
	    $im->interlaced('true');
	
	    # Put a black frame around the picture
	    $im->rectangle(0,0,$size[0]-1,$size[1]-1,$colors{'black'});
 	    
	    # draw functions
	    
 	     	foreach my $f ($self->fn) {
 			#$self->draw_function($f);
 			$f->draw($self);  # the graph is passed to the function so that the label can call back as needed.
 		}
	   # and fill the regions
		foreach my $r ($self->fillRegion) {
			my ($x,$y,$color_name) = @{$r};
			my $color = ${$self->colors}{$color_name};
			$self->im->fill($self->ii($x),$self->jj($y),$color);
		}
	    
 		#draw hticks
 		my $tk;
 		my @ticks = @{$self->{hticks}};
 		if (@ticks) {
	 		my $nudge = shift(@ticks);
	 		my $j     = $self->jj(shift(@ticks));
	 		my $tk_clr= $self->{'colors'}{shift(@ticks)};
 		
	 		foreach $tk (@ticks) {
	 			$tk = $self->ii($tk);
	 			# print "tk=$tk\n";
	 			$self->im->line($tk,$j+int($nudge),$tk,$j-int($nudge),$tk_clr);
	 		}
	 	}
 		#draw vticks
 		@ticks = @{$self->{vticks}};
 		if (@ticks) {
	 		my $nudge = shift(@ticks);
	 		my $i     = $self->ii(shift(@ticks));
	 		my $tk_clr= $self->{'colors'}{shift(@ticks)};
	 		
	 		foreach $tk (@ticks) {
	 			$tk = $self->jj($tk);
	 			# print "tk=$tk\n";
	 			$self->im->line($i+int($nudge),$tk,$i-int($nudge),$tk,$tk_clr);
	 		}
	 	}
 		#draw vgrid
 		
 		my @grid = @{$self->{vgrid}};
 		if (@grid)  {
	 		my $x_value;
	 		my $grid_clr= $self->{'colors'}{shift(@grid)};
	 		
	 		foreach $x_value (@grid) {
	 			$x_value = $self->ii($x_value); # scale
	 			#print "grid_line=$grid_line\n";
	 			$self->im->dashedLine($x_value,0,$x_value,$self->{'size'}[1],$grid_clr);
	 		}
	 	}
 		#draw hgrid
 		@grid = @{$self->{hgrid}};
 		if (@grid) {
	 		my $grid_clr= $self->{'colors'}{shift(@grid)};
	        my $y_value;
	 		foreach $y_value (@grid) {
	 			$y_value = $self->jj($y_value);
	 			#print "y_value=$y_value\n";
	 			#print "width= $self->{width}\n";
	 			$self->im->dashedLine(0,$y_value,$self->{'size'}[0],$y_value,$grid_clr);
	 		}
 		}
 		# draw axes
 		if (defined ${$self->{vaxis}}[0]) {
 			my ($x, $color_name) = @{$self->{vaxis}};
			my $color = ${$self->colors}{$color_name};
			$self->moveTo($x,$self->ymin);
			$self->lineTo($x,$self->ymax,$color);
			#print "draw vaxis", @{$self->{vaxis}},"\n";
			#$self->im->line(0,0,300,300,$color);
	 	}
	 	if (defined $self->{haxis}[0]) {
			my ($y, $color_name) = @{$self->{haxis}};
			my $color = ${$self->colors}{$color_name};
			$self->moveTo($self->xmin,$y);
			$self->lineTo($self->xmax,$y,$color);
	 	    #print "draw haxis", @{$self->{haxis}},"\n";
		}
		# draw functions again
	    
 		foreach my $f ($self->fn) {
 			#$self->draw_function($f);
 			$f->draw($self);  # the graph is passed to the function so that the label can call back as needed.
 		}
		

 		#draw labels
 		my $lb;
 		foreach $lb ($self->lb) {
 			$lb->draw($self);  # the graph is passed to the label so that the label can call back as needed.
 		}
 		#draw stamps
 		my $stamp;
 		foreach $stamp ($self->stamps) {
 			$stamp->draw($self); # the graph is passed to the label so that the label can call back as needed.
 		}
        my $out;
        if ($WWPlot::use_png) {
        	$out = $im->png;
        } else {
        	$out = $im->gif;
        }
        $out;
		
}



sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) || die "$self is not an object";
	my $name = $WWPlot::AUTOLOAD;
	$name =~ s/.*://;  # strip fully-qualified portion
 	unless (exists $self->{'_permitted'}->{$name} ) {
 		die "Can't find '$name' field in object of class $type";
 	}
	if (@_) {
		return $self->{$name} = shift;
	} else {
		return $self->{$name};
	}

}


sub DESTROY {
	# doing nothing about destruction, hope that isn't dangerous
}	

sub save_image {
		my $self = shift;
	warn "The method save_image is no longer supported. Use insertGraph(\$graph)";
	"The method save_image is no longer supported. Use insertGraph(\$graph)";		
}
 

1;
