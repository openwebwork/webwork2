################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-1307 The WeBWorK Project, http://openwebwork.sf.net/
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


###########################
# Utils::Tags
#
# Provides basic handling of OPL tags
###########################

package WeBWorK::Utils::Tags;

use base qw(Exporter);
use strict;
use warnings;
use Carp;
use IO::File;

our @EXPORT    = ();
our @EXPORT_OK = qw();
#	list_set_versions
#);

use constant BASIC => qw( DBsubject DBchapter DBsection Date Institution Author MLT MLTleader Level Language );
use constant NUMBERED => qw( TitleText AuthorText EditionText Section Problem );

my $basics = join('|', BASIC);
my $numbered = join('|', NUMBERED);
my $re = qr/#\s*\b($basics)\s*\(\s*'?(.*?)'?\s*\)\s*$/;

sub istagline {
  my $line = shift;
  return 1 if($line =~ /$re/);
  return 1 if($line =~ /#\s*\bKEYWORDS?\s*\(\s*'?(.*?)'?\s*\)/);
  return 1 if($line =~ /#\s*\b($numbered)\d+\s*\(\s*'?(.*?)'?\s*\)/);
  return 0;
}

sub kwtidy {
  my $s = shift;
  $s =~ s/\W//g;
  $s =~ s/_//g;
  $s = lc($s);
  return($s);
}

sub keywordcleaner {
  my $string = shift;
  my @spl1 = split /,/, $string;
#  my @spl2 = map(kwtidy($_), @spl1);
  return(@spl1);
}

sub mergekeywords {
  my $self=shift;
  my $kws=shift;
  if(not defined($self->{keywords})) {
    $self->{keywords} = $kws;
    return;
  }
  if(not defined($kws)) {
    return;
  }
  my @kw = @{$self->{keywords}};
  for my $j (@{$kws}) {
     my $old = 0;
     for my $k (@kw) {
       if(lc($k) eq lc($j)) {
         $old = 1;
         last;
       }
     }
     push @kw, $j unless ($old);
  }
  $self->{keywords} = \@kw;
}

# Note on texts, we store them in an array, but the index is one less than on
#    the corresponding tag.
sub isnewtext {
  my $self = shift;
  my $ti = shift;
  for my $j (@{$self->{textinfo}}) {
    my $ok = 1;
    for my $k ('TitleText', 'EditionText', 'AuthorText') {
      if($ti->{$k} ne $j->{$k}) {
        $ok = 0;
        last;
      }
    }
    return 0 if($ok);
  }
  return 1;
}

sub mergetexts {
  my $self=shift;
  my $newti=shift;
  for my $ti (@$newti) {
    if($self->isnewtext($ti)) {
      my @tia = @{$self->{textinfo}};
      push @tia, $ti;
      $self->{textinfo} = \@tia;
    }
  }
}

# Set a tag with a value
sub settag {
  my $self = shift;
  my $tagname = shift;
  my $newval = shift;
  my $force = shift;

  if(defined($newval) and ((defined($force) and $force) or $newval) and ((not defined($self->{$tagname})) or ($newval ne $self->{$tagname}))) {
    $self->{modified}=1;
    $self->{$tagname} = $newval;
  }
}

sub printtextinfo {
  my $textref = shift;
  print "{";
  for my $k (keys %{$textref}){
    print "$k -> ".$textref->{$k}.", ";
  }
  print "}\n";
}

sub printalltextinfo {
  my $self = shift;
  for my $j (@{$self->{textinfo}}) {
    printtextinfo $j;
  }
}

sub maybenewtext {
  my $textno = shift;
  my $textinfo = shift ;
  return $textinfo if defined($textinfo->[$textno-1]);
  # So, not defined yet
  $textinfo->[$textno-1] = { TitleText => '', AuthorText =>'', EditionText =>'',
             section => '', chapter =>'', problems => [] };
  return $textinfo;
}

sub gettextnos {
  my $textinfo = shift;
  return grep { defined $textinfo->[$_] } (0..(scalar(@{$textinfo})-1));
}

sub tidytextinfo {
  my $self = shift;
  my @textnos = gettextnos($self->{textinfo});
  my $ntxts = scalar(@textnos);
  if($ntxts and ($ntxts-1) != $textnos[-1]) {
    $self->{modified} = 1;
    my @tmptexts = grep{ defined $_ } @{$self->{textinfo}};
    $self->{textinfo} = \@tmptexts;
  }
}


# name is a path

sub new {
  my $class = shift;
  my $name = shift;
  my $self = {};

  $self->{isplaceholder} = 0;
  $self->{modified} = 0;
  my $lasttag = 1;

  my ($text, $edition, $textauthor, $textsection, $textproblem);
  my $textno;
  my $textinfo=[];

  open(IN,"$name") or die "can not open $name: $!";
  if ($name !~ /pg$/ && $name !~ /\.pg\.[-a-zA-Z0-9_.@]*\.tmp$/) {
    warn "Not a pg file";  #print caused trouble with XMLRPC 
    $self->{file}= undef;
    bless($self, $class);
    return $self;
  }
  my $lineno = 0;
  $self->{file} = $name;

  # Initialize some values
  for my $tagname ( BASIC ) {
    $self->{$tagname} = '';
  }
  $self->{keywords} = [];
  #$self->{Language} = 'eng'; # Default to English


  while (<IN>) {
  $lineno++;
  SWITCH: {
      if (/#\s*\bKEYWORDS\((.*)\)/i) {
        my @keyword = keywordcleaner($1);
		@keyword = grep { not /^\s*'?\s*'?\s*$/ } @keyword;
        $self->{keywords} = [@keyword];
        $lasttag = $lineno;
        last SWITCH;
      }
      if (/$re/) { # Checks all other un-numbered tags
        my $tmp1 = $1;
        my $tmp = $2;
        #$tmp =~ s/'/\'/g;
        $tmp =~ s/\s+$//;
        $tmp =~ s/^\s+//;
        $self->{$tmp1} = $tmp;
        $lasttag = $lineno;
        last SWITCH;
      }

      if (/#\s*\bTitleText(\d+)\(\s*'?(.*?)'?\s*\)/) {
        $textno = $1;
        $text = $2;
        $text =~ s/'/\'/g;
        if ($text =~ /\S/) {
          $textinfo = maybenewtext($textno, $textinfo);
          $textinfo->[$textno-1]->{TitleText} = $text;
        }
        $lasttag = $lineno;
        last SWITCH;
      }
      if (/#\s*\bEditionText(\d+)\(\s*'?(.*?)'?\s*\)/) {
        $textno = $1;
        $edition = $2;
        $edition =~ s/'/\'/g;
        if ($edition =~ /\S/) {
          $textinfo = maybenewtext($textno, $textinfo);
          $textinfo->[$textno-1]->{EditionText} = $edition;
        }
        $lasttag = $lineno;
        last SWITCH;
      }
      if (/#\s*\bAuthorText(\d+)\(\s*'?(.*?)'?\s*\)/) {
        $textno = $1;
        $textauthor = $2;
        $textauthor =~ s/'/\'/g;
        if ($textauthor =~ /\S/) {
          $textinfo = maybenewtext($textno, $textinfo);
          $textinfo->[$textno-1]->{AuthorText} = $textauthor;
        }
        $lasttag = $lineno;
        last SWITCH;
      }
      if (/#\s*\bSection(\d+)\(\s*'?(.*?)'?\s*\)/) {
        $textno = $1;
        $textsection = $2;
        $textsection =~ s/'/\'/g;
		$textsection =~ s/[^\d\.]//g;
		#print "|$textsection|\n";
        if ($textsection =~ /\S/) {
          $textinfo = maybenewtext($textno, $textinfo);
          if ($textsection =~ /(\d*?)\.(\d*)/) {
            $textinfo->[$textno-1]->{chapter} = $1;
            $textinfo->[$textno-1]->{section} = $2;
          } else {
            $textinfo->[$textno-1]->{chapter} = $textsection;
            $textinfo->[$textno-1]->{section} = -1;
          }
        }
        $lasttag = $lineno;
        last SWITCH;
      }
      if (/#\s*\bProblem(\d+)\(\s*(.*?)\s*\)/) {
        $textno = $1;
        $textproblem = $2;
        $textproblem =~ s/\D/ /g;
				my @textproblems = (-1);
        @textproblems = split /\s+/, $textproblem;
        @textproblems = grep { $_ =~ /\S/ } @textproblems;
        if (scalar(@textproblems) or defined($textinfo->[$textno])) {
          @textproblems = (-1) unless(scalar(@textproblems));
          $textinfo = maybenewtext($textno, $textinfo);
          $textinfo->[$textno-1]->{problems} = \@textproblems;
        }
        $lasttag = $lineno;
        last SWITCH;
      }
    }}                                               #end of SWITCH and while
  $self->{textinfo} = $textinfo;

  if (defined($self->{DBchapter}) and $self->{DBchapter} eq 'ZZZ-Inserted Text') {
    $self->{isplaceholder} = 1;
  }


  $self->{lasttagline}=$lasttag;
  bless($self, $class);
  $self->tidytextinfo();
#  $self->printalltextinfo();
  return $self;
}

sub isplaceholder {
  my $self = shift;
  return $self->{isplaceholder};
}

sub istagged {
  my $self = shift;
  #return 1 if (defined($self->{DBchapter}) and $self->{DBchapter} and (not $self->{isplaceholder}));
  return 1 if (defined($self->{DBsubject}) and $self->{DBsubject} and (not $self->{isplaceholder}));
	return 0;
}

# Try to copy in the contents of another Tag object.
# Return 1 if ok, 0 if not compatible
sub copyin {
  my $self = shift;
  my $ob = shift;
#  for my $j (qw( DBsubject DBchapter DBsection )) {
#    if($self->{$j} =~ /\S/ and $ob->{$j} =~ /\S/ and $self->{$j} ne $ob->{$j}) {
#    #  print "Incompatible $j: ".$self->{$j}." vs ".$ob->{$j} ."\n";
#      return 0;
#    }
#  }
  # Just copy in all basic tags
  for my $j (qw( DBsubject DBchapter DBsection Date Institution Author MLT MLTleader Level )) {
    $self->settag($j, $ob->{$j}) if(defined($ob->{$j}));
  }
  # Now copy in keywords
  $self->mergekeywords($ob->{keywords});
  # Finally, textbooks
  $self->mergetexts($ob->{textinfo});
  return 1;
}

sub dumptags {
  my $self = shift;
  my $fh = shift;

  for my $tagname ( BASIC ) {
    print $fh "## $tagname(".$self->{$tagname}.")\n" if($self->{$tagname});
  }
  my @textinfo = @{$self->{textinfo}};
  my $textno = 0;
  for my $ti (@textinfo) {
    $textno++;
    for my $nw ( NUMBERED ) {
      if($nw eq 'Problem') {
        print $fh "## $nw$textno('".join(' ', @{$ti->{problems}})."')\n";
        next;
      }
      if($nw eq 'Section') {
        if($ti->{section} eq '-1') {
          print $fh "## Section$textno('".$ti->{chapter}."')\n";
        } else {
          print $fh "## Section$textno('".$ti->{chapter}.".".$ti->{section}."')\n";
        }
        next;
      }
      print $fh "## $nw$textno('".$ti->{$nw}."')\n";
    }
  }
  print $fh "## KEYWORDS(".join(',', @{$self->{keywords}}).")\n" if(scalar(@{$self->{keywords}}));
}

# Write the file
sub write {
  my $self=shift;
  # First read it into an array
  open(IN,$self->{file}) or die "can not open $self->{file}: $!";
  my @lines = <IN>;
  close(IN);
  my $fh = IO::File->new(">".$self->{file}) or die "can not open $self->{file}: $!";
  my ($line, $lineno)=('', 0); 
  while($line = shift @lines) {
    $lineno++; 
    $self->dumptags($fh) if($lineno == $self->{lasttagline});
    next if istagline($line);
    print $fh $line;
  }

  $fh->close();
}

1;

