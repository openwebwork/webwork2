################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'WeBWorK::Controller', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator - base class for modules that generate page content.

=head1 SYNOPSIS

 # start with a WeBWorK::Controller object: $c

 use WeBWorK::ContentGenerator::SomeSubclass;

 my $cg = WeBWorK::ContentGenerator::SomeSubclass->new($c);
 my $result = $cg->go();

=head1 DESCRIPTION

WeBWorK::ContentGenerator provides the framework for generating page content.
"Content generators" are subclasses of this class which provide content for
particular parts of the system.

Default versions of methods used by the templating system are provided. Several
useful methods are provided for rendering common output idioms and some
miscellaneous utilities are provided.

=cut

use Carp;
use Date::Format;
use MIME::Base64;
use Scalar::Util qw(weaken);
use HTML::Entities;
use Encode;

use WeBWorK::File::Scoring qw(parse_scoring_file);
use WeBWorK::Localize;
use WeBWorK::Utils                       qw(fetchEmailRecipients generateURLs getAssetURL);
use WeBWorK::Utils::JITAR                qw(jitar_id_to_seq);
use WeBWorK::Utils::LanguageAndDirection qw(get_lang_and_dir);
use WeBWorK::Utils::Logs                 qw(writeCourseLog);
use WeBWorK::Utils::Routes               qw(route_title route_navigation_is_restricted);
use WeBWorK::Utils::Sets                 qw(format_set_name_display);
use WeBWorK::Authen::LTI::GradePassback  qw(massUpdate);

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

At this point, go() will terminate if the request is a HEAD request.

=item 4

go() then attempts to call the method initialize(). This method may be
implemented in subclasses which must do processing after the HTTP header is sent
but before any content is sent.

=item 5

The method content() is called to send the page content to client.

=back

=cut

async sub go ($c) {
	my $ce = $c->ce;

	# If grades are being passed back to the lti, then peroidically update all of the
	# grades because things can get out of sync if instructors add or modify sets.
	massUpdate($c) if $c->stash('courseID') && ref($c->db) && $ce->{LTIGradeMode};

	# Check to determine if this is a problem set response.  Individual content generators must check
	# $c->{invalidSet} and react appropriately.
	$c->{invalidSet} = $c->authz->checkSet;

	# We only write to the activity log if it has been defined and if we are in a specific course.  The latter check is
	# to prevent attempts to write to a course log file when viewing the top-level list of courses page.
	writeCourseLog($ce, 'activity_log', $c->prepare_activity_entry)
		if ($c->stash('courseID') && $c->ce->{courseFiles}{logs}{activity_log});

	my $tx = $c->render_later->tx;

	$c->stash->{footerWidthClass} = $c->can('info') ? 'col-md-8' : 'col-12';

	if ($c->can('pre_header_initialize')) {
		my $pre_header_initialize = $c->pre_header_initialize;
		await $pre_header_initialize
			if ref $pre_header_initialize eq 'Future' || ref $pre_header_initialize eq 'Mojo::Promise';
	}

	# Reply with a file.
	if (defined $c->{reply_with_file}) {
		return $c->do_reply_with_file($c->{reply_with_file});
	}

	# Reply with a redirect.
	if (defined $c->{reply_with_redirect}) {
		return $c->do_reply_with_redirect($c->{reply_with_redirect});
	}

	if ($c->can('initialize')) {
		my $initialize = $c->initialize;
		await $initialize if ref $initialize eq 'Future' || ref $initialize eq 'Mojo::Promise';
	}

	$c->content;

	# All content generator modules must have rendered at this point unless there was an error in which case an error
	# response will be rendered.  There is no special handing for HEAD requests.  Mojolicious takes care of that in its
	# render methods.  This just returns the status code of the response (typically set by the Mojolicious render
	# methods.  Although this return value isn't actually used at this point.
	return $c->header;
}

=item do_reply_with_file($fileHash)

Handler for reply_with_file(), used by go(). DO NOT CALL THIS METHOD DIRECTLY.

=cut

sub do_reply_with_file ($c, $fileHash) {
	my $type         = $fileHash->{type};
	my $source       = $fileHash->{source};
	my $name         = $fileHash->{name};
	my $delete_after = $fileHash->{delete_after};

	# If there was a problem, render the appropriate error response.
	return $c->render(text => 'File not found',           status => 404) unless -e $source;
	return $c->render(text => 'Insufficient permissions', status => 403) unless -r $source;

	# Send our custom HTTP header.
	$c->res->headers->content_type($type);
	$c->res->headers->add("Content-Disposition" => qq{attachment; filename="$name"});

	# send the file
	$c->reply->file($source);

	if ($delete_after) {
		unlink $source or $c->log->warn("failed to unlink $source after sending: $!");
	}

	return $c->res->code;
}

=item do_reply_with_redirect($url)

Handler for reply_with_redirect(), used by go(). DO NOT CALL THIS METHOD DIRECTLY.

=cut

sub do_reply_with_redirect ($c, $url) {
	$c->redirect_to($url);
	return $c->res->code;
}

=back

=cut

=head1 DATA MODIFIERS

Modifiers allow the caller to register a piece of data for later retrieval in a
standard way.

=over

=item reply_with_file($type, $source, $name, $delete_after)

Enables file sending mode, causing go() to send the file specified by $source to
the client after calling pre_header_initialize(). The content type sent is
$type, and the suggested client-side file name is $name. If $delete_after is
true, $source is deleted after it is sent.

Must be called from pre_header_initialize().

=cut

sub reply_with_file ($c, $type, $source, $name, $delete_after = 0) {
	$c->{reply_with_file} = {
		type         => $type,
		source       => $source,
		name         => $name,
		delete_after => $delete_after,
	};

	return;
}

=item reply_with_redirect($url)

Enables redirect mode, causing go() to redirect to the given URL after calling
pre_header_initialize().

Must be called from pre_header_initialize().

=cut

sub reply_with_redirect ($c, $url) {
	$c->{reply_with_redirect} = $url;
	return;
}

=item addmessage($message)

Adds a message to the list of messages to be output by the message() template
escape handler.

Must be called before the message() template escape is invoked.

=cut

sub addmessage ($c, $message) {
	return '' unless defined $message;
	$c->{status_message} //= $c->c;
	push(@{ $c->{status_message} }, $message);
	return;
}

=item addgoodmessage($message)

Adds a success message to the list of messages to be output by the
message() template escape handler.

=cut

sub addgoodmessage ($c, $message) {
	$c->addmessage($c->tag(
		'div',
		class => 'alert alert-success alert-dismissible fade show ps-1 py-1',
		role  => 'alert',
		$c->c(
			$message,
			$c->tag(
				'button',
				type         => 'button',
				class        => 'btn-close p-2',
				data         => { bs_dismiss => 'alert' },
				'aria-label' => $c->maketext('Dismiss')
			)
		)->join('')
	));
	return;
}

=item addbadmessage($message)

Adds a failure message to the list of messages to be output by the
message() template escape handler.

=cut

sub addbadmessage ($c, $message) {
	$c->addmessage($c->tag(
		'div',
		class => 'alert alert-danger alert-dismissible fade show ps-1 py-1',
		role  => 'alert',
		$c->c(
			$message,
			$c->tag(
				'button',
				type         => 'button',
				class        => 'btn-close p-2',
				data         => { bs_dismiss => 'alert' },
				'aria-label' => $c->maketext('Dismiss')
			)
		)->join('')
	));
	return;
}

=item prepare_activity_entry()

Prepare a string to be sent to the activity log, if it is turned on.
This can be overridden by different modules.

=cut

sub prepare_activity_entry ($c) {
	my $location = $c->location;
	my $string =
		($c->req->url->path->to_string =~ s/^$location//r)
		. "  --->  "
		. join("\t", (map { $_ eq 'key' || $_ eq 'passwd' ? '' : $_ . " => " . $c->param($_) } $c->param()));
	$string =~ s/\t+/\t/g;
	return $string;
}

=back

=cut

################################################################################

=head1 STANDARD METHODS

The following are the standard content generator methods. Some are defined here,
but may be overridden in a subclass. Others are not defined unless they are
defined in a subclass.

FIXME: The names of the first three methods don't really make sense anymore.
There really is no need for both of the pre_header_initialize and initialize
methods.  The initialize method should be dropped and the pre_header_initialize
method renamed.

=over

=item pre_header_initialize()

Not defined in this package.

May be defined by a subclass to perform any early processing that is needed.
This method must be used if responding with a file or redirect.

This method may be asynchronous.

=item header()

Defined in this package.

This method is not really useful anymore.  For now it returns the response
status code and this return value is ignored.  Headers are now set when
rendering a response (as it really should have been done before.

=cut

sub header {
	my $self = shift;
	return $self->res->code;
}

=item initialize()

Not defined in this package.

May be defined by a subclass to perform any early processing that is needed.
This method cannot be used if responding with a file or redirect.

This method may be asynchronous.

=item output_course_lang_and_dir()

Output the LANG and DIR tags in the main HTML tag of a generated web page when
a template file calls this function.

This calls WeBWorK::Utils::LanguageAndDirection::get_lang_and_dir.

=cut

sub output_course_lang_and_dir ($c) {
	return get_lang_and_dir($c->ce->{language});
}

=item webwork_logo()

Create the link to the webwork installation landing page with a logo and alt text

=cut

sub webwork_logo ($c) {
	my $ce = $c->ce;

	if ($c->authen->was_verified && !$c->authz->hasPermissions($c->param('user'), 'navigation_allowed')) {
		# If navigation is restricted for this user, then the webwork logo is not a link to the courses page.
		return $c->tag(
			'span',
			$c->image(
				"$ce->{webwork_htdocs_url}/themes/$ce->{defaultTheme}/images/webwork_logo.svg",
				alt => 'WeBWorK'
			)
		);
	} else {
		return $c->link_to(
			$c->image("$ce->{webwork_htdocs_url}/themes/$ce->{defaultTheme}/images/webwork_logo.svg",
				alt => $c->maketext('to courses page')) => $ce->{webwork_url}
		);
	}
}

=item institution_logo()

Create the link to the host institution with a logo and alt text

=cut

sub institution_logo ($c) {
	my $ce = $c->ce;
	return $c->link_to(
		$c->image(
			"$ce->{webwork_htdocs_url}/themes/$ce->{defaultTheme}/images/$ce->{institutionLogo}",
			alt => $c->maketext("to [_1] main web site", $ce->{institutionName})
		) => $ce->{institutionURL}
	);
}

=item content()

Defined in this package.

Print the content of the generated page.

This renders the Mojo::Template corresponding to the called ContentGenerator sub-package.

=cut

sub content ($c) {
	my $ce = $c->ce;
	return $c->render(template => ((ref($c) =~ s/^WeBWorK:://r) =~ s/::/\//gr), layout => 'system');
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Template escape handlers

Template escape handlers are invoked in the templates.

Some of the template escapes handlers are defined here but may be overridden
in a subclass.  Others, like C<head> and C<info> are not defined here, but
may be defined in a subclass if needed.

=over

=item head()

Not defined in this package.

Any tags that should appear in the HEAD of the document.

=item info()

Not defined in this package.

Auxiliary information related to the content displayed in the C<body>.

=item links()

Defined in this package.

Links that should appear on every page.

=cut

sub links ($c) {
	my $ce     = $c->ce;
	my $db     = $c->db;
	my $authen = $c->authen;
	my $authz  = $c->authz;

	# Grab data from the request.
	my $userID        = $c->param('user');
	my $eUserID       = $c->param('effectiveUser');
	my $courseID      = $c->stash('courseID');
	my $setID         = $c->stash('setID');
	my $problemID     = $c->stash('problemID');
	my $achievementID = $c->stash('achievementID');

	# Determine if navigation is restricted for this user.
	my $restricted_navigation = $authen->was_verified && !$authz->hasPermissions($userID, 'navigation_allowed');

	# If navigation is restricted and the setID was not in the route stash,
	# then get the setID this user is restricted to view from the session.
	$setID = $authen->session('set_id') if !$setID && $restricted_navigation;

	my $prettyProblemID = $problemID;

	# It's possible that the setID and the problemID are invalid, since they're just taken from the URL path info.
	if ($authen->was_verified) {
		if (defined $setID && $db->existsUserSet($eUserID, $setID)) {
			$problemID = undef unless (defined $problemID && $db->existsUserProblem($eUserID, $setID, $problemID));
		} else {
			$setID     = undef;
			$problemID = undef;
		}
	}

	# System link parameters that are common to all links (except the Courses link).
	my %systemlink_params = (
		$c->param('displayMode')    ? (displayMode    => $c->param('displayMode'))    : (),
		$c->param('showOldAnswers') ? (showOldAnswers => $c->param('showOldAnswers')) : ()
	);

	my $current_url = $c->url_for;

	# Subroutine for generating links.
	my $makelink = sub {
		my ($route_name, %options) = @_;

		my $new_url = $c->url_for($route_name, courseID => $courseID, %{ $options{captures} || {} });

		# If 'active' is not set in the options, then determine the active link
		# by comparing the generated url to the current url.
		my $active = $options{active} // $c->current_route eq $route_name && $new_url eq $current_url;

		# Do not use HTML::Entities::encode_entities on the link text.
		# Mojolicious has already encoded html entities at this point.
		return $c->link_to(
			($options{text} // route_title($c, $route_name, 1)) => $c->systemLink(
				$new_url, params => { %systemlink_params, %{ $options{systemlink_params} // {} } }
			),
			class => 'nav-link' . ($active ? ' active' : ''),
			$options{target} ? (target => $options{target}) : (),
			%{ $options{link_attrs} // {} }
		);
	};

	return $c->include(
		'ContentGenerator/Base/links',
		courseID              => $courseID,
		userID                => $userID,
		eUserID               => $eUserID,
		urlUserID             => $c->stash('userID'),
		setID                 => $setID,
		prettySetID           => format_set_name_display($setID // ''),
		problemID             => $problemID,
		prettyProblemID       => $prettyProblemID,
		achievementID         => $achievementID,
		restricted_navigation => $restricted_navigation,
		makelink              => $makelink,
	);
}

=item nav($args)

Not defined in this package.

Links to the previous, next, and parent objects.

$args is a reference to a hash containing the following fields:

 style       => text|buttons
 separator   => HTML to place in between links

For example:

 <!--#nav style="buttons" separator=" "-->

=item options()

Not defined in this package.

View options related to the content displayed in the body or info areas.

=item path($args)

Defined in this package.

Print "breadcrubs" from the root of the virtual hierarchy to the current page.
$args is a reference to a hash containing the following fields:

 style    => type of separator: text|image
 image    => if style=image, URL of image to use as path separator
 text     => if style=text, text to use as path separator
             if style=image, the ALT text of each separator image
 textonly => suppress all HTML, return only plain text

The implementation in this package gathers the route information from the
current request.

=cut

sub path ($c, $args = {}) {
	my $route = $c->app->routes->lookup($c->current_route);

	# Determine if navigation is restricted for this user.
	my $restrict_navigation =
		$c->authen->was_verified && !$c->authz->hasPermissions($c->param('user'), 'navigation_allowed');

	my @path;

	do {
		my $title = route_title($c, $route->name);
		# If it is a problemID for a jitar set, then display the pretty id.
		if ($route->name eq 'problem_detail' && $c->stash('setID')) {
			my $set = $c->db->getGlobalSet($c->stash('setID'));
			if ($set && $set->assignment_type eq 'jitar') {
				$title = join('.', jitar_id_to_seq($c->stash('problemID')));
			}
		}

		# If navigation is restricted for this user and path, then don't provide the link.
		unshift @path, $title,
			$restrict_navigation && route_navigation_is_restricted($route) ? '' : $c->url_for($route->name);
	} while (($route = $route->parent) && ref($route) eq 'Mojolicious::Routes::Route');

	# We don't want the last path element to be a link.
	$path[-1] = '';

	return $c->pathMacro($args, @path);
}

=item siblings()

Not defined in this package.

Print links to siblings of the current object.

=item timestamp()

Defined in this package.

Display the current time and date in the 'datetime_format_long' format.  For
example, for the 'en' language this will give "January 4, 2023 at 8:54:33 PM EST".
Note that the "at" is replaced with a comma for the latest version of
DateTime::Locale::FromData.

=cut

sub timestamp ($c) {
	return $c->formatDateTime(time, 'datetime_format_long');
}

=item message()

Defined in this package.

Print any messages (error or non-error) resulting from the last form submission.
This could be used to give Sucess and Failure messages after an action is performed by a module.

The implementation in this package outputs the value of the field
$c->{status_message}, if it is present.

=cut

sub message ($c) {
	$c->{status_message} //= $c->c;
	return $c->{status_message}->join('');
}

=item page_title()

Defined in this package.

Print the title of the current page.

The implementation in this package takes information from the current route.

=cut

sub page_title ($c) {
	my $ce = $c->ce;
	my $db = $c->db;

	# If the current route name is 'set_list' and the course has a course title then display that.
	if ($c->current_route eq 'set_list') {
		my $courseTitle = $db->getSettingValue('courseTitle');
		return $courseTitle if defined $courseTitle && $courseTitle ne '';
	}

	# Display the route name
	return route_title($c, $c->current_route, 1);
}

=item webwork_url

Defined in this package.

Outputs the $webwork_url defined in site.conf, unless $webwork_url is equal to
"/", in which case this outputs the empty string.

This is used to set a value in a global webworkConfig javascript variable,
that can be accessed in javascript files.

=cut

sub webwork_url ($c) {
	return $c->location;
}

=item warnings()

Defined in this package.

Print accumulated warnings.

The implementation in this package checks for a stash key named
"warnings". If present, its contents are formatted and returned.

=cut

sub warnings ($c) {
	return $c->include('ContentGenerator/Base/warning_output', warnings => [ split m/\n+/, $c->stash('warnings') ])
		if $c->stash('warnings');
	return '';
}

=item help()

Display a link to context-sensitive help for the current content generator module.

=cut

sub help ($c, $args) {
	return $c->helpMacro((ref($c) =~ s/WeBWorK::ContentGenerator:://r) =~ s/://gr, $args);
}

=item url($args)

Defined in this package.

Returns the specified URL from either %webworkURLs or %courseURLs in the course
environment. $args is a reference to a hash containing the following fields:

 type => type of URL: webwork|course (defaults to webwork)
 name => name of URL type (must be 'theme' or undefined)
 file => the local file name

=cut

sub url ($c, $args) {
	my $ce   = $c->ce;
	my $type = $args->{type} // 'webwork';
	my $name = $args->{name} // '';
	my $file = $args->{file};

	if ($type eq "webwork") {
		# We have to build this here (and not in say defaults.conf) because
		# defaultTheme will change as late as simple.conf.

		# If $file is defined, then try to look it up in the assets list.
		return getAssetURL($ce, $file, $name eq 'theme') if defined $file;

		# Fallback to the old method if $file was not defined.
		# This assumes the rest of the file path is appended after this.
		if ($name eq "theme") {
			return "$ce->{webworkURLs}{themes}/$ce->{defaultTheme}";
		} else {
			return $ce->{webworkURLs}{$name};
		}
	} elsif ($type eq "course") {
		return $ce->{courseURLs}{$name};
	} else {
		warn __PACKAGE__ . "::url: unrecognized type '$type'.\n";
	}
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Template conditions

Template condition methods are called in the template. If a method is defined
here or overridden in the instantiated subclass, it is invoked.

The following conditions are currently defined:

=over

=item can($function)

If a function named $function is present in the current content generator (or
any superclass), a true value is returned. Otherwise, a false value is returned.

This package just uses the UNIVERSAL::can() function.

A subclass could redefine this method to, for example, "hide" a method from the
template:

    sub can ($c, $arg) {
        my ($c, $arg) = @_;

        if ($arg eq "floobar") {
        	return 0;
        } else {
        	return $c->SUPER::can($arg);
        }
    }

=cut

=item have_warnings

If warnings have been emitted while handling this request return true, otherwise
return false.

This implementation checks if a stash value named "warnings" has been set or if
there are pg errors.

=cut

sub have_warnings ($c) {
	return $c->stash('warnings') || $c->{pgerrors};
}

=item exists_theme_file

Returns true if the specified file exists in the current theme directory
and false otherwise

=cut

sub exists_theme_file ($c, $arg) {
	my $ce = $c->ce;
	return -e "$ce->{webworkDirs}{themes}/$ce->{defaultTheme}/$arg";
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

 "Page Name" => Mojo::URL

If the page should not have a link associated with it, the URL should be the
empty string. Authentication data is added to each URL so you don't have to. A
fully-formed path line is returned, suitable for returning by a function
implementing the C<#path> escape.

=cut

sub pathMacro ($c, $args, @path) {
	my %args = %$args;
	$args{style} = 'text' if $args{textonly};

	my %auth = $c->url_authen_args;

	my $result = $c->c;
	while (@path) {
		my $name = shift @path;
		my $url  = shift @path;

		# Skip blank names. Blanks can happen for course header and set header files.
		next unless $name =~ /\S/;

		$name =~ s/_/ /g;

		if ($url && !$args{textonly}) {
			if ($args{style} eq 'bootstrap') {
				push @$result, $c->tag('li', class => 'breadcrumb-item', $c->link_to($name => $url->query(\%auth)));
			} else {
				push @$result, $c->link_to($name => $url->querylu(%auth));
			}
		} else {
			if ($args{style} eq 'bootstrap') {
				push @$result, $c->tag('li', class => 'breadcrumb-item active', $name);
			} else {
				push @$result, $name;
			}
		}
	}

	return $result->join($args{text});
}

=item navMacro($args, $tail, @links)

Helper macro for the C<#nav> escape sequence: C<$args> is a hash reference
containing the "style" and "separator" arguments to the escape.
C<@links> consists of ordered tuples of the form:

 "Link Name", Mojo::URL

If a nav element should not have a link associated with it, the URL should be
the empty string.  C<$tail> should be a hash reference of URL query parameters
to add to each URL after the authentication information.  A fully-formed nav
line is returned, suitable for returning by a function implementing the C<#nav>
escape.

=cut

sub navMacro ($c, $args, $tail, @links) {
	my $ce   = $c->ce;
	my %args = %$args;

	my %auth = $c->url_authen_args;

	my $result = $c->c;
	while (@links) {
		my $name      = shift @links;
		my $url       = shift @links;
		my $direction = shift @links;
		my $html      = ($direction && $args{style} eq "buttons") ? $direction : $name;
		push @$result,
			$url
			? $c->link_to($html => $url->query(%auth, %$tail), class => 'btn btn-primary')
			: $c->tag('span', class => 'btn btn-primary disabled', $html);
	}

	return $result->join($args{separator});
}

=item helpMacro($name)

This method outputs a link that opens a modal dialog containing the results of rendering a
HelpFiles template.  The template file that is rendered is $name.html.  If that file does not
exist, then nothing is output.

The optional argument $args is a hash that may contain the keys label, label_size, help_label,
or class. $args->{label} is the displayed label. $args->{label_size} is a font awesome size class
and is only used if $args->{label} is not set. $args->{help_label} is the hidden description of
the help button, "help_label help.", which defaults to the page title, and is only used if
$args->{label} is not set. $args->{class} is added to the html class attribute if defined.

=cut

sub helpMacro ($c, $name, $args = {}) {
	my $ce = $c->ce;
	return '' unless -e "$ce->{webworkDirs}{root}/templates/HelpFiles/$name.html.ep";

	my $label = $args->{label} // $c->tag(
		'i',
		class         => 'icon fa-solid fa-circle-question ' . ($args->{label_size} // ''),
		'aria-hidden' => 'true',
		''
		)
		. $c->tag(
			'span',
			class => 'visually-hidden',
			$c->maketext('[_1] help.', $args->{help_label} // $c->page_title)
		);
	delete $args->{label};
	delete $args->{label_size};
	delete $args->{help_label};

	return $c->include("HelpFiles/$name", name => $name, label => $label, args => $args);
}

=item feedbackMacro(%params)

Helper macro for displaying the feedback form. Returns a button named "Email
Instructor". %params contains the request parameters accepted by the Feedback
module and their values.

=cut

sub feedbackMacro ($c, %params) {
	return '' unless $c->authz->hasPermissions($c->param('user'), 'submit_feedback');

	if ($c->ce->{courseURLs}{feedbackURL}) {
		return $c->link_to(($c->maketext($c->ce->{feedback_button_name}) || $c->maketext('Email instructor')) =>
				$c->ce->{courseURLs}{feedbackURL});
	} elsif ($c->ce->{courseURLs}{feedbackFormURL}) {
		$params{notifyAddresses} =
			join(';', $c->fetchEmailRecipients('receive_feedback', $c->db->getUser($c->param('user'))));
		return $c->include(
			'ContentGenerator/Base/feedback_macro_form',
			params          => \%params,
			feedbackFormURL => $c->ce->{courseURLs}{feedbackFormURL}
		);
	} else {
		return $c->include('ContentGenerator/Base/feedback_macro_email', params => \%params);
	}
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

A hash of options may be passed for the first argument of this method.  The only
supported option is an "id_prefix" to prepend to the id's of all of the hidden
inputs that are created.

=cut

# FIXME: Hidden fields have no need for an id attribute.  Fix the javascript that finds these in by using the id, and
# remove the id here.  Then the id_prefix hack isn't needed.  The name does not need to be unique.
sub hidden_fields ($c, @fields) {
	my %options   = ref $fields[0] eq 'HASH' ? %{ shift @fields } : ();
	my $id_prefix = $options{id_prefix} // '';

	@fields = $c->param unless @fields;

	my $html = $c->c;
	for my $param (@fields) {
		my @values = $c->param($param);
		for my $value (@values) {
			next unless defined($value);
			push(@$html, $c->hidden_field($param => $value, id => "${id_prefix}hidden_$param"));
		}
	}

	return $html->join('');
}

=item hidden_authen_fields()

Use hidden_fields to return hidden <INPUT> tags for request fields used in
authentication.

An optional $id_prefix may be passed as the first argument of this method.

If session_management_via is "session_cookie" then the hidden authentication
fields that are return are for the "user" and the "effectiveUser".  If
session_management_via is "key" then the "key" is added.

=cut

# FIXME: The "user" also should not be added to forms when session_management_via is "session_cookie". However, the
# user param is used everywhere to get the user id.  That should be changed.
sub hidden_authen_fields ($c, $id_prefix = undef) {
	my @fields = ('user', 'effectiveUser');
	push(@fields, 'key') if $c->ce->{session_management_via} ne 'session_cookie';

	# Make the Shibboleth bypass_query parameter persistent if it is configured.
	push(@fields, $c->ce->{shibboleth}{bypass_query}) if $c->ce->{shibboleth}{bypass_query};

	return $c->hidden_fields({ id_prefix => $id_prefix }, @fields) if defined $id_prefix;
	return $c->hidden_fields(@fields);
}

=item url_args(@fields)

Return a hash containing values for each field mentioned in @fields, or all
fields if list is empty. Data is taken from the current request.  This return
value is suitable for passing to the Mojo::URL query method.

=cut

sub url_args ($c, @fields) {
	@fields = $c->param unless @fields;

	my %params;
	for my $param (@fields) {
		$params{$param} = [ $c->param($param) ] if defined $c->param($param);
	}

	return %params;
}

=item url_authen_args()

Use url_args to return a hash of request fields used in authentication that is
suitable for passing to the Mojo::URL query method.

=cut

sub url_authen_args ($c) {
	my $ce = $c->ce;

	# When cookie based session management is in use, there should be no need
	# to reveal the user and key in the URL. Putting it there makes session
	# hijacking easier, in particular should a student share such a URL.
	# If the Shibboleth authentication module is in use, then make the bypass_query parameter persistent.
	if ($ce->{session_management_via} eq 'session_cookie') {
		return $c->url_args('effectiveUser', $c->ce->{shibboleth}{bypass_query} // ());
	} else {
		return $c->url_args('user', 'effectiveUser', 'key', $c->ce->{shibboleth}{bypass_query} // ());
	}
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Utilities

=over

=item systemLink($urlpath, %options)

Generate a link to another part of the system. $urlpath is Mojo::URL
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
C<effectiveUser>, and C<key>) are included in the generated link unless
explicitly listed in C<params>.

=item use_abs_url

If set to a true value, the scheme, host, and port are prepended to the URL.
This is useful for links which must be usable on their own, such as those sent
via email.

=back

=cut

sub systemLink ($c, $urlpath, %options) {
	my %params;
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

	if ($options{authen} // 1) {
		# When cookie based session management is in use, there should be no need
		# to reveal the user and key in the URL. Putting it there makes session
		# hijacking easier, in particular should a student share such a URL.
		if ($c->ce->{session_management_via} eq "session_cookie") {
			delete $params{user};
			delete $params{key};
		} else {
			$params{user} = undef unless exists $params{user};
			$params{key}  = undef unless exists $params{key};
		}

		$params{effectiveUser} = undef unless exists $params{effectiveUser};

		# Make the Shibboleth bypass_query parameter persistent if it is configured.
		$params{ $c->ce->{shibboleth}{bypass_query} } = undef if $c->ce->{shibboleth}{bypass_query};
	}

	my $url = $options{use_abs_url} ? $urlpath->to_abs : $urlpath;

	for my $name (keys %params) {
		$params{$name} = [ $c->param($name) ] if (!defined $params{$name} && defined $c->param($name));
	}

	return %params ? $url->query(%params) : $url;
}

=item nbsp($string)

If string consists of only whitespace, the HTML entity C<&nbsp;> is returned.
Otherwise $string is returned.

=cut

sub nbsp ($c, $str) {
	return (defined $str && $str =~ /\S/) ? $str : '&nbsp;';
}

=item errorOutput($error, $details)

Used by Problem, ProblemSet, and Hardcopy to report errors encountered during
problem rendering.

=cut

sub errorOutput ($c, $error, $details) {
	return $c->include('ContentGenerator/Base/error_output', error => $error, details => $details);
}

=item warningMessage

Used to display a generic warning message at the top of the page

=cut

sub warningMessage ($c) {
	return $c->maketext('<strong>Warning</strong>: There may be something wrong with this question. '
			. 'Please inform your instructor including the warning messages below.');
}

=item $string = formatDateTime($date_time, $format_string, $timezone, $locale)

Formats a C<$date_time> epoch into a string in the format defined by
C<$format_string>. If C<$format_string> is not provided, the default WeBWorK
date/time format is used.  If C<$format_string> is a method of the
C<< $dt->locale >> instance, then C<format_cldr> is used, and otherwise
C<strftime> is used. The available patterns for $format_string can be found at
L<DateTime/strftime Patterns>. The available methods for the C<< $dt->locale >>
instance are documented at L<DateTime::Locale::FromData>. If C<$timezone> is
given, then the formatted string that is returned is in the specified timezone.
If C<$locale> is provided, the string returned will be in the format of that
locale. If C<$locale> is not provided, Perl defaults to using C<en-US>.

Note that the defaults for C<$timezone> and C<$locale> should almost never be
overriden when this method is used.

=cut

sub formatDateTime ($c, $date_time, $format_string = undef, $timezone = undef, $locale = undef) {
	my $ce = $c->ce;
	$timezone ||= $ce->{siteDefaults}{timezone};
	$locale   ||= $ce->{language};
	return WeBWorK::Utils::DateTime::formatDateTime($date_time, $format_string, $timezone, $locale);
}

=item read_scoring_file($fileName)

Wrapper for WeBWorK::File::Scoring that no-ops if $fileName is "None" and
prepends the path to the scoring directory.

=cut

sub read_scoring_file ($c, $fileName) {
	return {} if $fileName eq "None";    # callers expect a hashref in all cases
	return parse_scoring_file($c->ce->{courseDirs}{scoring} . "/$fileName");
}

=back

=cut

1;
