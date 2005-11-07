################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator.pm,v 1.151 2005/10/02 19:51:44 jj Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator;

=head1 NAME

WeBWorK::ContentGenerator - base class for modules that generate page content.

=head1 SYNOPSIS

 # start with a WeBWorK::Request object: $r
 
 use WeBWorK::ContentGenerator::SomeSubclass;
 
 my $cg = WeBWorK::ContentGenerator::SomeSubclass->new($r);
 my $result = $cg->go();

=head1 DESCRIPTION

WeBWorK::ContentGenerator provides the framework for generating page content.
"Content generators" are subclasses of this class which provide content for
particular parts of the system.

Default versions of methods used by the templating system are provided. Several
useful methods are provided for rendering common output idioms and some
miscellaneous utilities are provided.

=cut

use strict;
use warnings;
use Apache::Constants qw(:response);
use Carp;
use CGI qw(*ul *li escapeHTML);
use Date::Format;
use URI::Escape;
use WeBWorK::Debug;
use WeBWorK::PG;
use WeBWorK::Template qw(template);

###############################################################################

=head1 CONSTRUCTOR

=over

=item new($r)

Creates a new instance of a content generator. Supply a WeBWorK::Request object
$r.

=cut

sub new {
	my ($invocant, $r) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		r => $r, # this is now a WeBWorK::Request
		ce => $r->ce(),       # these three are here for
		db => $r->db(),       # backward-compatability
		authz => $r->authz(), # with unconverted CGs
		noContent => undef, # this should get clobbered at some point
	};
	bless $self, $class;
	return $self;
}

=back

=cut

################################################################################

=head1 INVOCATION

=over

=item go()

Generates a page, using methods from the particular subclass of ContentGenerator
that is instantiated. Generatoion is broken up into several steps, to give
subclasses ample control over the process.

=over

=item 1

go() will attempt to call the method pre_header_initialize(). This method may be
implemented in subclasses which must do processing before the HTTP header is
emitted.

=item 2

go() will attempt to call the method header(). This method emits the HTTP
header. It is defined in this class (see below), but may be overridden in
subclasses which need to send different header information. For some reason, the
return value of header() will be used as the result of this function, if it is
defined.

FIXME: figure out what the deal is with the return value of header(). If we sent
a header, it's too late to set the status by returning. If we didn't, header()
didn't perform its function!

=item 3

At this point, go() will terminate if the request is a HEAD request or if the
field $self->{noContent} contains a true value.

FIXME: I don't think we'll need noContent after reply_with_redirect() is
adopted by all modules.

=item 4

go() then attempts to call the method initialize(). This method may be
implemented in subclasses which must do processing after the HTTP header is sent
but before any content is sent.

=item 6

The method content() is called to send the page content to client.

=back

=cut

sub go {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	my $returnValue = OK;
	
	# We only write to the activity log if it has been defined and if
	# we are in a specific course.  The latter check is to prevent attempts
	# to write to a course log file when viewing the top-level list of
	# courses page.
	WeBWorK::Utils::writeCourseLog($ce, 'activity_log',
		$self->prepare_activity_entry) if ( $r->urlpath->arg("courseID") and
			$r->ce->{courseFiles}->{logs}->{activity_log});

	$self->pre_header_initialize(@_) if $self->can("pre_header_initialize");
	
	# send a file instead of a normal reply (reply_with_file() sets this field)
	defined $self->{reply_with_file} and do {
		return $self->do_reply_with_file($self->{reply_with_file});
	};
	
	# send a Location: header instead of a normal reply (reply_with_redirect() sets this field)
	defined $self->{reply_with_redirect} and do {
		return $self->do_reply_with_redirect($self->{reply_with_redirect});
	};
	
	my $headerReturn = $self->header(@_);
	$returnValue = $headerReturn if defined $headerReturn;
	# FIXME: we won't need noContent after reply_with_redirect() is adopted
	return $returnValue if $r->header_only or $self->{noContent};
	
	$self->initialize() if $self->can("initialize");
	
	$self->content();
	
	return $returnValue;
}

=item r()

Returns a reference to the WeBWorK::Request object associated with this
instance.

=cut

sub r {
	my ($self) = @_;
	
	return $self->{r};
}

=item do_reply_with_file($fileHash)

Handler for reply_with_file(), used by go(). DO NOT CALL THIS METHOD DIRECTLY.

=cut

sub do_reply_with_file {
	my ($self, $fileHash) = @_;
	my $r = $self->r;
	
	my $type = $fileHash->{type};
	my $source = $fileHash->{source};
	my $name = $fileHash->{name};
	my $delete_after = $fileHash->{delete_after};
	
	# if there was a problem, we return here and let go() worry about sending the reply
	return NOT_FOUND unless -e $source;
	return FORBIDDEN unless -r $source;
	
	# open the file now, so we can send the proper error status is we fail
	open my $fh, "<", $source or return SERVER_ERROR;
	
	# send our custom HTTP header
	$r->content_type($type);
	$r->header_out("Content-Disposition" => "attachment; filename=\"$name\"");
	$r->send_http_header;
	
	# send the file
	$r->send_fd($fh);
	
	# close the file and go home
	close $fh;
	
	if ($delete_after) {
		unlink $source or warn "failed to unlink $source after sending: $!";
	}
}

=item do_reply_with_redirect($url)

Handler for reply_with_redirect(), used by go(). DO NOT CALL THIS METHOD DIRECTLY.

=cut

sub do_reply_with_redirect {
	my ($self, $url) = @_;
	my $r = $self->r;
	
	$r->status(REDIRECT);
	$r->header_out(Location => $url);
	$r->send_http_header();
}

=back

=cut

################################################################################

=head1 DATA MODIFIERS

Modifiers allow the caller to register a piece of data for later retrieval in a
standard way.

=over

=item reply_with_file($type, $source, $name, $delete_after)

Enables file sending mode, causing go() to send the file specified by $source to
the client after calling pre_header_initialize(). The content type sent is
$type, and the suggested client-side file name is $name. If $delete_after is
true, $source is deleted after it is sent.

Must be called before the HTTP header is sent. Usually called from
pre_header_initialize().

=cut

sub reply_with_file {
	my ($self, $type, $source, $name, $delete_after) = @_;
	$delete_after ||= "";
	
	$self->{reply_with_file} = {
		type => $type,
		source => $source,
		name => $name,
		delete_after => $delete_after,
	};
}

=item reply_with_redirect($url)

Enables redirect mode, causing go() to redirect to the given URL after calling
pre_header_initialize().

Must be called before the HTTP header is sent. Usually called from
pre_header_initialize().

=cut

sub reply_with_redirect {
	my ($self, $url) = @_;
	
	$self->{reply_with_redirect} = $url;
}

=item addmessage($message)

Adds a message to the list of messages to be printed by the message() template
escape handler.

Must be called before the message() template escape is invoked.

=cut



sub addmessage {
	my ($self, $message) = @_;
	$self->{status_message} .= $message;
}

=item addgoodmessage($message)

Adds a success message to the list of messages to be printed by the
message() template escape handler.

=cut


sub addgoodmessage {
	my ($self, $message) = @_;
	$self->addmessage(CGI::div({class=>"ResultsWithoutError"}, $message));
}

=item addbadmessage($message)

Adds a failure message to the list of messages to be printed by the
message() template escape handler.

=cut


sub addbadmessage {
	my ($self, $message) = @_;
	$self->addmessage(CGI::div({class=>"ResultsWithError"}, $message));
}

=item prepare_activity_entry()
                                                                                
Prepare a string to be sent to the activity log, if it is turned on.
This can be overriden by different modules.
                                                                                
=cut                                                                            


sub prepare_activity_entry {
    my $self = shift;
	my $r = $self->r;
	my $string = $r->urlpath->path . "  --->  ".
		join("\t", (map { $_ eq 'key' || $_ eq 'passwd' ? '' : $_ ." => " . $r->param($_) } $r->param()));
	$string =~ s/\t+/\t/g;
	return($string);
}

=back

=cut

################################################################################

=head1 STANDARD METHODS

The following are the standard content generator methods. Some are defined here,
but may be overridden in a subclass. Others are not defined unless they are
defined in a subclass.

=over

=item pre_header_initialize()

Not defined in this package.

May be defined by a subclass to perform any processing that must occur before
the HTTP header is sent.

=cut

#sub pre_header_initialize {  }

=item header()

Defined in this package.

Generates and sends a default HTTP header, specifying the "text/html" content
type.

=cut

sub header {
	my $self = shift;
	my $r = $self->r;
	
	$r->content_type("text/html");
	$r->send_http_header();
	return OK;
}

=item initialize()

Not defined in this package.

May be defined by a subclass to perform any processing that must occur after the
HTTP header is sent but before any content is sent.

=cut

#sub initialize {  }

=item content()

Defined in this package.

Print the content of the generated page.

The implementation in this package uses WeBWorK::Template to define the content
of the page. See WeBWorK::Template for details.

If a method named templateName() exists, it it called to determine the name of
the template to use. If not, the default template, "system", is used. The
location of the template is looked up in the course environment.

=cut

sub content {
	my ($self) = @_;
	my $ce = $self->r->ce;
	
	# if the content generator specifies a custom template name, use that
	# field in the $ce->{templates} hash instead of "system" if it exists.
	my $templateName;
	if ($self->can("templateName")) {
		$templateName = $self->templateName;
	} else {
		$templateName = "system";
	}
	$templateName = "system" unless exists $ce->{templates}->{$templateName};
	template($ce->{templates}->{$templateName}, $self);
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Template escape handlers

Template escape handlers are invoked when the template processor encounters a
matching escape sequence in the template. The escapse sequence's arguments are
passed to the methods as a reference to a hash.

For more information, refer to WeBWorK::Template.

The following template escapes handlers are defined here or may be defined in
subclasses. For methods that are not defined in this package, the documentation
defines the interface and behavior that any subclass implementation must follow.

=over

=item head()

Not defined in this package.

Any tags that should appear in the HEAD of the document.

=cut

#sub head {  }

=item info()

Not defined in this package.

Auxiliary information related to the content displayed in the C<body>.

=cut

#sub info {  }

=item links()

Defined in this package.

Links that should appear on every page.

=cut

sub links {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $authen = $r->authen;
	my $authz = $r->authz;
	my $ce = $r->ce;
	my $urlpath = $r->urlpath;
	my $user = $r->param('user');
	
	# we don't currently have any links to display if the user's not logged in. this may change, though.
	return unless $authen and $authen->was_verified;
	
	# we're linking to other places in the same course, so grab the courseID from the current path
	my $courseID = $urlpath->arg("courseID");

	# grab the effective user, set and problem
	my $userID    = $r->param("effectiveUser");
	my $setID     = $urlpath->arg("setID");
	$setID = "" if (defined $setID && !(grep /$setID/, $db->listUserSets($userID)));
	my $problemID = $urlpath->arg("problemID");
	$problemID = "" if (defined $problemID && !(grep /$problemID/, $db->listUserProblems($userID, $setID)));
	
	# to make things more concise
	my %args = ( courseID => $courseID);
	my $pfx = "WeBWorK::ContentGenerator::";
	
	my $sets    = $urlpath->newFromModule("${pfx}ProblemSets", %args);
	my $options = $urlpath->newFromModule("${pfx}Options", %args);
	my $grades  = $urlpath->newFromModule("${pfx}Grades", %args);
	my $logout  = $urlpath->newFromModule("${pfx}Logout", %args);
	
	# experimental subroutine for generating links, to clean up the rest of the
	# code. ignore for now. (this is a closure over $self and $urlpath.)
	#my $makelink = sub {
	#	my ($module, $args, $name) = @_;
	#	
	#	defined $args or $args = {};
	#	my $new_urlpath = $urlpath->newFromModule($module, %$args);
	#	
	#	defined $name or $name = $new_urlpath->name;
	#	$name = sp2nbsp($name); # i don't like it, but that's what we do...
	#	
	#	return CGI::a({href => $self->systemLink($new_urlpath)}, $name);
	#};
	#
	#my $home_link = &$makelink("${pfx}Home");
	
	print "\n<!-- BEGIN " . __PACKAGE__ . "::links -->\n";
	
	# only users with appropriate permissions can report bugs
	if ($authz->hasPermissions($user, "report_bugs")) {
		print CGI::p(CGI::a({style=>"font-size:larger", href=>$ce->{webworkURLs}{bugReporter}}, "Report bugs")),CGI::hr();
	}

	my %displayOptions = (displayMode    => $self->{displayMode},
	                      showOldAnswers => $self->{will}->{showOldAnswers}
	);
	print CGI::start_ul({class=>"LinksMenu"});
	print CGI::start_li(),
	    CGI::span({style=>"font-size:larger"},
		     CGI::a({href=>$self->systemLink($sets,
		                                params=>{  %displayOptions,}
									    )}, sp2nbsp("Homework Sets"))
	);
	if (defined $setID and $setID ne "") {
		my $setPath = $urlpath->newFromModule("${pfx}ProblemSet", courseID =>$courseID, setID =>$setID);
		print CGI::start_ul();
		print CGI::li(CGI::a({href=>$self->systemLink($setPath,
		                                params=>{  %displayOptions,}
									    )}, $setID)
		);
#  Displaying a link back to the problem may not be necessary or useful.
# 		if (defined $problemID and $problemID ne "") {
# 		    my $problemPath = $urlpath->newFromModule("${pfx}Problem", 
# 		                 courseID =>$courseID, setID =>$setID, problemID =>$problemID);
# 			print CGI::start_ul();
# 				CGI::li(CGI::a({href=>$self->systemLink($problemPath,
# 		                                params=>{  %displayOptions,}
# 									    )}, $problemID)
# 				);
# 			print CGI::end_ul();
# 		}
	
		print CGI::end_ul();
	}
	print CGI::end_li();    


	
	if ($authz->hasPermissions($user, "change_password") or $authz->hasPermissions($user, "change_email_address")) {
		print CGI::li(CGI::a({href=>$self->systemLink($options,
		                                              params=>{  %displayOptions,}
									                  )
							  }, sp2nbsp($options->name))
		);
	}
	
	print CGI::li(CGI::a({href=>$self->systemLink($grades,
	                                              params=>{  %displayOptions,}
												  )},  sp2nbsp($grades->name)));
	print CGI::li(CGI::a({href=>$self->systemLink($logout)},  sp2nbsp($logout->name)));
	
	if ($authz->hasPermissions($user, "access_instructor_tools")) {
		my $ipfx = "${pfx}Instructor::";
		

		# instructor tools link

		my $instr = $urlpath->newFromModule("${ipfx}Index", %args);
		# Class list editor
		my $userList = $urlpath->newFromModule("${ipfx}UserList", %args);
		
		# Homework sets editor and set editing list links
		my $setList       = $urlpath->newFromModule("${ipfx}ProblemSetList", %args);
		my $setDetail     = $urlpath->newFromModule("${ipfx}ProblemSetDetail", %args, setID => $setID);
		my $problemEditor = $urlpath->newFromModule("${ipfx}PGProblemEditor", %args, setID => $setID, problemID => $problemID);
		
		# Library browser
		my $maker = $urlpath->newFromModule("${ipfx}SetMaker", %args);
		
		my $assigner = $urlpath->newFromModule("${ipfx}Assigner", %args);
		my $mail     = $urlpath->newFromModule("${ipfx}SendMail", %args);
		my $scoring  = $urlpath->newFromModule("${ipfx}Scoring", %args);
		
		# statistics links
		my $stats     = $urlpath->newFromModule("${ipfx}Stats", %args);
		my $userStats = $urlpath->newFromModule("${ipfx}Stats", %args, statType => "student", userID => $userID);
		my $setStats  = $urlpath->newFromModule("${ipfx}Stats", %args, statType => "set", setID => $setID);

		# progress links
		my $progress     = $urlpath->newFromModule("${ipfx}StudentProgress", %args);
		my $userProgress = $urlpath->newFromModule("${ipfx}StudentProgress", %args, statType => "student", userID => $userID);
		my $setProgress  = $urlpath->newFromModule("${ipfx}StudentProgress", %args, statType => "set", setID => $setID);
		
		
		my $fileMgr = $urlpath->newFromModule("${ipfx}FileManager", %args);
		my $courseConfig = $urlpath->newFromModule("${ipfx}Config", %args);
		
		print CGI::hr();
		print CGI::start_li();
	##  Instructor tools
		print CGI::span({style=>"font-size:larger"},
		                 CGI::a({href=>$self->systemLink($instr,params=>{  %displayOptions,})},  sp2nbsp($instr->name))
		);
	## Class list editor
		print CGI::start_ul();
		print CGI::li(CGI::a({href=>$self->systemLink($userList,params=>{  %displayOptions,})}, sp2nbsp($userList->name)));
		print CGI::start_li();
	## Homework sets editor and sub links
		print CGI::a({href=>$self->systemLink($setList,params=>{  %displayOptions,})}, sp2nbsp($setList->name));
		if (defined $setID and $setID ne "") {
			print CGI::start_ul();
			print CGI::li( CGI::a({href=>$self->systemLink($setDetail,params=>{  %displayOptions,})}, $setID) );
			if (defined $problemID and $problemID ne "") {
				print CGI::ul(
					CGI::li(CGI::a({href=>$self->systemLink($problemEditor,params=>{  %displayOptions,})}, $problemID))
				);
			}
			print CGI::end_ul();
		}
		print CGI::end_li();

	## Library browser
		print CGI::li(CGI::a({href=>$self->systemLink($maker,params=>{  %displayOptions,})}, sp2nbsp($maker->name)))
			if $authz->hasPermissions($user, "modify_problem_sets");
		print CGI::li(CGI::a({href=>$self->systemLink($assigner,params=>{  %displayOptions,})}, sp2nbsp($assigner->name)))
			if $authz->hasPermissions($user, "assign_problem_sets");
	## Stats	
		print CGI::li(CGI::a({href=>$self->systemLink($stats,params=>{  %displayOptions,})}, sp2nbsp($stats->name)));
		print CGI::start_li();
		    print CGI::start_ul();
			if (defined $userID and $userID ne "") {
				print CGI::li(CGI::a({href=>$self->systemLink($userStats,params=>{  %displayOptions,})}, $userID)),
			}
			if (defined $setID and $setID ne "") {
				print CGI::li(CGI::a({href=>$self->systemLink($setStats,params=>{  %displayOptions,})}, sp2nbsp($setID))),
			}
			print CGI::end_ul();
		print CGI::end_li();
	## Student Progress	
	    print CGI::li(CGI::a({href=>$self->systemLink($progress,params=>{  %displayOptions,})}, sp2nbsp($progress->name)));

		print CGI::start_li();
			print CGI::start_ul();
			if (defined $userID and $userID ne "") {
				print  CGI::li(CGI::a({href=>$self->systemLink($userProgress,params=>{  %displayOptions,})}, $userID));

			}
			if (defined $setID and $setID ne "") {

				print CGI::li(CGI::a({href=>$self->systemLink($setProgress,params=>{  %displayOptions,})}, sp2nbsp($setID)));

			}
			print CGI::end_ul();
		print CGI::end_li();
	## Scoring tools
		print CGI::li(CGI::a({href=>$self->systemLink($scoring,params=>{  %displayOptions,})}, sp2nbsp($scoring->name)))
			if $authz->hasPermissions($user, "score_sets");
	## Email
		print CGI::li(CGI::a({href=>$self->systemLink($mail,params=>{  %displayOptions,})}, sp2nbsp($mail->name)))
			if $authz->hasPermissions($user, "send_mail");
		print CGI::li(CGI::a({href=>$self->systemLink($fileMgr,params=>{  %displayOptions,})}, sp2nbsp($fileMgr->name)))
			if $authz->hasPermissions($user, "manage_course_files");
		print CGI::li(CGI::a({href=>$self->systemLink($courseConfig,params=>{  %displayOptions,})}, sp2nbsp($courseConfig->name)))
			if $authz->hasPermissions($user, "manage_course_files");
		#print CGI::li(CGI::a({href=>$self->systemLink($fileXfer)}, sp2nbsp($fileXfer->name)));
		print CGI::li( $self->helpMacro('instructor_links'));
		print CGI::end_ul();

	}
	
	print CGI::end_ul();
	print "<!-- end " . __PACKAGE__ . "::links -->\n";
	
	return "";
}

=item loginstatus()

Defined in this package.

Print a notification message announcing the current real user and effective
user, a link to stop acting as the effective user, and a link to logout.

=cut

sub loginstatus {
	my ($self) = @_;
	my $r = $self->r;
	my $authen = $r->authen;
	my $urlpath = $r->urlpath;
	
	if ($authen and $authen->was_verified) {
		my $courseID = $urlpath->arg("courseID");
		my $userID = $r->param("user");
		my $eUserID = $r->param("effectiveUser");
		
		my $stopActingURL = $self->systemLink($urlpath, # current path
			params => { effectiveUser => $userID },
		);
		my $logoutURL = $self->systemLink($urlpath->newFromModule(__PACKAGE__ . "::Logout", courseID => $courseID));

		my $text = "Logged in as $userID. " . CGI::br() . CGI::a({href=>$logoutURL}, "Log Out");
		
		if ($eUserID ne $userID) {
			$text .= print " | Acting as $eUserID. " . CGI::a({href=>$stopActingURL}, "Stop Acting");
		}
		
		#print CGI::div({class=>"LoginStatus"}, $text); # soon, my friend, soon...
		print $text;
	} else {
		#print CGI::div({class=>"LoginStatus"}, "Not logged in."); # likewise...
		print "Not logged in.";
	}
	
	return "";
}

=item nav($args)

Not defined in this package.

Links to the previous, next, and parent objects.

$args is a reference to a hash containing the following fields:

 style       => text|image
 imageprefix => prefix to prepend to base image URL
 imagesuffix => suffix to append to base image URL
 separator   => HTML to place in between links

If C<style> is "image", image URLs are constructed by prepending C<imageprefix>
and postpending C<imagesuffix> to the image base names defined by the
implementor. (Examples of base names include "Prev", "Next", "ProbSet", and
"Up"). Each concatenated string should form an absolute URL to an image file.
For example:

 <!--#nav style="images" imageprefix="/webwork2_files/images/nav"
          imagesuffix=".gif" separator="  "-->

=cut

#sub nav {  }

=item options()

Not defined in this package.

View options related to the content displayed in the body or info areas. See also
optionsMacro().

=cut

#sub options {  }

=item path($args)

Defined in this package.

Print "breadcrubs" from the root of the virtual hierarchy to the current page.
$args is a reference to a hash containing the following fields:

 style    => type of separator: text|image
 image    => if style=image, URL of image to use as path separator
 text     => if style=text, text to use as path separator
             if style=image, the ALT text of each separator image
 textonly => suppress all HTML, return only plain text

The implementation in this package takes information from the WeBWorK::URLPath
associated with the current request.

=cut

sub path {
	my ($self, $args) = @_;
	my $r = $self->r;
	
	my @path;
	
	my $urlpath = $r->urlpath;
	do {
		unshift @path, $urlpath->name, $r->location . $urlpath->path;
	} while ($urlpath = $urlpath->parent);
	
	$path[$#path] = ""; # we don't want the last path element to be a link
	
	#print "\n<!-- BEGIN " . __PACKAGE__ . "::path -->\n";
	print $self->pathMacro($args, @path);
	#print "<!-- END " . __PACKAGE__ . "::path -->\n";
	
	return "";
}

=item siblings()

Not defined in this package.

Print links to siblings of the current object.

=cut

#sub siblings {  }

=item timestamp()

Defined in this package.

Display the current time and date using default format "3:37pm on Jan 7, 2004".
The display format can be adjusted by giving a style in the template.
For example,

  <!--#timestamp style="%m/%d/%y at %I:%M%P"-->

will give standard WeBWorK time format.  Wording and other formatting
can be done in the template itself.
=cut

sub timestamp {
	my ($self, $args) = @_;
	my $formatstring = "%l:%M%P on %b %e, %Y";
	$formatstring = $args->{style} if(defined($args->{style}));
	return(Date::Format::time2str($formatstring, time()));
}
	
=item submiterror()

Defined in this package.

Print any error messages resulting from the last form submission.

This method is deprecated -- use message() instead

The implementation in this package prints the value of the field
$self->{submitError}, if it is present.

=cut

sub submiterror {
	my ($self) = @_;
	
	print "\n<!-- BEGIN " . __PACKAGE__ . "::submiterror -->\n";
	print $self->{submitError} if exists $self->{submitError};
	print "<!-- END " . __PACKAGE__ . "::submiterror -->\n";
	
	return "";
}

=item message()

Defined in this package.

Print any messages (error or non-error) resulting from the last form submission.
This could be used to give Sucess and Failure messages after an action is performed by a module.

The implementation in this package prints the value of the field
$self->{status_message}, if it is present.

=cut

sub message {
	my ($self) = @_;
	
	print "\n<!-- BEGIN " . __PACKAGE__ . "::message -->\n";
	print $self->{status_message} if exists $self->{status_message};
	
	print "<!-- END " . __PACKAGE__ . "::message -->\n";
	
	return "";
}

=item title()

Defined in this package.

Print the title of the current page.

The implementation in this package takes information from the WeBWorK::URLPath
associated with the current request.

=cut

sub title {
	my ($self, $args) = @_;
	my $r = $self->r;
	
	#print "\n<!-- BEGIN " . __PACKAGE__ . "::title -->\n";
	print underscore2nbsp($r->urlpath->name);
	#print "<!-- END " . __PACKAGE__ . "::title -->\n";
	
	return "";
}

=item warnings()

Defined in this package.

Print accumulated warnings.

The implementation in this package checks for a note in the request named
"warnings". If present, its contents are formatted and returned.

=cut

sub warnings {
	my ($self) = @_;
	my $r = $self->r;
	
	print "\n<!-- BEGIN " . __PACKAGE__ . "::warnings -->\n";
	print $self->warningOutput($r->notes("warnings")) if $r->notes("warnings");
	print "<!-- END " . __PACKAGE__ . "::warnings -->\n";
	
	return "";
}

=item help()

Display a link to context-sensitive help. If the argument C<name> is defined,
the link will be to the help document for that name. Otherwise the module of the
WeBWorK::URLPath node for the current system location will be used.

=cut

sub help {
	my $self = shift;
	my $args = shift;
	my $name = $args->{name};

	# old naming scheme
	#$name = lc($self->r->urlpath->name) unless defined($name);
	#$name =~ s/\s/_/g;

	$name = $self->r->urlpath->module unless defined($name);
	$name =~ s/WeBWorK::ContentGenerator:://;
	$name =~ s/://g;

	$self->helpMacro($name);
}

=item url($args)

Defined in this package.

Returns the specified URL from either %webworkURLs or %courseURLs in the course
environment. $args is a reference to a hash containing the following fields:

 type => type of URL: webwork|course
 name => name of URL (key in URL hash)

=cut

sub url {
	my ($self, $args) = @_;
	my $ce = $self->r->ce;
	my $type = $args->{type};
	my $name = $args->{name};
	
	if ($type eq "webwork") {
		return $ce->{webworkURLs}->{$name};
	} elsif ($type eq "course") {
		return $ce->{courseURLs}->{$name};
	} else {
		warn __PACKAGE__."::url: unrecognized type '$type'.\n";
	}
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Conditional predicates

Conditional predicate methods are invoked when the C<#if> escape sequence is
encountered in the template. If a method named C<if_predicate> is defined in
here or in the instantiated subclass, it is invoked.

The following predicates are currently defined:

=over

=item if_can($function)

If a function named $function is present in the current content generator (or
any superclass), a true value is returned. Otherwise, a false value is returned.

The implementation in this package uses the method UNIVERSAL->can(function) to
arrive at the result.

A subclass could redefine this method to, for example, "hide" a method from the
template:

 sub if_can {
 	my ($self, $arg) = @_;
 	
 	if ($arg eq "floobar") {
 		return 0;
 	} else {
 		return $self->SUPER::if_can($arg);
 	}
 }

=cut

sub if_can {
	my ($self, $arg) = @_;
	
	return $self->can($arg) ? 1 : 0;
}

=item if_loggedin($arg)

If the user is currently logged in, $arg is returned. Otherwise, the inverse of
$arg is returned.

#The implementation in this package always returns $arg, since most content
#generators are only reachable when the user is authenticated. It is up to
#classes that can be reached without logging in to override this method and
#provide the correct behavior.
#
#This is suboptimal, and may change in the future.

The implementation in this package uses WeBWorK::Authen::was_verified() to
retrieve the result of the last call to WeBWorK::Authen::verify().

=cut

sub if_loggedin {
	my ($self, $arg) = @_;
	
	#return $arg;
	return 0 unless $self->r->authen;
	return $self->r->authen->was_verified() ? $arg : !$arg;
}

=item if_submiterror($arg)

If the last form submission generated an error, $arg is returned. Otherwise, the
inverse of $arg is returned.

The implementation in this package checks for the field $self->{submitError} to
determine if an error condition is present.

If a subclass uses some other method to classify submission results, this method could be
redefined to handle that variance:

 sub if_submiterror {
 	my ($self, $arg) = @_;
 	
 	my $status = $self->{processReturnValue};
 	if ($status != 0) {
 		return $arg;
 	} else {
 		return !$arg;
 	}
 }

=cut

sub if_submiterror {
	my ($self, $arg) = @_;
	
	if (exists $self->{submitError}) {
		return $arg;
	} else {
		return !$arg;
	}
}

=item if_message($arg)

If the last form submission generated a message, $arg is returned. Otherwise, the
inverse of $arg is returned.

The implementation in this package checks for the field $self->{status_message} to
determine if a message is present.

If a subclass uses some other method to classify submission results, this method could be
redefined to handle that variance:

 sub if_message {
 	my ($self, $arg) = @_;
 	
 	my $status = $self->{processReturnValue};
 	if ($status != 0) {
 		return $arg;
 	} else {
 		return !$arg;
 	}
 }

=cut

sub if_message {
	my ($self, $arg) = @_;
	
	if (exists $self->{status_message}) {
		return $arg;
	} else {
		return !$arg;
	}
}

=item if_warnings

If warnings have been emitted while handling this request, $arg is returned.
Otherwise, the inverse of $arg is returned.

The implementation in this package checks for a note in the request named
"warnings". This is set by the WARN handler in Apache::WeBWorK when a warning is
handled.

=cut

sub if_warnings {
	my ($self, $arg) = @_;
	my $r = $self->r;
	
	if ($r->notes("warnings")) {
		return $arg;
	} else {
		!$arg;
	}
}

=back

=cut

################################################################################

=head1 HTML MACROS

Various routines are defined in this package for rendering common WeBWorK
idioms.

FIXME: some of these should be moved to WeBWorK::HTML:: modules!

# ------------------------------------------------------------------------------

=head2 Template escape handler macros

These methods are used by implementations of the escape sequence handlers to
maintain a consistent style.

=over

=item pathMacro($args, @path)

Helper macro for the C<#path> escape sequence: $args is a hash reference
containing the "style", "image", "text", and "textonly" arguments to the escape.
@path consists of ordered key-value pairs of the form:

 "Page Name" => URL

If the page should not have a link associated with it, the URL should be left
empty. Authentication data is added to each URL so you don't have to. A fully-
formed path line is returned, suitable for returning by a function implementing
the C<#path> escape.

FIXME: authentication data probably shouldn't be added here any more, now that
we have systemLink().

=cut

sub pathMacro {
	my ($self, $args, @path) = @_;
	my %args = %$args;
	$args{style} = "text" if $args{textonly};
	
	my $auth = $self->url_authen_args;
	my $sep;
	if ($args{style} eq "image") {
		$sep = CGI::img({-src=>$args{image}, -alt=>$args{text}});
	} else {
		$sep = $args{text};
	}
	
	my @result;
	while (@path) {
		my $name = shift @path;
		my $url = shift @path;
		if ($url and not $args{textonly}) {
			push @result, CGI::a({-href=>"$url?$auth"}, $name);
		} else {
			push @result, $name;
		}
	}
	
	return join($sep, @result), "\n";
}

=item siblingsMacro(@siblings)

Helper macro for the C<#siblings> escape sequence. @siblings consists of ordered
key-value pairs of the form:

 "Sibling Name" => URL

If the sibling should not have a link associated with it, the URL should be left
empty. Authentication data is added to each URL so you don't have to. A fully-
formed siblings block is returned, suitable for returning by a function
implementing the C<#siblings> escape.

FIXME: authentication data probably shouldn't be added here any more, now that
we have systemLink().

=cut

sub siblingsMacro {
	my ($self, @siblings) = @_;
	
	my $auth = $self->url_authen_args;
	my $sep = CGI::br();
	
	my @result;
	while (@siblings) {
		my $name = shift @siblings;
		my $url = shift @siblings;
		push @result, $url
			? CGI::a({-href=>"$url?$auth"}, $name)
			: $name;
	}
	
	return join($sep, @result) . "\n";
}



=item navMacro($args, $tail, @links)

Helper macro for the C<#nav> escape sequence: $args is a hash reference
containing the "style", "imageprefix", "imagesuffix", and "separator" arguments
to the escape. @siblings consists of ordered tuples of the form:

 "Link Name", URL, ImageBaseName

If the sibling should not have a link associated with it, the URL should be left
empty. ImageBaseName is placed between the C<imageprefix> and C<imagesuffix>.
Authentication data is added to each URL so you don't have to. $tail is appended
to each URL, after the authentication information. A fully-formed nav line is
returned, suitable for returning by a function implementing the C<#nav> escape.

=cut

sub navMacro {
	my ($self, $args, $tail, @links) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my %args = %$args;
	
	my $auth = $self->url_authen_args;
	my $prefix = $ce->{webworkURLs}->{htdocs}."/images";
	
	my @result;
	while (@links) {
		my $name = shift @links;
		my $url = shift @links;
		my $img = shift @links;
		my $html = 
			($img && $args{style} eq "images") 
			? CGI::img(
				{src=>($prefix."/".$img.$args{imagesuffix}), 
				border=>"",
				alt=>"$name"})
			: $name;
		unless($img && !$url) {
			push @result, $url
				? CGI::a({-href=>"$url?$auth$tail"}, $html)
				: $html;
		}
	}
	
	return join($args{separator}, @result) . "\n";
}

=item helpMacro($name)

This escape is represented by a question mark which links to an html page in the
helpFiles  directory.  Currently the link is made to the file $name.html

=cut

sub helpMacro {
    my $self = shift;
	my $name = shift;
	my $ce   = $self->r->ce;
	my $basePath = $ce->{webworkDirs}->{local_help};
	$name        = 'no_help' unless -e "$basePath/$name.html";
	my $path     = "$basePath/$name.html";
	my $url = $ce->{webworkURLs}->{local_help}."/$name.html";
	my $imageURL = $ce->{webworkURLs}->{htdocs}."/images/question_mark.png";
	return CGI::a({href      => $url,
	               target    => 'ww_help',
	               onclick   => "window.open(this.href,this.target,'width=550,height=350,scrollbars=yes,resizable=on')"},
	               CGI::img({src=>$imageURL}));
}

=item optionsMacro(options_to_show => \@options_to_show, extra_params => \@extra_params)

Helper macro for displaying the View Options panel.

@options_to_show lists the options to show, from among this list "displayMode",
"showOldAnswers", "showHints", "showSolutions". If no options are given,
"displayMode" is assumed.

@extraParams is dereferenced and passed to the hidden_fields() method. Use this
to preserve state from the content generator calling optionsMacro().

This macro is intended to be called from an implementation of the options()
method. The simplest way to to this is:

 sub options { shift->optionsMacro }

=cut

sub optionsMacro {
	my ($self, %options) = @_;
	debug("HELLO WORLD!");
	my @options_to_show = @{$options{options_to_show}} if exists $options{options_to_show};
	@options_to_show = "displayMode" unless @options_to_show;
	my %options_to_show; @options_to_show{@options_to_show} = (); # make hash for easy lookups
	my @extra_params = @{$options{extra_params}} if exists $options{extra_params};
	
	my $result = CGI::start_form("POST", $self->r->uri);
	$result .= $self->hidden_authen_fields;
	$result .= $self->hidden_fields(@extra_params) if @extra_params;
	$result .= CGI::start_div({class=>"viewOptions"});
	
	if (exists $options_to_show{displayMode}) {
		my $curr_displayMode = $self->r->param("displayMode") || $self->r->ce->{pg}->{options}->{displayMode};
		my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
		my @active_modes = grep { exists $display_modes{$_} } @{$self->r->ce->{pg}->{displayModes}};
		if (@active_modes > 1) {
			$result .= "View&nbsp;equations&nbsp;as:&nbsp;&nbsp;&nbsp;&nbsp;";
			$result .= CGI::br();
			$result .= CGI::radio_group(
				-name => "displayMode",
				-values => \@active_modes,
				-default => $curr_displayMode,
				-linebreak=>'true',
			);
			$result .= CGI::br();
		}
	}
	
	if (exists $options_to_show{showOldAnswers}) {
		# Note, 0 is a legal value, so we can't use || in setting this
		my $curr_showOldAnswers = defined($self->r->param("showOldAnswers")) ?
			$self->r->param("showOldAnswers") : $self->r->ce->{pg}->{options}->{showOldAnswers};
		$result .= "Show&nbsp;saved&nbsp;answers?";
		$result .= CGI::br();
		$result .= CGI::radio_group(
			-name => "showOldAnswers",
			-values => [1,0],
			-default => $curr_showOldAnswers,
			-labels => { 0=>'No', 1=>'Yes' },
		);
		$result .= CGI::br();
	}
	
	$result .= CGI::br();
	$result .= CGI::submit(-name=>"redisplay", -label=>"Apply Options");
	$result .= CGI::end_div();
	$result .= CGI::end_form();
	
	return $result;
}

=item feedbackMacro(%params)

Helper macro for displaying the feedback form. Returns a button named "Email
Instructor". %params contains the request parameters accepted by the Feedback
module and their values.

=cut

sub feedbackMacro {
	my ($self, %params) = @_;
	my $r = $self->r;
	my $userID = $r->param("user");
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	my $courseID = $urlpath->arg("courseID");
	
	# don't do anything unless the user has permission to
	return "" unless $authz->hasPermissions($userID, "submit_feedback");
	
	# feedback form url
	my $feedbackPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Feedback", courseID => $courseID);
	my $feedbackURL = $self->systemLink($feedbackPage, authen => 0); # no authen info for form action
	
	my $result = CGI::start_form(-method=>"POST", -action=>$feedbackURL) . "\n";
	$result .= $self->hidden_authen_fields . "\n";
	
	while (my ($key, $value) = each %params) {
		$result .= CGI::hidden($key, $value) . "\n";
	}

	$result .= CGI::p({-align=>"left"}, CGI::submit(-name=>"feedbackForm", -label=>"Email instructor"));
	$result .= CGI::endform() . "\n";
	
	return $result;
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Parameter management

Methods for formatting request parameters as hidden form fields or query string
fragments.

=over

=item hidden_fields(@fields)

Return hidden <INPUT> tags for each field mentioned in @fields (or all fields if
list is empty), taking data from the current request.

=cut

sub hidden_fields {
	my ($self, @fields) = @_;
	my $r = $self->r;
	
	@fields = $r->param unless @fields;
	
	my $html = "";
	foreach my $param (@fields) {
		my @values = $r->param($param);
		$html .= CGI::hidden($param, @values);
	}
	return $html;
}

=item hidden_authen_fields()

Use hidden_fields to return hidden <INPUT> tags for request fields used in
authentication.

=cut

sub hidden_authen_fields {
	my ($self) = @_;
	
	return $self->hidden_fields("user", "effectiveUser", "key");
}

=item hidden_proctor_authen_fields()

Use hidden_fields to return hidden <INPUT> tags for request fields used in
proctor authentication.

=cut

sub hidden_proctor_authen_fields {
	my $self = shift;
	if ( $self->r->param('proctor_user') ) {
		return $self->hidden_fields("proctor_user", "proctor_key");
	} else {
		return '';
	}
}

=item hidden_state_fields()

Use hidden_fields to return hidden <INPUT> tags for request fields used to
maintain state. Currently includes authentication fields and display option
fields.

=cut

sub hidden_state_fields {
	my ($self) = @_;
	
	return $self->hidden_authen_fields();
	
	# other things that may be state data:
	#$self->hidden_fields("displayMode", "showOldAnswers", "showCorrectAnswers", "showHints", "showSolutions");
}

=item url_args(@fields)

Return a URL query string (without the leading `?') containing values for each
field mentioned in @fields, or all fields if list is empty. Data is taken from
the current request.

=cut

sub url_args {
	my ($self, @fields) = @_;
	my $r = $self->r;
	
	@fields = $r->param unless @fields;
	
	my @pairs;
	foreach my $param (@fields) {
		my @values = $r->param($param);
		foreach my $value (@values) {
			push @pairs, uri_escape($param) . "=" . uri_escape($value);
		}
	}
	
	return join("&", @pairs);
}

=item url_authen_args()

Use url_args to return a URL query string for request fields used in
authentication.

=cut

sub url_authen_args {
	my ($self) = @_;
	
	return $self->url_args("user", "effectiveUser", "key");
}

=item url_state_args()

Use url_args to return a URL query string for request fields used to maintain
state. Currently includes authentication fields and display option fields.

=cut

sub url_state_args {
	my ($self) = @_;
	
	return $self->url_authen_args;
	
	# other things that may be state data:
	#$self->url_args("displayMode", "showOldAnswers", "showCorrectAnswers", "showHints", "showSolutions");
}

# This method is not used anywhere! --sam(1-Aug-05)
#
#=item url_display_args()
#
#Use url_args to return a URL query string for request fields used in
#authentication.
#
#=cut
#
#sub url_display_args {
#	my ($self) = @_;
#	
#	return $self->url_args("displayMode", "showOldAnswer");
#}

# This method is not used anywhere! --sam(1-Aug-05)
#
#=item print_form_data($begin, $middle, $end, $omit)
#
#Return a string containing every request field not matched by the quoted reguar
#expression $omit, placing $begin before each field name, $middle between each
#field name and its value, and $end after each value. Values are taken from the
#current request.
#
#=cut
#
#sub print_form_data {
#	my ($self, $begin, $middle, $end, $qr_omit) = @_;
#	my $r=$self->r;
#	my @form_data = $r->param;
#	
#	my $return_string = "";
#	foreach my $name (@form_data) {
#		next if ($qr_omit and $name =~ /$qr_omit/);
#		my @values = $r->param($name);
#		foreach my $variable (qw(begin name middle value end)) {
#			# FIXME: can this loop be moved out of the enclosing loop?
#			no strict 'refs';
#			${$variable} = "" unless defined ${$variable};
#		}
#		foreach my $value (@values) {
#			$return_string .= "$begin$name$middle$value$end";
#		}
#	}
#	
#	return $return_string;
#}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Utilities

=over

=item systemLink($urlpath, %options)

Generate a link to another part of the system. $urlpath is WeBWorK::URLPath
object from which the base path will be taken. %options can consist of:

=over

=item params

Can be either a reference to an array or a reference to a hash.

If it is a reference to a hash, it maps parmaeter names to values. These
parameters will be included in the generated link. If a value is an arrayref,
the values of the array referenced will be used. If a value is undefined, the
value from the current request will be used.

If C<params> is an arrayref, it is interpreted as a list of parameter names.
These parameters will be included in the generated link, using the values from
the current request.

Unless C<authen> is false (see below), the authentication parameters (C<user>,
C<effectiveUser>, and C<key>) are included with their default values.

=item authen

If set to a false value, the authentication parameters (C<user>,
C<effectiveUser>, and C<key>) are included in the the generated link unless
explicitly listed in C<params>.

=back

=cut

# FIXME: there should probably be an option for prepending "http://hostname:port"
sub systemLink {
	my ($self, $urlpath, %options) = @_;
	my $r = $self->r;
	
	my %params = ();
	if (exists $options{params}) {
		if (ref $options{params} eq "HASH") {
			%params = %{ $options{params} };
		} elsif (ref $options{params} eq "ARRAY") {
			my @names = @{ $options{params} };
			@params{@names} = ();
		} else {
			croak "option 'params' is not a hashref or an arrayref";
		}
	}
	
	my $authen = exists $options{authen} ? $options{authen} : 1;
	if ($authen) {
		$params{user}          = undef unless exists $params{user};
		$params{effectiveUser} = undef unless exists $params{effectiveUser};
		$params{key}           = undef unless exists $params{key};
	}
	
	my $url = $r->location . $urlpath->path;
	my $first = 1;
	
	foreach my $name (keys %params) {
		my $value = $params{$name};
		
		my @values;
		if (defined $value) {
			if (ref $value eq "ARRAY") {
				@values = @$value;
			} else {
				@values = $value;
			}
		} elsif (defined $r->param($name)) {
			@values = $r->param($name);
		}
		#FIXME  -- evntually we'd like to catch where this happens
		if ($name eq 'user' and @values >1 )    {
			warn "internal error --  user has been multiply defined! You may need to logout and log back in to correct this.";
			my $user = $r->param("user");
			$r->param(user => $user);
		    @values = ($user);
		    warn "requesting page is ", $r->headers_in->{'Referer'};
		    warn "Parameters are ", join("|",$r->param());

		}
		 
		if (@values) {
			if ($first) {
				$url .= "?";
				$first = 0;
			} else {
				$url .= "&";
			}
			$url .= join "&", map { "$name=$_" } @values;
		}
	}
	
	return $url;
}

=item nbsp($string)

If string consists of only whitespace, the HTML entity C<&nbsp;> is returned.
Otherwise $string is returned.

=cut

sub nbsp {
	my ($self, $str) = @_;
	return (defined $str && $str =~/\S/) ? $str : "&nbsp;";
}

=item sp2nbsp($string)

A copy of $string is returned with each space character replaced by the
C<&nbsp;> entity.

=cut

sub sp2nbsp {
	my ($str) = @_;
	return unless defined $str;
	$str =~ s/\s/&nbsp;/g;
	return $str;
}

=item underscore2nbsp($string)

A copy of $string is returned with each underscore character replaced by the
C<&nbsp;> entity.

=cut

sub underscore2nbsp {
	my ($str) = @_;
	return unless defined $str;
	$str =~ s/_/&nbsp;/g;
	return $str;
}

=item errorOutput($error, $details)

Used by Problem, ProblemSet, and Hardcopy to report errors encountered during
problem rendering.

=cut

sub errorOutput($$$) {
	my ($self, $error, $details) = @_;
	my $r = $self->{r};
	
	my $time = time2str("%a %b %d %H:%M:%S %Y", time);
	my $method = $r->method;
	my $uri = $r->uri;
	my $headers = do {
		my %headers = $r->headers_in;
		join("", map { CGI::Tr(CGI::td(CGI::small($_)), CGI::td(CGI::small($headers{$_}))) } keys %headers);
	};

	# if it is a long report pass details by reference rather than by value
	# for consistency we automatically convert all forms of $details into
	# a reference to an array.

	if (ref($details) =~ /SCALAR/i) {
		$details = [$$details];
	} elsif (ref($details) =~/ARRAY/i) {
		# no change needed	
	} else {
	   $details = [$details];
	}
	return
		CGI::h2("WeBWorK Error"),
		CGI::p(<<EOF),
WeBWorK has encountered a software error while attempting to process this
problem. It is likely that there is an error in the problem itself. If you are a
student, report this error message to your professor to have it corrected. If
you are a professor, please consult the error output below for more information.
EOF
		CGI::h3("Error messages"),

		CGI::p(CGI::code($error)),
		CGI::h3("Error details"),
		
		CGI::start_code(), CGI::start_p(),
		@{ $details },
		#CGI::code(CGI::p(@expandedDetails)), 
		# not using inclusive CGI calls here saves about 30Meg of memory!
		CGI::end_p(),CGI::end_code(),
		
		CGI::h3("Request information"),
		CGI::table({border=>"1"},
			CGI::Tr(CGI::td("Time"), CGI::td($time)),
			CGI::Tr(CGI::td("Method"), CGI::td($method)),
			CGI::Tr(CGI::td("URI"), CGI::td($uri)),
			CGI::Tr(CGI::td("HTTP Headers"), CGI::td(
				CGI::table($headers),
			)),
		),
	;  
	
}

=item warningOutput($warnings)

Used by warnings() in this class to report warnings caught during dispatching
and content generation.

=cut

sub warningOutput($$) {
	my ($self, $warnings) = @_;
	my $r = $self->{r};
	
	my @warnings = split m/\n+/, $warnings;
	foreach my $warning (@warnings) {
		#$warning = escapeHTML($warning);  # this would prevent using tables in output from answer evaluators
		$warning = CGI::li(CGI::code($warning));
	}
	$warnings = join("", @warnings);
	
	my $time = time2str("%a %b %d %H:%M:%S %Y", time);
	my $method = $r->method;
	my $uri = $r->uri;
	#my $headers = do {
	#	my %headers = $r->headers_in;
	#	join("", map { CGI::Tr(CGI::td(CGI::small($_)), CGI::td(CGI::small($headers{$_}))) } keys %headers);
	#};
	
	return
		CGI::h2("WeBWorK Warnings"),
		CGI::p(<<EOF),
WeBWorK has encountered warnings while processing your request. If this occured
when viewing a problem, it was likely caused by an error or ambiguity in that
problem. Otherwise, it may indicate a problem with the WeBWorK system itself. If
you are a student, report these warnings to your professor to have them
corrected. If you are a professor, please consult the warning output below for
more information.
EOF
		CGI::h3("Warning messages"),
		CGI::ul($warnings),
		CGI::h3("Request information"),
		CGI::table({border=>"1"},
			CGI::Tr(CGI::td("Time"), CGI::td($time)),
			CGI::Tr(CGI::td("Method"), CGI::td($method)),
			CGI::Tr(CGI::td("URI"), CGI::td($uri)),
			#CGI::Tr(CGI::td("HTTP Headers"), CGI::td(
			#	CGI::table($headers),
			#)),
		);
}

=item $dateTime = parseDateTime($string, $display_tz)

Parses $string as a datetime. If $display_tz is given, $string is assumed to be
in that timezone. Otherwise, the timezone defined in the course environment
variable $siteDefaults{timezone} is used. The result, $dateTime, is an integer
UNIX datetime (epoch) in the server's timezone.

=cut

sub parseDateTime {
	my ($self, $string, $display_tz) = @_;
	my $ce = $self->r->ce;
	$display_tz ||= $ce->{siteDefaults}{timezone};
	return WeBWorK::Utils::parseDateTime($string, $display_tz);
};

=item $string = formatDateTime($dateTime, $display_tz)

Formats the UNIX datetime $dateTime in the standard WeBWorK datetime format.
$dateTime is assumed to be in the server's time zone. If $display_tz is given,
the datetime is converted from the server's timezone to the timezone specified.
Otherwise, the timezone defined in the course environment variable
$siteDefaults{timezone} is used.

=cut

sub formatDateTime {
	my ($self, $dateTime, $display_tz) = @_;
	my $ce = $self->r->ce;
	$display_tz ||= $ce->{siteDefaults}{timezone};
	return WeBWorK::Utils::formatDateTime($dateTime, $display_tz);
}

=back

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu and Sam Hathaway,
sh002i (at) math.rochester.edu.

=cut

1;
