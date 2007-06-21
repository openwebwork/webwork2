package WebworkSOAP::Classes::Password;

=pod
=begin WSDL
        _ATTR user_id       $string
        _ATTR password      $string
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
