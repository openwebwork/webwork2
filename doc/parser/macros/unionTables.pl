######################################################################
##
##  Functions for creating tables of various kinds
##
##    ColumnTable()           Creates a two-column display in HTML,
##                            but only one column in TeX.
##
##    ColumnMatchTable()      Does a side-by-side match table
##
##    BeginTable()            Begin a borderless HTML table
##    Row()                   Create a row in the table
##    AlignedRow()            Create a row with alignment in each column
##    TableSpace()            Insert extra vertical space in the table
##    EndTable()              End the table
##

######################################################################
#
#  Make a two-column table in HTML and Latex2HTML modes
#
#  Usage:  ColumnTable(col1,col2,[options])
#
#  Options can be taken from:
#
#      indent => n           the width to indent the first column
#                            (default is 0)
#
#      separation => n       the width of the separating gutter
#                            (default is 50)
#
#      valign => type        set the vertical alignment
#                            (default is "MIDDLE")
#
sub ColumnTable {
  my $col1 = shift; my $col2 = shift;
  my %options = (indent => 0, separation => 50, valign => "MIDDLE", @_);
  my ($ind,$sep) = ($options{"indent"},$options{"separation"});
  my $valign = $options{"valign"};

  my ($bhtml,$ehtml) = ('\begin{rawhtml}','\end{rawhtml}');
  ($bhtml,$ehtml) = ('','') unless ($displayMode eq "Latex2HTML");

  my $HTMLtable = qq {
    $bhtml<TABLE BORDER="0"><TR VALIGN="$valign">
    <TD WIDTH="$ind">&nbsp;</TD><TD>$ehtml
    $col1
    $bhtml</TD><TD WIDTH="$sep">&nbsp;</TD><TD>$ehtml
    $col2
    $bhtml</TD></TR></TABLE>$ehtml
  };

  MODES(
    TeX => '\par\medskip\hbox{\qquad\vtop{'.
	   '\advance\hsize by -3em '.$col1.'}}'.
           '\medskip\hbox{\qquad\vtop{'.
           '\advance\hsize by -3em '.$col2.'}}\medskip',
    Latex2HTML => $HTMLtable,
    HTML => $HTMLtable
  );
}

#
#  Use columns for a match-list output
#
#  Usage:  ColumnMatchTable($ml,options)
#
#  where $ml is a math list reference and options are those
#  allowed for ColumnTable above.
#
sub ColumnMatchTable {
  my $ml = shift;

  ColumnTable($ml->print_q,$ml->print_a,@_);
}


#
#  Command for tables with no borders.
#
#  Usage:  BeginTable(options);
#
#  Options are taken from:
#
#    border => n           value for BORDER attribute (default 0)
#    spacing => n          value for CELLSPACING attribute (default 0)
#    padding => n          value for CELLPADDING attribute (default 0)
#    tex_spacing => dimen  value for spacing between columns in TeX
#                          (e.g, tex_spacing => 2em) (default 1em)
#    tex_border => dimen   value for left- and right border in TeX (0pt)
#    center => 0 or 1      center table or not (default 1)
#
sub BeginTable {
  my %options = (border => 0, padding => 0, spacing => 0, center => 1,
                 tex_spacing => "1em", tex_border => "0pt", @_);
  my ($bd,$pd,$sp) = ($options{border},$options{padding},$options{spacing});
  my ($tsp,$tbd) = ($options{tex_spacing},$options{tex_border});
  my ($center,$tcenter) = (' ALIGN="CENTER"','\centerline');
     ($center,$tcenter) = ('','') if (!$options{center});
  my $table = 
    qq{<TABLE BORDER="$bd" CELLPADDING="$pd" CELLSPACING="$sp"$center>};

  MODES(
    TeX => '\par\medskip'.$tcenter.'{\kern '.$tbd.
           '\vbox{\halign{#\hfil&&\kern '.$tsp.' #\hfil',
    Latex2HTML => $bHTML.$table.$eHTML."\n",
    HTML => $table."\n"
  );
}

#
#  Usage:  EndTable(options)
#
#  where options are taken from:
#
#     tex_border => dimen     extra vertical space in TeX mode (default 0pt)
#
sub EndTable {
  my %options = (tex_border => "0pt", @_);
  my $tbd = $options{tex_border};
  MODES(
    TeX => '\cr}}\kern '.$tbd.'}\medskip'."\n",
    Latex2HTML => $bHTML.'</TABLE>'.$eHTML."\n",
    HTML => '</TABLE>'."\n"
  );
}

#
#  Creates a row in the table
#
#  Usage:  Row([item1,item2,...],options);
#
#  Each item appears as a separate entry in the table.
#
#  Options control how the row is displayed:
#
#    indent => num           Specifies size of blank column on the left
#                            (default:  indent => 0)
#
#    separation => num       Specifies separation of columns
#                            (default:  spearation => 30)
#
#    align => "type"         Specifies alignment of initial column
#                            (default:  align => "LEFT")
#
#    valign => "type"        Specified vertical alignment of row
#                            (default:  valign => "MIDDLE")
#
sub Row {
  my $rowref = shift; my @row = @{$rowref};
  my %options = (
     indent => 0, separation => 30,
     align => "LEFT", valign => "MIDDLE",
     @_
  );
  my ($cind,$csep) = ($options{indent},$options{separation});
  my ($align,$valign) = ($options{align},$options{valign});
  my $sep = '<TD WIDTH="'.$csep.'">&nbsp;</TD>'; $sep = '' if ($csep < 1);
  my $ind = '<TD WIDTH="'.$cind.'">&nbsp;</TD>'; $ind = '' if ($cind < 1);
  my $fill = '';
  $fill = '\hfil' if (uc($align) eq "CENTER");
  $fill = '\hfill' if (uc($align) eq "RIGHT");

  MODES(
    TeX => "\\cr\n". $fill . join('& ',@row),
    Latex2HTML =>
      $bHTML."<TR VALIGN=\"$valign\">$ind<TD ALIGN=\"$align\">".$eHTML .
      join($bHTML."</TD>$sep<TD>".$eHTML,@row) .
      $bHTML.'</TD></TR>'.$eHTML."\n",
    HTML => "<TR VALIGN=\"$valign\">$ind<TD ALIGN=\"$align\">" .
      join("</TD>$sep<TD>",@row) . '</TD></TR>'."\n"
  );
}

#
#  AlignedRow([item1,item2,...],options);
#
#  Options control how the row is displayed:
#
#    indent => num           Specifies size of blank column on the left
#                            (default:  indent => 0)
#
#    separation => num       Specifies separation of columns
#                            (default:  spearation => 30)
#
#    align => "type"         Specifies alignment of all columns
#                            (default:  align => "CENTER")
#
#    valign => "type"        Specified vertical alignment of row
#                            (default:  valign => "MIDDLE")
#
sub AlignedRow {
  my $rowref = shift; my @row = @{$rowref};
  my %options = (
     indent => 0, separation => 30,
     align => "CENTER", valign => "MIDDLE",
     @_
  );
  my ($cind,$csep) = ($options{indent},$options{separation});
  my ($align,$valign) = ($options{align},$options{valign});
  my $sep = '<TD WIDTH="'.$csep.'">&nbsp;</TD>'; $sep = '' if ($csep < 1);
  my $ind = '<TD WIDTH="'.$cind.'">&nbsp;</TD>'; $ind = '' if ($cind < 1);
  my $fill = '';
  $fill = '\hfil ' if (uc($align) eq "CENTER");
  $fill = '\hfill ' if (uc($align) eq "RIGHT");

  MODES(
    TeX => "\\cr\n". $fill . join('&'.$fill,@row),
    Latex2HTML =>
      $bHTML."<TR VALIGN=\"$valign\">$ind<TD ALIGN=\"$align\">".$eHTML .
      join($bHTML."</TD>$sep<TD ALIGN=\"$align\">".$eHTML,@row) .
      $bHTML.'</TD></TR>'.$eHTML."\n",
    HTML => "<TR VALIGN=\"$valign\">$ind<TD ALIGN=\"$align\">" .
      join("</TD>$sep<TD ALIGN=\"$align\">",@row) . '</TD></TR>'."\n"
  );
}

#
#  Add extra space between rows of a table
#
#  Usage:  TableSpace(pixels,points)
#
#  where pixels is the number of pixels of space in HTML mode and
#  points is the number of points to use in TeX mode.
#
sub TableSpace {
  my $rsep = shift;
  my $tsep = shift;
  $rsep = $tsep if (defined($tsep) && $main::displayMode eq "TeX");
  return "" if ($rsep < 1);
  MODES(
    TeX => '\vadjust{\kern '.$rsep.'pt}' . "\n",
    Latex2HTML =>
      $bHTML.'<TR><TD HEIGHT="'.$rsep.'"><!></TD></TR>'.$eHTML."\n",
    HTML => '<TR><TD HEIGHT="'.$rsep.'"></TD></TR>'."\n",
  );
}

#
#  A horizontal rule within a table.  (Could have been a variable,
#  but all the other table commands are subroutines, so kept it
#  one to be consistent.)
#
sub TableLine {
  MODES(
    TeX => '\vadjust{\kern2pt\hrule\kern2pt}',
    Latex2HTML => $bHTML.
      '<TR><TD COLSPAN="10"><HR NOSHADE SIZE="1"></TD></TR>'.
      $eHTML."\n",
    HTML =>'<TR><TD COLSPAN="10"><HR NOSHADE SIZE="1"></TD></TR>'."\n"
  );
}

1;
