#! /usr/bin/perl

#
# Usage:  convert-functions [-t | --test] [-q | --quiet] filename [filename ...]
#
#  If the filename is '-', act as a filter (read from stdin and write to stdout),
#  otherwise, each file is read and modified.
#
#  If --test is specified, then no output is written, but you just see what changes
#    would have been made.
#
#  If --quiet is specified, the conversions are not printed out
#    (but the file names still are)
#

#
#  The functions to be converted and their parameter lists.
#
#  The hash key is the original function name, and the value is an array of two or three items:
#    The first is the name of the routine it is being mapped to
#    The second is an array that tells how to map the original functions parameters to the
#      new functions hash list (see below)
#    The third is an optional hash of parameters that are always passed to the new routine
#
#  The values in the array of arguments have several special interpretations:
#    A value listed as "undef" will be passed to the new routine as a plain argument (not as
#      part of the hash).
#    An entry of the form name[n] (where n is a number) will be put in position n of an array
#      reference whose key is name in the hash passed to the new routine.  (E.g., "limits[0]"
#      puts the argument in that position of the original argument list into the first entry
#      of limits=>[n,m] in the hash.)  The default value for the array hash is given by
#      the variable $default{name}, e.g. $default{limits} = ['$funcLLimitDefault','$funcULimitDefault'].
#   An entry of '@' means make the rest of the parameters into an array reference and pass them
#      as the first parameter to the new routine.
#
#   Any extra parameters from the original routine are passed verbatim to the new one.
#

%function = (
	std_num_cmp          => [ 'num_cmp', [ undef, 'relTol', 'format', 'zeroLevel', 'zeroLevelTol' ] ],
	std_num_cmp_abs      => [ 'num_cmp', [ undef, 'tol', 'format' ], { tolType => 'absolute' } ],
	std_num_cmp_list     => [ 'num_cmp', [ 'relTol', 'format', '@' ] ],
	std_num_cmp_abs_list => [ 'num_cmp', [ 'tol', 'format', '@' ], { tolType => 'absolute' } ],

	arith_num_cmp => [ 'num_cmp', [ undef, 'relTol', 'format', 'zeroLevel', 'zeroLevelTol' ], { mode => 'arith' } ],
	arith_num_cmp_abs  => [ 'num_cmp', [ undef,    'tol',    'format' ], { mode => 'arith', tolType => 'absolute' } ],
	arith_num_cmp_list => [ 'num_cmp', [ 'relTol', 'format', '@' ],      { mode => 'arith' } ],
	arith_num_cmp_abs_list => [ 'num_cmp', [ 'tol', 'format', '@' ], { mode => 'arith', tolType => 'absolute' } ],

	strict_num_cmp =>
		[ 'num_cmp', [ undef, 'relTol', 'format', 'zeroLevel', 'zeroLevelTol' ], { mode => 'strict' } ],
	strict_num_cmp_abs  => [ 'num_cmp', [ undef,    'tol',    'format' ], { mode => 'strict', tolType => 'absolute' } ],
	strict_num_cmp_list => [ 'num_cmp', [ 'relTol', 'format', '@' ],      { mode => 'strict' } ],
	strict_num_cmp_abs_list => [ 'num_cmp', [ 'tol', 'format', '@' ], { mode => 'strict', tolType => 'absolute' } ],

	frac_num_cmp => [ 'num_cmp', [ undef, 'relTol', 'format', 'zeroLevel', 'zeroLevelTol' ], { mode => 'frac' } ],
	frac_num_cmp_abs      => [ 'num_cmp', [ undef,    'tol',    'format' ], { mode => 'frac', tolType => 'absolute' } ],
	frac_num_cmp_list     => [ 'num_cmp', [ 'relTol', 'format', '@' ],      { mode => 'frac' } ],
	frac_num_cmp_abs_list => [ 'num_cmp', [ 'tol',    'format', '@' ],      { mode => 'frac', tolType => 'absolute' } ],

	std_num_str_cmp => [ 'num_cmp', [ undef, 'strings', 'relTol', 'format', 'zeroLevel', 'zeroLevelTol' ] ],

	function_cmp =>
		[ 'fun_cmp', [ undef, 'vars', 'limits[0]', 'limits[1]', 'relTol', 'numPoints', 'zeroLevel', 'zeroLevelTol' ] ],

	function_cmp_up_to_constant => [
		'fun_cmp',
		[
			undef,    'vars',      'limits[0]',                'limits[1]',
			'relTol', 'numPoints', 'maxConstantOfIntegration', 'zeroLevel',
			'zeroLevelTol'
		],
		{ mode => 'antider' }
	],

	function_cmp_abs =>
		[ fun_cmp, [ undef, 'vars', 'limits[0]', 'limits[1]', 'tol', 'numPoints' ], { tolType => 'absolute' } ],

	function_cmp_up_to_constant_abs => [
		fun_cmp,
		[ undef, 'vars', 'limits[0]', 'limits[1]', 'tol', 'numPoints', 'maxConstantOfIntegration' ],
		{ mode => 'antider', tolType => 'absolute' }
	],

	multivar_function_cmp => [ 'fun_cmp', [ undef, 'vars' ] ],

	std_str_cmp         => [ 'str_cmp', [] ],
	std_str_cmp_list    => [ 'str_cmp', ['@'] ],
	std_cs_str_cmp      => [ 'str_cmp', [],    { filters => [ 'trim_whitespace', 'compress_whitespace' ] } ],
	std_cs_str_cmp_list => [ 'str_cmp', ['@'], { filters => [ 'trim_whitespace', 'compress_whitespace' ] } ],
	strict_str_cmp      => [ 'str_cmp', [],    { filters => ['trim_whitespace'] } ],
	strict_str_cmp_list => [ 'str_cmp', ['@'], { filters => ['trim_whitespace'] } ],
	unordered_str_cmp   => [ 'str_cmp', [],    { filters => [ 'remove_whitespace', 'ignore_order', 'ignore_case' ] } ],
	unordered_str_cmp_list =>
		[ 'str_cmp', ['@'], { filters => [ 'remove_whitespace', 'ignore_order', 'ignore_case' ] } ],
	unordered_cs_str_cmp      => [ 'str_cmp', [],    { filters => [ 'remove_whitespace', 'ignore_order' ] } ],
	unordered_cs_str_cmp_list => [ 'str_cmp', ['@'], { filters => [ 'remove_whitespace', 'ignore_order' ] } ],
	ordered_str_cmp           => [ 'str_cmp', [],    { filters => [ 'remove_whitespace', 'ignore_case' ] } ],
	ordered_str_cmp_list      => [ 'str_cmp', ['@'], { filters => [ 'remove_whitespace', 'ignore_case' ] } ],
	ordered_cs_str_cmp        => [ 'str_cmp', [],    { filters => ['remove_whitespace'] } ],
	ordered_cs_str_cmp_list   => [ 'str_cmp', ['@'], { filters => ['remove_whitespace'] } ],

);

#numerical_compare_with_units() needs to be handled by hand -- but there are very few uses.

$default{limits} = [ '$funcLLimitDefault', '$funcULimitDefault' ];

#
#  Make a patter from all the names (we sort be length of the names, to
#  make sure prefixes appear later in the list).
#
$pattern = join("|", sort byName keys(%function));

sub byName {
	return $a <=> $b if length($a) == length($b);
	return length($b) <=> length($a);
}

#
#  Remove leading and trailing spaces
#
sub trim {
	my $s = shift;
	$s =~ s/(^\s+|\s+$)//g;
	return $s;
}

#
#  Remove leading comment lines
#
sub trimComments {
	my $s = shift;
	$s =~ s/^(\s*#.*?(\n|$))*//;
	return $s;
}

#
#  Command-line options and internal state parameters
#
$testing = 0;    # true if not writing output files
$quiet   = 0;    # true if not printing changed function calls
$changed = 0;    # true if we have changes a function in the current file

#
#  Read the contents of a file, and search through it for the functions
#  above.  Then modify the argument lists to use hashes rather than
#  direct parameter lists.
#
sub Process {
	my @lines;
	if ($file eq "-") {
		@lines = <>;
		open(PGFILE, ">&STDOUT");    # redirect this to STDOUT
	} elsif ($file eq "--test" || $file eq "-t") {
		$testing = 1;
		return;
	} elsif ($file eq "--quiet" || $file eq "-q") {
		$quiet = 1;
		return;
	} else {
		print stderr "\n" if $changed;
		print stderr "Converting: $file\n";
		open(PGFILE, $file) || warn "Can't read '$file': $!";
		@lines = <PGFILE>;
		close(PGFILE);
		open(PGFILE, $testing ? ">/dev/null" : ">$file");
	}
	$changed = 0;

	my $file = join("", @lines);
	$file =~ s/\&beginproblem(\(\))?/beginproblem()/gm;    # remove unneeded ampersands
	$file =~ s/\&ANS\(/ANS\(/gm;                           # remove unneeded ampersands
	$file =~ s/ANS\( */ANS\(/gm;                           # remove unneeded spaces
	my @parts = split(/($pattern)/o, $file);
	#
	#  Because of the parentheses around the pattern above, split returns the pattern
	#  as well as the stuff it separates.  So @parts contains stuff, first function,
	#  args and more stuff, next function, etc.
	#
	print PGFILE shift(@parts);
	while (my $f = shift(@parts)) {
		my ($args, $rest) = GetArgs(shift(@parts));
		unless ($args) { print $f, $rest; next }
		;    # skip it if doesn't look like an actual call
		print PGFILE HandleFunction($f, $function{$f}, $args), $rest;
	}
}

#
#  Convert the list of arguments to appropriate hash values
#  (taking into account the interpretations given above
#  for the special entries in the list).
#  Don't include empty parameters (I don't think this should be a problem).
#  Return the modified function call with the new name and hash
#
sub HandleFunction {
	my $original = shift;
	my $f        = shift;
	my $args     = shift;
	my @names    = @{ $f->[1] };
	my @args     = @{$args};
	my ($name, $value);
	#
	#  Get the fixed options needed for this function
	#
	my %options = %{ $f->[2] || {} };
	foreach my $id (keys(%options)) {
		if (ref($options{$id}) eq 'ARRAY') {
			$options{$id} = '["' . join('","', @{ $options{$id} }) . '"]';
		} else {
			$options{$id} = '"' . $options{$id} . '"';
		}
	}
	#
	#  Process the list of arguments supplied by the user
	#    (treating special cases properly)
	#
	my @options = ();
	my @params  = ();
	while (my ($name, $value) = (shift(@names), shift(@args))) {
		last unless defined $value;
		unless ($name) { push(@params, $value); next }
		if     ($name eq '@') { push(@params, '[' . join(',', $value, @args) . ']'); @args = (); last }
		if     ($name =~ s/\[(\d+)\]$//) {
			$options{$name} = $default{$name} unless defined $options{$name};
			$options{$name}[$1] = $value;
			next;
		}
		$options{$name} = $value unless $value eq '""' || $value eq "''";
	}
	#
	#  Add the hash values to the new argument list
	#
	while (($name, $value) = each %options) {
		$value = '[' . join(',', @{ $options{$name} }) . ']' if ref($value) eq 'ARRAY';
		push(@options, "$name=>$value");
	}
	#
	#  Create the new function and display it
	#
	my $F = $f->[0] . '(' . join(', ', @params, @options, @args) . ')';
	unless ($quiet) {
		print stderr "   $original(", join(',', @{$args}), ") -> $F\n";
		$changed = 1;
	}
	return $F;
}

#
#  Get the argument list for the function, respecting quotation marks,
#  nested parentheses, and so on.  Remove comments that might be
#  nested within a multi-line function call.
#
sub GetArgs {
	my $text       = shift;
	my @args       = ();
	my $parenCount = 0;
	my $arg        = "";
	return (undef, $text) unless $text =~ s/^\s*\(//;    # remove leading spaces and opening paren
	$text = trimComments($text);
	while ($text =~ s/^((?:"(?:\\.|[^\"])*"|'(?:\\.|[^\'])*'|\\.|[^\\])*?)([(){}\[\],\n])//) {
		if ($2 eq '(' || $2 eq '[' || $2 eq '{') { $parenCount++; $arg .= $1 . $2; next }
		if ($2 eq ')' && $parenCount == 0)       { $arg .= $1; push(@args, trim($arg)); last }
		if ($2 eq ')' || $2 eq ']' || $2 eq '}') { $parenCount--; $arg .= $1 . $2; next }
		if ($2 eq "\n")                          { $arg .= $1; $text = trimComments($text); next }
		if ($parenCount == 0) {
			push(@args, trim($arg . $1));
			$arg  = "";
			$text = trimComments($text);
		} else {
			$arg .= $1 . $2;
		}
	}
	$text =~ s/^ +//;    # remove unneeded leading spaces
	return (\@args, $text);
}

#
#  Process each file
#
push(@ARGV, "-") if (scalar(@ARGV) == 0);
foreach $file (@ARGV) { print Process($file) }
print stderr "\n";
