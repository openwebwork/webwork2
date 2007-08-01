package WebworkSOAP::Classes::UserProblem;

=pod
=begin WSDL
        _ATTR user_id       $string user_id
        _ATTR set_id        $string set_id
        _ATTR problem_id    $string problem_id
        _ATTR source_file   $string source_file
        _ATTR value         $string value
        _ATTR max_attempts  $string max_attempts
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
