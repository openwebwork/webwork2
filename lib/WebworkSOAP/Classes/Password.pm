package WebworkSOAP::Classes::Password;

=pod
=begin WSDL
        _ATTR user_id       $string user_id
        _ATTR password      $string password
=end WSDL
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{user_id} = $data->user_id;
    $self->{password} = $data->password;
    bless $self;
    return $self;
}


1;
