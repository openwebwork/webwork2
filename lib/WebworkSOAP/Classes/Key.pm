package WebworkSOAP::Classes::Key;

=pod
=begin WSDL
        _ATTR user_id       $string
        _ATTR key_not_a_keyboard $string
        _ATTR timestamp     $string
=end WSDL
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{user_id} = $data->user_id;
    $self->{key_not_a_keyboard} = $data->key_not_a_keyboard;
    $self->{timestamp} = $data->timestamp;
    bless $self;
    return $self;
}

1;
