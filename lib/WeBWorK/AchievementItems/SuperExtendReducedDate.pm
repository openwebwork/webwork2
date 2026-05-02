package WeBWorK::AchievementItems::SuperExtendReducedDate;
use Mojo::Base 'WeBWorK::AchievementItems::ExtendReducedDate', -signatures;

# Item to extend a close date by 48 * $achievementExtensionFactor hours.

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(getExtensionTime);

sub new ($class, $c) {
	my ($time, $timeText) = getExtensionTime($c, 2);

	return bless {
		id          => 'SuperExtendReducedDate',
		name        => x('Scroll of Longevity'),
		description => [
			x(
				'Adds [_1] to the reduced scoring date of an assignment.  You will have to resubmit '
					. 'any problems that have already been penalized to earn full credit.  You cannot '
					. 'extend the reduced scoring date beyond the due date of an assignment.',
				$timeText
			)
		],
		time     => $time,
		timeText => $timeText
	}, $class;
}

1;
