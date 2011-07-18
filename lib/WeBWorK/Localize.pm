package WeBWorK::Localize;

use Locale::Maketext 1.01;
use base ('Locale::Maketext');


# this is like [quant] but it doesn't write the number
#  usage: [quant,_1,<singular>,<plural>,<optional zero>]

sub plural {
    my($handle, $num, @forms) = @_;

    return "" if @forms == 0;  
    return $forms[2] if @forms > 2 and $num == 0; 

    # Normal case:
    return(  $handle->numerate($num, @forms) );
}

# this is like [quant] but it also has -1 case 
#  usage: [negquant,_1,<neg case>,<singular>,<plural>,<optional zero>]

sub negquant {
    my($handle, $num, @forms) = @_;

    return $num if @forms == 0;

    my $negcase = shift @forms;
    return $negcase if $num < 0;

    return $forms[2] if @forms > 2 and $num == 0; 
    return( $handle->numf($num) . ' ' . $handle->numerate($num, @forms) );
}



%Lexicon = (
	'_AUTO' => 1,
	'_REQUEST_ERROR' => q{
WeBWorK has encountered a software error while attempting to process this
problem. It is likely that there is an error in the problem itself. If you are a
student, report this error message to your professor to have it corrected. If
you are a professor, please consult the error output below for more information.
},
	);

1;
