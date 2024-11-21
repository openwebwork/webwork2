################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::Utils;
use Mojo::Base 'Exporter', -signatures;

use Email::Sender::Transport::SMTP;
use Mojo::JSON qw(from_json to_json);
use Mojo::Util qw(b64_encode b64_decode encode decode);
use Storable qw(nfreeze thaw);

our @EXPORT_OK = qw(
	runtime_use
	trim_spaces
	fix_newlines
	encodeAnswers
	decodeAnswers
	encode_utf8_base64
	decode_utf8_base64
	nfreeze_base64
	thaw_base64
	min
	max
	wwRound
	cryptPassword
	undefstr
	sortByName
	sortAchievements
	not_blank
	role_and_above
	fetchEmailRecipients
	processEmailMessage
	createEmailSenderTransportSMTP
	generateURLs
	getAssetURL
	x
);

sub runtime_use ($module, @import_list) {
	my $package = (caller)[0];    # import into caller's namespace

	my $import_string;
	if (@import_list == 1 && ref($import_list[0]) eq 'ARRAY' && @{ $import_list[0] } == 0) {
		$import_string = '';
	} else {
		# \Q = quote metachars \E = end quoting
		$import_string = "import $module " . join(',', map {qq|"\Q$_\E"|} @import_list);
	}
	eval "package $package; require $module; $import_string";
	die $@ if $@;
	return;
}

sub trim_spaces ($string) {
	return '' unless $string;
	return $string =~ s/^\s*|\s*$//gr;
}

sub fix_newlines ($in) {
	return $in =~ s/\r\n?/\n/gr;
}

sub encodeAnswers ($hash, $order) {
	my @ordered_hash;
	for my $key (@$order) {
		push @ordered_hash, $key, $hash->{$key};
	}
	return to_json(\@ordered_hash);
}

sub decodeAnswers ($serialized) {
	return unless $serialized;
	if ($serialized =~ /^\[/ && $serialized =~ /\]$/) {
		# Assuming this is JSON encoded
		my @array_data = @{ from_json($serialized) };
		return @array_data;
	} else {
		# Fall back to old Storable::thaw based code
		my $array_ref = eval { thaw($serialized) };
		if ($@ || !defined $array_ref) {
			return;
		} else {
			return @{$array_ref};
		}
	}
}

sub encode_utf8_base64 ($in) {
	return b64_encode(encode('UTF-8', $in));
}

sub decode_utf8_base64 ($in) {
	return decode('UTF-8', b64_decode($in));
}

sub nfreeze_base64 ($in) {
	return b64_encode(nfreeze($in));
}

sub thaw_base64 ($string) {
	my $result;

	eval { $result = thaw(b64_decode($string)); };

	if ($@) {
		warn('Deleting corrupted achievement data.');
		return {};
	} else {
		return $result;
	}

}

sub min (@items) {
	my $min = (shift @items) // 0;
	for my $item (@items) {
		$min = $item if ($item < $min);
	}
	return $min;
}

sub max (@items) {
	my $max = (shift @items) // 0;
	for my $item (@items) {
		$max = $item if ($item > $max);
	}
	return $max;
}

sub wwRound ($places, $float) {
	my $factor = 10**$places;
	return int($float * $factor + 0.5) / $factor;
}

sub cryptPassword ($clearPassword) {
	# Use an SHA512 salt with 16 digits
	my $salt = '$6$';
	for (my $i = 0; $i < 16; $i++) {
		$salt .= ('.', '/', '0' .. '9', 'A' .. 'Z', 'a' .. 'z')[ rand 64 ];
	}

	# Wrap crypt in an eval to catch any "Wide character in crypt" errors.
	# If crypt fails due to a wide character, encode to UTF-8 before calling crypt.
	my $cryptedPassword = '';
	eval { $cryptedPassword = crypt(trim_spaces($clearPassword), $salt); };
	if ($@ && $@ =~ /Wide char/) {
		$cryptedPassword = crypt(Encode::encode_utf8(trim_spaces($clearPassword)), $salt);
	}

	return $cryptedPassword;
}

sub undefstr ($default, @values) {
	return map { defined $_ ? $_ : $default } @values[ 0 .. $#values ];
}

################################################################################
# Sorting
################################################################################

sub sortByName ($field, @items) {
	my %itemsByIndex;
	if (ref($field) eq 'ARRAY') {
		for my $item (@items) {
			my $key = '';
			for (@$field) {
				$key .= $item->$_;    # in this case we assume
			}    #    all entries in @$field
			$itemsByIndex{$key} = $item;    #  are defined.
		}
	} else {
		%itemsByIndex = map { defined $field ? $_->$field : $_ => $_ } @items;
	}

	my @sKeys = sort {
		return $a cmp $b if (uc($a) eq uc($b));

		my @aParts = split m/(?<=\D)(?=\d)|(?<=\d)(?=\D)/, $a;
		my @bParts = split m/(?<=\D)(?=\d)|(?<=\d)(?=\D)/, $b;

		while (@aParts && @bParts) {
			my $aPart    = shift @aParts;
			my $bPart    = shift @bParts;
			my $aNumeric = $aPart =~ m/^\d*$/;
			my $bNumeric = $bPart =~ m/^\d*$/;

			# numbers should come before words
			return -1 if $aNumeric  && !$bNumeric;
			return +1 if !$aNumeric && $bNumeric;

			# both have the same type
			if ($aNumeric && $bNumeric) {
				next if $aPart == $bPart;    # check next pair
				return $aPart <=> $bPart;    # compare numerically
			} else {
				next if uc($aPart) eq uc($bPart);    # check next pair
				return uc($aPart) cmp uc($bPart);    # compare alphabetically
			}
		}
		return +1 if @aParts;    # a has more sections, should go second
		return -1 if @bParts;    # a had fewer sections, should go first
	} (keys %itemsByIndex);

	return map { $itemsByIndex{$_} } @sKeys;
}

sub sortAchievements (@achievements) {
	# First sort by achievement id.
	@achievements = sort { uc($a->{achievement_id}) cmp uc($b->{achievement_id}) } @achievements;

	# Next sort by number.
	@achievements = sort { ($a->number || 0) <=> ($b->number || 0) } @achievements;

	# Finally sort by category.
	@achievements = sort {
		if ($a->number && $b->number) {
			return $a->number <=> $b->number;
		} elsif ($a->{category} eq $b->{category}) {
			return 0;
		} elsif ($a->{category} eq 'secret' or $b->{category} eq 'level') {
			return -1;
		} elsif ($a->{category} eq 'level' or $b->{category} eq 'secret') {
			return 1;
		} else {
			return $a->{category} cmp $b->{category};
		}
	} @achievements;

	return @achievements;

}

################################################################################
# Validate strings and labels
################################################################################

sub not_blank ($str = undef) {
	return defined $str && $str =~ /\S/;
}

sub role_and_above ($userRoles, $role) {
	my $role_array = [$role];
	for my $userRole (keys %$userRoles) {
		push @$role_array, $userRole if ($userRoles->{$userRole} > $userRoles->{$role});
	}
	return $role_array;
}

sub fetchEmailRecipients ($c, $permissionType, $sender = undef) {
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;

	my @recipients;
	push(@recipients, @{ $ce->{mail}{feedbackRecipients} }) if ref($ce->{mail}{feedbackRecipients}) eq 'ARRAY';

	return @recipients unless $permissionType && defined $ce->{permissionLevels}{$permissionType};

	my $roles =
		ref $ce->{permissionLevels}{$permissionType} eq 'ARRAY'
		? $ce->{permissionLevels}{$permissionType}
		: role_and_above($ce->{userRoles}, $ce->{permissionLevels}{$permissionType});
	my @rolePermissionLevels = map { $ce->{userRoles}{$_} } grep { defined $ce->{userRoles}{$_} } @$roles;
	return @recipients unless @rolePermissionLevels;

	my $user_ids = [ map { $_->user_id } $db->getPermissionLevelsWhere({ permission => \@rolePermissionLevels }) ];

	push(
		@recipients,
		map { $_->rfc822_mailbox } $db->getUsersWhere({
			user_id       => $user_ids,
			email_address => { '!=', undef },
			$ce->{feedback_by_section}
				&& defined $sender ? (section => ($sender->section eq '' ? undef : $sender->section)) : ()
		})
	);

	return @recipients;
}

sub processEmailMessage ($text, $user_record, $STATUS, $merge_data, $for_preview = 0) {
	# User macros that can be used in the email message
	my $SID        = $user_record->student_id;
	my $FN         = $user_record->first_name;
	my $LN         = $user_record->last_name;
	my $SECTION    = $user_record->section;
	my $RECITATION = $user_record->recitation;
	my $EMAIL      = $user_record->email_address;
	my $LOGIN      = $user_record->user_id;

	# Get record from merge data.
	my @COL = defined($merge_data->{$SID}) ? @{ $merge_data->{$SID} } : ();
	unshift(@COL, '');    # This makes COL[1] the first column.

	# For safety, only evaluate special variables.
	my $msg = $text;
	$msg =~ s/\$SID/$SID/g;
	$msg =~ s/\$LN/$LN/g;
	$msg =~ s/\$FN/$FN/g;
	$msg =~ s/\$STATUS/$STATUS/g;
	$msg =~ s/\$SECTION/$SECTION/g;
	$msg =~ s/\$RECITATION/$RECITATION/g;
	$msg =~ s/\$EMAIL/$EMAIL/g;
	$msg =~ s/\$LOGIN/$LOGIN/g;

	if (defined $COL[1]) {
		$msg =~ s/\$COL\[(\-?\d+)\]/$COL[$1]/g;
	} else {
		$msg =~ s/\$COL\[(\-?\d+)\]//g;
	}

	$msg =~ s/\r//g;

	if ($for_preview) {
		my @preview_COL = @COL;
		shift @preview_COL;    # Shift of the added empty string for preview.
		return $msg,
			join(' ',
				'', (map { "COL[$_]" . '&nbsp;' x (3 - length $_) } 1 .. $#COL),
				'<br>', (map { $_ =~ s/\s/&nbsp;/gr } map { sprintf('%-8.8s', $_); } @preview_COL));
	} else {
		return $msg;
	}
}

sub createEmailSenderTransportSMTP ($ce) {
	return Email::Sender::Transport::SMTP->new({
		host => $ce->{mail}{smtpServer},
		ssl  => $ce->{mail}{tls_allowed} // 0,
		defined $ce->{mail}->{smtpPort}       ? (port          => $ce->{mail}{smtpPort})       : (),
		defined $ce->{mail}->{smtpUsername}   ? (sasl_username => $ce->{mail}{smtpUsername})   : (),
		defined $ce->{mail}->{smtpPassword}   ? (sasl_password => $ce->{mail}{smtpPassword})   : (),
		defined $ce->{mail}->{smtpSSLOptions} ? (ssl_options   => $ce->{mail}{smtpSSLOptions}) : (),
		timeout => $ce->{mail}{smtpTimeout},
	});
}

sub generateURLs ($c, %params) {
	my $db       = $c->db;
	my $userName = $c->param('user');

	# generate context URLs
	my ($emailableURL, $returnURL);

	if ($userName) {
		my $routePath;
		my @args;
		if (defined $params{set_id} && $params{set_id} ne '') {
			if ($params{problem_id}) {
				$routePath = $c->url_for('problem_detail', setID => $params{set_id}, problemID => $params{problem_id});
				@args      = qw/displayMode showOldAnswers showCorrectAnswers showHints showSolutions/;
			} else {
				$routePath = $c->url_for('problem_list', setID => $params{set_id});
			}
		} else {
			$routePath = $c->url_for('set_list');
		}
		$emailableURL = $c->systemLink(
			$routePath,
			authen      => 0,
			params      => [ 'effectiveUser', @args ],
			use_abs_url => 1,
		);
		$returnURL = $c->systemLink($routePath, params => [@args]);
	} else {
		$emailableURL = '(not available)';
		$returnURL    = '';
	}

	if ($params{url_type}) {
		if ($params{url_type} eq 'relative') {
			return $returnURL;
		} else {
			return $emailableURL;    # could include other types of URL here...
		}
	} else {
		return ($emailableURL, $returnURL);
	}
}

my $staticWWAssets;
my $staticPGAssets;
my $thirdPartyWWDependencies;
my $thirdPartyPGDependencies;

sub readJSON ($fileName) {
	return unless -r $fileName;

	open(my $fh, '<:encoding(UTF-8)', $fileName) or die "FATAL: Unable to open '$fileName'!";
	local $/;
	my $data = <$fh>;
	close $fh;

	return from_json($data);
}

sub getThirdPartyAssetURL ($file, $dependencies, $baseURL, $useCDN = 0) {
	for (keys %$dependencies) {
		if ($file =~ /^node_modules\/$_\/(.*)$/) {
			if ($useCDN) {
				return
					"https://cdn.jsdelivr.net/npm/$_\@"
					. substr($dependencies->{$_}, 1) . '/'
					. ($1 =~ s/(?:\.min)?\.(js|css)$/.min.$1/gr);
			} else {
				return "$baseURL/$file?version=$dependencies->{$_}";
			}
		}
	}
	return;
}

# Get the URL for static assets.
sub getAssetURL ($ce, $file, $isThemeFile = 0) {
	# Load the static files list generated by `npm ci` the first time this method is called.
	unless ($staticWWAssets) {
		my $staticAssetsList = "$ce->{webworkDirs}{htdocs}/static-assets.json";
		$staticWWAssets = readJSON($staticAssetsList);
		unless ($staticWWAssets) {
			warn "ERROR: '$staticAssetsList' not found or not readable!\n"
				. "You may need to run 'npm ci' from '$ce->{webworkDirs}{htdocs}'.";
			$staticWWAssets = {};
		}
	}

	unless ($staticPGAssets) {
		my $staticAssetsList = "$ce->{pg_dir}/htdocs/static-assets.json";
		$staticPGAssets = readJSON($staticAssetsList);
		unless ($staticPGAssets) {
			warn "ERROR: '$staticAssetsList' not found or not readable!\n"
				. "You may need to run 'npm ci' from '$ce->{pg_dir}/htdocs'.";
			$staticPGAssets = {};
		}
	}

	# Load the package.json files the first time this method is called.
	unless ($thirdPartyWWDependencies) {
		my $packageJSON = "$ce->{webworkDirs}{htdocs}/package.json";
		my $data        = readJSON($packageJSON);
		warn "ERROR: '$packageJSON' not found or not readable!\n" unless $data && defined $data->{dependencies};
		$thirdPartyWWDependencies = $data->{dependencies} // {};
	}

	unless ($thirdPartyPGDependencies) {
		my $packageJSON = "$ce->{pg_dir}/htdocs/package.json";
		my $data        = readJSON($packageJSON);
		warn "ERROR: '$packageJSON' not found or not readable!\n" unless $data && defined $data->{dependencies};
		$thirdPartyPGDependencies = $data->{dependencies} // {};
	}

	# Check to see if this is a third party asset file in node_modules (either in webwork2/htdocs or pg/htdocs).
	# If so, then either serve it from a CDN if requested, or serve it directly with the library version
	# appended as a URL parameter.
	if ($file =~ /^node_modules/) {
		my $wwFile = getThirdPartyAssetURL(
			$file, $thirdPartyWWDependencies,
			$ce->{webworkURLs}{htdocs},
			$ce->{options}{thirdPartyAssetsUseCDN}
		);
		return $wwFile if $wwFile;

		my $pgFile =
			getThirdPartyAssetURL($file, $thirdPartyPGDependencies, $ce->{pg_htdocs_url},
				$ce->{options}{thirdPartyAssetsUseCDN});
		return $pgFile if $pgFile;
	}

	# If a right-to-left language is enabled (Hebrew or Arabic) and this is a css file that is not a third party asset,
	# then determine the rtl variant file name.  This will be looked for first in the asset lists.
	my $rtlfile =
		($ce->{language} =~ /^(he|ar)/ && $file !~ /node_modules/ && $file =~ /\.css$/)
		? $file =~ s/\.css$/.rtl.css/r
		: undef;

	if ($isThemeFile) {
		# If the theme directory is the default location, then the file is in the static assets list.
		# Otherwise just use the given file name.
		if ($ce->{webworkDirs}{themes} =~ /^$ce->{webworkDirs}{htdocs}\/themes$/) {
			$rtlfile = "themes/$ce->{defaultTheme}/$rtlfile" if defined $rtlfile;
			$file    = "themes/$ce->{defaultTheme}/$file";
		} else {
			return "$ce->{webworkURLs}{themes}/$ce->{defaultTheme}/$file";
		}
	}

	# First check to see if this is a file in the webwork htdocs location with a rtl variant.
	return "$ce->{webworkURLs}{htdocs}/$staticWWAssets->{$rtlfile}"
		if defined $rtlfile && defined $staticWWAssets->{$rtlfile};

	# Next check to see if this is a file in the webwork htdocs location.
	return "$ce->{webworkURLs}{htdocs}/$staticWWAssets->{$file}" if defined $staticWWAssets->{$file};

	# Now check to see if this is a file in the pg htdocs location with a rtl variant.
	return "$ce->{pg_htdocs_url}/$staticPGAssets->{$rtlfile}"
		if defined $rtlfile && defined $staticPGAssets->{$rtlfile};

	# Next check to see if this is a file in the pg htdocs location.
	return "$ce->{pg_htdocs_url}/$staticPGAssets->{$file}" if defined $staticPGAssets->{$file};

	# If the file was not found in the lists, then assume it is in the webwork htdocs location, and use the given file
	# name.  If it is actually in the pg htdocs location, then the Mojolicious rewrite will send it there.
	return "$ce->{webworkURLs}{htdocs}/$file";
}

sub x (@args) { return @args }

1;

=head1 NAME

WeBWorK::Utils - General utility methods.

=head2 runtime_use

Usage: C<runtime_use($module, @import_list)>

This is like use, except it happens at runtime. The module name must be quoted,
and a comma after it if an import list is specified. Also, to specify an empty
import list (as opposed to no import list) use an empty array reference instead
of an empty array.

The following demonstrates equivalent usage of C<runtime_use> to that of C<use>.

    use Xyzzy;               =>    runtime_use 'Xyzzy';
    use Foo qw(pine elm);    =>    runtime_use 'Foo', qw(pine elm);
    use Foo::Bar ();         =>    runtime_use 'Foo::Bar', [];

=head2 trim_spaces

Usage: C<trim_spaces($string)>

Returns a string with whitespace trimmed from the start and end of C<$string>.

=head2 fix_newlines

Usage: C<fix_newlines($string)>

Converts carriage returns followed by new lines into just a new line. In other
words, converts non-unix like new lines into unix new lines.

=head2 encodeAnswers

Usage: C<encodeAnswers($hash, $order)>

Give a reference to a hash whose keys are answer names and values are student
answers in C<$hash>, and a reference to an array of answer names in the order
the answers appear in the problem in C<$order>, this returns a JSON encoded
array of answer name/student answer pairs where the pairs appear in the array in
the order provided by C<$order>.

=head2 decodeAnswers

Usage: C<decodeAnswers($serialized)>

Returns an array of answers decoded from the given C<$serialized> string.

This method attempts to detect if C<$serialized> is a JSON encoded array, or is
a L<Storable::nfreeze> encoded hash (the old method), and decodes using the
appropriate method.

=head2 encode_utf8_base64

Usage: C<encode_utf8_base64($in)>

UTF-8 encodes, and then base 64 endcodes the input and returns the result.

=head2 decode_utf8_base64

Usage: C<decode_utf8_base64($in)>

Base 64 decodes, and then UTF-8 decodes the input and returns the result.

=head2 nfreeze_base64

Usage: C<nfreeze_base64($in)>

This C<Storable::nfreeze> encodes and then base 64 encodes C<$in> and returns
the result.

=head2 thaw_base64

Usage: C<thaw_base64($in)>

This base 64 decodes and then C<Storable::thaw> decodes C<$in> and returns
result.

=head2 min

Usage: C<min(@items)>

Return the minimum element in C<@items>.

=head2 max

Usage: C<max(@items)>

Return the maximum element in C<@items>.

=head2 wwRound

Usage: C<wwRound($places, $float)>

Returns C<$float> rounded to C<$places> decimal places.

=head2 cryptPassword

Usage: C<cryptPassword($clearPassword)>

Returns the crypted form of C<$clearPassword> using a random 16 character
salt.

=head2 undefstr

Usage: C<undefstr($default, @values)>

Returns a copy of C<@values> whose undefined entries are replaced with
C<$default>.

=head2 sortByName

Usage: C<sortByName($field, @items)>

If C<$field> is a string naming a single field, then this returns the elements
in C<@items> sorted by that field.

If C<$field> is a reference to an array of strings each naming a field, then
this returns the entries of C<@items> sorted first by the first name field,
then by second, etc.

A natural sort algorithm is used for sorting, i.e., numeric parts are sorted
numerically, and alphabetic parts sorted lexicographically.

=head2 sortAchievements

Usage: C<sortAchievements(@achievements)>

Returns C<@achievements> sorted first by achievement id, then by number or
category (if the achievement does not have a number).

=head2 not_blank

Usage: C<not_blank($str)>

Returns true if C<$str> is defined and does not consist entirely of white space.

=head2 role_and_above

Usage: C<role_and_above($userRoles, $role)>

Given a reference to a hash C<$userRoles> whose keys are roles and values are
permission levels, returns a reference to an array of roles that are at or above
that of the permission level of the role specified in C<$role>.

=head2 fetchEmailRecipients

Usage: C<fetchEmailRecipients($c, $permissionType, $sender)>

Given a C<WeBWorK::ContentGenerator> object C<$c> and permission type
C<$permissionType>, this returns a list of feedback email recipients for the
course. If C<$sender> is provided, then this list is filtered by the section of
that sender.

=head2 processEmailMessage

Usage: C<processEmailMessage($text, $user_record, $STATUS, $merge_data, $for_preview)>

Process the email message in C<$text> and replace macros with values from the
C<$user_record>, the C<$STATUS>, and C<$merge_data>. If C<$for_prevew> is true
then the result is formatted to be display in HTML.

The replaceable macros and what they will be replaced with are

	$SID        => $user_record->student_id
	$FN         => $user_record->first_name
	$LN         => $user_record->last_name
	$SECTION    => $user_record->section
	$RECITATION => $user_record->recitation
	$EMAIL      => $user_record->email_address
	$LOGIN      => $user_record->user_id
    $STATUS     => $STATUS
    $COL[n]     => nth column of $merge_data
    $COL[-1]    => last column of $merge_data

=head2 createEmailSenderTransportSMTP

Usage: C<createEmailSenderTransportSMTP($ce)>

This returns an C<Email::Sender::Transport::SMTP> object for use in sending
emails. A valid C<WeBWorK::CourseEnvironment> object must be provided in C<$ce>.

=head2 generateURLs

Usage: C<generateURLs($c, %params)>

The parameter C<$c> must be a C<WeBWorK::Controller> object.

The following optional parameters may be passed:

=over

=item set_id

A problem set name.

=item problem_id

Problem id of a problem in the set.

=item url_type

This should a string with the value 'relative' or 'absolute' to return a single
URL, or undefined to return an array containing both URLs this subroutine could
be expanded to.

=back

=head2 getAssetURL

Usage: C<getAssetURL($ce, $file, $isThemeFile)>

Returns the URL for the asset specified in C<$file>.  If C<$isThemeFile> is
true, then the asset will be assumed to be located in a theme directory.  The
parameter C<$ce> must be a valid C<WeBWorK::CourseEnvironment> object.

=head2 x

Usage: C<x(@args)>

This is a dummy function used to mark constant strings for localization.  It
just returns C<@args>.

=cut
