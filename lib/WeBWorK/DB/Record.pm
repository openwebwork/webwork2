package WeBWorK::DB::Record;

=head1 NAME

WeBWorK::DB::Record - common functionality for Record classes.

=cut

use strict;
use warnings;
use Carp;

=head1 CONSTRUCTOR

=over

=item new($Prototype)

Create a new record object, set initial values from the record object
$Prototype, which must be a subclass of WeBWorK::DB::Record.

=item new(%fields)

Create a new record object, set initial values from the hash %fields, which
must contain keys equal to the field names of the record class.

=cut

sub new {
	my ($invocant, @params) = @_;
	my $self = bless {}, ref($invocant) || $invocant;

	if (@_) {
		if (UNIVERSAL::isa($params[0], __PACKAGE__)) {
			$self->init_from_object($params[0]);
		} elsif (ref $params[0] eq 'HASH') {
			$self->init_from_hashref($params[0]);
		} elsif (ref $params[0] eq 'ARRAY') {
			$self->init_from_arrayref($params[0]);
		} else {
			$self->init_from_hashref({@params});
		}
	}

	return $self;
}

# this will have to be changed if we actually implement any custom accessors/mutators
sub init_from_object { shift->init_from_hashref(shift); return; }

sub init_from_hashref {
	my ($self, $prototype) = @_;
	@$self{ $self->FIELDS } = @$prototype{ $self->FIELDS };
	return;
}

sub init_from_arrayref {
	my ($self, $prototype) = @_;
	@$self{ $self->FIELDS } = @$prototype;
	return;
}

=back

=head1 BASE METHODS

=over

=item idsToString

Returns a string representation of the object's keyfields.

=cut

sub idsToString {
	my $self = shift;
	return join " ", map { "$_=" . (defined $self->$_ ? "'" . $self->$_ . "'" : "undef") } $self->KEYFIELDS;
}

=item idsToString

Returns a string representation of the object's fields.

=cut

sub toString {
	my $self = shift;
	return join " ", map { "$_=" . (defined $self->$_ ? "'" . $self->$_ . "'" : "undef") } $self->FIELDS;
}

=item toHash

Returns a hash representation of the object's fields. If interpreted as a list,
the fields will be in order.

=cut

sub toHash {
	my $self = shift;
	return map { $_ => $self->$_ } $self->FIELDS;
}

=item toArray

Returns an array representation of the object's fields.

=cut

sub toArray {
	my $self = shift;
	return map { $self->$_ } $self->FIELDS;
}

=back

=cut

sub _fields {
	my ($invocant, @field_data) = @_;
	my $class = ref $invocant || $invocant;

	my %field_data   = @field_data;
	my @field_order  = @field_data[ grep { $_ % 2 == 0 } 0 .. $#field_data ];
	my @keyfields    = grep { $field_data{$_}{key} } @field_order;
	my @nonkeyfields = grep { not $field_data{$_}{key} } @field_order;
	my @sql_types    = map  { $field_data{$_}{type} } @field_order;

	## no critic (TestingAndDebugging::ProhibitNoStrict TestingAndDebugging::ProhibitProlongedStrictureOverride)
	no strict 'refs';
	## use critic (TestingAndDebugging::ProhibitNoStrict TestingAndDebugging::ProhibitProlongedStrictureOverride)

	# class methods that return field info
	*{ $class . "::FIELD_DATA" }   = sub { return \%field_data };
	*{ $class . "::FIELDS" }       = sub { return @field_order };
	*{ $class . "::KEYFIELDS" }    = sub { return @keyfields };
	*{ $class . "::NONKEYFIELDS" } = sub { return @nonkeyfields };
	*{ $class . "::SQL_TYPES" }    = sub { return @sql_types };

	# accessor functions
	foreach my $field (@field_order) {
		# always define a "base" accessor
		# custom public accessors can use this to actually do the getting and setting
		*{ $class . "::_base_$field" } = sub {
			my $self = shift;
			$self->{$field} = shift if @_;
			return $self->{$field};
		};
		# if there isn't a public accessor in the subclass, alias it to the base accessor
		next if exists ${ $class . "::" }{$field};
		*{ $class . "::$field" } = *{ $class . "::_base_$field" };
	}

	use strict 'refs';

	return;
}

sub _initial_records {
	my ($invocant, @initializers) = @_;
	my $class = ref $invocant || $invocant;

	no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
	*{ $class . "::INITIAL_RECORDS" } = sub { return @initializers };
	use strict 'refs';

	return;
}

1;
