#!/usr/bin/env perl

=head1 Test User Set Data functions

Tests the functions in C<DB.pm> related to user set data.

=cut

use Test2::V0 '!E', { E => 'EXISTS' };

my ($webwork_root, $pg_root);

BEGIN {
	$webwork_root = $ENV{WEBWORK_ROOT};
	die "WEBWORK_ROOT not found in environment.\n" unless $ENV{WEBWORK_ROOT};
	$pg_root = $ENV{PG_ROOT};
	$pg_root = "$webwork_root/../pg" unless $pg_root;
	die "PG_ROOT not found in environment.\n" unless $pg_root;
}

use lib "$webwork_root/lib";
use lib "$pg_root/lib";

use Clone qw/clone/;
use Data::Dumper;

use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::DB::Record::UserSetData;

# Load the settings for running the tests
my $settings_file = "$webwork_root/conf/dev/db_settings.conf";
die "Make sure that the database settings are defined in '$webwork_root/conf/dev/db_settings.conf.dist'"
	unless -r $settings_file;

our $db_settings;
require($settings_file);

my $ce = WeBWorK::CourseEnvironment->new({ webwork_dir => $webwork_root, courseName => $db_settings->{course_name} });
my $db = WeBWorK::DB->new($ce->{dbLayout});

# Create a new user, set and user set to test.

my $user_id = 'user_to_test_the_db';
my $set_id  = 'set_to_test_the_db';

$db->addUser($db->newUser({
	user_id    => $user_id,
	first_name => 'Homer',
	last_name  => 'Simpson'
}));

$db->addGlobalSet($db->newGlobalSet({
	set_id => $set_id,
}));

$db->addUserSet($db->newUserSet({
	user_id => $user_id,
	set_id  => $set_id
}));

# Add a new datum:

$db->putUserSetDatum({
	user_id => $user_id,
	set_id  => $set_id,
	key     => 'key1',
	value   => 25
});

my $ext_data1 = $db->getUserSetData($user_id, $set_id);

ok $db->existsUserSetKeyDatum($user_id,  $set_id, 'key1'),            'Check that the data for the key exists';
ok !$db->existsUserSetKeyDatum($user_id, $set_id, 'nonexistent_key'), 'Check that the data for the key does not exists';

is $ext_data1, { key1 => 25 }, 'Check that the uset set data was stored correctly.';
is $db->getUserSetKeyDatum($user_id, $set_id, 'key1'), 25, 'Check that the data is retrieved correctly';

# update the key

$db->putUserSetDatum({
	user_id => $user_id,
	set_id  => $set_id,
	key     => 'key1',
	value   => [ 1, 2, 3 ]
});

my $ext_data2 = $db->getUserSetData($user_id, $set_id);

is $ext_data2, { key1 => [ 1, 2, 3 ] }, 'Check that the data was updated.';
is $db->getUserSetKeyDatum($user_id, $set_id, 'key1'), [ 1, 2, 3 ], 'Check that the key is retrieved correctly';

# Add some additional data

my $data_keys = { key2 => [ 'a', 'b', 'c' ], key3 => { a => 1 }, key4 => 'hello' };
for my $key (keys %$data_keys) {
	$db->putUserSetDatum({
		user_id => $user_id,
		set_id  => $set_id,
		key     => $key,
		value   => $data_keys->{$key}
	});
}

my @all_keys = sort (@{ $db->getUserSetDataKeys($user_id, $set_id) });
is \@all_keys, [ 'key1', 'key2', 'key3', 'key4' ], 'Check the list of keys';

for my $key ('key2', 'key3', 'key4') {
	is $db->getUserSetKeyDatum($user_id, $set_id, $key), $data_keys->{$key}, 'Check different data types';
}

# Delete a key

my $key_data = $db->deleteUserSetDataKey($user_id, $set_id, 'key4');
is $key_data, { key4 => 'hello' }, 'Delete a key from the user set data';
@all_keys = sort (@{ $db->getUserSetDataKeys($user_id, $set_id) });
is \@all_keys, [ 'key1', 'key2', 'key3' ], 'Check that the key was deleted.';

# Delete all data associated with a user set
$db->deleteUserSetData($user_id, $set_id);

# Delete the created user, set and user_set

$db->deleteUser($user_id);
$db->deleteGlobalSet($set_id);

done_testing();
