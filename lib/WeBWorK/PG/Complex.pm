BEGIN {
	be_strict(); # an alias for use strict.  This means that all global variable must contain main:: as a prefix.
    
}
*i = *Complex1::i;
package Complex;

@Complex::ISA=qw(Complex1);


1;