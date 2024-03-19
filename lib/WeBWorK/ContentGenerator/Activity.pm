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

package WeBWorK::ContentGenerator::Activity;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Activity - Display activity (logins, answer submissions) over time by user.

=cut

use Mojo::File;
use Statistics::R::IO;

sub displayStudentActivity ($c, $studentID) {
	my $ce = $c->ce;

	my $login_log = Mojo::File::path($ce->{courseFiles}{logs}{login_log})->slurp('UTF-8');
	# we just want the "LOGIN OK" lines
	my @login_ok = grep {/^.* LOGIN OK .*$/} split("\n", $login_log);
	# now convert lines to a suitable format for data analysis
	for (@login_ok) {
		$_ = [ $_ =~ /^\[(.*?)\] LOGIN OK user_id=(\S*) .* credential_source=(\S*) .*UA=(.*)$/g ];
		$_ = join('|', @{$_});
	}
	my $logins_table_string = join('|', @login_ok);

	my $query = join(
		"\n",
		'library(ggplot2)',
		'library(svglite)',
		'library(fasttime)',
		"table_string <- '$logins_table_string'",
		'setClass("myDate")',
		'setAs("character", "myDate", function(from) as.POSIXct(from, format="%a %b %d %H:%M:%S %Y"))',
		'logins <- read.table(text=table_string, sep = "|", '
			. ' col.names=c("date", "user", "credential", "UA"), colClasses=c("myDate", "factor", "factor", "character"))',
		'our_logins <- logins[logins$user=="' . $c->{studentID} . '",]',
		's <- svgstring(width = 10, height = 2)',
		'plot(ggplot(our_logins, aes(x=date, y=0)) '
			. '+ggtitle("Logins (see logs folder in File Manager for more detail)") '
			. '+theme(aspect.ratio=1/8) '
			. '+geom_hline(yintercept=0, color = "black", size=0.3) '
			. '+geom_point(aes(y=0), size=3) '
			. '+theme(axis.line.y=element_blank(), axis.text.y=element_blank(), axis.title.y=element_blank(), '
			. 'axis.ticks.y=element_blank(), legend.position = "bottom") '
			. ')',
		's()',

	);

	my $rserve = Rserve::access(server => $ce->{pg}{specialPGEnvironmentVars}{Rserve}{host}, _usesocket => 1);
	my $result = Rserve::try_eval($rserve, $query);
	$rserve->close();
	$result =~ s/^\s*character\(|\)\s*$//g;
	return ($result);

}

1;
