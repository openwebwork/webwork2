package WeBWorK::ContentGenerator;

use strict;
use warnings;
use CGI ();
use Apache::Constants qw(:common);

# Send 'die' message to the browser window
#use CGI::Carp qw(fatalsToBrowser);


# This is a superclass for Apache::WeBWorK's content generators.
# You are /definitely/ encouraged to read this file, since there are
# "abstract" functions here which show aproximately what form you would
# want over-ridden sub-classes to follow.

# new(Apache::Request, WeBWorK::CourseEnvironment)
sub new($$$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	($self->{r}, $self->{courseEnvironment}) = @_;
	bless $self, $class;
	return $self;
}


# This is a quick and dirty function to print out all (or almost all) of the
# fields in a form in a specified format.  As you can see from the print
# statement, it just prints out $begining$name$middle$value$end for every
# field who's name doesn't match $qr_omit, a quoted regex.
# In it's current incarnation, it should be called from subclasses only,
# by saying $self->print_form_data.  Of course, you could construct a
# hashref with ->{r} being an Apache::Request, I suppose.
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
# P.S. This function is beat, but I use it in places.  We'll kill it eventually, I guess.

sub hidden_authen_fields {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $html = "";
	
	foreach my $param ("user","effectiveUser","key") {
		my $value = $r->param($param);
		$html .= CGI::input({-type=>"hidden",-name=>"$param",-value=>"$value"});
	}
	return $html;
}

#sub hidden_authen_fields($) {
#	my $self = shift;
#	return $self->hidden_fields("user","effectiveUser","key");
#}

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

### Functions that subclasses /should/ override under most circumstances

sub title {
	return "Superclass";
}

sub body {
	print "Generated content";
	"";
}

### Functions that subclasses /may/ want to override, if they've got something
### special to say

sub pre_header_initialize {}

sub header {
	my $self = shift;
	my $r=$self->{r};
	$r->content_type('text/html');
	$r->send_http_header();
}

sub initialize {}

### Content-generating functions that should probably not be overridden
### by most subclasses

sub logo {
	my $self = shift;
	return $self->{courseEnvironment}->{webworkURLs}->{logo};
}

sub htdocs_base {
	my $self = shift;
	return $self->{courseEnvironment}->{webworkURLs}->{base};
}

sub test_args {
	my %args = %{$_[-1]};

	print "<pre>";
	print "$_ => $args{$_}\n" foreach (keys %args);
	print "</pre>";
	"";
}

# Used by &go to parse the argument fields of the template escapes
sub cook_args($) {
	# There are a bunch of commented-out lines that I am using to remind myself
	# That I want to write a better regex sometime.
	my ($raw_args) = @_;
	my $args = {};
	#my $quotable_string = qr/(?:".*?(?<![^\\](?:\\\\)*\\)"|\W*)/;
	#my $quotable_string = qr/(?:".*?(?<!\\)"|\W*)/;
	#my $test_string = '"hel \" lo" hello';
	
	#warn $test_string =~ m/($quotable_string)/ ? $1 : "false";
	
	while ($raw_args =~ m/\G\s*(\w*)="(.*?)"/g) {
	#while ($raw_args =~ m/\G\s*($quotable_string)=($quotable_string)/g) {
		$args->{$1} = $2;
	}
	
	return $args;
}

# Perform substitution in a template file and print it.  This should be called
# for all content generators that are creating HTML output, and is called by
# default by the &go method.
sub template {
	my ($self, $templateFile) = (shift, shift);
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	
	open(TEMPLATE, $templateFile) or die "Couldn't open template $templateFile";
	my @template = <TEMPLATE>;
	close TEMPLATE;
	
	foreach my $line (@template) {
		# This is incremental regex processing.
		# the /c is so that pos($line) doesn't die when the regex fails.
		while ($line =~ m/\G(.*?)<!--#(\w*)((?:\s+.*?)?)-->/gc) {
			my ($before, $function, $raw_args) = ($1, $2, $3);
			# $args here will be a hashref
			my $args = $raw_args =~ /\S/ ? cook_args $raw_args : {};
			print $before;
			
			print $self->$function(@_, $args) if $self->can($function);
		}
		
		print substr $line, (defined(pos($line)) ? pos($line) : 0);
	}
}

# Do whatever needs to be done in order to get a page to the client.  You
# probably don't want to override this unless you're not making a web page
# with the template.
sub go {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};

	$self->pre_header_initialize(@_);
	$self->header(@_); return OK if $r->header_only;
	$self->initialize(@_);
	
	$self->template($courseEnvironment->{templates}->{system}, @_);

	return OK;
}

1;
