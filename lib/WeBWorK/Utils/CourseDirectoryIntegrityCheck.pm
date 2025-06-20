package WeBWorK::Utils::CourseDirectoryIntegrityCheck;
use parent Exporter;

=head1 NAME

WeBWorK::Utils::CourseDirectoryIntegrityCheck - Check that course directory
structure is correct.

=cut

use strict;
use warnings;

use Mojo::File qw(path);

our @EXPORT_OK = qw(checkCourseDirectories checkCourseLinks updateCourseDirectories);

# Developer note:  This file should not format messages in html.  Instead return an array of tuples.  Each tuple should
# contain the message components, and the last element of the tuple should be 0 or 1 to indicate failure or success
# respectively.  See the the updateCourseDirectories method.

=head2 checkCourseDirectories

Usage: C<< checkCourseDirectories($ce) >>

Checks the course directories to make sure they exist and have the correct
permissions.

=cut

sub checkCourseDirectories {
	my $ce = shift;

	my @results;
	my $directories_ok = 1;

	for my $dir (sort keys %{ $ce->{courseDirs} }) {
		my $path   = $ce->{courseDirs}{$dir};
		my $status = -e $path ? (-r $path ? 'r' : '-') . (-w _ ? 'w' : '-') . (-x _ ? 'x' : '-') : 'missing';

		# All directories should be readable, writable and executable.
		my $good = $status eq 'rwx';
		$directories_ok = 0 if !$good;

		push @results, [ $dir, $path, $good ];
	}

	return ($directories_ok, \@results);
}

sub checkCourseLinks {
	my $ce = shift;

	my @results;
	my $links_ok = 1;

	for my $link (sort keys %{ $ce->{courseLinks} }) {
		my ($path, $label) = @{ $ce->{courseLinks}{$link} };

		my $isLink   = (-l $label ? 1 : 0);
		my $status   = -e $label ? (-r $label ? 'r' : '-') . (-w _ ? 'w' : '-') . (-x _ ? 'x' : '-') : 'missing';
		my $goodPath = path($label)->realpath eq $path;

		# All links should be readable and executable, not writeable.
		my $good = $isLink && ($status eq 'r-x') && $goodPath;
		$links_ok = 0 if !$good;

		push @results, [ $link, $path, $label, $good ];
	}

	return ($links_ok, \@results);
}

=head2 updateCourseDirectories

Usage: C<< updateCourseDirectories($ce) >>

Check to see if all course directories exist and have the correct permissions.

If a directory does not exist, then it is copied from the model course if the
corresponding directory exists in the model course, and is created otherwise.

If the permissions are not correct, then an attempt is made to correct the
permissions.  The permissions are expected to match the course root directory.
If the permissions of the course root directory are not correct, then that will
need to be manually fixed.  This method does not check that.

=cut

sub updateCourseDirectories {
	my $ce = shift;

	my @messages;

	# Sort courseDirs by path.  The important thing for the order is that a directory that is a subdirectory of
	# another is listed after the directory containing it.
	my @course_dirs =
		grep { $_ ne 'root' } sort { $ce->{courseDirs}{$a} =~ /^$ce->{courseDirs}{$b}/ } keys %{ $ce->{courseDirs} };

	# These are the directories in the model course that can be copied if not found in this course.
	my %model_course_dirs = (
		templates                 => 'templates',
		html                      => 'html',
		achievements              => 'templates/achievements',
		achievement_notifications => 'templates/achievements/notifications',
		email                     => 'templates/email',
		achievements_html         => 'html/achievements'
	);

	my $permissions = path($ce->{courseDirs}{root})->stat->mode & oct(777);

	for my $dir (@course_dirs) {
		my $path = path($ce->{courseDirs}{$dir});
		next if -r $path && -w $path && -x $path;

		my $path_exists_initially = -e $path;

		# Create the directory if it doesn't exist.
		if (!$path_exists_initially) {
			eval {
				$path->make_path({ mode => $permissions });
				push(@messages, [ "Created directory $path.", 1 ]);
			};
			if ($@) {
				push(@messages, [ "Failed to create directory $path.", 0 ]);
				next;
			}
		}

		# Fix permissions if those are not correct.
		if (($path->stat->mode & oct(777)) != $permissions) {
			eval {
				$path->chmod($permissions);
				push(@messages, [ "Changed permissions for directory $path.", 1 ]);
			};
			push(@messages, [ "Failed to change permissions for directory $path.", 0 ]) if $@;
		}

		# If the path did not exist to begin with and there is a corresponding model course directory,
		# then copy the contents of the model course directory.
		if (!$path_exists_initially && $model_course_dirs{$dir}) {
			my $modelCoursePath = "$ce->{webworkDirs}{courses}/modelCourse/$model_course_dirs{$dir}";
			if (!-r $modelCoursePath) {
				push(
					@messages,
					[
						'Your modelCourse in the "courses" directory is out of date or missing. Please update it from '
							. "the webwork2/courses.dist directory. Cannot find directory $modelCoursePath. The "
							. "directory $path has been created, but may be missing the files it should contain.",
						0
					]
				);
				next;
			}

			eval {
				for (path($modelCoursePath)->list_tree({ dir => 1 })->each) {
					my $destPath = $_ =~ s!$modelCoursePath!$path!r;
					if (-l $_) {
						symlink(readlink $_, $destPath);
					} elsif (-d $_) {
						path($destPath)->make_path({ mode => $permissions });
					} else {
						$_->copy_to($destPath);
					}
				}
				push(@messages, [ "Copied model course directory $modelCoursePath to $path.", 1 ]);
			};
			push(@messages, [ "Failed to copy model course directory $modelCoursePath to $path: $@.", 0 ]) if $@;
		}

	}

	return \@messages;
}

1;
