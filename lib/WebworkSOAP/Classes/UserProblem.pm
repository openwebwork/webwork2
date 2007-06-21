package WebworkSOAP::Classes::UserProblem;

=pod
=begin WSDL
        _ATTR user_id       $string
        _ATTR set_id        $string
        _ATTR problem_id    $string
        _ATTR source_file   $string
        _ATTR value         $string
        _ATTR max_attempts  $string
        _ATTR problem_seed  $string
        _ATTR status        $string
        _ATTR attempted     $string
        _ATTR last_answer   $string
        _ATTR num_correct   $integer
        _ATTR num_incorrect $integer
=cut
sub new {
    my $self = shift;
    my $data = shift;
    $self = {};
    $self->{user_id} = $data->user_id;
    $self->{set_id} = $data->set_id;
    $self->{problem_id} = $data->problem_id;
    $self->{source_file} = $data->source_file;
    $self->{value} = $data->value;
    $self->{max_attempts} = $data->max_attempts;
    $self->{problem_seed} = $data->problem_seed;
    $self->{status} = $data->status;
    $self->{attempted} = $data->attempted;
    $self->{last_answer} = $data->last_answer;
    $self->{num_correct} = $data->num_correct;
    $self->{num_incorrect} = $data->num_incorrect;
    bless $self;
    return $self;
}

1;
