package WeBWorK::Form::TiedParam;
use strict;
use warnings;

sub TIESCALAR ($$$) {
	my ($invocant, $f, $param) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		f => $f,
		param => $param,
	};
	
	return bless $self, $class;
}

sub FETCH {
	my $self = shift;
	my $f = $self->{f};
	my $param = $self->{param};
	return $f->param($param);
}

sub STORE {
	my $self = shift;
	my @values = @_;
	my $f = $self->{f};
	my $param = $self->{param};
	$f->param($param, @values);
}

###

package WeBWorK::Form;
# This package will extract form input from an Apache::Request and provides
# an interface to it.

sub new {
	print "new called with \@_ = ( " . (join ", ", @_)  . " )\n";
	my ($invocant, $r) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {};

	return bless $self, $class;
}

sub new_from_paramable ($$) {
	my ($invocant, $r) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {};

	# list of param names
	my @params = $r->param;
	foreach my $key (@params) {
		$self->{$key} = [ $r->param($key) ];
	}

	return bless $self, $class;
}

sub new_test {
	my ($invocant, $r) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		a => [qw(aa ab ac)],
		b => [ "bcontents" ],
		c => [ "cc", "ccd" ],
		d => [ "what d has" ],
	};

	return bless $self, $class;
}

# @keys = $f->param
# $value = $f->param("key")
# @values = $f->param("key")
# $f->param("key", "value")
# $f->param(key => [qw(val1 val2 val3)]
# $f->param(key => "val1", "val2", "val3");

# Oh, there I go again with multiple returns all over.  To be fair,
# any function that emulates CGI::param has to do a few different things
# in different contexts.
sub param {
	my ($self, $param, @values) = @_;
	
	# Called with one argument.  Return keys.
	if (!defined $param) {
		return keys %$self;
	}
	
	# called with three arguments.  Set a value, then fall through
	if (scalar(@values)) {
		if (ref $values[0]) {
			$self->{$param} = $values[0];
		} else {
			$self->{$param} = [ @values ];
		}
	}
	
	# Called with 2+ arguments.  Return requested value
	if (wantarray) {
		return @{$self->{$param}};
	} else {
		return $self->{$param}[0];
	}
}

# lparam("key") will return the same value as param("key"), but it returns
# it as a scalar lvalue, so that you can assign strings or arrayrefs to the
# function call like this: $form->lparam("foo") = "bar" or
# $form->lparam("foo") = [qw(bar baz blah)].
# This function absolutely requires 5.6, which is where :lvalue comes from.
sub lparam($$) : lvalue {
	tie my $lvalue, 'WeBWorK::Form::TiedParam', shift, shift;
	$lvalue;
}

sub delete {
	my ($self, $param) = @_;
	CORE::delete $self->{$param};
}

sub Delete {
	my $self = shift;
	$self->delete(@_);
}

sub printable {
	my $self = shift;
	my $printedform = "";
	foreach my $key ($self->param) {
		$printedform .= "[$key]\n";
		foreach my $value ($self->param($key)) {
			$printedform .= "$value\n";
		}
		$printedform .= "\n";
	}
	
	return $printedform;
}

# This partially supports the :cgi-lib Vars() interface, a-la CGI.pm.  Not
# supported is being called in scalar context, which in CGI.pm returned a
# tied hashref to the original form data.  WeBWorK didn't need that, so I
# didn't add it.  If you're feeling industrious...
sub Vars {
	my $self = shift;
	my %varsFormat = ();
	foreach my $key ($self->param) {
		$varsFormat{$key} = join "\0", $self->param($key);
	}
	
	return %varsFormat;	
}

1;
