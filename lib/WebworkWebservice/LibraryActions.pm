#!/usr/local/bin/perl -w 

# Copyright (C) 2002 Michael Gage 

###############################################################################
# Web service which fetches WeBWorK problems from a library.
###############################################################################


#use lib '/home/gage/webwork/pg/lib';
#use lib '/home/gage/webwork/webwork-modperl/lib';

package WebworkWebservice::LibraryActions;
use WebworkWebservice;
use base qw(WebworkWebservice); 

use strict;
use sigtrap;
use Carp;
use WWSafe;
#use Apache;
use WeBWorK::Utils;
use WeBWorK::CourseEnvironment;
use WeBWorK::PG::Translator;
use WeBWorK::PG::IO;
use Benchmark;
use MIME::Base64 qw( encode_base64 decode_base64);

##############################################
#   Obtain basic information about directories, course name and host 
##############################################
our $WW_DIRECTORY = $WebworkWebservice::WW_DIRECTORY;
our $PG_DIRECTORY = $WebworkWebservice::PG_DIRECTORY;
our $COURSENAME   = $WebworkWebservice::COURSENAME;
our $HOST_NAME    = $WebworkWebservice::HOST_NAME;
our $PASSWORD     = "we-don't-need-no-stinking-passowrd";


#our $ce           = WeBWorK::CourseEnvironment->new($WW_DIRECTORY, "", "", $COURSENAME);
# warn "library ce \n ", WebworkWebservice::pretty_print_rh($ce);
# warn "LibraryActions is ready";

##############################################
#   Obtain basic information about local libraries
##############################################
# my %prob_libs	= %{$ce->{courseFiles}->{problibs} };

 #warn pretty_print_rh(\%prob_libs);
 # replace library names with full paths
 
# my $templateDir    = $ce->{courseDirs}->{templates};
# warn "template Directory is $templateDir";
# foreach my $key (keys %prob_libs) {
# 	$prob_libs{$key} = "$templateDir/$key";
# }
 #warn "prob libraries", WebworkWebservice::pretty_print_rh(\%prob_libs);

sub listLibraries {  # list the problem libraries that are available.
	my $self = shift;
	my $rh = shift;
	#my $my_ce = $self->{ce};
	my %libraries = %{$self->{ce}->{courseFiles}->{problibs}};
 
	my $templateDirectory = $self->{ce}->{courseDirs}{templates};

	foreach my $key (keys %libraries) {
 		$libraries{$key} = "$templateDirectory/$key";
 	}
	
	my @outListLib = sort keys %libraries;
	my $out = {};
	$out->{ra_out} = \@outListLib;
	$out->{text} = encode_base64("success");
	return $out;
}

use File::stat;
sub readFile {
    my $self = shift;
	my $rh   = shift;
	local($|)=1;
	my $out = {};
	my $filePath = $rh->{filePath};

	my %libraries = %{$self->{ce}->{courseFiles}->{problibs}};
 
	my $templateDirectory = $self->{ce}->{courseDirs}{templates};

	foreach my $key (keys %libraries) {
 		$libraries{$key} = "$templateDirectory/$key";
 	}
	

	
	if (  defined($libraries{$rh->{library_name}} )   ) {
		$filePath = $libraries{$rh->{library_name}} .'/'. $filePath;
	} else {
		$out->{error} = "Could not find library:".$rh->{library_name}.":";
		return($out);
	}
	
	if (-r $filePath) {
		open IN, "<$filePath";
		local($/)=undef;
		my $text = <IN>;
		$out->{text}= encode_base64($text);
		my $sb=stat($filePath);
		$out->{size}=$sb->size;
		$out->{path}=$filePath;
		$out->{permissions}=$sb->mode&07777;
		$out->{modTime}=scalar localtime $sb->mtime;
		close(IN);
	} else {
		$out->{error} = "Could not read file at |$filePath|";
	}
	return($out);
}

use File::Find;	
#idea from http://www.perlmonks.org/index.pl?node=How%20to%20map%20a%20directory%20tree%20to%20a%20perl%20hash%20tree
sub build_tree {
    my $node = $_[0] = {};
    my @s;
    find({wanted=>sub {
      # fixed 'if' => 'while' -- thanks Rudif
      unless ($File::Find::dir =~/.svn/ || $File::Find::name =~/.svn/) {
      	$node = (pop @s)->[1] while @s and $File::Find::dir ne $s[-1][0];
     	return $node->{$_} = -s if -f;
      	push @s, [ $File::Find::name, $node ];
      	$node = $node->{$_} = {};
      }
    }, follow_fast=>1}, $_[1]);
    $_[0]{$_[1]} = delete $_[0]{'.'};
}

sub listLib {
	my $self = shift;
	my $rh = shift;
	my $out = {};
	my $dirPath = $self->{ce}->{courseDirs}{templates}."/".$rh->{library_name};
	my @outListLib;
	my %libDirectoryList;
	
	my $wanted = sub {
		unless ($File::Find::dir =~/.svn/ ) {
			my $name = $File::Find::name;
			if ($name =~/\S/ ) {
				$name =~ s|^$dirPath/*||;  # cut the first directory
				push(@outListLib, "$name") if $name =~/\.pg/;
	
			}
		}
	};
	
	my $wanted_directory = sub {
		unless ($File::Find::dir =~/.svn/ ) {
			my $dir = $File::Find::dir;
			if ($dir =~/\S/ ) {
				$dir =~ s|^$dirPath/*||;  # cut the first directory
	
				$libDirectoryList{$dir}++;
			}
		}
	};
	 
	my $command = $rh->{command};
	warn "the command being executed is ' $command '";
	$command = 'all' unless defined($command);
			$command eq 'all' &&    do {
										$out->{command}="all -- list all pg files in $dirPath";
										find({wanted=>$wanted,follow_fast=>1 }, $dirPath);
										@outListLib = sort @outListLib;
										$out->{ra_out} = \@outListLib;
										$out->{text} = encode_base64( join("\n", @outListLib) );
										return($out);
			};
			$command eq 'dirOnly' &&   do {
										find({wanted=>$wanted_directory,follow_fast=>1 }, $dirPath);
										build_tree(my $tree, $dirPath);
										@outListLib = sort keys %libDirectoryList;
										$out->{ra_out} = \@outListLib;
										$out->{text} = encode_base64("Loaded libraries");
										return($out);
			};
			$command eq 'buildtree' &&   do {
										#find({wanted=>$wanted_directory,follow_fast=>1 }, $dirPath);
										build_tree(my $tree, $dirPath);
										#@outListLib = sort keys %libDirectoryList;
										$out->{ra_out} = $tree;
										$out->{text} = encode_base64("Loaded libraries");
										return($out);
			};

			$command eq 'files' && do {  @outListLib=();
										 my $separator = ($dirPath =~m|/$|) ?'' : '/';
			 							 my $dirPath2 = $dirPath . $separator . $rh->{dirPath};
			 							 if ( -e $dirPath2) {
											 find($wanted, $dirPath2);
											 @outListLib = sort @outListLib;
											 $out ->{text} = encode_base64( join("\n", @outListLib ) );
											 $out->{ra_out} = \@outListLib;
										 } else {
										   $out->{error} = "Can't open directory  $dirPath2";
										 }
										 return($out);

			};
			# else
			$out->{error}="Unrecognized command $command";
			return( $out );
}


sub pretty_print_rh {
	my $rh = shift;
	my $out = "";
	my $type = ref($rh);
	if ( ref($rh) =~/HASH/ ) {
 		foreach my $key (sort keys %{$rh})  {
 			$out .= "  $key => " . pretty_print_rh( $rh->{$key} ) . "\n";
 		}
	} elsif ( ref($rh) =~ /SCALAR/ ) {
		$out = "scalar reference ". ${$rh};
	} elsif ( ref($rh) =~/Base64/ ) {
		$out .= "base64 reference " .$$rh;
	} else {
		$out =  $rh;
	}
	if (defined($type) ) {
		$out .= "type = $type \n";
	}
	return $out;
}


1;
