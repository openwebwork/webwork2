# Apache::WeBWorK - The WeBWorK dispatcher module
# Place something like the following in your Apache configuration to load the
# WeBWorK module and install it as a handler for the WeBWorK system

# PerlModule Apache::WeBWorK
# <Location /webwork>
#	SetHandler perl-script
#	PerlHandler Apache::WeBWorK::dispatch
# </Location>

package Apache::WeBWorK;

use strict;
use Apache::Constants qw(:common REDIRECT);
use Apache::Request;
use WeBWorK::CourseEnvironment;
use WeBWorK::Test;
#use WeBWorK::Authen;

# registering discontent: wanted to call this dispatch, but mod_perl gave me lip
sub handler() {
	my $r = Apache::Request->new(shift); # have to deal with unpredictable GET or POST data ,and sift through it for the key.  So use Apache::Request
	my $path_info = $r->path_info;
	my $path_translated = $r->lookup_uri($path_info)->filename;
	my $current_uri = $r->uri;
	unless ($path_info) {
		$r->header_out(Location => "$current_uri/");
		return REDIRECT;
	}
	
	return OK if $r->header_only;
	my($junk, @components) = split "/", $path_info;
	my $webwork_root = $r->dir_config('webwork_root'); # From a PerlSetVar in httpd.conf
	my $course = shift @components;
	# catch errors in $@
	my $course_env = eval {WeBWorK::CourseEnvironment->new($webwork_root, $course);};
	if ($@) {
		# TODO: display an error page.  For now, print something mildly useful
		return DECLINED;
	}
	
#	if (!WeBWorK::Authen->new($r, $course_env)->authen) {
#		return WeBWorK::Login->new($r, $course_env)->go();
#	} else {
		if (1) {
			return WeBWorK::Test->new($r, $course_env)->go();
		}
#	}
	
	
	
	$r->print(<<END);
COURSE = $course<br>
WEBWORK_ROOT = $webwork_root<br>
URI = <em>$current_uri</em><br>
Path information = <em>$path_info</em><br>
Translated path = <em>$path_translated</em>
</body>
</html>
END

	return OK;
}

1;

__END__

#	if (!auth) {
#		loginpage
#	} else {
#		dispatch
#	}



load some global settings for the system
	- apparently, these are going to live in the package Global
	- this sucks, since it's not really the global namespace
	- but whatever.

disassemble the URI to some extent
	- we need to know the course
