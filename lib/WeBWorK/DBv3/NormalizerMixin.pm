# This mixin is modeled after Tatsuhiko Miyagawa's Class::Trigger mixin. It is
# simpler and less reusable.

package WeBWorK::DBv3::NormalizerMixin;

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

1;
