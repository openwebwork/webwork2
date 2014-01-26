#!/usr/bin/env perl

print "Content-type:  text/HTML\n\n";

$file = $ENV{PATH_INFO};

Error("Can't load specified file") if ($file =~ m!(\.\./|//|:|~)!);
Error("Can't load specified file") if ($file !~ m!\.p[lg]$!);


#$root = '/usr/local/WeBWorK';
$root = '/opt/webwork/';
$filedir = $file; $filedir =~ s!/[^/]+$!!;
$file =~ s!.*/!!;

@PGdirs = (
  "../templates$filedir",
  "../templates/macros",
#  "$root/local/macros",
  "$root/pg/macros",
);

foreach $dir (@PGdirs) {ShowSource("$dir/$file") if (-e "$dir/$file")}

Error("Can't find specified file",join(",",@PGdirs).": ".$file);

sub Error {
  print "<HTML>\n<HEAD>\n<TITLE>Show-Source Error</TITLE>\n</HEAD>\n";
  print "<BODY>\n\n<H1>Show-Source Error:</H1>\n\n";
  print join("\n",@_),"\n";
  print "</BODY>\n</HTML>";
  exit;
}

sub ShowSource {
  my $file = shift;
  my $name = $file; $name =~ s!.*/!!;

  open(PGFILE,$file);
  $program = join('',<PGFILE>);
  close(PGFILE);

  $program =~ s/&/\&amp;/g;
  $program =~ s/</\&lt;/g;
  $program =~ s/>/\&gt;/g;
  $program =~ s/\t/        /g;
  print "<HTML>\n<HEAD>\n<TITLE>Problem Source Code</TITLE>\n</HEAD>\n";
  print "<BODY>\n\n<H1>Source Code for <CODE>$name</CODE>:</H1>\n\n";
  print "<HR>\n<BLOCKQUOTE>\n";
  print "<PRE>";
  print MarkSource($program);
  print "</PRE>\n";
  print "</BLOCKQUOTE>\n<HR>\n";
  print "</BODY>\n</HTML>\n";
  exit;
}

sub MarkSource {
  my $program = shift;
  local $cgi = $ENV{SCRIPT_NAME};
  $program =~ s/loadMacros *\(([^\)]*)\)/MakeLinks($1)/ge;
  return $program;
}

sub MakeLinks {
  my $macros = shift;
  $macros =~ s!"([^\"<]*)"!"<A HREF="$cgi$filedir/\1">\1</A>"!g;
  $macros =~ s!'([^\'<]*)'!'<A HREF="$cgi$filedir/\1">\1</A>'!g;
  return 'loadMacros('.$macros.')';
}

1;
