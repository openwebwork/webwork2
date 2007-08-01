package WebworkSOAP::Classes::User;

=pod
=begin WSDL
        _ATTR user_id       $string user_id
        _ATTR first_name    $string first_name
        _ATTR last_name     $string last_name
        _ATTR email_address $string email_address
        _ATTR student_id    $string student_id
        _ATTR status        $string status
        _ATTR section       $string section
        _ATTR recitation    $string recitation
        _ATTR comment       $string comment
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
