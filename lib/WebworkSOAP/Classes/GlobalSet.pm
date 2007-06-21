package WebworkSOAP::Classes::GlobalSet;
=pod
=begin WSDL
        _ATTR set_id                    $string set_id
        _ATTR set_header                $string set_header
        _ATTR hardcopy_header           $string hardcopy_header
        _ATTR open_date                 $integer open_date
        _ATTR due_date                  $integer due_date
        _ATTR answer_date               $integer answer_date
        _ATTR published                 $integer published
        _ATTR assignment_type           $string assignment_type
        _ATTR attempts_per_version      $integer attempts_per_version
        _ATTR time_interval             $integer time_interval
        _ATTR versions_per_interval     $integer versions_per_interval
        _ATTR version_time_limit        $integer version_time_limit
        _ATTR version_creation_time     $integer version_creation_time
        _ATTR problem_randorder         $integer
        _ATTR version_last_attempt_time $integer
        _ATTR problems_per_page         $integer
=cut
sub new() {
        my $self = shift;
        my $data = shift;
        $self = {};
        $self->{set_id} = $data->set_id;
        $self->{set_header} = $data->set_header;
        $self->{hardcopy_header} = $data->hardcopy_header;
        $self->{open_date} = $data->open_date;
        $self->{due_date} = $data->due_date;
        $self->{answer_date} = $data->answer_date;
        $self->{published} = $data->published;
        $self->{assignment_type} = $data->assignment_type;
        $self->{attempts_per_version} = $data->attempts_per_version;
        $self->{time_interval} = $data->time_interval;
        $self->{versions_per_interval} = $data->versions_per_interval;
        $self->{version_time_limit} = $data->version_time_limit;
        $self->{version_creation_time} = $data->version_creation_time;
        $self->{problem_randorder} = $data->problem_randorder;
        $self->{version_last_attempt_time} = $data->version_last_attempt_time;
        $self->{problems_per_page} = $data->problems_per_page;
        bless $self;
        return $self;
}

1;

