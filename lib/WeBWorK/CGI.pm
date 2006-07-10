################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Constants.pm,v 1.44 2006/06/26 23:25:15 dpvc Exp $
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
use HTML::EasyTags;
use strict;
package CGI; # (override standard CGI namespace!!)

@CGI::ISA = qw(HTML::EasyTags);
our $html2 = HTML::EasyTags->new();
our $AUTOLOAD;

sub AUTOLOAD {
	my $func = $AUTOLOAD;
	$func =~ s/^CGI:://;
	my $result;
	my @inputs = @_;
	# reverse order to make this compatible with CGI

	$func=~s/^start_?(.*)$/$1_start/;
	$func=~s/^end_?(.*)$/$1_end/;
	my $label = undef;
	# handle special cases
	$func =~/^(checkbox|hidden)$/  && do {
	                           my $type = $func;
	                           $func ='input', 
	                           push @inputs, '-type',$type;
	                           my %inputs = @inputs;
	                           my ($key) = grep /-?label/, @inputs;
	                           $label = ($key)?$inputs{$key}:'';
	                           delete($inputs{$key}) if defined $key and exists($inputs{$key});
	                           @inputs = (\%inputs);
	                           };
    $func =~/^submit$/        && do {
    	                       my $type = $func;
	                           $func ='input', 
	                           push @inputs, '-type',$type;
	                           my %inputs = @inputs;
	                           my ($key) = grep /-?label/, @inputs;
	                           $inputs{-value}= $inputs{$key};  # use value for name
	                           delete($inputs{$key}) if defined $key and exists $inputs{$key};
	                           @inputs = (\%inputs);
	                           };
    $func =~/^radio$/          && do {
							   my $type = $func;
							   $func ='input', 
							   push @inputs, '-type',$type;
							   my %inputs = @inputs;
							   my ($key) = grep /-?values/, @inputs;
							   $inputs{-value}= $inputs{$key};  # use value for name
							   delete($inputs{$key}) if defined $key and exists $inputs{$key};
							   @inputs = (\%inputs);
							   };
	$func =~/^(p|Tr|td|li)$/     && do { # concatenate inputs
							   my $attributes;
							   $attributes = shift @inputs if ref($inputs[0]) =~/HASH/;
							   if (ref($inputs[0]) =~/ARRAY/) { # implied group
								   $func = $func.'_group' if ref($inputs[0]) =~/ARRAY/;
							   } else { #combine inputs
								   my $text = join("", @inputs);
								   @inputs = ($text);
							   }
							   unshift @inputs, $attributes if defined $attributes;
							   };
 
       $func =~/^radio_group$/ &&do {
   							   my $type = $func;
	                           $func ='input_group', 
	                           push @inputs, '-type','radio';
	                           my %inputs = @inputs;
	                           my ($key) = grep /-?labels/, @inputs;
	                           my @text=();
	                           my ($key2) = grep /-?values/, @inputs;
	                           # get values
							   my @values =  @{$inputs{$key2}};
	                           my $ret = (defined($inputs{'-linebreak'}) and $inputs{'-linebreak'} eq 'true')?"<br>\n":'';
	                           if (defined($key) and $key) {
								   my %button_labels= %{$inputs{$key}}; 
								   delete($inputs{$key}) if exists $inputs{$key};
								   @text  = map {$button_labels{$_}.$ret} @values;
							   } else { # no labels
							   	  @text = map {$_ .$ret} @values;
							   }
	                           $inputs{text} = \@text;
	                           @inputs = (\%inputs);
	                           }; 
    
    
    #my @singles   = grep /override|enable|disable|selected/, @inputs;
    #warn "possible problem with single names (no values)", join(" ", @singles) if @singles;
    
	if (ref($inputs[0]) or @inputs==1 or @inputs%2 == 0 or $func eq 'td') {  # even number of hash elements
		#$result = "OK: $func( @inputs )"; 
		$result = eval {  $html2->$func(@inputs) };
	} else {
		$result = "ERROR: bad number of inputs $func(   " .join(" ", @_)." )";
	}
	#$result = eval { use WeBWorK::CGI; $html2->$func(@_) };
	#handle special cases
	if ( defined($label) ) {
		$result =~ s/^\n//;   # get rid of extra return
		$result = "\n<label>$result$label</label>" if defined $label and $label;
	}
	return $result;
}

1;