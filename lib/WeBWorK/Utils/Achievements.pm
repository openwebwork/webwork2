package WeBWorK::Utils::Achievements;
use Mojo::Base 'Exporter', -signatures;

use Storable   qw(nfreeze thaw);
use Mojo::Util qw(b64_encode b64_decode);

our @EXPORT_OK = qw(
	nfreeze_base64
	thaw_base64
	sortAchievements
	isAchievementAssetSafe
	getAchievementAssetPaths
	isAchievementAssetOverridden
	getAchievementIconURL
);

sub nfreeze_base64 ($in) {
	return b64_encode(nfreeze($in));
}

sub thaw_base64 ($string) {
	my $result;

	eval { $result = thaw(b64_decode($string)); };

	if ($@) {
		warn('Deleting corrupted achievement data.');
		return {};
	}
	return $result;
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
	return !defined $asset || $asset eq '' || $asset =~ m#(^/|^\.\.|\.\./|/\.\.)# ? 0 : 1;
}

sub getAchievementAssetPaths ($ce, $type, $asset) {
	my ($coursePath, $systemPath);
	if (!isAchievementAssetSafe($asset)) {
		# Unsafe asset, skip.
	} elsif ($type eq 'icon') {
		$systemPath = "$ce->{webworkDirs}{achievementIcons}/$asset"
			if $asset !~ /\// && -f "$ce->{webworkDirs}{achievementIcons}/$asset";
		$coursePath = "$ce->{courseDirs}{achievements_html}/$asset"
			if -f "$ce->{courseDirs}{achievements_html}/$asset";
	} elsif ($type eq 'test') {
		$systemPath = "$ce->{webworkDirs}{achievementEvaluators}/$asset"
			if $asset !~ /\// && -f "$ce->{webworkDirs}{achievementEvaluators}/$asset";
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

=head2 nfreeze_base64

Usage: C<nfreeze_base64($in)>

This C<Storable::nfreeze> encodes and then base 64 encodes C<$in> and returns
the result.

=head2 thaw_base64

Usage: C<thaw_base64($in)>

This base 64 decodes and then C<Storable::thaw> decodes C<$in> and returns
result.

=head2 sortAchievements

Usage: C<sortAchievements(@achievements)>

Returns C<@achievements> sorted first by achievement id, then by number or
category (if the achievement does not have a number).

=head2 isAchievementAssetSafe

Usage: C<isAchievementAssetSafe($asset)>

This is a simple test if an achievement C<$asset> filename is safe. A
filename is safe if it is a file inside an achievement asset directory
or subdirectory. This is a crude test that tests if C<$asset> is defined,
nonempty, not absolute (doesn't start with a slash), doesn't start with
"..", and doesn't contain "../" or "/..". This will also reject
nonstandard filenames like "..foo" or "foo../bar".

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
