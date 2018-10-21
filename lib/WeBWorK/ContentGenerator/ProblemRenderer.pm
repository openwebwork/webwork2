################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/ProblemRenderer.pm,v 1.1 2008/04/29 19:27:34 sh002i Exp $
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

package WeBWorK::ContentGenerator::ProblemRenderer;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::ProblemRenderer - render a problem with a minimal
amount of UI garbage.

=cut

use strict;
use warnings;
use WeBWorK::CGI;
use WeBWorK::Utils::Tasks qw(renderProblems);

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	
	my $pg = $r->param('pg');
	my $file = $r->param('file');
	my $seed = $r->param('seed');
	my $mode = $r->param('mode');
	my $hint = $r->param('hint');
	my $sol = $r->param('sol');
	
	die "must specify either a PG problems (param 'pg') or a path to a PG file (param 'file') and not both"
		unless defined $pg and length $pg xor defined $file and length $file;
	
	my $problem = $self->get_problem($pg, $file);
	my @options = (r=>$r, problem_list=>[\$pg]);
	
	#push @options, (problem_seed=>$seed) if defined $seed;
	#push @options, (displayMode=>$mode) if defined $mode;
	#push @options, (showHints=>$hint) if defined $hint;
	#push @options, (showSolutions=>$sol) if defined $sol;
	
	($self->{result}) = renderProblems(@options);
}

sub get_problem {
	my ($self, $pg, $file) = @_;
	
	if (defined $pg) {
		return \$pg;
	} else {
		return $file;
	}
}

use Data::Dumper;
sub content {
	my ($self) = @_;
	my $result = $self->{result};
	my $dump = Dumper($result);
	
	print <<EOF;
<html>
<head>
<title>Yuck!</title>
</head>
<body>
<pre>$dump</pre>
</body>
</html>
EOF
}

1;
