## This is a number of common subroutines needed when processing the routes.


package Utils::Users;
use base qw(Exporter);

use WeBWorK::Utils qw/cryptPassword/;
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash convertBooleans/;

our @user_props = qw/first_name last_name student_id user_id email_address permission status
                    section recitation comment displayMode showOldAnswers useMathView/;
our @boolean_user_props = qw/showOldAnswers useMathView/;


our @EXPORT    = ();
our @EXPORT_OK = qw/get_one_user add_one_user @user_props @boolean_user_props/;


###
#
#  get a single user
#
###

sub get_one_user {
  my ($db,$user_id) = @_;
  my $user = $db->getUser($user_id);
  my $permission = $db->getPermissionLevel($user_id);
  my $user_props = convertObjectToHash($user,\@boolean_user_props);
  $user_props->{permission} = $permission->{permission};
  $user_props->{_id} = $user->{user_id};

  return $user_props;
}


###
#
#  add one user to the course.
#
###

sub add_one_user {
  my ($db,$props) = @_;

  # ensure that some default properties are set

  $props->{status} = 'C' unless defined $props->{status};


  # update the standard user properties

  my $user = $db->newUser();

  for my $key (@user_props) {
    $user->{$key} = $props->{$key} if (defined($props->{$key}));
  }


  # password record

  my $password = $db->newPassword();
  $password->{user_id} = $user->{user_id};
  my $cryptedpassword = "";
  if (defined($props->{password})) {
    $cryptedpassword = cryptPassword($props->{password});
  }
  elsif (defined($props->{student_id})) {
    $cryptedpassword = cryptPassword($props->{student_id});
  }
  $password->password($cryptedpassword);



  # permission record

  my $permission = $db->newPermissionLevel();
  $permission->{user_id} = $props->{user_id};
  $permission->{permission} = $props->{permission} || 0;

  $db->addUser($user);
  $db->addPassword($password);
  $db->addPermissionLevel($permission);

  return get_one_user($db,$user->{user_id});

}
