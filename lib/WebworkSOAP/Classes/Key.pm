package WebworkSOAP::Classes::Key;

# _ATTR user_id       $string user_id
# _ATTR key_not_a_keyboard $string key_not_a_keyboard
# _ATTR timestamp     $string timestamp

sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{user_id} = SOAP::Data->type( 'string', $data->user_id );
    $self->{key_not_a_keyboard} = SOAP::Data->type( 'string', $data->key_not_a_keyboard );
    $self->{timestamp} = SOAP::Data->type( 'string', $data->timestamp );
    bless $self;
    return $self;
}

1;
