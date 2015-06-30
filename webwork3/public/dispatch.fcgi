#!/usr/bin/env perl
use Dancer ':syntax';
use FindBin '$RealBin';
use Plack::Handler::FCGI;

# For some reason Apache SetEnv directives dont propagate
# correctly to the dispatchers, so forcing PSGI and env here 
# is safer.
set apphandler => 'PSGI';
set environment => 'development';

# this makes sure that the application knows that we are running apache2. 
$ENV{MOD_PERL_API_VERSION}=2;

my $psgi = path($RealBin, '..', 'bin', 'app.pl');
my $app = do($psgi);
die "Unable to read startup script: $@" if $@;
my $server = Plack::Handler::FCGI->new(nproc => 1, detach => 1);

$server->run($app);
