#!/usr/bin/env perl

use strict;
use warnings;

print "Content-type: text/html\n\n";

my $file = $ENV{PATH_INFO};

Error(q{Can't load specified file.}) if $file =~ m!(\.\./|//|:|~)! || $file !~ m!\.p[lg]$!;

my $root    = '/opt/webwork';
my $filedir = $file =~ s!/[^/]+$!!r;
$file =~ s!.*/!!;

my @PGdirs = (
	"../templates$filedir",  '../templates/macros',      "$root/pg/macros",      "$root/pg/macros/answers",
	"$root/pg/macros/capa",  "$root/pg/macros/contexts", "$root/pg/macros/core", "$root/pg/macros/deprecated",
	"$root/pg/macros/graph", "$root/pg/macros/math",     "$root/pg/macros/misc", "$root/pg/macros/parsers",
	"$root/pg/macros/ui",
);

for my $dir (@PGdirs) { ShowSource("$dir/$file") if (-e "$dir/$file") }

Error(qq{Can't find file "$file" in the following allowed locations:\n}, @PGdirs);

sub Error {
	my @errors = @_;

	print '<!DOCTYPE html><html lang="en-US"><head><meta charset="utf-8"><title>Show-Source Error</title></head>';
	print '<body><h1>Show-Source Error:</h1><pre>';
	print join("\n", @errors);
	print '</pre></body></html>';

	exit;
}

sub ShowSource {
	my $file = shift;
	my $name = $file;
	$name =~ s!.*/!!;

	open(my $pg_file, '<', $file);
	my $program = join('', <$pg_file>);
	close($pg_file);

	$program =~ s/&/\&amp;/g;
	$program =~ s/</\&lt;/g;
	$program =~ s/>/\&gt;/g;

	print '<!DOCTYPE html><html lang="en-US"><head><meta charset="utf-8"><title>Problem Source Code</title></head>';
	print "<body><h1>Source Code for <code>$name</code>:</h1>";
	print '<hr><blockquote>';
	print '<pre style="tab-size:4;">';
	print MarkSource($program);
	print '</pre>';
	print '</blockquote><hr>';
	print '</body></html>';

	exit;
}

sub MarkSource {
	my $program = shift;
	$program =~ s/loadMacros *\(([^\)]*)\)/MakeLinks($1)/ge;
	return $program;
}

sub MakeLinks {
	my $macros = shift;
	$macros =~ s!"([^\"<]*)"!"<a href="$ENV{SCRIPT_NAME}$filedir/$1">$1</a>"!g;
	$macros =~ s!'([^\'<]*)'!'<a href="$ENV{SCRIPT_NAME}$filedir/$1">$1</a>'!g;
	return "loadMacros($macros)";
}

1;
