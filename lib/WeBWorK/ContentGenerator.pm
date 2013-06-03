################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2012 The WeBWorK Project, http://github.com/openwebwork
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator.pm,v 1.196 2009/06/04 01:33:15 gage Exp $
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
use mod_perl;
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );
use Scalar::Util qw(weaken);

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

=item 6

The method content() is called to send the page content to client.

=back

=cut

sub go {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

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
		my $text = $options{text};
		my $active = $options{active};
		my %target = ($options{target} ? (target => $options{target}) : ());
		
		my $new_urlpath = $self->r->urlpath->newFromModule($module, $r, %$urlpath_args);
		my $new_systemlink = $self->systemLink($new_urlpath, %$systemlink_args);
		
		defined $text or $text = $new_urlpath->name;  #too clever
		
		my $id = $text;
		$id =~ s/\W/\_/g; 
		#$text = sp2nbsp($text); # ugly hack to prevent text from wrapping
		
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
			# add <strong> for old browsers
			$new_anchor = CGI::strong(CGI::a({href=>$new_systemlink, id=>$id, class=>"active", %target}, $text));
		} else {
			$new_anchor = CGI::a({href=>$new_systemlink, id=>$id, %target}, "$text");
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
	
	print CGI::h2($r->maketext("Main Menu"));
	print CGI::start_ul();
	print CGI::start_li(); # Courses
	print &$makelink("${pfx}Home", text=>$r->maketext("Courses"), systemlink_args=>{authen=>0});
	
	if (defined $courseID) {
		#print CGI::start_ul();
		#print CGI::start_li(); # $courseID
		#print CGI::strong(CGI::span({class=>"active"}, $courseID));
		
		if ($authen->was_verified) {
			print CGI::start_ul();
			print CGI::start_li(); # Homework Sets
			print &$makelink("${pfx}ProblemSets", text=>$r->maketext("Homework Sets"), urlpath_args=>{%args}, systemlink_args=>\%systemlink_args);
			
			if (defined $setID) {
				print CGI::start_ul();
				print CGI::start_li(); # $setID
				# show a link if we're displaying a homework set, or a version
				#    of a gateway assignment; to know if it's a gateway
				#    assignment, we have to get the set record.
				my ($globalSetID) = ( $setID =~ /(.+?)(,v\d+)?$/ );
				my $setRecord = $db->getGlobalSet( $globalSetID );
				if ( $setRecord->assignment_type !~ /gateway/ ) {
					print &$makelink("${pfx}ProblemSet", text=>"$prettySetID", urlpath_args=>{%args,setID=>$setID}, systemlink_args=>\%systemlink_args);
				} elsif ($setID =~ /,v(\d)+$/) {
					print &$makelink("${pfx}GatewayQuiz", text=>"$prettySetID", urlpath_args=>{%args,setID=>$setID}, systemlink_args=>\%systemlink_args);
				}

				if (defined $problemID) {
					print CGI::start_ul();
					print CGI::start_li(); # $problemID
					print &$makelink("${pfx}Problem", text=>$r->maketext("Problem [_1]", $problemID), urlpath_args=>{%args,setID=>$setID,problemID=>$problemID}, systemlink_args=>\%systemlink_args);
					
					print CGI::end_li(); # end $problemID
					print CGI::end_ul();
				}
				print CGI::end_li(); # end $setID
				print CGI::end_ul();
			}
			print CGI::end_li(); # end Homework Sets
			
			if ($authz->hasPermissions($userID, "change_password") or $authz->hasPermissions($userID, "change_email_address")) {
				print CGI::li(&$makelink("${pfx}Options", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));
			}
			
			print CGI::li(&$makelink("${pfx}Grades", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));
			
			if ($ce->{achievementsEnabled}) {
			    print CGI::li(&$makelink("${pfx}Achievements", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args)); 
			}

			if ($authz->hasPermissions($userID, "access_instructor_tools")) {
				$pfx .= "Instructor::";
				
				print CGI::start_li(); # Instructor Tools
				print &$makelink("${pfx}Index", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args);
				print CGI::start_ul();
				

				print CGI::li(&$makelink("${pfx}UserList", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args))
					if $ce->{showeditors}->{classlisteditor1};
				print CGI::li(&$makelink("${pfx}UserList2", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args))
					if $ce->{showeditors}->{classlisteditor2};;
				print CGI::li(&$makelink("${pfx}UserList3", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args))
					if $ce->{showeditors}->{classlisteditor3};;

				
				print CGI::start_li(); # Homework Set Editor
				print &$makelink("${pfx}ProblemSetList", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args)
					if $ce->{showeditors}->{homeworkseteditor1};
				print "<br/>";
				print &$makelink("${pfx}ProblemSetList2", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args)
					if $ce->{showeditors}->{homeworkseteditor2};;
				
				## only show editor link for non-versioned sets
				if (defined $setID && $setID !~ /,v\d+$/ ) {
					print CGI::start_ul();
					print CGI::start_li(); # $setID
					print &$makelink("${pfx}ProblemSetDetail", text=>"$prettySetID", urlpath_args=>{%args,setID=>$setID}, systemlink_args=>\%systemlink_args);
					
					if (defined $problemID) {
						print CGI::start_ul();
						print CGI::li(&$makelink("${pfx}PGProblemEditor", text=>"$problemID", urlpath_args=>{%args,setID=>$setID,problemID=>$problemID}, systemlink_args=>\%systemlink_args, target=>"WW_Editor1"))
							if $ce->{showeditors}->{pgproblemeditor1};
						print CGI::end_ul();
					}
					if (defined $problemID) {
						print CGI::start_ul();
						print CGI::li(&$makelink("${pfx}PGProblemEditor2", text=>"--$problemID", urlpath_args=>{%args,setID=>$setID,problemID=>$problemID}, systemlink_args=>\%systemlink_args, target=>"WW_Editor2"))
							if $ce->{showeditors}->{pgproblemeditor2};;
						print CGI::end_ul();
					}
					if (defined $problemID) {
						print CGI::start_ul();
						print CGI::li(&$makelink("${pfx}PGProblemEditor3", text=>"----$problemID", urlpath_args=>{%args,setID=>$setID,problemID=>$problemID}, systemlink_args=>\%systemlink_args, target=>"WW_Editor3"))
							if $ce->{showeditors}->{pgproblemeditor3};;
						print CGI::end_ul();
					}
					
					print CGI::end_li(); # end $setID
					print CGI::end_ul();
				}
				print CGI::end_li(); # end Homework Set Editor
				
				print CGI::li(&$makelink("${pfx}SetMaker", text=>$r->maketext("Library Browser"), urlpath_args=>{%args}, systemlink_args=>\%systemlink_args))
					if $ce->{showeditors}->{librarybrowser1};
				print CGI::li(&$makelink("${pfx}SetMaker2", text=>$r->maketext("Library Browser 2"), urlpath_args=>{%args}, systemlink_args=>\%systemlink_args))
					if $ce->{showeditors}->{librarybrowser2};
				print CGI::li(&$makelink("${pfx}SetMaker3", text=>$r->maketext("Library Browser 3"), urlpath_args=>{%args}, systemlink_args=>\%systemlink_args))
					if $ce->{showeditors}->{librarybrowser3};
#print CGI::li(&$makelink("${pfx}Compare", text=>"Compare", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args));
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
				# old stats
				print CGI::start_li(); # Stats_old
				print &$makelink("${pfx}Stats_old", urlpath_args=>{%args}, systemlink_args=>\%systemlink_args);
				if ($userID ne $eUserID or defined $setID) {
					print CGI::start_ul();
					if ($userID ne $eUserID) {
						print CGI::li(&$makelink("${pfx}Stats_old", text=>"$eUserID", urlpath_args=>{%args,statType=>"student",userID=>$eUserID}, systemlink_args=>\%systemlink_args));
					}
					if (defined $setID) {
						# make sure we don't try to send a versioned
						#    set id in to the Stats_old link
						my ( $nvSetID ) = ( $setID =~ /(.+?)(,v\d+)?$/ );
						my ( $nvPretty ) = ( $prettySetID =~ /(.+?)(,v\d+)?$/ );
						print CGI::li(&$makelink("${pfx}Stats_old", text=>"$nvPretty", urlpath_args=>{%args,statType=>"set",setID=>$nvSetID}, systemlink_args=>\%systemlink_args));
					}
					print CGI::end_ul();
				}
				print CGI::end_li(); # end Stats_old
				
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
					print CGI::start_ul();
					print CGI::start_li(); # $achievementID
					print &$makelink("${pfx}AchievementEditor", text=>"$prettyAchievementID", urlpath_args=>{%args,achievementID=>$achievementID}, systemlink_args=>\%systemlink_args);
					print CGI::end_ul();
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
				print CGI::li({}, $self->helpMacro('instructor_links','Help'),$self->help() );
				if ($authz->hasPermissions($userID, "manage_course_files") # show this only on the FileManager page
				     && $r->urlpath->module eq "WeBWorK::ContentGenerator::Instructor::FileManager") {
				    my %augmentedSystemLinks = %systemlink_args;
				    $augmentedSystemLinks{params}->{archiveCourse}=1;
					print CGI::li(&$makelink("${pfx}FileManager", text=>"Archive this Course",urlpath_args=>{%args}, systemlink_args=>\%augmentedSystemLinks));
				}
				print CGI::end_ul();
				print CGI::end_li(); # end Instructor Tools
			} # /* access_instructor_tools */
			
			print CGI::end_ul();
			
			print CGI::start_ul();
			if (exists $ce->{webworkURLs}{bugReporter} and $ce->{webworkURLs}{bugReporter} ne ""
				and $authz->hasPermissions($userID, "report_bugs")) {
				print CGI::li(CGI::a({style=>'font-size:larger', href=>$ce->{webworkURLs}{bugReporter}}, $r->maketext("Report bugs")));
			}
	
	print CGI::end_ul();

		} # /* authentication was_verified */
		
		#print CGI::end_li(); # end $courseID
		#print CGI::end_ul();
	} # /* defined $courseID */
	
	print CGI::end_li(); # end Courses
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
	
	if ($authen and $authen->was_verified) {
		my $courseID = $urlpath->arg("courseID");
		my $userID = $r->param("user");
		my $eUserID = $r->param("effectiveUser");
		
		my $stopActingURL = $self->systemLink($urlpath, # current path
			params => { effectiveUser => $userID },
		);
		my $logoutURL = $self->systemLink($urlpath->newFromModule(__PACKAGE__ . "::Logout", $r, courseID => $courseID));
		
		if ($eUserID eq $userID) {
			print $r->maketext("Logged in as [_1]. ", $userID) . CGI::br() . CGI::a({href=>$logoutURL}, $r->maketext("Log Out"));
		} else {
			print $r->maketext("Logged in as [_1]. ", $userID) . CGI::a({href=>$logoutURL}, $r->maketext("Log Out")) . CGI::br();
			print $r->maketext("Acting as [_1]. ", $eUserID) . CGI::a({href=>$stopActingURL}, $r->maketext("Stop Acting"));
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

=item footer()

	-by ghe3
	
	combines timestamp() and other elements of the footer, including the copyright, into one output subroutine,
=cut

sub footer(){
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $ww_version = $ce->{WW_VERSION}||"unknown -- set version in defaults.config";
	my $pg_version = $ce->{PG_VERSION}||"unknown -- set version in defaults.config";
	my $copyright_years = $ce->{WW_COPYRIGHT_YEARS}||"1996-2011";
	print CGI::p({-id=>"last-modified"}, $r->maketext("Page generated at [_1]", timestamp($self)));
	print CGI::div({-id=>"copyright"}, "WeBWorK &#169; $copyright_years", "| ww_version: $ww_version | pg_version: $pg_version|", CGI::a({-href=>"http://webwork.maa.org/"}, $r->maketext("The WeBWorK Project"), ));
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
	#print underscore2nbsp($r->urlpath->name);
	my $name = $r->urlpath->name;
	# $name =~ s/_/ /g;
	print $name;
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
	print CGI::p("Entering ContentGenerator::warnings") if $TRACE_WARNINGS;
	print "\n<!-- BEGIN " . __PACKAGE__ . "::warnings -->\n";
	my $warnings = MP2 ? $r->notes->get("warnings") : $r->notes("warnings");
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
		if ($url and not $args{textonly}) {
		    if($args{style} eq "bootstrap"){
		        push @result, CGI::li(CGI::a({-href=>"$url?$auth"}, $r->maketext(lc($name))));
		    } else {
			    push @result, CGI::a({-href=>"$url?$auth"}, $r->maketext(lc($name)));
		    }
		} else {
		    if($args{style} eq "bootstrap"){
                push @result, CGI::li({-class=>"active"}, $r->maketext($name));
            } else {
			    push @result, $r->maketext($name);
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
			# ($img && $args{style} eq "images")
			# ? CGI::img(
				# {src=>($prefix."/".$img.$args{imagesuffix}),
				# border=>"",
				# alt=>"$name"})
			# : $name."lol";
#		unless($img && !$url) {  ## these are now "disabled" versions in grey -- DPVC
			push @result, $url
				? CGI::a({-href=>"$url?$auth$tail", -class=>"nav_button"}, $html)
				: CGI::span({-class=>"gray_button"}, $html);
#		}
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
	my $label  = shift; #optional
	my $ce   = $self->r->ce;
	my $basePath = $ce->{webworkDirs}->{local_help};
	$name        = 'no_help' unless -e "$basePath/$name.html";
	my $path     = "$basePath/$name.html";
	my $url = $ce->{webworkURLs}->{local_help}."/$name.html";
	my $imageURL = $ce->{webworkURLs}->{htdocs}."/images/question_mark.png";
	$label    = CGI::img({src=>$imageURL, alt=>" ? "}) unless defined $label;
	return CGI::a({href      => $url,
	               target    => 'ww_help',
	               onclick   => "window.open(this.href,this.target,'width=550,height=350,scrollbars=yes,resizable=yes')"},
	               $label);
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
	my $r = $self->r;
	
	my @options_to_show = @{$options{options_to_show}} if exists $options{options_to_show};
	@options_to_show = "displayMode" unless @options_to_show;  #FIXME -- I don't understant this -- type seems wrong
	my %options_to_show; @options_to_show{@options_to_show} = (); # make hash for easy lookups
	my @extra_params = @{$options{extra_params}} if exists $options{extra_params};
	
	print CGI::h2($r->maketext("Display Options"));
	
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
	
	$result .= CGI::submit(-name=>"redisplay", -label=>$r->maketext("Apply Options"));
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
	$result .= $self->hidden_authen_fields . "\n";
	
	while (my ($key, $value) = each %params) {
	    next if $key eq 'pg_object';    # not used in internal feedback mechanism
		$result .= CGI::hidden($key, $value) . "\n";
	}
	$result .= CGI::p({-align=>"left"}, CGI::submit(-name=>"feedbackForm", -value=>$feedbackName));
	$result .= CGI::endform() . "\n";
	
	return $result;
}

sub feedbackMacro_form {
	my ($self, $feedbackFormURL, %params) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $urlpath = $r->urlpath;
	my $courseID = $urlpath->arg("courseID");
	
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
	$result .= CGI::endform() . "\n";
	
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
# 		my @values = $r->param($param);
# 		$html .= CGI::hidden($param, @values);  #MEG
# 		 warn "$param ", join(" ", @values) if @values >1; #this should never happen!!!
		my $value  = $r->param($param);
#		$html .= CGI::hidden($param, $value); # (can't name these items when using real CGI) 
		$html .= CGI::hidden(-name=>$param, -default=>$value, -id=>"hidden_".$param); # (can't name these items when using real CGI) 

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
	
	return $self->url_args("user", "effectiveUser", "key", "theme");
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
		$params{user}          = undef unless exists $params{user};
		$params{effectiveUser} = undef unless exists $params{effectiveUser};
		$params{key}           = undef unless exists $params{key};
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
		CGI::h2("WeBWorK Error"),
		CGI::p($r->maketext("_REQUEST_ERROR")),

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
			CGI::Tr({},CGI::td("Time"), CGI::td($time)),
			CGI::Tr({},CGI::td("Method"), CGI::td($method)),
			CGI::Tr({},CGI::td("URI"), CGI::td($uri)),
			CGI::Tr({},CGI::td("HTTP Headers"), CGI::td(
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
	print "Entering ContentGenerator::warningOutput subroutine</br>" if $TRACE_WARNINGS;
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
			CGI::Tr({},CGI::td("Time"), CGI::td($time)),
			CGI::Tr({},CGI::td("Method"), CGI::td($method)),
			CGI::Tr({},CGI::td("URI"), CGI::td($uri)),
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

=back

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu and Sam Hathaway,
sh002i (at) math.rochester.edu.

=cut

1;
