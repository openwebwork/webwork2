## This is a number of common subroutines needed when processing the routes.  


package Utils::Convert;
use base qw(Exporter);
use JSON;
our @EXPORT    = ();
our @EXPORT_OK = qw(convertObjectToHash convertArrayOfObjectsToHash);


##  This converts an array of objects to an array of Hashes
## the parameter $boolean_props is an array reference of properties that are boolean.
## these will be converted to true/false (in the JSON sense).

sub convertArrayOfObjectsToHash {
    my ($arr,$boolean_props) = @_;

    my @newArray = map { convertObjectToHash($_,$boolean_props) } @{$arr};

    return \@newArray;  
}

sub convertObjectToHash {
    my ($obj,$boolean_props) = @_;
    my $s = {};

    $boolean_props = [] unless defined($boolean_props);


    for my $key (keys %{$obj}){
        if(grep(/^$key$/,@{$boolean_props})){
            $s->{$key} = $obj->{$key} ? JSON::true : JSON::false;    
        } else {
            $s->{$key} = $obj->{$key};
        }
    }
    
    return $s;
}

return 1;