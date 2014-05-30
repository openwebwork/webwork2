package WebworkSOAP::Classes::UserProblem;

=pod
=begin WSDL
        _ATTR user_id       $string user_id
        _ATTR set_id        $string set_id
        _ATTR problem_id    $string problem_id
        _ATTR source_file   $string source_file
        _ATTR value         $string value
        _ATTR max_attempts  $string max_attempts
        _ATTR showMeAnother  $string showMeAnother
        _ATTR showMeAnotherCount  $string showMeAnotherCount
        _ATTR problem_seed  $string problem_seed
        _ATTR status        $string status
        _ATTR attempted     $string attempted
        _ATTR last_answer   $string last_answer
        _ATTR num_correct   $string num_correct
        _ATTR num_incorrect $string num_incorrect
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{user_id} = SOAP::Data->type( 'string', $data->user_id );
    $self->{set_id} = SOAP::Data->type( 'string', $data->set_id );
    $self->{problem_id} = SOAP::Data->type( 'string', $data->problem_id );
    $self->{source_file} = SOAP::Data->type( 'string', $data->source_file );
    $self->{value} = SOAP::Data->type( 'string', $data->value );
    $self->{max_attempts} = SOAP::Data->type( 'string', $data->max_attempts );
    $self->{showMeAnother} = SOAP::Data->type( 'string', $data->showMeAnother );
    $self->{showMeAnotherCount} = SOAP::Data->type( 'string', $data->showMeAnotherCount );
    $self->{problem_seed} = SOAP::Data->type( 'string', $data->problem_seed );
    $self->{status} = SOAP::Data->type( 'string', $data->status );
    $self->{attempted} = SOAP::Data->type( 'string', $data->attempted );
    $self->{last_answer} = SOAP::Data->type( 'string', $data->last_answer );
    $self->{num_correct} = SOAP::Data->type( 'string', $data->num_correct );
    $self->{num_incorrect} = SOAP::Data->type( 'string', $data->num_incorrect );
    bless $self;
    return $self;
}

1;
