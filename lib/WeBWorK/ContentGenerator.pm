package WeBWorK::ContentGenerator;

use CGI qw(-compile :html :form);
use Apache::Constants qw(:common);

# This is a superclass for Apache::WeBWorK's content generators.
# You are /definitely/ encouraged to read this file, since there are
# "abstract" functions here which show aproximately what form you would
# want over-ridden sub-classes to follow.  go() is a particularly pertinent
# example.

# new(Apache::Request, WeBWorK::CourseEnvironment)
sub new($$$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	($self->{r}, $self->{courseEnvironment}) = @_;
	bless $self, $class;
	return $self;
}


# This generates the template code (eventually using a secondary storage
# data source, I hope) for the common elements of all WeBWorK pages.
# Arguments are substitutions for data points within the template.
sub top {
	my (
		$self,			# invocant
		$title,			# Page title
	) = @_;
	
	my $r = $self->{r};
	
	print start_html("WeBWorK - $title");

	print h1("WeBWorK $title");
}

# This generates the "bottom" of pages.  It'll probably be mostly for
# closing <body> and stuff like that.
sub bottom {
	my $self = @_;
	print end_html();
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
	
	$r=$self->{r};
	my @form_data = $r->param;
	foreach my $name (@form_data) {
		next if ($qr_omit and $name =~ /$qr_omit/);
		my @values = $r->param($name);
		foreach my $value (@values) {
			print $begin, $name, $middle, $value, $end;
		}
	}
}

sub hidden_authen_fields {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $html = "";
	
	foreach $param ("user","key") {
		my $value = $r->param($param);
		$html .= input({-type=>"hidden",-name=>"$param",-value=>"$value"});
	}
	return $html;
}

sub pre_header_initialize {}

sub header {
	my $self = shift;
	my $r=$self->{r};
	$r->content_type('text/html');
	$r->send_http_header();
}

sub initialize {}

sub title {
	print "Superclass";
}

sub body {
	print "Generated content";
}

sub go {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};

	$self->pre_header_initialize(@_);
	$self->header(@_); return OK if $r->header_only;
	$self->initialize(@_);
	
	my $templateFile = $courseEnvironment->{templates}->{system};
	
	open(TEMPLATE, $templateFile) or die "Couldn't open template $templateFile";
	my @template = <TEMPLATE>;
	close TEMPLATE;
	
	foreach my $line (@template) {
		my $pos = 0;

		while ($line =~ m/\G(.*?)<!--#(.*?)\s*-->/g) {
			print "$1";
			$pos = pos($line);
			print $self->$2(@_) if $self->can($2);
		}
		# I thought I could use pos($line) here, but /noooooo/
		print substr $line, $pos;
	}
	
	return OK;
}

1;
