package WebworkSOAP::Classes::Permission;

=pod
=begin WSDL
        _ATTR user_id       $string
        _ATTR permission    $integer
=end WSDL
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{user_id} = $data->user_id;
    $self->{permission} = $data->permission;
    bless $self;
    return $self;
}


1;
