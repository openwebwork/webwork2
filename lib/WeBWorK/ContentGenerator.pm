################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator.pm,v 1.80 2004/03/06 21:49:32 sh002i Exp $
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

FIXME: write this

=cut

use strict;
use warnings;
use Apache::Constants qw(:common);
use CGI qw(*ul *li);
use URI::Escape;
use WeBWorK::Authz;
use WeBWorK::DB;
use WeBWorK::Template qw(template);
use WeBWorK::Utils qw(readFile);

# This is a very unruly file, so I'm going to use very large comments to divide
# it into logical sections.

=head1 CONSTRUCTOR

=over

=item new($r)

Create a new instance of a content generator. Supply a WeBWorK::Request object
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
# Invocation and template processing
################################################################################

=head1 INVOCATION

=over

=item go()

Render a page, using methods from the particular subclass of ContentGenerator.
go() will call the following methods when invoked:

=over

=item pre_header_initialize()

Give the subclass a chance to do initialization necessary before generating the
HTTP header.

=item header()

This method provides a standard HTTP header with Content-Type text/html.
Subclasses are welcome to override this for things like an image-creation
content generator or a PDF generator. In addition, if header() returns a value,
that will be the value returned by go().

=item initialize()

Let the subclass do post-header initialization.

If pre_header_initialize() or header() sets $self->{noContent} to a true value,
initialize() will not be run and the content or template processing code
will not be executed.  This is probably only desirable if a redirect has been
issued.

=item template()

The layout template is processed. See template() below.

If the subclass implements a method named content(), it is called
instead and no template processing occurs.

=back

=cut

sub go {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r->ce;
	
	my $returnValue = OK;
	
	$self->pre_header_initialize(@_) if $self->can("pre_header_initialize");
	my $headerReturn = $self->header(@_);
	$returnValue = $headerReturn if defined $headerReturn;
	return $returnValue if $r->header_only or $self->{noContent};
	
	# if the sendFile flag is set, send the file and exit;
	if ($self->{sendFile}) {
		return $self->sendFile;
	}
	
	$self->initialize(@_) if $self->can("initialize");
	
	# A content generator will have a "content" method if it does not
	# wish to be passed through template processing, but wishes to be
	# completely responsible for it's own output.
	if ($self->can("content")) {
		$self->content(@_);
	} else {
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
	
	return $returnValue;
}

=item sendFile()

=cut

sub sendFile {
	my ($self) = @_;
	
	my $file = $self->{sendFile}->{source};
	
	return NOT_FOUND unless -e $file;
	return FORBIDDEN unless -r $file;
	
	open my $fh, "<", $file
		or return SERVER_ERROR;
	while (<$fh>) {
		print $_;
	}
	close $fh;
	
	return OK;
}

=back

=cut

################################################################################
# Macros used by content generators to render common idioms
################################################################################

# FIXME: some of these should be moved to WeBWorK::HTML:: modules!

=head1 HTML MACROS

Macros used by content generators to render common idioms

=over

=item pathMacro($args, @path)

Helper macro for <!--#path--> escape: $args is a hash reference containing the
"style", "image", "text", and "textonly" arguments to the escape. @path consists
of ordered key-value pairs of the form:

 "Page Name" => URL

If the page should not have a link associated with it, the URL should be left
empty. Authentication data is added to the URL so you don't have to. A fully-
formed path line is returned, suitable for returning by a function implementing
the #path escape.

=cut

sub pathMacro {
	my $self = shift;
	my %args = %{ shift() };
	my @path = @_;
	$args{style} = "text" if $args{textonly};
	my $sep;
	if ($args{style} eq "image") {
		$sep = CGI::img({-src=>$args{image}, -alt=>$args{text}});
	} else {
		$sep = $args{text};
	}
	my $auth = $self->url_authen_args;
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

=cut

sub siblingsMacro {
	my $self = shift;
	my @siblings = @_;
	my $sep = CGI::br();
	my $auth = $self->url_authen_args;
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

=item navMacro($args, $tail)

=cut

sub navMacro {
	my $self = shift;
	my %args = %{ shift() };
	my $tail = shift;
	my @links = @_;
	my $auth = $self->url_authen_args;
	my $ce = $self->{ce};
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

=item hidden_fields(@fields)

Return hidden <INPUT> tags for each field mentioned in @fields (or all fields if
list is empty), taking data from the current request.

=cut

sub hidden_fields($;@) {
	my $self = shift;
	my $r = $self->{r};
	my @fields = @_;
	@fields or @fields = $r->param;
	my $courseEnvironment = $self->{ce};
	my $html = "";
	
	foreach my $param (@fields) {
		my $value = $r->param($param);
		$html .= CGI::input({-type=>"hidden",-name=>"$param",-value=>"$value"});
	}
	return $html;
}

=item hidden_authen_fields()

Use hidden_fields to return hidden <INPUT> tags for request fields used in
authentication.

=cut

sub hidden_authen_fields($) {
	my $self = shift;
	return $self->hidden_fields("user","effectiveUser","key");
}

=item url_args(@fields)

Return a URL query string (without the leading `?') containing values for each
field mentioned in @fields, or all fields if list is empty. Data is taken from
the current request.

=cut

sub url_args($;@) {
	my $self = shift;
	my $r = $self->{r};
	my @fields = @_;
	@fields or @fields = $r->param; # If no fields are passed in, do them all.
	my $courseEnvironment = $self->{ce};
	
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

sub url_authen_args($) {
	my $self = shift;
	my $r = $self->{r};
	return $self->url_args("user","effectiveUser","key");
}

=item nbsp($string)

If string is the empty string, the HTML entity C< &nbsp; > is returned.
Otherwise the string is returned.

=cut

sub nbsp {
	my $self = shift;
	my $str  = shift;
	($str =~/\S/) ? $str : '&nbsp;'  ;  # returns non-breaking space for empty strings
	                                    # tricky cases:   $str =0;
	                                    #  $str is a complex number
}

=item print_form_data($begin, $middle, $end, $omit)

Return a string containing request fields not matched by $omit, placing $begin
before each field name, $middle between each field and its value, and $end after
each value. Values are taken from the current request. $omit is a quoted reguar
expression.

=cut

sub print_form_data {
	my ($self, $begin, $middle, $end, $qr_omit) = @_;
	my $return_string = "";
	my $r=$self->{r};
	my @form_data = $r->param;
	foreach my $name (@form_data) {
		next if ($qr_omit and $name =~ /$qr_omit/);
		my @values = $r->param($name);
		foreach my $variable (qw(begin name middle value end)) {
			no strict 'refs';
			${$variable} = "" unless defined ${$variable};
		}
		foreach my $value (@values) {
			$return_string .= "$begin$name$middle$value$end";
		}
	}
	return $return_string;
}

=item errorOutput($error, $details)

=cut

sub errorOutput($$$) {
	my ($self, $error, $details) = @_;
	return
		CGI::h3("Software Error"),
		CGI::p(<<EOF),
WeBWorK has encountered a software error while attempting to process this
problem. It is likely that there is an error in the problem itself. If you are
a student, contact your professor to have the error corrected. If you are a
professor, please consut the error output below for more informaiton.
EOF
		CGI::h3("Error messages"), CGI::p(CGI::tt($error)),
		CGI::h3("Error context"), CGI::p(CGI::tt($details));
}

=item warningOutput($warnings)

=cut

sub warningOutput($$) {
	my ($self, $warnings) = @_;
	
	my @warnings = split m/\n+/, $warnings;
	
	return
		CGI::h3("Software Warnings"),
		CGI::p(<<EOF),
WeBWorK has encountered warnings while attempting to process this problem. It
is likely that this indicates an error or ambiguity in the problem itself. If
you are a student, contact your professor to have the problem corrected. If you
are a professor, please consut the warning output below for more informaiton.
EOF
		CGI::h3("Warning messages"),
		CGI::ul(CGI::li(\@warnings)),
	;
}

=item systemLink($urlpath, %options)

Generate a link to another part of the system. $urlpath is WeBWorK::URLPath
object from which the base path will be taken. %options can consist of:

=over

=item authen

Boolen, whether to include authentication information in the resulting URL. If
not given, a true value is assumed.

=item realUserID

If C<authen> is true, the current real user ID is replaced with this value.

=item sessionKey

If C<authen> is true, the current session key is replaced with this value.

=item effectiveUserID

If C<authen> is true, the current effective user ID is replaced with this value.

=back

=cut

sub systemLink {
	my ($self, $urlpath, %options) = @_;
	my $r = $self->{r};
	
	my $authen = $options{authen} || 1;
	
	my $url = $r->location . $urlpath->path;
	
	if ($authen) {
		my $realUserID      = $options{realUserID}      || $r->param("user");
		my $sessionKey      = $options{sessionKey}      || $r->param("key");
		my $effectiveUserID = $options{effectiveUserID} || $r->param("effectiveUser");
		
		my @params;
		defined $realUserID      and push @params, "user=$realUserID";
		defined $sessionKey      and push @params, "key=$sessionKey";
		defined $effectiveUserID and push @params, "effectiveUser=$effectiveUserID";
		
		$url .= "?" . join("&", @params) if @params;
	}
	
	return $url;
}

=back

=cut

################################################################################
# Generic versions of template escapes
################################################################################

=head1 THE HEADER METHOD

=over

=item header()

The C<header> method is defined in WeBWorK::ContentGenerator to generate a
default C<Content-type> of text/html and send the HTTP header.

=back

=cut

sub header {
	my $self = shift;
	my $r = $self->{r};
	
	if ($self->{sendFile}) {
		my $contentType = $self->{sendFile}->{type};
		my $fileName = $self->{sendFile}->{name};
		$r->content_type($contentType);
		$r->header_out("Content-Disposition" => "attachment; filename=\"$fileName\"");
	} else {
		$r->content_type("text/html");
		
	}
	
	$r->send_http_header();
	return OK;
}

=head1 TEMPLATE ESCAPE METHODS

Template escape methods are invoked when a
C< <!--#escape argument="value" ... -> > construct is encountered in the
template. The methods can be defined here in ContentGenerator, or in a
particular subclass. Arguments are passed to the method as a reference to a
hash.

The following template escapes are currently defined:

=over

=item head

Any tags that should appear in the HEAD of the document. Not defined by default.

=item info

Auxiliary information related to the C<body>. Not defined by default.

=item links

Links that should appear on every page. Defined in WeBWorK::ContentGenerator by
default.

=cut

sub links {
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	# we're linking to other places in the same course, so grab the courseID from the current path
	my $courseID = $urlpath->arg("courseID");
	
	# to make things more concise
	my %args = ( courseID => $courseID );
	my $pfx = "WeBWorK::ContentGenerator::";
	
	my $PermissionLevel = $db->getPermissionLevel($r->param("user")); # checked
	my $permLevel = $PermissionLevel ? $PermissionLevel->permission : 0;
	
	my $iResult = "";
	
	if ($permLevel > 0) {
		my $ipfx = "${pfx}Instructor::";
		
		my $userID    = $r->param("effectiveUser");
		my $setID     = $urlpath->arg("setID");
		my $problemID = $urlpath->arg("problemID");
		
		my $instr = $urlpath->newFromModule("${ipfx}Index", %args);
		my $userList = $urlpath->newFromModule("${ipfx}UserList", %args);
		
		# set list links
		my $setList       = $urlpath->newFromModule("${ipfx}ProblemSetList", %args);
		my $setDetail     = $urlpath->newFromModule("${ipfx}ProblemSetEditor", %args, setID => $setID);
		my $problemEditor = $urlpath->newFromModule("${ipfx}PGProblemEditor", %args, setID => $setID, problemID => $problemID);
		
		my $mail     = $urlpath->newFromModule("${ipfx}SendMail", %args);
		my $scoring  = $urlpath->newFromModule("${ipfx}Scoring", %args);
		
		# statistics links
		my $stats     = $urlpath->newFromModule("${ipfx}Stats", %args);
		my $userStats = $urlpath->newFromModule("${ipfx}Stats", %args, statType => "student", userID => $userID);
		my $setStats  = $urlpath->newFromModule("${ipfx}Stats", %args, statType => "set", setID => $setID);
		
		my $files = $urlpath->newFromModule("${ipfx}FileXfer", %args);
		
		$iResult .= CGI::start_li();
		$iResult .= CGI::span({style=>"font-size:larger"}, CGI::a({href=>$self->systemLink($instr)}, $instr->name));
		$iResult .= CGI::start_ul();
		$iResult .= CGI::li(CGI::a({href=>$self->systemLink($userList)}, $userList->name));
		$iResult .= CGI::start_li();
		$iResult .= CGI::a({href=>$self->systemLink($setList)}, $setList->name);
		if (defined $setID and $setID ne "") {
			$iResult .= CGI::start_ul();
			$iResult .= CGI::start_li();
			$iResult .= CGI::a({href=>$self->systemLink($setDetail)}, $setID);
			if (defined $problemID and $problemID ne "") {
				$iResult .= CGI::ul(
					CGI::li(CGI::a({href=>$self->systemLink($problemEditor)}, $problemID))
				);
			}
			$iResult .= CGI::end_li();
			$iResult .= CGI::end_ul();
		}
		$iResult .= CGI::end_li();
		$iResult .= CGI::li(CGI::a({href=>$self->systemLink($mail)}, $mail->name));
		$iResult .= CGI::li(CGI::a({href=>$self->systemLink($scoring)}, $scoring->name));
		$iResult .= CGI::start_li();
		$iResult .= CGI::a({href=>$self->systemLink($stats)}, $stats->name);
		if (defined $userID and $userID ne "") {
			$iResult .= CGI::ul(
				CGI::li(CGI::a({href=>$self->systemLink($userStats)}, $userID))
			);
		}
		if (defined $setID and $setID ne "") {
			$iResult .= CGI::ul(
				CGI::li(CGI::a({href=>$self->systemLink($setStats)}, $setID))
			);
		}
		$iResult .= CGI::end_li();
		$iResult .= CGI::li(CGI::a({href=>$self->systemLink($files)}, $files->name));
		$iResult .= CGI::end_ul();
		$iResult .= CGI::end_li();
	}
	
	my $sets    = $urlpath->newFromModule("${pfx}ProblemSets", %args);
	my $options = $urlpath->newFromModule("${pfx}Options", %args);
	my $grades  = $urlpath->newFromModule("${pfx}Grades", %args);
	my $logout  = $urlpath->newFromModule("${pfx}Logout", %args);
	
	return CGI::ul({class=>"LinksMenu"},
		CGI::li(CGI::span({style=>"font-size:larger"},
			CGI::a({href=>$self->systemLink($sets)}, "Problem Sets"))),
		CGI::li(CGI::a({href=>$self->systemLink($options)}, $options->name)),
		CGI::li(CGI::a({href=>$self->systemLink($grades)},  $grades->name)),
		CGI::li(CGI::a({href=>$self->systemLink($logout)},  $logout->name)),
		$iResult,
	);
}

## FIXME: drunk code. rewrite.
## also, this should be structured s.t. subclasses can add items to the links
## area, i.e. "stacking"
#sub links {
#	my $self = shift;
#	my @components = @_;
#	my $ce = $self->{ce};
#	my $db = $self->{db};
#	my $userName = $self->{r}->param("user");
#	my $courseName = $ce->{courseName};
#	my $root = $ce->{webworkURLs}->{root};
#	
#	#my $Key = $db->getKey($userName); # checked
#	#my $key = (defiend $key
#	#	? $Key->key()
#	#	: "");
#	#
#	#return "" unless defined $key;
#	# This has been replaced by using "#if loggedin" in ur.template.
#	
#	# URLs to parts of the system
#	my $probSets   = "$root/$courseName/?"            . $self->url_authen_args();
#	my $prefs      = "$root/$courseName/options/?"    . $self->url_authen_args();
#	my $grades      = "$root/$courseName/grades/?"    . $self->url_authen_args();
#	my $help       = "$ce->{webworkURLs}->{docs}?"    . $self->url_authen_args();
#	my $logout     = "$root/$courseName/logout/?"     . $self->url_authen_args();
#	
#	my $PermissionLevel = $db->getPermissionLevel($userName); # checked
#	my $permLevel = (defined $PermissionLevel
#		? $PermissionLevel->permission()
#		: 0);
#	
#	return join("",
#		CGI::div( {style=>'font-size:larger'},CGI::a({-href=>$probSets}, "Problem&nbsp;Sets")
#		), 
#		CGI::a({-href=>$prefs}, "User&nbsp;Prefs"), CGI::br(),
#		CGI::a({-href=>$grades}, "Grades"), CGI::br(),
#		CGI::a({-href=>$help,-target=>'_help_'}, "Help"), CGI::br(),
#		CGI::a({-href=>$logout}, "Log Out"), CGI::br(),
#		($permLevel > 0
#			? $self->instructor_links(@components) : ""
#		),
#	);
#}
#
#sub instructor_links {
#	my $self       = shift;
#	my @components = @_; 
#	my $args       = pop(@components);  # get hash of option arguments
#	my $courseName = $self->{ce}->{courseName};
#	my $root       = $self->{ce}->{webworkURLs}->{root};
#	my $userName = $self->{r}->param("effectiveUser");
#	$userName    = $self->{r}->param("user") unless defined $userName;
#	my ($set, $prob) = @components;
#	my $instructor = "$root/$courseName/instructor/?" . $self->url_authen_args();
#	my $sets       = "$root/$courseName/instructor/sets/?" . $self->url_authen_args();
#	my $users      = "$root/$courseName/instructor/users/?" . $self->url_authen_args();
#	my $email      = "$root/$courseName/instructor/send_mail/?" . $self->url_authen_args();
#	my $scoring    = "$root/$courseName/instructor/scoring/?" . $self->url_authen_args();
#	my $statsRoot  = "$root/$courseName/instructor/stats";     
#	my $stats      = $statsRoot. '/?'.$self->url_authen_args();
#	my $fileXfer   = "$root/$courseName/instructor/files/?" . $self->url_authen_args();
#
#	
#	#  Add direct links to sets e.g.  3:4 for set3 problem 4
#	my $setURL = (defined $set)
#		? "$root/$courseName/instructor/sets/$set/?" . $self->url_authen_args()
#		: '';
#	my $probURL = (defined $set && defined $prob)
#		? "$root/$courseName/instructor/pgProblemEditor/$set/$prob?" . $self->url_authen_args()
#		: '';
#	
#	my ($setLink, $problemLink) = ("", "");
#	if ($setURL) {
#		$setLink = "&nbsp;&nbsp;&nbsp;&nbsp;"
#			. CGI::a({-href=>$setURL}, "Set&nbsp;$set")
#			. CGI::br();
#		if ($probURL) {
#			$problemLink = "&nbsp;&nbsp;&nbsp;&nbsp;"
#				. CGI::a({-href=>$probURL}, "Problem&nbsp;$prob")
#				. CGI::br();
#		}
#	}
#	
#	#my $setProb = ($setURL)
#	#	? CGI::a({-href=>$setURL}, $set)
#	#	: '';
#	#$setProb .= ':' . CGI::a({-href=>$probURL},$prob) if $setProb && $probURL;
#	
#	return join("",
#		 CGI::hr(),
#		 CGI::div( {style=>'font-size:larger'},
#		 	CGI::a({-href=>$instructor}, "Instructor&nbsp;Tools") 
#		 ), 
#		 '&nbsp;&nbsp;&nbsp;',CGI::a({-href=>$users}, "User&nbsp;List"), CGI::br(),
#		 '&nbsp;&nbsp;&nbsp;',CGI::a({-href=>$sets}, "Set&nbsp;List"), CGI::br(),
#		 $setLink,
#		 $problemLink,
#		 '&nbsp;&nbsp;&nbsp;',CGI::a({-href=>$email}, "Mail&nbsp;Merge"), CGI::br(),
#		 '&nbsp;&nbsp;&nbsp;',CGI::a({-href=>$scoring}, "Scoring"), CGI::br(),
#		 '&nbsp;&nbsp;&nbsp;',CGI::a({-href=>$stats}, "Statistics"), CGI::br(),
#		 (defined($set))
#		 	? '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'.CGI::a({-href=>"$statsRoot/set/$set/?".$self->url_authen_args}, "$set").CGI::br() 
#			: '',
#		 (defined($userName))
#		 	? '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'.CGI::a({-href=>"$statsRoot/student/$userName/?".$self->url_authen_args}, "$userName").CGI::br()
#			: '',
#		 '&nbsp;&nbsp;&nbsp;',CGI::a({-href=>$fileXfer}, "File&nbsp;Transfer"), CGI::br(),
#	);
#}

=item loginstatus

A notification message announcing the current real user and effective user, a
link to stop acting as the effective user, and a logout link. Defined in
WeBWorK::ContentGenerator by default.

=cut

sub loginstatus {
	my ($self) = @_;
	my $r = $self->{r};
	my $urlpath = $r->urlpath;
	
	my $key = $r->param("key");
	
	if ($key) {
		my $courseID = $urlpath->arg("courseID");
		my $userID = $r->param("user");
		my $eUserID = $r->param("effectiveUser");
		
		my $stopActingURL = $self->systemLink($urlpath, effectiveUserID => $userID);
		my $logoutURL = $self->systemLink($urlpath->newFromModule(__PACKAGE__ . "::Logout", courseID => $courseID));
		
		print "Logged in as $userID. ";
		print CGI::a({href=>$logoutURL}, "Log Out");
		
		if ($eUserID ne $userID) {
			print " | Acting as $eUserID. ";
			print CGI::a({href=>$stopActingURL}, "Stop Acting");
		}
	}
	
	return "";
}

#sub loginstatus_crap {
#	my $self = shift;
#	my $r = $self->{r};
#	my $ce = $self->{ce};
#	
#	my $user = $r->param("user");
#	my $eUser = $r->param("effectiveUser");
#	my $key = $r->param("key");
#	
#	return "" unless $key;
#	
#	my $exitURL = $r->uri() . "?user=$user&key=$key";
#	
#	my $root = $ce->{webworkURLs}->{root};
#	my $courseID = $ce->{courseName};
#	my $logout = "$root/$courseID/logout/?" . $self->url_authen_args();
#	
#	print CGI::small("User:", "$user");
#	
#	if ($user ne $eUser) {
#		print CGI::br(), CGI::font({-color=>'red'},
#				CGI::small("Acting as:", "$eUser")
#			),
#			CGI::br(), CGI::a({-href=>$exitURL},
#				CGI::small("Stop Acting")
#			);
#	}
#	
#	print CGI::br(), CGI::a({-href=>$logout}, CGI::small("Log Out"));
#	
#	return "";
#}

=item nav

Links to the previous, next, and parent objects. Not defined by default.

 style       => text|image
 imageprefix => prefix to prepend to base image URL
 imagesuffix => suffix to append to base image URL
 separator   => HTML to place in between links

=item options

A place for an options form, like the problem display options. Not defined by
default.

=item path

"Breadcrubs" from the current page to the root of the virtual hierarchy. Defined
in WeBWorK::ContentGenerator to pull information from the WeBWorK::URLPath.

 style    => type of separator: text|image
 image    => URL of separator image
 text     => text of texual separator (also used for image alt text)
 textonly => suppress links

=cut

sub path {
	my ($self, $args) = @_;
	my $r = $self->{r};
	
	my @path;
	
	my $urlpath = $r->urlpath;
	do {
		unshift @path, $urlpath->name, $r->location . $urlpath->path;
	} while ($urlpath = $urlpath->parent);
	
	$path[$#path] = ""; # we don't want the last path element to be a link
	
	return $self->pathMacro($args, @path);
}

=item siblings

Links to siblings of the current object. Not defined by default.

=item submiterror

Any error messages resulting from the last form submission. Defined in
WeBWorK::ContentGenerator by default.

=cut

sub submiterror {
	my ($self) = @_;
	if (exists $self->{submitError}) {
		return $self->{submitError};
	} else {
		return "";
	}
}

=item title

The title of the current page. Defined in WeBWorK::ContentGenerator to pull
information from the WeBWorK::URLPath.

=cut

sub title {
	my ($self, $args) = @_;
	my $r = $self->{r};
	
	return $r->urlpath->name;
}

=item warnings

Any warnings. Not defined by default.

=cut

sub warnings {
	my ($self) = @_;
	my $r = $self->{r};
	if ($r->notes("warnings")) {
		return $self->warningOutput($r->notes("warnings"));
	} else {
		return "";
	}
}

=back

=head CONDITIONAL PREDICATES

Conditional predicate methods are invoked when the
C< <!--#if predicate="value"--> > construct is encountered in the template. If a
method named C<if_predicate> is defined in here or in a particular subclass, it
is invoked.

The following predicates are currently defined:

=over

=item if_can

will return 1 if the current object->can("do $_[1]")

=cut

sub if_can ($$) {
	my ($self, $arg) = (@_);
	
	if ($self->can("$arg")) {
		return 1;
	} else {
		return 0;
	}
}

=item if_loggedin

Every content generator is logged in unless it overrides this method to say
otherwise.

=cut

sub if_loggedin($$) {
	my ($self, $arg) = (@_);
	
	return $arg;
}

=item if_submiterror

=cut

sub if_submiterror($$) {
	my ($self, $arg) = @_;
	if (exists $self->{submitError}) {
		return $arg;
	} else {
		return !$arg;
	}
}

=item if_warnings

=cut

sub if_warnings($$) {
	my ($self, $arg) = @_;
	return $self->{r}->notes("warnings") ? $arg : !$arg;
}

=back

=cut

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu
and Sam Hathaway, sh002i (at) math.rochester.edu.

=cut
