package WebworkSOAP::Classes::GlobalProblem;

# _ATTR set_id        $string set_id
# _ATTR problem_id    $string problem_id
# _ATTR source_file   $string source_file
# _ATTR value         $string value
# _ATTR max_attempts  $string max_attempts
# _ATTR showMeAnother  $string showMeAnother
# _ATTR showMeAnotherCount  $string showMeAnotherCount

sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{set_id} = SOAP::Data->type( 'string', $data->set_id );
    $self->{problem_id} = SOAP::Data->type( 'string', $data->problem_id );
    $self->{source_file} = SOAP::Data->type( 'string', $data->source_file );
    $self->{value} = SOAP::Data->type( 'string', $data->value );
    $self->{max_attempts} = SOAP::Data->type( 'string', $data->max_attempts );
    $self->{showMeAnother} = SOAP::Data->type( 'string', $data->showMeAnother );
    $self->{showMeAnotherCount} = SOAP::Data->type( 'string', $data->showMeAnotherCount );
    bless $self;
    return $self;
}

1;
