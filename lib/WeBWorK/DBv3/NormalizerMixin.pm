package WeBWorK::DBv3::NormalizerMixin;

=head1 NAME

WeBWorK::DBv3NormalizerMixin - Mixin to add/call inhertiable normalizers.

=head1 SYNOPSIS

 package My::DB;
 use base "Class::DBI";
 use WeBWorK::DBv3::NormalizerMixin;
 
 # overload Class::DBI's empty normalize_column_values method to use call_normalizer().
 sub normalize_column_values {
 	my ($self, $column_values) = @_;
 	
 	my @errors;
 	
 	foreach my $column (keys %$column_values) {
 		#warn "callig normalizers for column '$column'.\n";
 		eval { $self->call_normalizer($column_values, $column) };
 		push @errors, $column => $@ if $@;
 	}
 	
 	return unless @errors;
 	$self->_croak(
 		"normalize_column_values error: " . join(" ", @errors),
 		method => "normalize_column_values",
 		data => { @errors },
 	);
 }
 
 package My::DB::SomeTable;
 
 # ... other Class::DBI stuff here ...
 
 # add normalizers for various fields
 __PACKAGE__->add_normalizer(field => \&normalizer_sub);

=cut

use strict;
use warnings;
use Class::Data::Inheritable;
use Carp ();

sub import {
	my ($invocant) = @_;
	my $pkg = caller(0);
	
	# XXX 5.005_03 isa() is broken with MI
	unless ($pkg->can('mk_classdata')) {
		no strict 'refs';
		push @{"$pkg\::ISA"}, 'Class::Data::Inheritable';
	}

	$pkg->mk_classdata('__normalizers');

	# export mixin methods
	no strict 'refs';
	my @methods = qw(add_normalizer call_normalizer);
	*{"$pkg\::$_"} = \&{$_} for @methods;
}

sub add_normalizer {
	my ($invocant, @new) = @_;
	
	my $normalizers = __fetch_normalizers($invocant) || {};
	my %normalizers = __deep_dereference($normalizers);
	
	while (my ($column, $code) = splice @new, 0, 2) {
		__validate_field($invocant, $column);
		Carp::croak('add_normalizer() needs coderef') unless ref($code) eq 'CODE';
		push @{$normalizers{$column}}, $code;
	}
	
	__store_normalizers($invocant, \%normalizers);
}

sub call_normalizer {
	my ($invocant, $column_values, $column) = @_;
	
	my $normalizers = __fetch_normalizers($invocant) || return;
	if (exists $normalizers->{$column}) {
		foreach my $code (@{$normalizers->{$column}}) {
			#warn "call_normalizer: old value of column '$column': '", $column_values->{$column}, "'.\n";
			$column_values->{$column} = $code->($column_values->{$column});
			#warn "call_normalizer: new value of column '$column': '", $column_values->{$column}, "'.\n";
		}
	} else {
		__validate_field($invocant, $column);
	}
}

################################################################################

sub __validate_field {
	my ($invocant, $column) = @_;
	Carp::croak("$column is not valid field for " . (ref($invocant) || $invocant))
		unless $invocant->find_column($column) ? 1 : "";
}

sub __fetch_normalizers {
	my ($invocant) = @_;
	
	if (ref $invocant) {
		# called with an instance, use the instance's normalizers
		return $invocant->{__normalizers};
	} else {
		# called with a class, use the class's normalizers
		return $invocant->__normalizers;
	}
}

sub __store_normalizers {
	my ($invocant, $normalizers) = @_;
	
	if (ref $invocant) {
		# called with an instance, use the instance's normalizers
		$invocant->{__normalizers} = $normalizers;
	} else {
		# called with a class, use the class's normalizers
		$invocant->__normalizers($normalizers);
	}
}

# straight from Class::Trigger -- two-level copy of hash-of-arrays.
sub __deep_dereference {
	my $hashref = shift;
	my %copy;
	while (my($key, $arrayref) = each %$hashref) {
		$copy{$key} = [ @$arrayref ];
	}
	return %copy;
}

################################################################################

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

Based on Class::Trigger, which says:

 Original idea by Tony Bowden <tony@kasei.com> in Class::DBI.
 
 Code by Tatsuhiko Miyagawa <miyagawa@bulknews.net>.
 
 Patches by Tim Buce <Tim.Bunce@pobox.com>.

=cut

1;
