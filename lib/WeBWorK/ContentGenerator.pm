################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator.pm,v 1.87 2004/03/15 23:03:46 sh002i Exp $
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
use Apache::Constants qw(:common);
use Carp;
use CGI::Pretty qw(*ul *li);
use URI::Escape;
use WeBWorK::Template qw(template);

################################################################################

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

=item 3

At this point, go() will terminate if the request is a HEAD request or if the
field $self->{noContent} contains a true value.

=item 4

If the field $self->{sendFile} is defined, the method sendFile() is called to
send the specified file to the client, and go() terminates. See below.

=item 5

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
	
	$self->pre_header_initialize(@_) if $self->can("pre_header_initialize");
	
	my $headerReturn = $self->header(@_);
	$returnValue = $headerReturn if defined $headerReturn;
	return $returnValue if $r->header_only or $self->{noContent};
	
	# if the sendFile flag is set, send the file and exit;
	if ($self->{sendFile}) {
		return $self->sendFile;
	}
	
	$self->initialize() if $self->can("initialize");
	
	$self->content();
	
	return $returnValue;
}

=item sendFile()

Sends the file specified in $self->{sendFile} to the client. $self->{sendFile}
should be a reference to a hash containing the following fields:

 source => full path to the file to send
 type   => the content type of the file
 name   => the name that the client should give to the file upon download

This method is called internally by go() if the field $self->{sendFile} is
present.

This mechanism relies on the header() method to send appropriate C<Content-Type>
and C<Content-Disposition> headers.

This mechanism is fragile and will probably be replaced by something else in the
future.

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

=item r()

Returns a reference to the WeBWorK::Request object associated with this
instance.

=cut

sub r {
	my ($self) = @_;
	
	return $self->{r};
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

Generates and sends a default HTTP header. If the field $self->{sendFile} is
present, sends the following headers (where TYPE is $self->{sendFile}->{type}
and NAME is $self->{sendFile}->{name}):

 Content-Type: TYPE
 Content-Disposition: attachment; filename=NAME

If $self->{sendFile} is not present, sends the following headers:

 Content-Type: text/html

See sendFile() above for more information on the sendFile mechanism.

=cut

sub header {
	my $self = shift;
	my $r = $self->r;
	
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
	my $urlpath = $r->urlpath;
	
	# we're linking to other places in the same course, so grab the courseID from the current path
	my $courseID = $urlpath->arg("courseID");
	
	# to make things more concise
	my %args = ( courseID => $courseID );
	my $pfx = "WeBWorK::ContentGenerator::";
	
	my $sets    = $urlpath->newFromModule("${pfx}ProblemSets", %args);
	my $options = $urlpath->newFromModule("${pfx}Options", %args);
	my $grades  = $urlpath->newFromModule("${pfx}Grades", %args);
	my $logout  = $urlpath->newFromModule("${pfx}Logout", %args);
	
	print "\n<!-- BEGIN " . __PACKAGE__ . "::links -->\n";
	print CGI::start_ul({class=>"LinksMenu"});
	print CGI::li(CGI::span({style=>"font-size:larger"},
		CGI::a({href=>$self->systemLink($sets)}, "Problem Sets")));
	print CGI::li(CGI::a({href=>$self->systemLink($options)}, $options->name));
	print CGI::li(CGI::a({href=>$self->systemLink($grades)},  $grades->name));
	print CGI::li(CGI::a({href=>$self->systemLink($logout)},  $logout->name));
	
	my $PermissionLevel = $db->getPermissionLevel($r->param("user")); # checked
	my $permLevel = $PermissionLevel ? $PermissionLevel->permission : 0;
	
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
		
		print CGI::start_li();
		print CGI::span({style=>"font-size:larger"}, CGI::a({href=>$self->systemLink($instr)}, $instr->name));
		print CGI::start_ul();
		print CGI::li(CGI::a({href=>$self->systemLink($userList)}, $userList->name));
		print CGI::start_li();
		print CGI::a({href=>$self->systemLink($setList)}, $setList->name);
		if (defined $setID and $setID ne "") {
			print CGI::start_ul();
			print CGI::start_li();
			print CGI::a({href=>$self->systemLink($setDetail)}, $setID);
			if (defined $problemID and $problemID ne "") {
				print CGI::ul(
					CGI::li(CGI::a({href=>$self->systemLink($problemEditor)}, $problemID))
				);
			}
			print CGI::end_li();
			print CGI::end_ul();
		}
		print CGI::end_li();
		print CGI::li(CGI::a({href=>$self->systemLink($mail)}, $mail->name));
		print CGI::li(CGI::a({href=>$self->systemLink($scoring)}, $scoring->name));
		print CGI::start_li();
		print CGI::a({href=>$self->systemLink($stats)}, $stats->name);
		if (defined $userID and $userID ne "") {
			print CGI::ul(
				CGI::li(CGI::a({href=>$self->systemLink($userStats)}, $userID))
			);
		}
		if (defined $setID and $setID ne "") {
			print CGI::ul(
				CGI::li(CGI::a({href=>$self->systemLink($setStats)}, $setID))
			);
		}
		print CGI::end_li();
		print CGI::li(CGI::a({href=>$self->systemLink($files)}, $files->name));
		print CGI::end_ul();
		print CGI::end_li();
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
	my $urlpath = $r->urlpath;
	
	my $key = $r->param("key");
	
	if ($key) {
		my $courseID = $urlpath->arg("courseID");
		my $userID = $r->param("user");
		my $eUserID = $r->param("effectiveUser");
		
		my $stopActingURL = $self->systemLink($urlpath, # current path
			values => {
				effectiveUser => $userID,
			},
		);
		my $logoutURL = $self->systemLink($urlpath->newFromModule(__PACKAGE__ . "::Logout", courseID => $courseID));
		
		print "\n<!-- BEGIN " . __PACKAGE__ . "::loginstatus -->\n";
		
		print "Logged in as $userID. ";
		print CGI::a({href=>$logoutURL}, "Log Out");
		
		if ($eUserID ne $userID) {
			print " | Acting as $eUserID. ";
			print CGI::a({href=>$stopActingURL}, "Stop Acting");
		}
		
		print "<!-- END " . __PACKAGE__ . "::loginstatus -->\n";
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

Print an auxiliary options form, related to the content displayed in the
C<body>.

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

=item submiterror()

Defined in this package.

Print any error messages resulting from the last form submission.

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
	print $r->urlpath->name;
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

The implementation in this package always returns $arg, since most content
generators are only reachable when the user is authenticated. It is up to
classes that can be reached without logging in to override this method and
provide the correct behavior.

This is suboptimal, and may change in the future.

=cut

sub if_loggedin {
	my ($self, $arg) = @_;
	
	return $arg;
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

=item print_form_data($begin, $middle, $end, $omit)

Return a string containing every request field not matched by the quoted reguar
expression $omit, placing $begin before each field name, $middle between each
field name and its value, and $end after each value. Values are taken from the
current request.

=cut

sub print_form_data {
	my ($self, $begin, $middle, $end, $qr_omit) = @_;
	my $r=$self->r;
	my @form_data = $r->param;
	
	my $return_string = "";
	foreach my $name (@form_data) {
		next if ($qr_omit and $name =~ /$qr_omit/);
		my @values = $r->param($name);
		foreach my $variable (qw(begin name middle value end)) {
			# FIXME: can this loop be moved out of the enclosing loop?
			no strict 'refs';
			${$variable} = "" unless defined ${$variable};
		}
		foreach my $value (@values) {
			$return_string .= "$begin$name$middle$value$end";
		}
	}
	
	return $return_string;
}

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

A reference to a list containing names of parameters to add to the C<values>
hash below. The values are taken from the current request.

=item values

A reference to a hash associating request parameters with replacement values.
Each parameter listed here is added to the URL.

FIXME: this should be changed so that params is a hash, and a value is taken
from the current request if the value given is undef. The get rid of values. FIX
THIS SOON before too much code relies on it!

=item authen

If true, authentication parameters (C<user>, C<effectiveUser>, and <key>) will
be included in the list of C<params>. Since this is usually what you want, if
this option is not given a true value is assumed.

=back

=cut

# FIXME: there should probably be an option for prepending "http://hostname:port"
sub systemLink {
	my ($self, $urlpath, %options) = @_;
	my $r = $self->r;
	
	my @params = ();
	if (exists $options{params}) {
		croak "option 'params' is not an arrayref" unless ref $options{params} eq "ARRAY";
		@params = @{ $options{params} };
	}
	
	my %values = ();
	if (exists $options{values}) {
		croak "option 'values' is not an hashref" unless ref $options{values} eq "HASH";
		%values = %{ $options{values} };
	}
	
	my $authen = exists $options{authen} ? $options{authen} : 1;
	push @params, qw/user effectiveUser key/ if $authen;
	
	foreach my $param (@params) {
		next if exists $values{$param};
		$values{$param} = $r->param($param);
	}
	
	my $url = $r->location . $urlpath->path;
	
	if (keys %values) {
		$url .= "?";
		$url .= join("&", map { "$_=$values{$_}" } keys %values);
	}
	
	return $url;
}

=item nbsp($string)

If string consists of only whitespace, the HTML entity C<&nbsp;> is returned.
Otherwise $string is returned.

=cut

sub nbsp {
	my $self = shift;
	my $str  = shift;
	($str =~/\S/) ? $str : '&nbsp;';
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
		# FIXME: this message shouldn't refer the the "problem" since it is for general error reporting
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
		# FIXME: this message shouldn't refer the the "problem" since it is for general warning reporting
		CGI::h3("Warning messages"),
		CGI::ul(CGI::li(\@warnings));
}

=back

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu and Sam Hathaway,
sh002i (at) math.rochester.edu.

=cut

1;
