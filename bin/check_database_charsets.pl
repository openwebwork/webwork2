#!/usr/bin/perl -w

my $host = $ENV{WEBWORK_DB_HOST};
my $port = $ENV{WEBWORK_DB_PORT};
my $database_name = $ENV{WEBWORK_DB_NAME};
my $database_user = $ENV{WEBWORK_DB_USER};
my $database_password = $ENV{WEBWORK_DB_PASSWORD};


print `mysql -u $database_user -p$database_password $database_name -h $host  -e "SHOW VARIABLES WHERE Variable_name LIKE \'character\_set\_%\' OR Variable_name LIKE \'collation%\' or Variable_name LIKE \'init_connect\'  "`;