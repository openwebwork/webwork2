################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record - common functionality for Record classes.

=cut

use strict;
use warnings;

sub new($@) {
	my ($invocant, %fields) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	
	foreach ($invocant->FIELDS()) {
		$self->{$_} = $fields{$_} if exists $fields{$_};
	}
	
	bless $self, $class;
	return $self;
}

sub AUTOLOAD($;@) {
	my ($self, @args) = @_;
	our $AUTOLOAD;
	my ($package, $function) = $AUTOLOAD =~ m/^(.*)::(.*)$/;
	return if $function eq "DESTROY";
	if (grep { $_ eq $function } $self->FIELDS()) {
		$self->{$function} = $args[0] if @args;
		return $self->{$function};
	} else {
		die "Undefined subroutine $package\::$function called";
	}
}

sub toString($) {
	my $self = shift;
	my $result;
	foreach ($self->FIELDS()) {
		$result .= "$_ => ";
		$result .= defined $self->$_() ? $self->$_() : "";
		$result .= "\n";
	}
	return $result;
}

1;
