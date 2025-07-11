# This is an interface for getting global and local statistics about library problems for display.
package WeBWorK::Utils::LibraryStats;

use strict;
use warnings;

use DBI;

sub new {
	my ($class, $ce) = @_;

	my $dbh = DBI->connect_cached(
		$ce->{problemLibrary_db}{dbsource},
		$ce->{problemLibrary_db}{user},
		$ce->{problemLibrary_db}{passwd},
		{
			PrintError => 0,
			RaiseError => 0,
		},
	);

	return bless {
		dbh             => $dbh,
		localselectstm  => $dbh->prepare("SELECT * FROM OPL_local_statistics WHERE source_file = ?"),
		globalselectstm => $dbh->prepare("SELECT * FROM OPL_global_statistics WHERE source_file = ?"),
	}, $class;
}

sub getLocalStats {
	my ($self, $source_file) = @_;

	my $selectstm = $self->{localselectstm};

	unless ($selectstm->execute($source_file)) {
		if ($selectstm->errstr =~ /Table .* doesn't exist/) {
			warn "Couldn't find the OPL local statistics table.  "
				. "Did you download the latest OPL and run update-OPL-statistics.pl?";
		}
		die $selectstm->errstr;
	}

	my $result = $selectstm->fetchrow_arrayref();

	if ($result) {
		return {
			source_file        => $source_file,
			students_attempted => $$result[1],
			average_attempts   => $$result[2],
			average_status     => $$result[3],
		};
	} else {
		return { source_file => $source_file };
	}
}

sub getGlobalStats {
	my ($self, $source_file) = @_;

	my $selectstm = $self->{globalselectstm};

	unless ($selectstm->execute($source_file)) {
		if ($selectstm->errstr =~ /Table .* doesn't exist/) {
			warn "Couldn't find the OPL global statistics table.  "
				. "Did you download the latest OPL and run load-OPL-global-statistics.pl?";
		}
		die $selectstm->errstr;
	}

	my $result = $selectstm->fetchrow_arrayref();

	if ($result) {
		return {
			source_file        => $source_file,
			students_attempted => $$result[1],
			average_attempts   => $$result[2],
			average_status     => $$result[3],
		};
	} else {
		return { source_file => $source_file };
	}
}

1;
