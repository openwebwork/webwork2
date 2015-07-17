#!/local/bin/perl

use DateTime; 
use DateTime::TimeZone;
use feature qw/say/;
use Data::Dump;

use Utils::GeneralUtils qw/timeToUTC/;

#my $dt = DateTime->new(year=>2015,month=>7,day=>17,hour=>9,minute=>45,second=>0,time_zone=>"America/New_York");

my $dt = DateTime->now; 
$dt->time_zone("UTC");
#my $start_time = 1430020140;

my $time = timeToUTC($dt->epoch,"America/New_York");

#my $new_time = DateTime->from_epoch(epoch=>$start_time,time_zone=>"America/New_York");
#
#say $new_time->mdy("/") . " " . $new_time->hms;
#
##dd($new_time);
#
#say $otime = DateTime->from_epoch(epoch=>$start_time);
#say $otime->mdy("/") . " " . $otime->hms;
#say $new_time->epoch;


my $utc = DateTime::TimeZone->new( name => "UTC");
dd $utc;

