package WeBWorK::DB::GDBM;

use GDBM_File;

# these should probably be in a constants file somewhere...
use constant MAX_TIE_ATTEMPTS => 30;
use constant TIE_RETRY_DELAY  => 2;
use constant CREATE_MODE => 0660;

sub new($$) {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {
		hashRef    => {},
		gdbm_file  => shift,
	};
	bless $self, $class;
	return $self;
}

sub connect($$) {
	my $self = shift;
	my $accessMode = shift;
	return if tied %$self->{hashRef}; # already tied!
	my $mode = lc $accessMode eq "rw" ? GDBM_WRCREAT() : GDBM_READER();
	foreach (1 .. MAX_TIE_ATTEMPTS) {
		return if tie %{$self->{hashRef}}, "GDBM_File",
			$self->{gdbm_file},
			$mode,
			$accessMode;
		sleep TIE_RETRY_DELAY;
	}
	die "unable to tie ", $self->{gdbm_file}, ": $!";
}

sub hashRef($) {
	my $self = shift;
	return unless tied %{$self->{hashRef}}; # not tied!
	return $self->{hashRef};
}

sub disconnect($) {
	my $self = shift;
	return unless tied %{$self->{hashRef}}; # not tied!
	return 1 if untie %{$self->{hashRef}}; 
}

1;
