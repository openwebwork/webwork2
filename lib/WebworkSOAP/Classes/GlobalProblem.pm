package WebworkSOAP::Classes::GlobalProblem;
=pod
=begin WSDL
        _ATTR set_id        $string set_id
        _ATTR problem_id    $integer
        _ATTR source_file   $string
        _ATTR value         $integer
        _ATTR max_attempts  $integer
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{set_id} = $data->set_id;
    $self->{problem_id} = $data->problem_id;
    $self->{source_file} = $data->source_file;
    $self->{value} = $data->value;
    $self->{max_attempts} = $data->max_attempts;
    bless $self;
    return $self;
}

1;
