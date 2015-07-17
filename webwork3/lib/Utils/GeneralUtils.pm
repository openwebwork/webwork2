package Utils::GeneralUtils;
use base qw(Exporter);

### this is a number of subrotines from the webwork2 version of WeBWorK::Utils


use strict;
use warnings;
use DateTime;
use DateTime::TimeZone;

our @EXPORT    = ();

our @EXPORT_OK = qw(timeToUTC timeFromUTC);


################################################################################
# Date/time processing
################################################################################

=head2 Date/time processing

=over

=item $dateTime = timeToUTC($time_as_epoch, $tz_name)

This shifts the date/time $datetime (as a epoch) from the timezone: $tz_name to UTC. 
This should be called after a date/time is read from the DB and before sent to the client.  

=cut

sub timeToUTC {
    my ($time_as_epoch,$tz_name) = @_;

    $tz_name ||= "local";  # use the timezone local to the server if no timezone is set. 
    if(!DateTime::TimeZone->is_valid_name($tz_name)){
        warn qq! $tz_name is not a legal time zone name. Fix it on the Course Configuration page. 
	      <a href="http://en.wikipedia.org/wiki/List_of_zoneinfo_time_zones">View list of time zones.</a> \n!;
	    $tz_name = "America/New_York";
    }
    
    my $utc = DateTime::TimeZone->new( name => $tz_name);
    my $dt = DateTime->from_epoch(epoch=>$time_as_epoch,time_zone=>"UTC");
    $dt->subtract(seconds=>$utc->offset_for_datetime($dt)); 
    return $dt->epoch;

}

=item $dateTime = timeFromUTC($time_as_epch,$tz_name)

 This shifts the date/time $datetime (as a epoch) from the timezone in $timezone to UTC.  This should be called
 after a date/time is returned from the client and before it is written to the DB. 


=cut

sub timeFromUTC {
    my ($dateTime,$tz_name) = @_;

    $tz_name ||= "local";  # use the timezone local to the server if no timezone is set. 
    if(!DateTime::TimeZone->is_valid_name($tz_name)){
        warn qq! $tz_name is not a legal time zone name. Fix it on the Course Configuration page. 
	      <a href="http://en.wikipedia.org/wiki/List_of_zoneinfo_time_zones">View list of time zones.</a> \n!;
	    $tz_name = "America/New_York";
    }
    my $tz = DateTime::TimeZone->new( name => $tz_name );
    my $dt = DateTime->from_epoch(epoch=>$dateTime,time_zone =>"UTC");  # This is the datetime object in the timezone $timezone. 
    $dt->add(seconds => $tz->offset_for_datetime($dt));

    return $dt->epoch;
}




1;