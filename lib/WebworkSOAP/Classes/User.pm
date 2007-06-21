package WebworkSOAP::Classes::User;

=pod
=begin WSDL
        _ATTR user_id       $string
        _ATTR first_name    $string
        _ATTR last_name     $string
        _ATTR email_address $string
        _ATTR student_id    $string
        _ATTR status        $string
        _ATTR section       $string
        _ATTR recitation    $string
        _ATTR comment       $string
=end WSDL
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{user_id} = $data->user_id;
    $self->{first_name} = $data->first_name;
    $self->{last_name} = $data->last_name;
    $self->{email_address} = $data->email_address;
    $self->{student_id} = $data->student_id;
    $self->{status} = $data->status;
    $self->{section} = $data->section;
    $self->{recitation} = $data->recitation;
    $self->{comment} = $data->comment;
    bless $self;
    return $self;
}

1;
