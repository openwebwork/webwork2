################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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
use Carp;
#use CGI qw(-nosticky *ul *li escapeHTML);
use WeBWorK::CGI;
use WeBWorK::File::Scoring qw/parse_scoring_file/;
use Date::Format;
use URI::Escape;
use WeBWorK::Debug;
use WeBWorK::PG;
use MIME::Base64;
use WeBWorK::Template qw(template);
use WeBWorK::Localize;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );
use Scalar::Util qw(weaken);
use HTML::Entities;
use HTML::Scrubber;
use WeBWorK::Utils qw(jitar_id_to_seq fetchEmailRecipients generateURLs);
use WeBWorK::Authen::LTIAdvanced::SubmitGrade;
use Encode;

our $TRACE_WARNINGS = 0;   # set to 1 to trace channel used by warning message


BEGIN {
	if (MP2) {
		require Apache2::Const;
		Apache2::Const->import(-compile => qw/OK NOT_FOUND FORBIDDEN SERVER_ERROR REDIRECT/);
	} else {
		require Apache::Constants;
		Apache::Constants->import(qw/OK NOT_FOUND FORBIDDEN SERVER_ERROR REDIRECT/);
	}
}

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
		noContent => undef, # FIXME this should get clobbered at some point
		   };
 	weaken $self -> {r};
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

=item 5

The method content() is called to send the page content to client.

=back

=cut

sub go {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	# If grades are begin passed back to the lti then we peroidically
	# update all of the grades because things can get out of sync if
	# instructors add or modify sets.
	if ($ce->{LTIGradeMode} and ref($r->{db}//'')  ) {

	  my $grader = WeBWorK::Authen::LTIAdvanced::SubmitGrade->new($r);

	  my $post_connection_action = sub {
	    my $grader = shift;

	    # catch exceptions generated during the sending process
	    my $result_message = eval { $grader->mass_update() };
	    if ($@) {
	      # add the die message to the result message
	      $result_message .= "An error occurred while trying to update grades via LTI.\n"
		. "The error message is:\n\n$@\n\n";
	      # and also write it to the apache log
	      $r->log->error("An error occurred while trying to update grades via LTI: $@\n");
	    }
	  };
	  if (MP2) {
	    $r->connection->pool->cleanup_register($post_connection_action, $grader);
	  } else {
	    $r->post_connection($post_connection_action, $grader);
	  }

	}

	# check to verify if there are set-level problems with running
	#    this content generator (individual content generators must
	#    check $self->{invalidSet} and react correctly)
	my $authz = $r->authz;
	$self->{invalidSet} = $authz->checkSet();

	my $returnValue = MP2 ? Apache2::Const::OK : Apache::Constants::OK;

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
	return MP2 ? Apache2::Const::NOT_FOUND : Apache::Constants::NOT_FOUND unless -e $source;
	return MP2 ? Apache2::Const::FORBIDDEN : Apache::Constants::FORBIDDEN unless -r $source;

	my $fh;
	if (!MP2) {
		# open the file now, so we can send the proper error status is we fail
		open $fh, "<", $source or return Apache::Constants::SERVER_ERROR;
	}

	# send our custom HTTP header
	$r->content_type($type);
	$r->headers_out->{"Content-Disposition"} = "attachment; filename=\"$name\"";
	$r->send_http_header unless MP2;

	# send the file
	if (MP2) {
		$r->sendfile($source);
	} else {
		$r->send_fd($fh);
	}

	if (!MP2) {
		# close the file and go home
		close $fh;
	}

	if ($delete_after) {
		unlink $source or warn "failed to unlink $source after sending: $!";
	}

	return; # (see comment on return statement in do_reply_with_redirect, below.)
}

=item do_reply_with_redirect($url)

Handler for reply_with_redirect(), used by go(). DO NOT CALL THIS METHOD DIRECTLY.

=cut

sub do_reply_with_redirect {
	my ($self, $url) = @_;
	my $r = $self->r;

	$r->status(MP2 ? Apache2::Const::REDIRECT : Apache::Constants::REDIRECT);
	$r->headers_out->{"Location"} = $url;
	$r->send_http_header unless MP2;

	return; # we need to explicitly return noting here, otherwise we return $url under Apache2.
	        # the return value from the mod_perl handler is used to set the HTTP status code,
	        # but we're setting it explicitly above. i think we should dispense with setting it
	        # with the return value altogether, and always do it with $r->status. the other way
	        # is too oblique and error-prone. this is probably a FIXME.
	        #
	        # Apache::WeBWorK::handler always returns the value it got from WeBWorK::dispatch
	        # WeBWorK::dispatch always returns the value it got from WW::ContentGenerator::go
	        # WW::ContentGenerator::go works like this:
	        #		- if reply_with_file, return the return value from do_reply_with_file
	        #		  (do_reply_with_file actually uses this to return NOT_FOUND/FORBIDDEN)
	        #		- if reply_with_redirect, return the return value from do_reply_with_redirect
	        #		  (do_reply_with_redirect does NOT use this -- it sets $r->status instead!)
	        #		- if header returns a defined value, return that
	        #		  (CG::header always returns OK!)
	        #		- otherwise, return OK (this never happens!)
	        # there are no longer any legitimate header() methods other than the one in CG.pm
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
    #addmessages takes html so we use htmlscrubber to get rid of
    # any scripts or html comments.  However, we leave everything else
    # by default.

	my ($self, $message) = @_;
	return unless defined($message);

	my $scrubber = HTML::Scrubber->new(
	    default => 1,
	    script => 0,
	    comment => 0
	    );
	$scrubber->default(
	    undef,
	    {
		'*' => 1,
	    }
	    );

	$message = $scrubber->scrub($message);
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

	$r->content_type("text/html; charset=utf-8");
	$r->send_http_header unless MP2;
	return MP2 ? Apache2::Const::OK : Apache::Constants::OK;
}

=item initialize()

Not defined in this package.

May be defined by a subclass to perform any processing that must occur after the
HTTP header is sent but before any content is sent.

=cut

#sub initialize {  }

=item output_course_lang_and_dir()

Output the LANG and DIR tags in the main HTML tag of a generated web page when
a template files calls this function.

This calls WeBWorK::Utils::LanguageAndDirection::get_lang_and_dir.

=cut

sub output_course_lang_and_dir{
	my $self = shift;
	print WeBWorK::Utils::LanguageAndDirection::get_lang_and_dir($self->r->ce->{language});
	return "";
}

=item webwork_logo()

Create the link to the webwork installation landing page with a logo and alt text

=cut

sub webwork_logo {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $theme = $r->param("theme") || $ce->{defaultTheme};
	my $htdocs = $ce->{webwork_htdocs_url};
	print CGI::a(
		{href => $ce->{webwork_url}},
		CGI::img({
			src => "$htdocs/themes/$theme/images/webwork_logo.svg",
			alt => $r->maketext("to courses page")
		},'')
	);
	return "";
}

=item institution_logo()

Create the link to the host institution with a logo and alt text

=cut

sub institution_logo {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $theme = $r->param("theme") || $ce->{defaultTheme};
	my $htdocs = $ce->{webwork_htdocs_url};
	print CGI::a(
		{href => $ce->{institutionURL}},
		CGI::img({
			src => "$htdocs/themes/$theme/images/" . $ce->{institutionLogo},
			alt => $r->maketext("to [_1] main web site", $ce->{institutionName})
		},'')
	);
	return "";
}

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
	my $r = $self->r;
	my $ce = $r->ce;

	my $themesDir = $ce->{webworkDirs}{themes};
	my $theme = $r->param("theme") || $ce->{defaultTheme};
	$theme = $ce->{defaultTheme} if $theme =~ m!(?:^|/)\.\.(?:/|$)!;
	#$ce->{webworkURLs}->{stylesheet} = ($ce->{webworkURLs}->{htdocs})."/css/$theme.css";   # reset the style sheet
	# the line above is clever -- but I think it is better to link directly to the style sheet from the system.template
	# then the link between template and css is made in .template file instead of hard coded as above
	# this means that the {stylesheet} option in defaults.config is never used
	my $template = $self->can("templateName") ? $self->templateName : $ce->{defaultThemeTemplate};
	my $templateFile = "$themesDir/$theme/$template.template";
	unless (-r $templateFile) {  #hack to prevent disaster when missing theme directory
	   if (-r "$themesDir/math4/$template.template") {
	   		$templateFile = "$themesDir/math4/$template.template";
			$theme = HTML::Entities::encode_entities($theme);
	   		warn "Theme $theme is not one of the available themes. ".
	   		"Please check the theme configuration ".
	   		"in the files localOverrides.conf, course.conf and ".
	   		"simple.conf and on the course configuration page.\n"
	   	} else {
			$theme = HTML::Entities::encode_entities($theme);
	   		die "Neither the theme $theme nor the defaultTheme math4 are available.  ".
	   		"Please notify your site administrator that the structure of the ".
	   		"themes directory needs attention.";

	   	}
	}
	template($templateFile, $self);
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
	my $ce = $r->ce;
	my $db = $r->db;
	my $authen = $r->authen;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	# we don't currently have any links to display if the user's not logged in. this may change, though.
	#return "" unless $authen->was_verified;

	# grab some interesting data from the request
	my $courseID = $urlpath->arg("courseID");
	my $userID = $r->param('user');
	my $eUserID   = $r->param("effectiveUser");
	my $setID     = $urlpath->arg("setID");
	my $problemID = $urlpath->arg("problemID");
	my $achievementID = $urlpath->arg("achievementID");

	my $prettySetID = $setID;
	my $prettyAchievementID = $achievementID;
	$prettySetID =~ s/_/ /g if defined $prettySetID;
	$prettyAchievementID =~ s/_/ /g if defined $prettyAchievementID;

	my $prettyProblemID = $problemID;

	# it's possible that the setID and the problemID are invalid, since they're just taken from the URL path info
	if ($authen->was_verified) {
		# DBFIXME testing for existence by keyfields -- don't need fetch record
		if (defined $setID and $db->getUserSet($eUserID, $setID)) {

			if (defined $problemID and $db->getUserProblem($eUserID, $setID, $problemID)) {
				# both set and poblem exist -- do nothing
			} else {
				$problemID = undef;
			}
		} else {
			$setID = undef;
			$problemID = undef;
		}
	}

	# experimental subroutine for generating links, to clean up the rest of the
	# code. ignore for now. (this is a closure over $self.)
	my $makelink = sub {
		my ($module, %options) = @_;

		my $urlpath_args = $options{urlpath_args} || {};
		my $systemlink_args = $options{systemlink_args} || {};
		my $text = HTML::Entities::encode_entities($options{text});
		my $active = $options{active};
		my %target = ($options{target} ? (target => $options{target}) : ());

		my $new_urlpath = $self->r->urlpath->newFromModule($module, $r, %$urlpath_args);
		my $new_systemlink = $self->systemLink($new_urlpath, %$systemlink_args);

		defined $text or $text = $new_urlpath->name;  #too clever


		# try to set $active automatically by comparing
		if (not defined $active) {
			if ($urlpath->module eq $new_urlpath->module) {
				my @args = sort keys %{{$urlpath->args}};
				my @new_args = sort keys %{{$new_urlpath->args}};
				if (@args == @new_args) {
					foreach my $i (0 .. $#args) {
						$active = 0;
						last if $args[$i] ne $new_args[$i];
						$active = 1;
					}
				} else {
					$active = 0;
				}
			} else {
				$active = 0;
			}
		}

		my $new_anchor;
		if ($active) {
			# add active class for current location
			$new_anchor = CGI::a({href=>$new_systemlink, class=>"active", %target}, $text);
		} else {
			$new_anchor = CGI::a({href=>$new_systemlink, %target}, "$text");
		}

		return $new_anchor;
	};

	# to make things more concise
	my $pfx = "WeBWorK::ContentGenerator::";
	my %args = ( courseID => $courseID );

	# we'd like to preserve displayMode and showOldAnswers between pages, and we
	# don't have a general way of preserving non-authen params between requests,
	# so here is the hack:
	my %params;
	$params{displayMode} = $r->param("displayMode") if defined $r->param("displayMode");
	$params{showOldAnswers} = $r->param("showOldAnswers") if defined $r->param("showOldAnswers");
	# in the past, we were checking $self->{displayMode} and $self->{will}->{showOldAnswers}
	# to set these args, but I don't wanna do that anymore, since it relies on
	# fields specific to Problem.pm (pretty sure). The only differences in this
	# approach are:
	# (a) displayMode will not be set if it wasn't set in the current request,
	# but this is ok since the resulting page will just use the default value
	# (b) showOldAnswers will get set to the value specified in the current
	# request, regardless of whether it is allowed, but this is OK since we
	# always this value before using it.
	my %systemlink_args;
	$systemlink_args{params} = \%params if %params;

	print CGI::start_ul();
	print CGI::start_li({class => "nav-header"});
	print CGI::h2($r->maketext("Main Menu"));
	print CGI::end_li();
	print CGI::start_li(); # Courses
	print &$makelink("${pfx}Home", text=>$r->maketext("Courses"), systemlink_args=>{authen=>0});
	print CGI::end_li(); # end Courses

	if (defined $courseID) {
		if ($authen->was_verified) {
			print CGI::start_li(); # Homework Sets
                        my $primaryMenuName = $r->maketext("Homework Sets");
                        $primaryMenuName = $r->maketext("Course Administration") if ($ce->{courseName} eq 'admin');
			print &$makelink("${pfx}ProblemSets", text=>$primaryMenuName, urlpath_args=>{%args}, systemlink_args=>\%systemlink_args);
			print CGI::end_li();
			if (defined $setID) {
			    print CGI::start_li();
				print CGI::start_ul();
				print CGI::start_li(); # $setID
				# show a link if we're displaying a homework set, or a version
				#    of a gateway assignment; to know if it's a gateway
				#    assignment, we have to get the set record.
				my ($globalSetID) = ( $setID =~ /(.+?)(,v\d+)?$/ );
				my $setRecord = $db->getGlobalSet( $globalSetID );
			    if ($setRecord->assignment_type eq 'jitar'  && defined $problemID) {
				$prettyProblemID = join('.',jitar_id_to_seq($problemID));
			    }
				if ( $setRecord->assignment_type !~ /gateway/ ) {
					print &$makelink("${pfx}ProblemSet", text=>"$prettySetID", urlpath_args=>{%args,setID=>$setID}, systemlink_args=>\%systemlink_args);
				} elsif ($setID =~ /,v(\d)+$/) {
					print &$makelink("${pfx}GatewayQuiz", text=>"$prettySetID", urlpath_args=>{%args,setID=>$setID}, systemlink_args=>\%systemlink_args);
				}
			    print CGI::end_li();

				if (defined $problemID) {
				    print CGI::start_li();
					print CGI::start_ul();
					print CGI::start_li(); # $problemID
					print &$makelink("${pfx}Problem", text=>$r->maketext("Problem [_1]", $prettyProblemID), urlpath_args=>{%args,setID=>$setID,problemID=>$problemID}, systemlink_args=>\%systemlink_args);
					print CGI::end_li(); # end $problemID
					print CGI::end_ul();
				    print CGI::end_li();
				}
				print CGI::end_ul();
			    print CGI::end_li(); # end Homework Sets
			}


				print CGI::li(&$makelink("${pfx}Options", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));

			print CGI::li(&$makelink("${pfx}Grades", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));

			if ($ce->{achievementsEnabled}) {
			    print CGI::li(&$makelink("${pfx}Achievements", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));

			}

			if ($authz->hasPermissions($userID, "access_instructor_tools")) {
				$pfx .= "Instructor::";

				print CGI::start_li(); # Instructor Tools
				print &$makelink("${pfx}Index", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args);
				print CGI::end_li();
				print CGI::start_li();
				print CGI::start_ul();

                #class list editor
				print CGI::li(&$makelink("${pfx}UserList", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));

				# Homework Set Editor
				print CGI::li(&$makelink("${pfx}ProblemSetList", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));

				## only show editor link for non-versioned sets
				if (defined $setID && $setID !~ /,v\d+$/ ) {
				    print CGI::start_li();
				    print CGI::start_ul();

					print CGI::start_li();
					print &$makelink("${pfx}ProblemSetDetail", text => "$prettySetID", urlpath_args => { %args, setID => $setID }, systemlink_args => \%systemlink_args);
					print CGI::end_li();

					if (defined $problemID) {
					    print CGI::start_li();
					    print CGI::start_ul();
						print CGI::li(&$makelink("${pfx}PGProblemEditor", text=>"$prettyProblemID", urlpath_args=>{%args,setID=>$setID,problemID=>$problemID}, systemlink_args=>\%systemlink_args, target=>"WW_Editor"));
					    print CGI::end_ul();
					    print CGI::end_li();
					}

					print CGI::end_ul();
				    print CGI::end_li();
				}

				print CGI::li(&$makelink("${pfx}SetMaker", text=>$r->maketext("Library Browser"), urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));

				print CGI::start_li(); # Stats
				print &$makelink("${pfx}Stats", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args);
				if ($userID ne $eUserID or defined $setID) {
					print CGI::start_ul();
					if ($userID ne $eUserID) {
						print CGI::li(&$makelink("${pfx}Stats", text=>"$eUserID", urlpath_args=>{%args,statType=>"student",userID=>$eUserID}, systemlink_args=>\%systemlink_args));
					}
					if (defined $setID) {
						# make sure we don't try to send a versioned
						#    set id in to the stats link
						my ( $nvSetID ) = ( $setID =~ /(.+?)(,v\d+)?$/ );
						my ( $nvPretty ) = ( $prettySetID =~ /(.+?)(,v\d+)?$/ );
						print CGI::li(&$makelink("${pfx}Stats", text=>"$nvPretty", urlpath_args=>{%args,statType=>"set",setID=>$nvSetID}, systemlink_args=>\%systemlink_args));
					}
					print CGI::end_ul();
				}
				print CGI::end_li(); # end Stats

				print CGI::start_li(); # Student Progress
				print &$makelink("${pfx}StudentProgress", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args);
				if ($userID ne $eUserID or defined $setID) {
					print CGI::start_ul();
					if ($userID ne $eUserID) {
						print CGI::li(&$makelink("${pfx}StudentProgress", text=>"$eUserID", urlpath_args=>{%args,statType=>"student",userID=>$eUserID}, systemlink_args=>\%systemlink_args));
					}
					if (defined $setID) {
						# make sure we don't try to send a versioned
						#    set id in to the stats link
						my ( $nvSetID ) = ( $setID =~ /(.+?)(,v\d+)?$/ );
						my ( $nvPretty ) = ( $prettySetID =~ /(.+?)(,v\d+)?$/ );
						print CGI::li(&$makelink("${pfx}StudentProgress", text=>"$nvPretty", urlpath_args=>{%args,statType=>"set",setID=>$nvSetID}, systemlink_args=>\%systemlink_args));
					}
					print CGI::end_ul();
				}
				print CGI::end_li(); # end Student Progress

				if ($authz->hasPermissions($userID, "score_sets")) {
					print CGI::li(&$makelink("${pfx}Scoring", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));
				}

				#Show achievement editor for instructors
				if ($ce->{achievementsEnabled} && $authz->hasPermissions($userID, "edit_achievements")) {
				    print CGI::li(&$makelink("${pfx}AchievementList", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));
				    if (defined $achievementID ) {
					print CGI::start_li();
					print CGI::start_ul();
					print CGI::start_li(); # $achievementID
					print &$makelink("${pfx}AchievementEditor", text=>"$prettyAchievementID", urlpath_args=>{%args,achievementID=>$achievementID}, systemlink_args=>\%systemlink_args);
					print CGI::end_ul();
					print CGI::end_li();
				    }

				}

				if ($authz->hasPermissions($userID, "send_mail")) {
					print CGI::li(&$makelink("${pfx}SendMail", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));
				}

				if ($authz->hasPermissions($userID, "manage_course_files")) {
					print CGI::li(&$makelink("${pfx}FileManager", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));
				}

				if ($authz->hasPermissions($userID, "manage_course_files")) {
					print CGI::li(&$makelink("${pfx}Config", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));
				}
				print CGI::li({}, $self->helpMacro('instructor_links', $r->maketext('Help')));
				print CGI::li({}, $self->help());
				if ($authz->hasPermissions($userID, "manage_course_files") # show this only on the FileManager page
				     && $r->urlpath->module eq "WeBWorK::ContentGenerator::Instructor::FileManager") {
				    my %augmentedSystemLinks = %systemlink_args;
				    $augmentedSystemLinks{params}->{archiveCourse}=1;
					print CGI::li(&$makelink("${pfx}FileManager", text=>$r->maketext("Archive this Course"),urlpath_args=>{%args}, systemlink_args=>\%augmentedSystemLinks));
				}
				print CGI::end_ul();
				print CGI::end_li(); # end Instructor Tools
			} # /* access_instructor_tools */

			if (exists $ce->{webworkURLs}{bugReporter} and $ce->{webworkURLs}{bugReporter} ne ""
				and $authz->hasPermissions($userID, "report_bugs")) {
				print CGI::li({class=>'divider', 'aria-hidden'=>'true'},"");
				print CGI::li(CGI::a({href=>$ce->{webworkURLs}{bugReporter}}, $r->maketext("Report bugs")));
			}

		} # /* authentication was_verified */

	} # /* defined $courseID */

	print CGI::end_ul();


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
	#This will contain any extra parameters which are needed to make
	# the page function properly.  This will normally be empty.
	my $extraStopActingParams = $r->{extraStopActingParams};

	if ($authen and $authen->was_verified) {
		my $courseID = $urlpath->arg("courseID");
		my $userID = $r->param("user");
		my $eUserID = $r->param("effectiveUser");

		$extraStopActingParams->{effectiveUser} = $userID;
		my $stopActingURL = $self->systemLink($urlpath, # current path
			params=>$extraStopActingParams);
		my $logoutURL = $self->systemLink($urlpath->newFromModule(__PACKAGE__ . "::Logout", $r, courseID => $courseID));

		my $signOutIcon = CGI::i({ class=> "icon fas fa-sign-out-alt", aria_hidden => "true", data_alt => "signout" }, "");

		if ($eUserID eq $userID) {
			print $r->maketext("Logged in as [_1].", HTML::Entities::encode_entities($userID)) .
				CGI::a({ href => $logoutURL, class => "btn btn-small" }, $r->maketext("Log Out") . " " . $signOutIcon);
		} else {
			print $r->maketext("Logged in as [_1].", HTML::Entities::encode_entities($userID)) .
				CGI::a({ href => $logoutURL, class => "btn btn-small" }, $r->maketext("Log Out") . " " . $signOutIcon);
			print CGI::br();
			print $r->maketext("Acting as [_1].", HTML::Entities::encode_entities($eUserID)) .
				CGI::a({ href => $stopActingURL, class => "btn btn-small" }, $r->maketext("Stop Acting") . " " . $signOutIcon);
		}
	} else {
		print $r->maketext("Not logged in.");
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
	    my $name = $urlpath->name;
	    # If its a problemid for a jitar set (something which requires
	    # a fair bit of checking, we need to print out the pretty id
	    if (defined($urlpath->module) && $urlpath->module eq 'WeBWorK::ContentGenerator::Problem') {
 		if ($urlpath->parent->name) {
 		    my $set = $r->db->getGlobalSet($urlpath->parent->name);
 		    if ($set && $set->assignment_type eq 'jitar') {
 			$name = join('.',jitar_id_to_seq($name));
 		    }
 		}
	    }
	    unshift @path, $name, $r->location . $urlpath->path;
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

=item footer()

	-by ghe3

	combines timestamp() and other elements of the footer, including the copyright, into one output subroutine,
=cut

sub footer(){
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $ww_version = $ce->{WW_VERSION}||"unknown -- set ww version VERSION";
	my $pg_version = $ce->{PG_VERSION}||"unknown -- set pg version PG_VERSION link to ../pg/VERSION";
	my $theme = $ce->{defaultTheme}||"unknown -- set defaultTheme in localOverides.conf";
	my $copyright_years = $ce->{WW_COPYRIGHT_YEARS}||"1996-2019";
	print CGI::div({-id=>"last-modified"}, $r->maketext("Page generated at [_1]", timestamp($self)));
	print CGI::div({-id=>"copyright"}, $r->maketext("WeBWorK &copy; [_1]| theme: [_2] | ww_version: [_3] | pg_version [_4]|",
	                $copyright_years,$theme, $ww_version, $pg_version),
	                CGI::a({-href=>"http://webwork.maa.org/"},
	                $r->maketext("The WeBWorK Project"), ));

	return ""
}


=item timestamp()

Defined in this package.

Display the current time and date using default format "3:37pm on Jan 7, 2004".
The display format can be adjusted by giving a style in the template.
For example,

  <!--#timestamp style="%m/%d/%y at %I:%M%P"-->

will give standard WeBWorK time format.  Wording and other formatting
can be done in the template itself.
=cut

# sub timestamp {
# 	my ($self, $args) = @_;
# 	my $formatstring = "%l:%M%P on %b %e, %Y";
# 	$formatstring = $args->{style} if(defined($args->{style}));
# 	return(Date::Format::time2str($formatstring, time()));
# }
sub timestamp {
	my ($self, $args) = @_;
    # need to use the formatDateTime in this file (some subclasses access Util's version.
	return( $self->formatDateTime( time() ) );
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
	print $self->{status_message}
	    if exists $self->{status_message};

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
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;

	# If the urlpath name is the courseID, and if the course has
	# a course title then display that instead.
	if (defined($urlpath->arg("courseID")) &&
	    $urlpath->name eq $urlpath->arg("courseID") &&
	    $db->settingExists('courseTitle')) {
	    print $db->getSettingValue('courseTitle');
	} else {
	    # just display the urlpath name
	    #print "\n<!-- BEGIN " . __PACKAGE__ . "::title -->\n";
	    #print underscore2nbsp($r->urlpath->name);
	    my $name = $urlpath->name;
	    # $name =~ s/_/ /g;
	    print $name;
	    #print "<!-- END " . __PACKAGE__ . "::title -->\n";
	}

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
	print CGI::p("Entering ContentGenerator::warnings") if $TRACE_WARNINGS;
	print "\n<!-- BEGIN " . __PACKAGE__ . "::warnings -->\n";
	my $warnings = MP2 ? $r->notes->get("warnings") : $r->notes("warnings");
	$warnings = Encode::decode("UTF-8",$warnings);
	print $self->warningOutput($warnings) if $warnings;
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
	    # we have to build this here (and not in say defaults.conf) because
	    # defaultTheme will chage as late as simple.conf
	    if ($name eq "theme") {
		return $ce->{webworkURLs}->{htdocs}.'/themes/'.$ce->{defaultTheme};
	    } else {

		return $ce->{webworkURLs}->{$name};
	    }
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

	if ( (MP2 ? $r->notes->get("warnings") : $r->notes("warnings"))
	     or ($self->{pgerrors}) )
	{
		return $arg;
	} else {
		!$arg;
	}
}

=item if_exists

Returns true if the specified file exists in the current theme directory
and false otherwise

=cut

sub if_exists {
	my ($self, $arg) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	return -e $ce->{webworkDirs}{themes}.'/'.$ce->{defaultTheme}.'/'.$arg;
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
	my $r = $self->r;
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
		next unless $name =~/\S/;  #skip blank names. Blanks can happen for course header and set header files.
		if ($url and not $args{textonly}) {
		    if($args{style} eq "bootstrap"){
		        push @result, CGI::li(CGI::a({-href=>"$url?$auth"}, lc($name)));
		    } else {
			    push @result, CGI::a({-href=>"$url?$auth"}, lc($name));
		    }
		} else {
		    if($args{style} eq "bootstrap"){
                push @result, CGI::li({-class=>"active"}, $name);
            } else {
			    push @result, $name;
			}
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
		my $id = $name;
		$id =~ s/\W/\_/g;
		push @result, $url
			? CGI::span( {id=>$id}, CGI::a({-href=>"$url?$auth"}, $name) )
			: CGI::span( {id=>$id},$name );
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
		my $direction = shift @links;
		my $html = ($direction && $args{style} eq "buttons") ? $direction : $name;
		push @result, $url
		  ? CGI::a({-href=>"$url?$auth$tail", -class=>"nav_button"}, $html)
		  : CGI::span({-class=>"gray_button"}, $html);
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
	my $label = shift; #optional

	my $ce   = $self->r->ce;
	$name = 'no_help' unless -e "$ce->{webworkDirs}{local_help}/$name.html";

	return CGI::a({
			href => $ce->{webworkURLs}{local_help} . "/$name.html",
			target => 'ww_help',
			# FIXME: Replace inline javascript
			onclick => "window.open(this.href,this.target,'width=550,height=350,scrollbars=yes,resizable=yes')"
		},
		defined($label) ? $label
		: CGI::i({ class => "icon fas fa-question-circle", aria_hidden => "true", data_alt => " ? " }, '')
	);
}

=item sub optionsMacro

This function has been depreciated

=cut

sub optionsMacro {
    return '';
}

=item feedbackMacro(%params)

Helper macro for displaying the feedback form. Returns a button named "Email
Instructor". %params contains the request parameters accepted by the Feedback
module and their values.

=cut

sub feedbackMacro {
	my ($self, %params) = @_;
	my $r = $self->r;
	my $authz = $r->authz;
	my $userID = $r->param("user");

	# don't do anything unless the user has permission to
	return "" unless $authz->hasPermissions($userID, "submit_feedback");

	my $feedbackURL = $r->ce->{courseURLs}{feedbackURL};
	my $feedbackFormURL = $r->ce->{courseURLs}{feedbackFormURL};
	if (defined $feedbackURL and $feedbackURL ne "") {
		return $self->feedbackMacro_url($feedbackURL);
	} elsif (defined $feedbackFormURL and $feedbackFormURL ne "") {
		return $self->feedbackMacro_form($feedbackFormURL,%params);
	} else {
		return $self->feedbackMacro_email(%params);
	}
}

sub feedbackMacro_email {
	my ($self, %params) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $urlpath = $r->urlpath;
	my $courseID = $urlpath->arg("courseID");

	# feedback form url
	my $feedbackPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Feedback",  $r, courseID => $courseID);
	my $feedbackURL = $self->systemLink($feedbackPage, authen => 0); # no authen info for form action
	my $feedbackName = $r->maketext($ce->{feedback_button_name}) || $r->maketext("Email instructor");

	my $result = CGI::start_form(-method=>"POST", -action=>$feedbackURL) . "\n";
	#This is being used on forms with hidden_authen_fields already included
	# in many pages so we need to change the fields to be hidden
	my $hiddenFields = $self->hidden_authen_fields;
	$hiddenFields =~ s/\"hidden_/\"email-hidden_/g;
	$result .=  $hiddenFields."\n";

	while (my ($key, $value) = each %params) {
	    next if $key eq 'pg_object';    # not used in internal feedback mechanism
		$result .= CGI::hidden($key, $value) . "\n";
	}
	$result .= CGI::p(CGI::submit(-name=>"feedbackForm", -value=>$feedbackName));
	$result .= CGI::end_form() . "\n";

	return $result;
}

sub feedbackMacro_form {
	my ($self, $feedbackFormURL, %params) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	# feedback form url
	my $feedbackName = $r->maketext($ce->{feedback_button_name}) || $r->maketext("Email instructor");

	my $result = CGI::start_form(-method=>"POST", -action=>$feedbackFormURL,-target=>"WW_info") . "\n";

	$result .= $self->hidden_authen_fields . "\n";

	while (my ($key, $value) = each %params) {
	    if ($key eq 'pg_object') {
	        my $tmp = $value->{body_text};
	        $tmp .= CGI::p(CGI::b("Note: "). CGI::i($value->{result}->{msg})) if $value->{result}->{msg} ;
	        $result .= CGI::hidden($key, encode_base64($tmp, "") );
	    } else {
			$result .= CGI::hidden($key, $value) . "\n";
		}
	}
	$result .= CGI::p({-align=>"left"}, CGI::submit(-name=>"feedbackForm", -value=>$feedbackName));
	$result .= CGI::end_form() . "\n";

	return $result;
}

sub feedbackMacro_url {
	my ($self, $url) = @_;
	my $r = $self->r;
	my $feedbackName = $r->maketext($r->ce->{feedback_button_name}) || $r->maketext("Email instructor");
	return CGI::a({-href=>$url}, $feedbackName);
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
	    foreach my $value (@values) {
		next unless defined($value);
#		$html .= CGI::hidden($param, $value); # (can't name these items when using real CGI)
		$html .= CGI::hidden(-name=>$param, -default=>$value, -id=>"hidden_".$param); # (can't name these items when using real CGI)
	    }
	}

	return $html;
}

=item hidden_authen_fields()

Use hidden_fields to return hidden <INPUT> tags for request fields used in
authentication.

=cut

sub hidden_authen_fields {
	my ($self) = @_;

	return $self->hidden_fields("user", "effectiveUser", "key", "theme");
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
			push @pairs, uri_escape_utf8($param) . "=" . uri_escape($value);
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
	my $ce = $self->r->ce;

	# When cookie based session management is in use, there should be no need
	# to reveal the user and key in the URL. Putting it there makes session
	# hijacking easier, in particular should a student share such a URL.
	if ( $ce->{session_management_via} eq "session_cookie" ) {
		return $self->url_args("effectiveUser", "theme");
	} else {
		return $self->url_args("user", "effectiveUser", "key", "theme");
	}
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

=item use_abs_url

If set to a true value, the scheme, host, and port are prepended to the URL.
This is useful for links which must be usable on their own, such as those sent
via email.

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

		# When cookie based session management is in use, there should be no need
		# to reveal the user and key in the URL. Putting it there makes session
		# hijacking easier, in particular should a student share such a URL.

		if ( $r->ce->{session_management_via} eq "session_cookie" ) {
			undef( $params{user} ) if exists $params{user};
			undef( $params{key} )  if exists $params{key};
		} else {
			$params{user}          = undef unless exists $params{user};
			$params{key}           = undef unless exists $params{key};
		}

		$params{effectiveUser} = undef unless exists $params{effectiveUser};
		$params{theme}         = undef unless exists $params{theme};
	}

	my $url;

	$url = $r->ce->{apache_root_url} if $options{use_abs_url};
	$url .= $r->location . $urlpath->path;
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
			$url .= join "&", map { "$name=".HTML::Entities::encode_entities($_) } @values;
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

=item underscore2sp($string)

A copy of $string is returned with each underscore character replaced by a space entity.

=cut

sub underscore2sp {
	my ($str) = @_;
	return unless defined $str;
	$str =~ s/_/ /g;
	return $str;
}

=item errorOutput($error, $details)

Used by Problem, ProblemSet, and Hardcopy to report errors encountered during
problem rendering.

=cut

sub errorOutput($$$) {
	my ($self, $error, $details) = @_;
	my $r = $self->{r};
	print "Entering ContentGenerator::errorOutput subroutine</br>" if $TRACE_WARNINGS;
	my $time = time2str("%a %b %d %H:%M:%S %Y", time);
	my $method = $r->method;
	my $uri = $r->uri;
	my $headers = do {
		my %headers = %{$r->headers_in};
		join("", map { CGI::Tr({},CGI::td(CGI::small($_)), CGI::td(CGI::small($headers{$_}))) } keys %headers);
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
		CGI::h2($r->maketext("WeBWorK Error")),
		CGI::p($r->maketext("_REQUEST_ERROR")),

		CGI::h3($r->maketext("Error messages")),

		CGI::p(CGI::code($error)),
		CGI::h3("Error details"),

		CGI::start_code(), CGI::start_p(),
		@{ $details },
		#CGI::code(CGI::p(@expandedDetails)),
		# not using inclusive CGI calls here saves about 30Meg of memory!
		CGI::end_p(),CGI::end_code(),

		CGI::h3($r->maketext("Request information")),
		CGI::table({border=>"1"},
			CGI::Tr({},CGI::td($r->maketext("Time")), CGI::td($time)),
			CGI::Tr({},CGI::td($r->maketext("Method")), CGI::td($method)),
			CGI::Tr({},CGI::td($r->maketext("URI")), CGI::td($uri)),
			CGI::Tr({},CGI::td($r->maketext("HTTP Headers")), CGI::td(
				CGI::table($headers),
			)),
		),
	;

}

=item warningMessage

Used to print out a generic warning message at the top of the page

=cut

sub warningMessage {
  my $self = shift;
  my $r = $self->r;

  return CGI::b($r->maketext("Warning")), ' -- ',
    $r->maketext("There may be something wrong with this question. Please inform your instructor including the warning messages below.");

}


=item warningOutput($warnings)

Used by warnings() in this class to report warnings caught during dispatching
and content generation.

=cut

sub warningOutput($$) {
	my ($self, $warnings) = @_;
	my $r = $self->{r};
	print "Entering ContentGenerator::warningOutput subroutine</br>" if $TRACE_WARNINGS;
	my @warnings = split m/\n+/, $warnings;

	my $scrubber = HTML::Scrubber->new(
	    default => 1,
	    script => 0,
	    comment => 0
	    );
	$scrubber->default(
	    undef,
	    {
		'*' => 1,
	    }
	    );

	foreach my $warning (@warnings) {
            # Since these warnings have html they look better scrubbed
	    #$warning = HTML::Entities::encode_entities($warning);
	    $warning = $scrubber->scrub($warning);
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
		CGI::h2($r->maketext("WeBWorK Warnings")),
		CGI::p($r->maketext('WeBWorK has encountered warnings while processing your request. If this occured when viewing a problem, it was likely caused by an error or ambiguity in that problem. Otherwise, it may indicate a problem with the WeBWorK system itself. If you are a student, report these warnings to your professor to have them corrected. If you are a professor, please consult the warning output below for more information.')),
		CGI::h3($r->maketext("Warning messages")),
		CGI::ul($warnings),
		CGI::h3($r->maketext("Request information")),
		CGI::table({border=>"1"},
			CGI::Tr({},CGI::td($r->maketext("Time")), CGI::td($time)),
			CGI::Tr({},CGI::td($r->maketext("Method")), CGI::td($method)),
			CGI::Tr({},CGI::td($r->maketext("URI")), CGI::td($uri)),
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
	my ($self, $dateTime, $display_tz,$formatString,$locale) = @_;
	my $ce = $self->r->ce;
	$display_tz ||= $ce->{siteDefaults}{timezone};
	$locale ||= $ce->{siteDefaults}{locale};
	return WeBWorK::Utils::formatDateTime($dateTime, $display_tz,$formatString,$locale);
}

=item read_scoring_file($fileName)

Wrapper for WeBWorK::File::Scoring that no-ops if $fileName is "None" and
prepends the path to the scoring directory.

=cut

sub read_scoring_file {
	my ($self, $fileName) = @_;
	return {} if $fileName eq "None"; # callers expect a hashref in all cases
	return parse_scoring_file($self->r->ce->{courseDirs}{scoring}."/$fileName");
}

=item createEmailSenderTransportSMTP

Wrapper that creates an Email::Sender::Transport::SMTP object

=cut

# this function abstracts the process of creating a transport layer for SendMail
# it is used in Feedback.pm, SendMail.pm and ProblemUtil.pm (for JITAR messages)

sub createEmailSenderTransportSMTP {
	my $self = shift;
	my $ce = $self->r->ce;
	my $transport;
	if (defined $ce->{mail}->{smtpPort} ) {
		$transport = Email::Sender::Transport::SMTP->new({
			host => $ce->{mail}->{smtpServer},
			ssl => $ce->{mail}->{tls_allowed}//0, ## turn off ssl security by default
			port => $ce->{mail}->{smtpPort},
			timeout => $ce->{mail}->{smtpTimeout},
			# debug => 1,
		});
	} else {
		$transport = Email::Sender::Transport::SMTP->new({
			host => $ce->{mail}->{smtpServer},
			ssl => $ce->{mail}->{tls_allowed}//0, ## turn off ssl security by default
			timeout => $ce->{mail}->{smtpTimeout},
			# debug => 1,
		});
	}
# 		warn "port is ", $transport->port();
# 		warn "ssl is ", $transport->ssl();
# 		warn "tls_allowed is ", $ce->{mail}->{tls_allowed}//'';
#         warn " smtpPort is set to ", $ce->{mail}->{smtpPort}//'';

    return $transport;
}
=back

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu and Sam Hathaway,
sh002i (at) math.rochester.edu.

=cut

1;
