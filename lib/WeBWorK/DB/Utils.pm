################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/DB/Utils.pm,v 1.13 2004/06/15 18:47:07 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::DB::Utils;
use base qw(Exporter);

=head1 NAME

WeBWorK::DB::Utils - useful utilities for the database modules.

=cut

use strict;
use warnings;
use Data::Dumper;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	record2hash
	hash2record
	hash2string
	string2hash
	global2user
	user2global
	initializeUserProblem
	findDefaults
);

################################################################################
# WWDBv2 record <-> WWDBv1 hash
#  not in the Record classes, since they are for legacy support
################################################################################

# FIXME: this should go away -- let WW1Hash and Classlist1Hash handle their own
# stupid conversions!

# RECORDHASH defines the correspondance between WWDBv1 hash keys and WWDBv2
# record fields.
use constant RECORDHASH => {
	"WeBWorK::DB::Record::User" => [
		['stfn', "first_name"   ],
		['stln', "last_name"    ],
		['stea', "email_address"],
		['stid', "student_id"   ],
		['stst', "status"       ],
		['clsn', "section"      ],
		['clrc', "recitation"   ],
		['comt', "comment"      ],
	],
#	"WeBWorK::DB::Record::UserSet" => [
#		['stlg', "user_id"       ],
#		['stnm', "set_id"        ],
#		['shfn', "set_header"    ],
#		['phfn', "hardcopy_header"],
#		['opdt', "open_date"     ],
#		['dudt', "due_date"      ],
#		['andt', "answer_date"   ],
#	],
#	# a hash destined to be converted into a UserProblem must be converted
#	# so that the hash keys, rather than containing the problem number,
#	# contain the character '#'. Also, a new hash key '#' must be added
#	# which contains the problem number.
#	"WeBWorK::DB::Record::UserProblem" => [
#		['stlg',  "user_id"      ],
#		['stnm',  "set_id"       ],
#		['#',     "problem_id"   ],
#		['pfn#',  "source_file"  ],
#		['pva#',  "value"        ],
#		['pmia#', "max_attempts" ],
#		['pse#',  "problem_seed" ],
#		['pst#',  "status"       ],
#		['pat#',  "attempted"    ],
#		['pan#',  "last_answer"  ],
#		['pca#',  "num_correct"  ],
#		['pia#',  "num_incorrect"],
#	],
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
		my $value = defined $hash{$v1} ? $hash{$v1} : ""; # promote undef to ""
		$record->$v2($value);
	}
	return $record;
}

################################################################################
# WWDBv1 hash <-> WWDBv1 string
################################################################################

sub hash2string(@) {
	my (%hash) = @_;
	my $string;
	return "" unless keys %hash;
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
# global <-> user record conversion
################################################################################

sub global2user($$) {
	my ($userRecordClass, $GlobalRecord) = @_;
	my $UserRecord = $userRecordClass->new();
	foreach my $field ($GlobalRecord->FIELDS()) {
		$UserRecord->$field($GlobalRecord->$field());
	}
	return $UserRecord;
}

sub user2global($$) {
	my ($globalRecordClass, $UserRecord) = @_;
	my $GlobalRecord = $globalRecordClass->new();
	foreach my $field ($GlobalRecord->FIELDS()) {
		$GlobalRecord->$field($UserRecord->$field());
	}
	return $GlobalRecord;
}

# Populate a user record with sane defaults and a random seed
# This function edits the record in place, so you can discard
# the return value.
sub initializeUserProblem {
	my ($userProblem) = @_;
	$userProblem->status(0.0);
	$userProblem->attempted(0);
	$userProblem->num_correct(0);
	$userProblem->num_incorrect(0);
	$userProblem->problem_seed(int(rand(5000)));

	return $userProblem;
}

################################################################################
# default generation
################################################################################

sub findDefaults($@) {
	my ($globalClass, @Records) = @_;
	
	my %fields = map { $_ => {} } $globalClass->FIELDS();
	#delete $fields{$_} foreach $globalClass->KEYFIELDS();
	
	foreach my $Record (@Records) {
		foreach my $field (keys %fields) {
			my $value = $Record->$field();
			if ($value eq "UNDEFINED") {
				die "Uh oh... value eq \"UNDEFINED\"\n";
			}
			unless (defined $value) {
				$value = "UNDEFINED";
			}
			$fields{$field}{$value}++;
		}
	}
	
	#warn "Frequencies: ", Dumper(\%fields);
	
	my $Defaults = $globalClass->new();
	foreach my $field (keys %fields) {
		my $maxFreq = 0;
		my $maxValue;
		foreach my $value (keys %{$fields{$field}}) {
			my $freq = $fields{$field}{$value};
			if ($freq > $maxFreq) {
				$maxFreq = $freq;
				$maxValue = $value;
			}
		}
		undef $maxValue if $maxValue eq "UNDEFINED";
		$Defaults->$field($maxValue);
	}
	
	#warn "Consensus defaults: ", Dumper($Defaults);
	
	return $Defaults;
}

1;
