## This is a number of common subroutines needed when processing the routes.  


package Routes;
use base qw(Exporter);
our @EXPORT    = ();
our @EXPORT_OK = qw(convertObjectToHash convertArrayOfObjectsToHash);


##  This converts an array of objects to an array of Hashes

sub convertArrayOfObjectsToHash {
    my $arr = shift;

    
    my @newArray = ();
    foreach my $element (@{$arr}){
        my $s = {};
        for my $key (keys %{$element}){
            $s->{$key} = $element->{$key};
        }
        push(@newArray,$s);
    }

    return \@newArray; 

}

sub convertObjectToHash {
    my $obj = shift;
    my $s = {};
    for my $key (keys %{$obj}){
        $s->{$key} = $obj->{$key};
    }
    
    return $s;
}

return 1;