package WeBWorK::Utils::TOTP;

use strict;
use warnings;
use utf8;

use Digest::SHA qw(hmac_sha512_hex hmac_sha256_hex hmac_sha1_hex);
use MIME::Base32 qw(encode_base32);
use Math::Random::Secure qw(irand);

sub new {
	my ($invocant, @options) = @_;
	my $self = bless {}, ref($invocant) || $invocant;

	if (@options) {
		my $options = ref($options[0]) eq 'HASH' ? $options[0] : {@options};
		@$self{ keys %$options } = values %$options;
	}

	$self->{digits}    = 6      unless $self->{digits}            && $self->{digits}    =~ m/^[678]$/;
	$self->{period}    = 30     unless $self->{period}            && $self->{period}    =~ m/^[36]0$/;
	$self->{algorithm} = 'SHA1' unless $self->{algorithm}         && $self->{algorithm} =~ m/^SHA(1|256|512)$/;
	$self->{tolerance} = 0      unless defined $self->{tolerance} && $self->{tolerance} =~ m/^\d+$/;

	$self->{secret} = $self->gen_secret($self->{algorithm} eq 'SHA512' ? 64 : $self->{algorithm} eq 'SHA256' ? 32 : 20)
		unless $self->{secret};

	return $self;
}

sub secret {
	my $self = shift;
	return $self->{secret};
}

sub gen_secret {
	my ($self, $length) = @_;
	$length ||= 20;
	my @chars =
		('/', 1 .. 9, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '-', '_', '+', '=', 'A' .. 'Z', 'a' .. 'z');
	return join('', map { @chars[ irand(@chars) ] } 0 .. $length - 1);
}

sub hmac {
	my ($self, $Td) = @_;

	if ($self->{algorithm} eq 'SHA512') {
		return hmac_sha512_hex($Td, $self->{secret});
	} elsif ($self->{algorithm} eq 'SHA256') {
		return hmac_sha256_hex($Td, $self->{secret});
	} else {
		return hmac_sha1_hex($Td, $self->{secret});
	}
}

sub generate_otp {
	my ($self, $user, $issuer) = @_;

	return
		qq[otpauth://totp/$user?secret=]
		. encode_base32($self->{secret})
		. qq[&algorithm=$self->{algorithm}]
		. qq[&digits=$self->{digits}]
		. qq[&period=$self->{period}]
		. ($issuer ? qq[&issuer=$issuer] : '');
}

sub validate_otp {
	my ($self, $otp) = @_;

	return 0 unless $otp && $otp =~ m/^\d{$self->{digits}}$/;

	my $currentTime = time;
	my @tests       = ($currentTime);
	for my $i (1 .. $self->{tolerance}) {
		push(@tests, $currentTime - $self->{period} * $i, $currentTime + $self->{period} * $i);
	}

	for my $when (@tests) {
		my $hmac = $self->hmac(pack('H*', sprintf('%016x', int($when / $self->{period}))));

		# Use the 4 least significant bits (1 hex char) from the encrypted string as an offset.
		# Take the 4 bytes (8 hex chars) at the offset (* 2 for hex), and drop the high bit.
		my $encrypted = hex(substr($hmac, hex(substr($hmac, -1)) * 2, 8)) & 0x7fffffff;

		return 1 if sprintf("\%0$self->{digits}d", $encrypted % (10**$self->{digits})) eq $otp;
	}

	return 0;
}

1;
