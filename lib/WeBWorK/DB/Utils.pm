################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::DB::Utils;

=head1 NAME

WeBWorK::DB::Utils - useful utilities for the database modules.

=cut

use strict;
use warnings;
use base qw(Exporter);

our @EXPORT    = ();
our @EXPORT_OK = qw(
	record2hash
	hash2record
	hash2string
	string2hash
);

################################################################################
# WWDBv2 record <-> WWDBv1 hash
#  not in the Record classes, since they are for legacy support
################################################################################

use constant RECORDHASH => {
	"WeBWorK::DB::Record::User" =>	[
		["stfn", "first_name"   ],
		["stln", "last_name"    ],
		["stea", "email_address"],
		["stid", "student_id"   ],
		["stst", "status"       ],
		["clsn", "section"      ],
		["clrc", "recitation"   ],
		["comt", "comment"      ],
	],
	# *** add tables for the rest of the record types
};

sub record2hash($) {
	my ($record) = @_;
	my $map = RECORDHASH->{ref $record};
	die ref $record, ": unknown record type" unless defined $map;
	my %hash;
	for (my $i = 0; $i < @$map; $i++) {
		my ($v1, $v2) = @{$map->[$i]};
		$hash{$v1} = $record->$v2;
	}
	return %hash;
}

sub hash2record($@) {
	my ($type, %hash) = @_;
	my $map = RECORDHASH->{$type};
	die $type, ": unknown record type" unless defined $map;
	my $record = $type->new();
	for (my $i = 0; $i < @$map; $i++) {
		my ($v1, $v2) = @{$map->[$i]};
		$record->$v2($hash{$v1});
	}
	return $record;
}

################################################################################
# WWDBv1 hash <-> WWDBv1 string
################################################################################

sub hash2string(@) {
	my %hash = @_;
	my $string;
	foreach (keys %hash) {
		$hash{$_} = "" unless defined $hash{$_}; # promote undef to ""
		$hash{$_} =~ s/(=|&)/\\$1/g; # escape & and =
		$string .= "$_=$hash{$_}&";
	}
	chop $string; # remove final '&' from string for old code :p
	return $string;
}

sub string2hash($) {
	my $string = shift;
	return unless defined $string and $string;
	my %hash = $string =~ /(.*?)(?<!\\)=(.*?)(?:(?<!\\)&|$)/g;
	$hash{$_} =~ s/\\(&|=)/$1/g foreach keys %hash; # unescape & and =
	return %hash;
}

################################################################################
# WWDBv1 answers <-> WWDBv1 string
################################################################################

# *** where did this go?

1;
