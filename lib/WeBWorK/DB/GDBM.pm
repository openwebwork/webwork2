package WeBWorK::DB::GDBM;

use GDBM_File;

# these should probably be in a constants file somewhere...
use constant MAX_TIE_ATTEMPTS => 30;
use constant TIE_RETRY_DELAY  => 2;
use constant TIE_PERMISSION => 0660;

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
	my $symbolicFlags = shift; # "ro" or "rw"
	return if tied %$self->{hashRef}; # already tied!
	my $flags = lc $symbolicFlags eq "rw" ? GDBM_WRCREAT() : GDBM_READER();
	foreach (1 .. MAX_TIE_ATTEMPTS) {
		return if tie %{$self->{hashRef}},
			"GDBM_File",        # class
			$self->{gdbm_file}, # file name
			$flags,             # I/O flags
			TIE_PERMISSION;     # access mode
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
