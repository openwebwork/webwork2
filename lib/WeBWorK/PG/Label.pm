=head1 NAME

	Label


=head1 SYNPOSIS

	use Carp;
	use GD;
	use WWPlot;
	use Fun;


=head1 DESCRIPTION

This module defines labels for the graph objects (WWPlot).


=head2 Usage

	$label1 = new Label($x_value, $y_value, $label_string, $label_color, @justification)
	$justification   =   one of ('left', 'center', 'right) and ('bottom', 'center', 'top')
	                     describes the position of the ($x_value, $y_value) within the string.
	                     The default is 'left', 'top'



=head2  Example

	$new_label = new Label ( 0,0, 'origin','red','left', 'top')
	@labels    = $graph->lb($new_label);



=cut


BEGIN {
	be_strict(); # an alias for use strict.  This means that all global variable must contain main:: as a prefix.
}
package Label;
use strict;
#use Exporter;
#use DynaLoader;
#use GD;   # this is needed to be able to define GD::gdMediumBoldFont and other terms used by GD
#          # however  constants from GD need to be addressed fully, they have not been imported.
#use  "WWPlot.pm";
#Because of the way problem modules are loaded 'use' is disabled.


@Label::ISA = qw(WWPlot);

my %fields =(
		'x'		=>	0,  
		'y'		=>	0,
		color	=>  'black',
		font	=>	GD::gdMediumBoldFont,    #gdLargeFont
		# constants from GD need to be addressed fully, they have not been imported.
		str		=>	"",
		lr_nudge => 0, #justification parameters
		tb_nudge =>	0,
);


sub new {
	my $class 				=	shift;
	my $self 			= { 
				_permitted	=>	\%fields,
				%fields,
	};
	
	bless $self, $class;
	$self->_initialize(@_);
	return $self;
}

sub _initialize {
	my $self 				=	shift;
	my ($x,$y,$str,$color,@justification)	=   @_;
	$self -> x($x);
	$self -> y($y);
	$self -> str($str);
	$self -> color($color) if defined($color);
	my $j;
	foreach $j (@justification)  {
		$self->lr_nudge( - length($self->str) ) 	if $j eq 'right';
		$self->tb_nudge( - 1 			      )		if $j eq 'bottom';
		$self->lr_nudge( - ( length($self->str) )/2)if $j eq 'center';
		$self->tb_nudge(-0.5)                   	if $j eq 'middle';
#		print "\njustification=$j",$self->lr_nudge,$self->tb_nudge,"\n";
	}
}
sub draw {
	my $self = shift;
	my $g = shift;   #the containing graph
  	$g->im->string( $self->font,
  					$g->ii($self->x)+int( $self->lr_nudge*($self->font->width) ),
  					$g->jj($self->y)+int( $self->tb_nudge*($self->font->height) ),
  					$self->str,
  					${$g->colors}{$self->color}
  				);
 
}

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) || die "$self is not an object";
	my $name = $Label::AUTOLOAD;
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

1;

		
	
