#!/usr/bin/env perl
BEGIN {
  $ENV{DANCER_APPHANDLER} = 'PSGI';
}
use Dancer2;
use FindBin '$RealBin';
use Plack::Handler::FCGI;
use Data::Dump qw/dump/;

# For some reason Apache SetEnv directives don't propagate
# correctly to the dispatchers, so forcing PSGI and env here
# is safer.
set apphandler => 'PSGI';
set environment => 'development';

$ENV{WEBWORK_ROOT} = config->{webwork_dir};
$ENV{PG_ROOT} = config->{pg_dir} || config->{webwork_dir} . "../pg";

my $psgi = path($RealBin, '..', 'bin', 'app.psgi');
my $app = do($psgi);
die "Unable to read startup script: $@" if $@;
my $server = Plack::Handler::FCGI->new(nproc => 5, detach => 1);

$server->run($app);
