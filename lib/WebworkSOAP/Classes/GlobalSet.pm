package WebworkSOAP::Classes::GlobalSet;

# _ATTR set_id                    $string set_id
# _ATTR set_header                $string set_header
# _ATTR hardcopy_header           $string hardcopy_header
# _ATTR open_date                 $string open_date
# _ATTR due_date                  $string due_date
# _ATTR answer_date               $string answer_date
# _ATTR visible                   $string visible
# _ATTR enable_reduced_scoring    $string enable_reduced_scoring
# _ATTR assignment_type           $string assignment_type
# _ATTR attempts_per_version      $string attempts_per_version
# _ATTR time_interval             $string time_interval
# _ATTR versions_per_interval     $string versions_per_interval
# _ATTR version_time_limit        $string version_time_limit
# _ATTR version_creation_time     $string version_creation_time
# _ATTR problem_randorder         $string problem_randorder
# _ATTR version_last_attempt_time $string version_last_attempt_time
# _ATTR problems_per_page         $string problems_per_page

sub new() {
        my $self = shift;
        my $data = shift;
        $self = {};
        $self->{set_id} = SOAP::Data->type( 'string', $data->set_id );
        $self->{set_header} = SOAP::Data->type( 'string', $data->set_header );
        $self->{hardcopy_header} = SOAP::Data->type( 'string', $data->hardcopy_header );
        $self->{open_date} = SOAP::Data->type( 'string', $data->open_date );
        $self->{due_date} = SOAP::Data->type( 'string', $data->due_date );
        $self->{answer_date} = SOAP::Data->type( 'string', $data->answer_date );
        $self->{visible} = SOAP::Data->type( 'string', $data->visible );
        $self->{enable_reduced_scoring} = SOAP::Data->type( 'string', $data->enable_reduced_scoring );
        $self->{assignment_type} = SOAP::Data->type( 'string', $data->assignment_type );
        $self->{attempts_per_version} = SOAP::Data->type( 'string', $data->attempts_per_version );
        $self->{time_interval} = SOAP::Data->type( 'string', $data->time_interval );
        $self->{versions_per_interval} = SOAP::Data->type( 'string', $data->versions_per_interval );
        $self->{version_time_limit} = SOAP::Data->type( 'string', $data->version_time_limit );
        $self->{version_creation_time} = SOAP::Data->type( 'string', $data->version_creation_time );
        $self->{problem_randorder} = SOAP::Data->type( 'string', $data->problem_randorder );
        $self->{version_last_attempt_time} = SOAP::Data->type( 'string', $data->version_last_attempt_time );
        $self->{problems_per_page} = SOAP::Data->type( 'string', $data->problems_per_page );
        bless $self;
        return $self;
}

1;
