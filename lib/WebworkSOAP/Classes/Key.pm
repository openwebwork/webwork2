package WebworkSOAP::Classes::Key;

=pod
=begin WSDL
        _ATTR user_id       $string user_id
        _ATTR key_not_a_keyboard $string key_not_a_keyboard
        _ATTR timestamp     $string timestamp
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
