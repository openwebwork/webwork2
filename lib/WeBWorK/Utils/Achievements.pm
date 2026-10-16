package WeBWorK::Utils::Achievements;
use Mojo::Base 'Exporter', -signatures;

use Mojo::JSON qw(from_json to_json);
use Mojo::Util qw(b64_decode decode);
use Storable   qw(thaw);

use WeBWorK::Utils qw(encode_utf8_base64);

our @EXPORT_OK = qw(
	encodeAchievementData
	decodeAchievementData
	sortAchievements
	isAchievementAssetSafe
	getAchievementAssetPaths
	isAchievementAssetOverridden
	getAchievementIconURL
);

sub encodeAchievementData ($data) {
	return encode_utf8_base64(to_json($data));
}

sub decodeAchievementData ($serialized) {
	return {} unless $serialized;

	my $bytes = b64_decode($serialized);
	# Data stored by older versions of WeBWorK was encoded with Storable::nfreeze.
	my $data = eval { $bytes =~ /^\{/ ? from_json(decode('UTF-8', $bytes)) : thaw($bytes) };

	if ($@ || ref($data) ne 'HASH') {
		warn('Deleting corrupted achievement data.');
		return {};
	}

	return $data;
}

sub sortAchievements (@achievements) {
	# First sort by achievement id.
	@achievements = sort { uc($a->{achievement_id}) cmp uc($b->{achievement_id}) } @achievements;

	# Next sort by number.
	@achievements = sort { ($a->number || 0) <=> ($b->number || 0) } @achievements;

	# Finally sort by category. Always place level achievements last.
	@achievements = sort {
		if ($a->{category} eq 'level' && $b->{category} eq 'level') {
			return 0;
		} elsif ($a->{category} eq 'level') {
			return 1;
		} elsif ($b->{category} eq 'level') {
			return -1;
		} elsif ($a->number && $b->number) {
			return $a->number <=> $b->number;
		} elsif ($a->{category} eq $b->{category}) {
			return 0;
		} elsif ($a->{category} eq 'secret') {
			return -1;
		} elsif ($b->{category} eq 'secret') {
			return 1;
		} else {
			return $a->{category} cmp $b->{category};
		}
	} @achievements;

	return @achievements;
}

sub isAchievementAssetSafe ($asset) {
	return !defined $asset || $asset eq '' || $asset =~ m#^/|/$|^\.\.|\.\./|/\.\.# ? 0 : 1;
}

sub getAchievementAssetPaths ($ce, $type, $asset) {
	my ($coursePath, $systemPath);
	if (!isAchievementAssetSafe($asset)) {
		# Unsafe asset, skip.
	} elsif ($type eq 'icon') {
		$systemPath = "$ce->{webworkDirs}{achievementIcons}/$asset"
			if -f "$ce->{webworkDirs}{achievementIcons}/$asset";
		$coursePath = "$ce->{courseDirs}{achievements_html}/$asset"
			if -f "$ce->{courseDirs}{achievements_html}/$asset";
	} elsif ($type eq 'test') {
		$systemPath = "$ce->{webworkDirs}{achievementEvaluators}/$asset"
			if -f "$ce->{webworkDirs}{achievementEvaluators}/$asset";
		$coursePath = "$ce->{courseDirs}{achievements}/$asset" if -f "$ce->{courseDirs}{achievements}/$asset";
	}
	return ($coursePath, $systemPath);
}

sub isAchievementAssetOverridden ($ce, $type, $asset) {
	my ($coursePath, $systemPath) = getAchievementAssetPaths($ce, $type, $asset);
	return $coursePath && $systemPath ? 1 : 0;
}

sub getAchievementIconURL ($ce, $icon) {
	my ($courseIconPath, $systemIconPath) = getAchievementAssetPaths($ce, 'icon', $icon);
	return "$ce->{courseURLs}{achievements}/$icon"      if $courseIconPath;
	return "$ce->{webworkURLs}{achievementIcons}/$icon" if $systemIconPath;
	return "$ce->{webworkURLs}{achievementIcons}/defaulticon.png";
}

=head1 NAME

WeBWorK::Utils::Achievements - contains utility subroutines for achievements.

=head2 encodeAchievementData

Usage: C<encodeAchievementData($data)>

JSON encodes the achievement data hash reference C<$data>, and then UTF-8 and
base 64 encodes the result.  The base 64 encoding keeps the stored value ASCII,
which avoids database driver differences in the handling of UTF-8 data in the
binary C<frozen_hash> column.

=head2 decodeAchievementData

Usage: C<decodeAchievementData($serialized)>

Returns the achievement data hash reference decoded from C<$serialized>.

This method detects if C<$serialized> is a JSON encoded hash (encoded with
C<encodeAchievementData>), or is a L<Storable::nfreeze> encoded hash (the old
method), and decodes using the appropriate method.  An empty hash reference is
returned if C<$serialized> is empty, cannot be decoded, or does not decode to a
hash reference.

=head2 sortAchievements

Usage: C<sortAchievements(@achievements)>

Returns C<@achievements> sorted first by achievement id, then by number or
category (if the achievement does not have a number).

=head2 isAchievementAssetSafe

Usage: C<isAchievementAssetSafe($asset)>

This is a simple test if an achievement C<$asset> filename is safe. A
filename is safe if it is a file inside an achievement asset directory
or subdirectory. This is a crude test that tests if C<$asset> is defined,
nonempty, not absolute (doesn't start with a slash), not a directory (ends
with a slash), doesn't start with "..", and doesn't contain "../" or "/..".
This will also reject nonstandard filenames like "..foo" or "foo../bar".

=head2 getAchievementAssetPaths

Usage: C<getAchievementAssetPaths($ce, $type, $asset)>

Returns an array with the course file path followed by the system file path
of an achievement icon, C<$type='icon'>, or an achievement evaluator,
C<$type='test'>, with the filename C<$asset>, in the course environment C<$ce>,
provided it is safe. Unsafe or nonexistent files are returned undefined.

=head2 isAchievementAssetOverridden

Usage: C<isAchievementAssetOverridden($ce, $type, $asset)>

Tests if an achievement icon, C<$type='icon'>, or an achievement evaluator,
C<$type='test'>, file name C<$asset> is a system file being overridden by a
course file of the same name in the course environment C<$ce>.

=head2 getAchievementIconURL

Usage: C<getAchievementIconURL($ce, $icon)>

Returns a URL to the C<$icon> file in the course directory if it exists, otherwise
a URL to the C<$icon> file in the system directory if it exists, otherwise a URL
to the system's default icon, for the given course environment C<$ce>.

=cut
