#!/usr/bin/perl -w
use strict;
use 5.10.0;
my $SITE_URL = "foobar";
my $template = do("standard_format.pl");
my %replacement_key_value_pairs =(
	 SITE_URL      	 =>   $SITE_URL,
	 FORM_ACTION_URL  =>  "FORM_ACTION_URL",
	 courseID         =>  "courseID",
	 userID           =>  "userID",
	 course_password  =>  "course_password",
	 problemSeed      =>  "problemSeed",
	 session_key      =>  "session_key",
	 displayMode      =>  "displayMode",
	 previewMode      =>  "previewMode",
	 submitMode       =>  "submitMode",
	 showCorrectMode  =>  "showCorrectMode",
			# Can be added to the request as a parameter.  Adds a prefix to the 
			# identifier used by the sticky format.  
	 problemUUID => "problemUUID",
	 problemResult    =>  "problemResult",
	 problemState     =>  "problemState",
	 showSummary      => " showSummary", #default to show summary for the moment
	 formLanguage     => "formLanguage",
	 scoreSummary     =>  "scoreSummary",
);
foreach my $key (keys %replacement_key_value_pairs) {
	say $key ," => ", $replacement_key_value_pairs{$key};
	$template =~ s/\$$key/$replacement_key_value_pairs{$key}/g;
}
print $template;
1;

