################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator;

=head1 NAME

WeBWorK::ContentGenerator - base class for modules that generate page content.

=cut

use strict;
use warnings;
use Apache::Constants qw(:common);
use CGI qw();
use URI::Escape;
use WeBWorK::Utils qw(readFile);
#use CGI::Carp qw(fatalsToBrowser);

################################################################################
# This is a very unruly file, so I'm going to use very large comments to divide
# it into logical sections.
################################################################################

# new(Apache::Request, WeBWorK::CourseEnvironment) -  create a new instance of a
# content generator. Usually only called by the dispatcher, although one might
# be able to use it for things like "sub-requests". Uh... uh... I have to think
# about that one. The dispatcher uses this idiom:
# 
# 
# 	WeBWorK::ContentGenerator::WHATEVER->new($r, $ce)->go(@whatever);
# 
# and throws away the result ;)
#
sub new($$$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	($self->{r}, $self->{courseEnvironment}) = @_;
	bless $self, $class;
	return $self;
}

################################################################################
# Invocation and template processing
################################################################################

# go(@otherArguments) - render a page, using methods from the particular
# subclass of ContentGenerator. @otherArguments is passed to each method, so
# that the dispatcher can pass CG-specific data. The order of calls looks like
# this:
# 
# 	* &pre_header_initialize - give subclasses a chance to do initialization
# 	  necessary for generating the HTTP header.
# 	* &header - this class provides a standard HTTP header with Content-Type
# 	  text/html. Subclasses are welcome to overload this for things like
# 	  an image-creation content generator or a PDF generator.
# 	* &initialize - let subclasses do post-header initialization.
# 	* any "template escapes" defined in the system template and supported by
# 	  the subclass. Generic implementations of &title and &body are provided.
# 
sub go {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};

	$self->pre_header_initialize(@_) if $self->can("pre_header_initialize");
	$self->header(@_);
	return OK if $r->header_only;
	
	$self->initialize(@_) if $self->can("initialize");
	$self->template($courseEnvironment->{templates}->{system}, @_);

	return OK;
}

# template(STRING, @otherArguments) - parse a template, looking for escapes of
# the form <!--#NAME ARG1="FOO" ARG2="BAR"--> and calling a member function NAME
# (if available) for each NAME. The escapes are called like:
# 
# 	$self->NAME(@otherArguments, \%escapeArguments)
# 
# where @otherArguments originates in the dispatcher and %escapeArguments is
# parsed out of the escape itself (i.e. ARG1 => FOO, ARG2 => BAR)
# 
sub template {
	my ($self, $templateFile) = (shift, shift);
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my @ifstack = (1); # Start off in printing mode
		# say $ifstack[-1] to get the result of the last <#!--if-->
	
	# so even though the variable $/ APPEARS to contain a newline,
	# <TEMPLATE> is slurping the whole file into the first element of
	# @template ONLY AFTER THE TRANSLATOR RUNS. WTF!!!
	#
	#open(TEMPLATE, $templateFile) or die "Couldn't open template $templateFile";
	#my @template = <TEMPLATE>;
	#close TEMPLATE;
	#
	# Let's try something else instead:
	my @template = split /\n/, readFile($templateFile);
	
	foreach my $line (@template) {
		#warn "foo: $line\n";
		# This is incremental regex processing.
		# the /c is so that pos($line) doesn't die when the regex fails.
		while ($line =~ m/\G(.*?)<!--#(\w*)((?:\s+.*?)?)-->/gc) {
			my ($before, $function, $raw_args) = ($1, $2, $3);
			# $args here will be a hashref
			my @args = $raw_args =~ /\S/ ? cook_args($raw_args) : {};
			if ($ifstack[-1]) {
				print $before;
			}

			if ($self->can($function)) {
				if ($function eq "if") {
					push @ifstack, $self->$function(@_, [@args]);
				} elsif ($function eq "else" and @ifstack > 1) {
					$ifstack[-1] = not $ifstack[-1];
				} elsif ($function eq "endif" and @ifstack > 1) {
					pop @ifstack;
				} elsif ($ifstack[-1]) {
					print $self->$function(@_, {@args});
				}
			}
		}
		
		if ($ifstack[-1]) {
			print substr $line, (defined pos $line) ? pos $line : 0;
		}
	}
}

# cook_args(STRING) - parses a string of the form ARG1="FOO" ARG2="BAR". Returns
# a list which pairs into key/values and fits nicely in {}s.
# 
sub cook_args($) {
	my ($raw_args) = @_;
	my @args = ();
	
	# Boy I love m//g in scalar context!  Go read the camel book, heathen.
	# First, get the whole token with the quotes on both ends...
	while ($raw_args =~ m/\G\s*(\w*)="((?:[^"\\]|\\.)*)"/g) {
		my ($key, $value) = ($1, $2);
		# ... then, rip out all the protecty backspaces
		$value =~ s/\\(.)/$1/g;
		push @args, $key => $value;
	}
	
	return @args;
}

################################################################################
# Macros used by content generators to render common idioms
################################################################################

# pathMacro(HASHREF, LIST) - helper macro for <!--#path--> escape: the hash
# reference contains the "style", "image", and "text" arguments to the escape.
# The LIST consists of ordered key-value pairs of the form:
# 
# 	"Page Name" => URL
# 
# If the page should not have a link associated with it, the URL should be left
# empty. Authentication data is added to the URL so you don't have to. A fully-
# formed path line is returned, suitable for returning by a function
# implementing the #path escape.
# 
sub pathMacro {
	my $self = shift;
	my %args = %{ shift() };
	my @path = @_;
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
		push @result, $url
			? CGI::a({-href=>"$url?$auth"}, $name)
			: $name;
	}
	return join($sep, @result), "\n";
}

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
	return join($sep, @result), "\n";
}

sub navMacro {
	my $self = shift;
	my %args = %{ shift() };
	my @links = @_;
	my $auth = $self->url_authen_args;
	my @result;
	while (@links) {
		my $name = shift @links;
		my $url = shift @links;
		push @result, $url
			? CGI::a({-href=>"$url?$auth"}, $name)
			: $name;
	}
	return join($args{separator}, @result), "\n";
}

# hidden_fields(LIST) - return hidden <INPUT> tags for each field mentioned in
# LIST (or all fields if list is empty), taking data from the current request.
# 
sub hidden_fields($;@) {
	my $self = shift;
	my $r = $self->{r};
	my @fields = @_;
	@fields or @fields = $r->param;
	my $courseEnvironment = $self->{courseEnvironment};
	my $html = "";
	
	foreach my $param (@fields) {
		my $value = $r->param($param);
		$html .= CGI::input({-type=>"hidden",-name=>"$param",-value=>"$value"});
	}
	return $html;
}

# hidden_authen_fields() - use hidden_fields to return hidden <INPUT> tags for
# request fields used in authentication.
# 
sub hidden_authen_fields($) {
	my $self = shift;
	return $self->hidden_fields("user","effectiveUser","key");
}

# url_args(LIST) - return a URL query string (without the leading `?')
# containing values for each field mentioned in LIST, or all fields if list is
# empty. Data is taken from the current request.
# 
sub url_args($;@) {
	my $self = shift;
	my $r = $self->{r};
	my @fields = @_;
	@fields or @fields = $r->param;
	my $courseEnvironment = $self->{courseEnvironment};
	
	my @pairs;
	foreach my $param (@fields) {
		my $value = $r->param($param) || "";
		push @pairs, uri_escape($param) . "=" . uri_escape($value);
	}
	
	return join("&", @pairs);
}

# url_authen_args() - use url_args to return a URL query string for request
# fields used in authentication.
# 
sub url_authen_args($) {
	my $self = shift;
	my $r = $self->{r};
	return $self->url_args("user","effectiveUser","key");
}

# print_form_data(BEGIN, MIDDLE, END, OMIT) - return a string containing request
# fields not matched by OMIT, placing BEGIN before each field name, MIDDLE
# between each field and its value, and END after each value. Values are taken
# from the current request. OMIT is a quoted reguar expression.
# 
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

################################################################################
# Generic versions of template escapes
################################################################################

# Reminder: here are the template functions currently defined:
# 
# path
# 	style = text|image
# 	image = URL of image
# 	text  = text separator
# links
# siblings
# nav
# 	style       = text|image
# 	imageprefix = prefix to image URL
# 	imagesuffix = suffix to image URL
# 	separator   = HTML to place in between links
# title
# body

sub header {
	my $self = shift;
	my $r = $self->{r};
	$r->content_type('text/html');
	$r->send_http_header();
}

sub links {
	my $self = shift;
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $probSets = "$root/$courseName/?" . $self->url_authen_args();
#	my $prefs    = "$root/prefs/?" . $self->url_authen_args();
#	my $help     = $ce->{webworkURLs}->{docs} . "?" . $self->url_authen_args();
	my $logout   = "$root/$courseName/";
	return
		CGI::a({-href=>$probSets}, "Problem Sets"), CGI::br(),
#		CGI::a({-href=>$prefs}, "User Options"), CGI::br(),
#		CGI::a({-href=>$help}, "Help"), CGI::br(),
		CGI::a({-href=>$logout}, "Log Out"), CGI::br(),
	;
}

# This is different.  It probably should print anything (except in debugging cases)
# and it should return a boolean, not a string.  &if is called in a nonstandard way
# by &template, with $args as an arrayref instead of a hashref.  this is a hack!  yay!
sub if {
	my ($self, $args) = @_[0,-1];
	# A single if "or"s it's components.  Nesting produces "and".
	
	my @args = @$args; # Hahahahaha, get it?!
	
	if (@args % 2 != 0) {
		# flip out and kill people, but do not commit seppuku
		print '<!--&if recieved an uneven number of arguments.  This shouldn\'t happen, but I\'ll let it slide.-->\n';
	}
	
	while (@args > 1) {
		my ($key, $value) = (shift @args, shift @args);
		
		if ($key eq "can" and $self->can($value)) {
			return 1;
		}

		# Other conditions go here, friend.
	}
	
	return 0;
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu
and Sam Hathaway, sh002i (at) math.rochester.edu.

=cut
