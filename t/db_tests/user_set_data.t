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

# Start with an empty database table:

my @data = $db->{user_set_data}->delete_where({});

# Add a new datum:

my $new_user_set_datum = $db->newUserSetData({
	user_id => 'homer',
	set_id  => 'set1',
	key_id  => 'key1',
	value   => '{ z => 25 }'
});

$db->addUserSetDatum($new_user_set_datum);

my @keys = $db->listUserSetData('homer', 'set1');

is scalar(@keys), 1,        'There is one datum in the db.';
is \@keys,        ['key1'], 'The proper data keys are in the db.';

# Check the existsUserSetDatum function

ok $db->existsUserSetKeyDatum('homer', 'set1', 'key1'), 'Check that the item exists in the db.';

# Check that the added data is correct:

my $datum2 = $db->getUserSetKeyDatum('homer', 'set1', 'key1');
is $datum2, $new_user_set_datum, 'Check that the correct item is in the db.';

# Update the data

my $updated_user_set_datum = clone $new_user_set_datum;
$updated_user_set_datum->{value} = '{ z => 35 }';
$db->putUserSetDatum($updated_user_set_datum);

my $updated_datum_from_db = $db->getUserSetKeyDatum('homer', 'set1', 'key1');
is $updated_datum_from_db, $updated_user_set_datum, 'Check that the datum is updated correctly.';

# Add some additional data

my $data_keys = { key2 => 'x => [1,2,3]', key3 => 'x => {a => 1}', key4 => 'y => 5' };
for my $key (keys %$data_keys) {
	$db->addUserSetDatum($db->newUserSetData({
		user_id => 'homer',
		set_id  => 'set1',
		key_id  => $key,
		value   => $data_keys->{$key}
	}));
}

# Fetch all data with a given user_id and set_id

my @user_set_data = $db->getUserSetData('homer', 'set1');
is scalar(@user_set_data),                 4, 'Check that the number of user set data for a given user/set is correct';
is $db->countUserSetData('homer', 'set1'), 4, 'Count the number of keys for a given user in a course';

my $user_set_data3 = (grep { $_->{key_id} eq 'key3' } @user_set_data)[0];
is $user_set_data3->{value}, $data_keys->{key3}, 'Check that the value of another key is correct';

# add some other keys for a different user.
my $d1 = {
	user_id => 'lisa',
	set_id  => 'set1',
	key_id  => 'key1',
	value   => '{"x": [1,2,3]}'
};

my $d2 = {
	user_id => 'lisa',
	set_id  => 'set1',
	key_id  => 'key2',
	value   => '{"y": ["a","b","c"]}'
};

$db->addUserSetDatum($db->newUserSetData($d1));
$db->addUserSetDatum($db->newUserSetData($d2));

my @data2 = $db->getUserSetData('lisa', 'set1');

is \@data2, [ $d1, $d2 ], 'Check that added data for a different user is correct.';

# delete a user set key datum
$db->deleteUserSetKeyDatum('homer', 'set1', 'key1');

# and check that it has been deleted
ok !$db->existsUserSetKeyDatum('homer', 'set1', 'key1'), 'Check that the user set datum has been deleted.';

done_testing();
