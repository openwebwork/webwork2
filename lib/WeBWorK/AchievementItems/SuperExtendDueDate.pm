package WeBWorK::AchievementItems::SuperExtendDueDate;
use Mojo::Base 'WeBWorK::AchievementItems::ExtendDueDate', -signatures;

# Item to extend a close date by 48 * $achievementExtensionFactor hours.

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(getExtensionTime);

sub new ($class, $c) {
	my ($time, $timeText) = getExtensionTime($c, 2);

	return bless {
		id          => 'SuperExtendDueDate',
		name        => x('Robe of Longevity'),
		description => [
			x(
				'Adds [_1] to the close date of a homework. '
					. 'This will randomize problem details if used after the original close date.',
				$timeText
			)
		],
		time     => $time,
		timeText => $timeText
	}, $class;
}

1;
