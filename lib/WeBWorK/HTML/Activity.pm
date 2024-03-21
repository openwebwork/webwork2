################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::HTML::Activity;
use Mojo::Base 'Exporter', -signatures;
use DateTime::Format::Strptime;
use WeBWorK::Utils::DateTime qw(formatDateTime);
use WeBWorK::Utils::Sets qw(format_set_name_display);

our @EXPORT_OK = qw(studentActivityTable studentActivityGraph);

=head1 NAME

WeBWorK::ContentGenerator::Activity - Display activity (logins, answer submissions) over time by user.

=cut

use Mojo::File;

sub parseLoginLog ($c) {
	my @login_lines;

	if (-r $c->ce->{courseFiles}{logs}{login_log}) {
		my $login_log = Mojo::File::path($c->ce->{courseFiles}{logs}{login_log})->open('<');
		while (my $line = <$login_log>) {
			if ($line =~ / LOGIN OK user_id=$c->{studentID}/) {
				my $datetime = ($line =~ /^\[(.*?)\]/)[0];
				my ($day, $mon, $mday, $hour, $min, $sec, $year) = split /[\s:]+/, $datetime;
				my $strp = DateTime::Format::Strptime->new(
					pattern   => '%a %b %d %H:%M:%S %Y',
					time_zone => 'local',
				);
				my $timestamp = $strp->parse_datetime($datetime)->epoch;
				push @login_lines,
					{
						timestamp         => $timestamp,
						credential_source => ($line =~ / credential_source=(\S*) /)[0],
						UA                => ($line =~ / UA=(.*)$/)[0]
					};
			}
		}
		$login_log->close;
	}

	return \@login_lines;
}

sub group_lines {
	my ($login_lines, $answer_lines) = @_;
	my @lines = (sort { $a->{timestamp} <=> $b->{timestamp} } (@{$login_lines}, @{$answer_lines}));
	my @sessions;
	for (@lines) {
		if (defined $_->{credential_source}) {
			push @sessions, [$_];
		} elsif (scalar @sessions == 0) {
			push @sessions,
				[
					{
						timestamp         => 0,
						credential_source => '',
						UA                => ''
					},
					$_
				];
		} else {
			push @{ $sessions[-1] }, $_;
		}
	}
	return \@sessions;

}

sub studentActivityTable ($c, $studentID) {
	my $login_lines  = parseLoginLog($c);
	my $past_answers = [ $c->db->getPastAnswersWhere({ user_id => $studentID }, 'answer_id') ];

	my $sessions = group_lines($login_lines, $past_answers);

	my $table_contents;
	for my $session (@{$sessions}) {
		$table_contents .= $c->tag(
			'tbody',
			sub {
				$c->tag(
					'tr',
					class => 'table-secondary',
					sub {
						$c->tag(
							'th',
							colspan => 4,
							$c->maketext(
								'Logged in at [_1] using [_2] with user agent [_3]',
								formatDateTime($session->[0]{timestamp}),
								$session->[0]{credential_source} eq 'params'
								? 'password'
								: $session->[0]{credential_source},
								$session->[0]{UA}
							)
						);
					}
					)
					. (
						$session->[1]
						? $c->tag(
							'tr',
							sub {
								$c->tag('th', $c->maketext('Time'))
								. $c->tag('th', $c->maketext('Assignment'))
								. $c->tag('th', $c->maketext('Problem Number'))
								. $c->tag('th', $c->maketext('Submission Response'));
							}
						)
						: ''
					)
					. join(
						"\n",
						map {
							$c->tag(
								'tr',
								sub {
									$c->tag('td', formatDateTime($_->{timestamp})) . $c->tag(
										'td',
										$c->tag(
											'a',
											href => $c->systemLink(
												$c->url_for(
													'instructor_set_detail', setID => $_->{set_id}
											)->fragment("psd_list_item_$_->{problem_id}"),
												params => { editForUser => $studentID }
											),
											format_set_name_display($_->{set_id} =~ s/,v(\d+)$//r)
											. ($1 ? ' ' . $c->maketext('(version [_1])', $1) : '')

										)
									)
									. $c->tag(
										'td',
										$c->tag(
											'a',
											href => $c->systemLink(
												$c->url_for('answer_log'),
												params => {
													selected_users    => $studentID,
													selected_sets     => $_->{set_id},
													selected_problems => $_->{problem_id}
												}
											),
											$_->{problem_id}
										)
									)
									. $c->tag(
										'td',
										sub {
											join(
												'',
												map {
													$_ == 1
													? '<i class="fa-solid fa-check"></i>'
													: '<i class="fa-solid fa-xmark"></i>'
												} (split //, $_->{scores})
											);
										}
									);
								}
							)
						} (@{$session})[ 1 .. $#$session ]
					);
			}
		);
	}

	return $c->tag(
		'table',
		class => 'table table-hover',
		sub {
			$table_contents;
		}
	);
}

sub studentActivityGraph ($c, $studentID) {
	return 'NOT IMPLEMENTED';
}

1;
