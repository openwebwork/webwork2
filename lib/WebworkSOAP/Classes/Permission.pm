package WebworkSOAP::Classes::Permission;

# _ATTR user_id       $string user_id
# _ATTR permission    $string permission

sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{user_id} = SOAP::Data->type( 'string', $data->user_id );
    $self->{permission} = SOAP::Data->type( 'string', $data->permission );
    bless $self;
    return $self;
}


1;
