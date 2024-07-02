package WebworkSOAP::Classes::Key;

=pod

=begin WSDL
    _ATTR user_id            $string user_id
    _ATTR key                $string key
    _ATTR timestamp          $string timestamp
=end WSDL

=cut

sub new {
	my $self = shift;
	my $data = shift;
	$self              = {};
	$self->{user_id}   = SOAP::Data->type('string', $data->user_id);
	$self->{key}       = SOAP::Data->type('string', $data->key);
	$self->{timestamp} = SOAP::Data->type('string', $data->timestamp);
	bless $self;
	return $self;
}

1;
