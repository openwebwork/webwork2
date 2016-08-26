package Dancer2::Plugin::Auth::Extensible::Provider::WeBWorK;

use Moo;
with "Dancer2::Plugin::Auth::Extensible::Role::Provider";

use WeBWorK3::Authen;

#our $VERSION = '0.600';

has course_environment => (is => 'rw');

#plugin_keywords 'set_course_environment';


sub set_course_environment {
    my ($self,$ce) = @_;
    $self->course_environment($ce);
}


# sub users {
#
#
#
# }

# A more sensible provider would be likely to get this information from e.g. a
# database (or LDAP, or...) rather than hardcoding it.  This, however, is an
# example.
sub users {
    return {
        'dave' => {
            name     => 'David Precious',
            password => 'beer',
            roles    => [ qw(Motorcyclist BeerDrinker) ],
        },
        'bob' => {
            name     => 'Bob The Builder',
            password => 'canhefixit',
            roles    => [ qw(Fixer) ],
        },
        'profa' => {
            name => 'Professor A',
            password => 'profa',
            roles => [qw/Professor/]
        }
    };
}

##
#
#  this is called automatically when needed from Dancer2 apps.


sub authenticate_user {
    my ($self, $username_course, $password) = @_;

    #  this is a hack to pass the course information into this method;
    my ($username,$course) = split(";",$username_course);


    my $ce = WeBWorK::CourseEnvironment->new({
                webwork_dir => $WeBWorK::Constants::WEBWORK_DIRECTORY,
                courseName=> $course});
    my $authen = WeBWorK3::Authen->new($ce);

    ## make a new WW session key

    my $newKey = $authen->create_session($username);

  	$authen->set_params({
  			user => $username,
  			password => $password, key => $newKey
  		});

   return  $authen->verify();

    # my $user_details = $self->get_user_details($username) or return;
    # return $self->match_password($password, $user_details->{password});
}

=item get_user_details

Given a username, return details about the user.  The details returned will vary
depending on the provider; some providers may be able to return various data
about the user, some may not, depending on the authentication source.

Details should be returned as a hashref.

=cut

sub get_user_details {
    my ($self, $username) = @_;

    return $self->users->{lc $username};
}

=item get_user_roles

Given a username, return a list of roles that user has.

=back

=cut

sub get_user_roles {
    my ($self, $username) = @_;

    my $user_details = $self->get_user_details($username) or return;
    return $user_details->{roles};
}



1;
