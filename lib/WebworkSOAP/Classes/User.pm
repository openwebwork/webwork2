package WebworkSOAP::Classes::User;

# _ATTR user_id       $string user_id
# _ATTR first_name    $string first_name
# _ATTR last_name     $string last_name
# _ATTR email_address $string email_address
# _ATTR student_id    $string student_id
# _ATTR status        $string status
# _ATTR section       $string section
# _ATTR recitation    $string recitation
# _ATTR comment       $string comment

sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
	$self->{user_id} = SOAP::Data->type( 'string', $data->user_id );
    $self->{first_name} = SOAP::Data->type( 'string', $data->first_name );
    $self->{last_name} = SOAP::Data->type( 'string', $data->last_name );
    $self->{email_address} = SOAP::Data->type( 'string', $data->email_address );
    $self->{student_id} = SOAP::Data->type( 'string', $data->student_id );
    $self->{status} = SOAP::Data->type( 'string', $data->status );
    $self->{section} = SOAP::Data->type( 'string', $data->section );
    $self->{recitation} = SOAP::Data->type( 'string', $data->recitation );
    $self->{comment} = SOAP::Data->type( 'string', $data->comment );
    bless $self;
    return $self;
}

1;
