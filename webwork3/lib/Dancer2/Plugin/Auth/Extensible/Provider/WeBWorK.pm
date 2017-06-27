package Dancer2::Plugin::Auth::Extensible::Provider::WeBWorK;

#use Carp qw/croak/;
use Moo;
with "Dancer2::Plugin::Auth::Extensible::Role::Provider";

use WeBWorK3::Authen;
use Utils::Convert qw/convertObjectToHash/;
use Data::Dump qw(dump);

##
#
#  this is called automatically when needed from Dancer2 apps.


sub authenticate_user {
  my ($self, $username, $password) = @_;
  #$self->plugin->dsl->debug("In authenticate_user");
  #$self->plugin->dsl->debug(dump $self->plugin->dsl->request);
  my $course_id = $self->plugin->dsl->session->data->{course_id};
  die "The course parameter must be set in the session" unless defined($course_id);
  my $ce = WeBWorK::CourseEnvironment->new({
               webwork_dir => $WeBWorK::Constants::WEBWORK_DIRECTORY,
               courseName=> $course_id});

  my $authen = WeBWorK3::Authen->new($ce);
  my $session_key = $self->plugin->dsl->session->data->{session_key};
  $authen->set_params({
  		user => $username
      ,password => $password
      , key => $session_key
  	});

  #$self->plugin->dsl->debug($authen->verify());
  return $authen->verify()->{result};
}

=item get_user_details

Given a username, return details about the user.  The details returned will vary
depending on the provider; some providers may be able to return various data
about the user, some may not, depending on the authentication source.

Details should be returned as a hashref.

=cut

sub get_user_details {
    my ($self, $username) = @_;
    #$self->plugin->dsl->debug($self->plugin->dsl->session);
    #$self->plugin->dsl->debug($username);
    my $user = $self->plugin->dsl->vars->{db}->getUser($username);
    return convertObjectToHash($user);
}

=item get_user_roles

Given a username, return a list of roles that user has.

=back

=cut

sub get_user_roles {
    my ($self, $username) = @_;

    $username = $self->plugin->dsl->session("logged_in_user") unless (defined $username);

    #$self->plugin->dsl->debug("in get_user_roles");
    #$self->plugin->dsl->debug($username);
    my %roles = reverse %{$self->plugin->dsl->vars->{ce}->{userRoles}};
  	my $db = $self->plugin->dsl->vars->{db};
  	my $permission = $db->getPermissionLevel($username);
    # $self->plugin->dsl->debug(%roles);
    # $self->plugin->dsl->debug($username);
    # $self->plugin->dsl->debug($permission);
    # $self->plugin->dsl->debug($roles{$permission->{permission}});
  	return [$roles{$permission->{permission}}];

}



1;
