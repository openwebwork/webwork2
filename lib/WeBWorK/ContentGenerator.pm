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
use WeBWorK::Authz;
use WeBWorK::DB;
use WeBWorK::Utils qw(readFile);

################################################################################
# This is a very unruly file, so I'm going to use very large comments to divide
# it into logical sections.
################################################################################

# new(Apache::Request, WeBWorK::CourseEnvironment, WeBWorK::DB) - create a new    
# instance of a content generator. Usually only called by the dispatcher, although
# one might be able to use it for things like "sub-requests". Uh... uh... I have  
# to think about that one. The dispatcher uses this idiom:                        
# 
# 	WeBWorK::ContentGenerator::WHATEVER->new($r, $ce, $db)->go(@whatever);
# 
# and throws away the result ;)
#
sub new {
	my ($invocant, $r, $ce, $db) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		r  => $r,
		ce => $ce,
		db => $db,
		authz => WeBWorK::Authz->new($r, $ce, $db),
		noContent => undef,
	};
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
#	  In addition, if &header returns a value, that will be the value
#         returned by the entire PerlHandler.
# 	* &initialize - let subclasses do post-header initialization.
# 	* any "template escapes" defined in the system template and supported by
# 	  the subclass.
#         (if &content exists on a content generator, it is called
#         and no template processing occurs.)
#
# If &pre_header_initialize or &header sets $self->{noContent} to a true value,
# &initialize will not be run and the content or template processing code
# will not be executed.  This is probably only desirable if a redirect has been
# issued.
sub go {
	my $self = shift;
	
	my $r = $self->{r};
	my $ce = $self->{ce};
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
		$self->template($ce->{templates}->{$templateName}, @_);
	}
	
	return $returnValue;
}

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
	my $courseEnvironment = $self->{ce};
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
		# This is incremental regex processing.
		# the /c is so that pos($line) doesn't die when the regex fails.
		while ($line =~ m/\G(.*?)<!--#(\w*)((?:\s+.*?)?)-->/gc) {
			my ($before, $function, $raw_args) = ($1, $2, $3);
			my @args = ($raw_args =~ /\S/) ? cook_args($raw_args) : ();
			
			if ($ifstack[-1]) {
				print $before;
			}
			
			if ($function eq "if") {
				# a predicate can only be true if everything else on the ifstack is already true, for ANDing
				push @ifstack, ($self->$function(@_, [@args]) && $ifstack[-1]);
			} elsif ($function eq "else" and @ifstack > 1) {
				$ifstack[-1] = not $ifstack[-1];
			} elsif ($function eq "endif" and @ifstack > 1) {
				pop @ifstack;
			} elsif ($ifstack[-1]) {
				if ($self->can($function)) {
					my @result = $self->$function(@_, {@args});
					if (@result) {
						print @result;
					} else {
						warn "Template escape $function returned an empty list.";
					}
				}
			}
		}
		
		if ($ifstack[-1]) {
			print substr($line, (defined pos $line) ? pos $line : 0), "\n";
		}
	}
}

# cook_args(STRING) - parses a string of the form ARG1="FOO" ARG2="BAR". Returns
# a list which pairs into key/values and fits nicely in {}s.
# 
sub cook_args($) { # ... also used by bin/wwdb, so watch out
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

# This is different.  It probably shouldn't print anything (except in debugging cases)
# and it should return a boolean, not a string.  &if is called in a nonstandard way
# by &template, with $args as an arrayref instead of a hashref.  this is a hack!  yay!

# OK, this is a pluggin architecture.  it iterates through attributes of the "if" tag,
# and for each predicate $p, it calls &if_$p in an object-oriented way, continuing the
# grand templating theme of an object-oriented pluggable architecture using ->can($).
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
		
		# a non-existent &if_$key is the same as a false result, but we're ORing, so it's OK
		my $sub = "if_$key"; # perl doesn't like it when you try to construct a string right in a method invocation
		if ($self->can("if_$key") and $self->$sub("$value")) {
			return 1;
		}
	}
	
	return 0;
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
	return join($sep, @result) . "\n";
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

# hidden_fields(LIST) - return hidden <INPUT> tags for each field mentioned in
# LIST (or all fields if list is empty), taking data from the current request.
# 
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

################################################################################
# Generic versions of template escapes
################################################################################

# Reminder: here are the template functions currently defined:
# FIXME: this list is out of date!!!!!!!!
# 
# head
# path
# 	style = text|image
# 	image = URL of image
# 	text  = text separator
# loginstatus
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

sub loginstatus {
	my $self = shift;
	my $r = $self->{r};
	my $user = $r->param("user");
	my $eUser = $r->param("effectiveUser");
	my $key = $r->param("key");
	return "" unless $key;
	my $exitURL = $r->uri() . "?user=$user&key=$key";
	print CGI::small("User:", "$user");
	if ($user ne $eUser) {
		print CGI::br(), CGI::font({-color=>'red'},
				CGI::small("Acting as:", "$eUser")
			),
			CGI::br(), CGI::a({-href=>$exitURL},
				CGI::small("Stop Acting")
			);
	}
	return "";
}

# FIXME: drunk code. rewrite.
# also, this should be structured s.t. subclasses can add items to the links
# area, i.e. "stacking"
sub links {
	my $self = shift;
	my @components = @_;
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $userName = $self->{r}->param("user");
	my $courseName = $ce->{courseName};
	my $root = $ce->{webworkURLs}->{root};
	
	#my $Key = $db->getKey($userName); # checked
	#my $key = (defiend $key
	#	? $Key->key()
	#	: "");
	#
	#return "" unless defined $key;
	# This has been replaced by using "#if loggedin" in ur.template.
	
	# URLs to parts of the system
	my $probSets   = "$root/$courseName/?"            . $self->url_authen_args();
	my $prefs      = "$root/$courseName/options/?"    . $self->url_authen_args();
	my $help       = "$ce->{webworkURLs}->{docs}?"    . $self->url_authen_args();
	my $logout     = "$root/$courseName/logout/?"     . $self->url_authen_args();
	
	my $PermissionLevel = $db->getPermissionLevel($userName); # checked
	my $permLevel = (defined $PermissionLevel
		? $PermissionLevel->permission()
		: 0);
	
	return join("",
		CGI::a({-href=>$probSets}, "Problem&nbsp;Sets"), CGI::br(),
		CGI::a({-href=>$prefs}, "User&nbsp;Prefs"), CGI::br(),
		CGI::a({-href=>$help}, "Help"), CGI::br(),
		CGI::a({-href=>$logout}, "Log Out"), CGI::br(),
		($permLevel > 0
			? $self->instructor_links(@components) : ""
		),
	);
}
sub instructor_links {
	my $self       = shift;
	my @components = @_; 
	my $args       = pop(@components);  # get hash of option arguments
	my $courseName = $self->{ce}->{courseName};
	my $root       = $self->{ce}->{webworkURLs}->{root};
	my $userName = $self->{r}->param("effectiveUser");
	$userName    = $self->{r}->param("user") unless defined $userName;
	my ($set, $prob) = @components;
	my $instructor = "$root/$courseName/instructor/?" . $self->url_authen_args();
	my $sets       = "$root/$courseName/instructor/sets/?" . $self->url_authen_args();
	my $users      = "$root/$courseName/instructor/users/?" . $self->url_authen_args();
	my $email      = "$root/$courseName/instructor/send_mail/?" . $self->url_authen_args();
	my $scoring    = "$root/$courseName/instructor/scoring/?" . $self->url_authen_args();
	my $statsRoot  = "$root/$courseName/instructor/stats";     
	my $stats      = $statsRoot. '/?'.$self->url_authen_args();
	my $fileXfer   = "$root/$courseName/instructor/files/?" . $self->url_authen_args();

	
	#  Add direct links to sets e.g.  3:4 for set3 problem 4
	my $setURL = (defined $set)
		? "$root/$courseName/instructor/sets/$set/?" . $self->url_authen_args()
		: '';
	my $probURL = (defined $set && defined $prob)
		? "$root/$courseName/instructor/pgProblemEditor/$set/$prob?" . $self->url_authen_args()
		: '';
	
	my ($setLink, $problemLink) = ("", "");
	if ($setURL) {
		$setLink = "&nbsp;&nbsp;&nbsp;&nbsp;"
			. CGI::a({-href=>$setURL}, "Set&nbsp;$set")
			. CGI::br();
		if ($probURL) {
			$problemLink = "&nbsp;&nbsp;&nbsp;&nbsp;"
				. CGI::a({-href=>$probURL}, "Problem&nbsp;$prob")
				. CGI::br();
		}
	}
	
	#my $setProb = ($setURL)
	#	? CGI::a({-href=>$setURL}, $set)
	#	: '';
	#$setProb .= ':' . CGI::a({-href=>$probURL},$prob) if $setProb && $probURL;
	
	return join("",
		 CGI::hr(),
		 CGI::a({-href=>$instructor}, "Instructor&nbsp;Tools") , CGI::br(),
		 '&nbsp;&nbsp;',CGI::a({-href=>$sets}, "Set&nbsp;List"), CGI::br(),
		 $setLink,
		 $problemLink,
		 '&nbsp;&nbsp;',CGI::a({-href=>$users}, "User&nbsp;List"), CGI::br(),
		 '&nbsp;&nbsp;',CGI::a({-href=>$email}, "Send&nbsp;Email"), CGI::br(),
		 '&nbsp;&nbsp;',CGI::a({-href=>$scoring}, "Score&nbsp;Sets"), CGI::br(),
		 '&nbsp;&nbsp;',CGI::a({-href=>$stats}, 'Statistics'), CGI::br(),
		 (defined($set))
		 	? '&nbsp;&nbsp;&nbsp;&nbsp;'.CGI::a({-href=>"$statsRoot/set/$set/?".$self->url_authen_args}, "$set").CGI::br() 
			: '',
		 (defined($userName))
		 	? '&nbsp;&nbsp;&nbsp;&nbsp;'.CGI::a({-href=>"$statsRoot/student/$userName/?".$self->url_authen_args}, "$userName").CGI::br()
			: '',
		 '&nbsp;&nbsp;',CGI::a({-href=>$fileXfer}, "File&nbsp;Transfer"), CGI::br(),
	);
}

# &if_can will return 1 if the current object->can("do $_[1]")
sub if_can ($$) {
	my ($self, $arg) = (@_);
	
	if ($self->can("$arg")) {
		return 1;
	} else {
		return 0;
	}
}

# Every content generator is logged in unless it says otherwise.
sub if_loggedin($$) {
	my ($self, $arg) = (@_);
	
	return $arg;
}

# Handling of errors in submissions

sub if_submiterror($$) {
	my ($self, $arg) = @_;
	if (exists $self->{submitError}) {
		return $arg;
	} else {
		return !$arg;
	}
}

sub submiterror {
	my ($self) = @_;
	if (exists $self->{submitError}) {
		return $self->{submitError};
	} else {
		return "";
	}
}

# General warning handling

sub if_warnings($$) {
	my ($self, $arg) = @_;
	return $self->{r}->notes("warnings") ? $arg : !$arg;
}

sub warnings {
	my ($self) = @_;
	my $r = $self->{r};
	if ($r->notes("warnings")) {
		return $self->warningOutput($r->notes("warnings"));
	} else {
		return "";
	}
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu
and Sam Hathaway, sh002i (at) math.rochester.edu.

=cut
