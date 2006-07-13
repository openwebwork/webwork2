################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/

# $CVSHeader: webwork2/lib/WeBWorK/CGI.pm,v 1.19 2006/07/13 17:24:36 gage Exp $
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
	my $prolog = '';
	my $postlog = '';
	# handle special cases
	CASES:{
	$func =~/^(checkbox)$/  && do {
	                           my $type = $func;
	                           $func ='input'; 
	                           my %inputs       = (ref($_[0])=~/HASH/) ? %{$_[0]} : @inputs;
	                           $inputs{-type} = $type;
	                           my $labels_key = normalizeName('labels?',keys %inputs);
	                           my $label = ($labels_key)?$inputs{$labels_key}:'';
	                           delete($inputs{$labels_key}) if defined $labels_key and exists($inputs{$labels_key});
	                           @inputs = (\%inputs);
	                           if (defined($label) and $label) {
	                           		$prolog = "<label>";
	                           		$postlog = "$label</label>";
	                           }
	                           last CASES;
	                       };
	$func =~/^textfield$/     && do {
	                          my $type = 'text';
	                          $func ='input';
	                          push @inputs, '-type',$type;
	                          last CASES;
	                       };
	$func =~/^password_field$/     && do {
	                          my $type = 'password';
	                          $func ='input';
	                          push @inputs, '-type',$type;
	                          last CASES;
	                       };
	$func =~/^textarea$/     && do {
	                          my %inputs       = (ref($_[0])=~/HASH/) ? %{$_[0]} : @inputs;
	                          my $default_label = normalizeName('defaults?',keys %inputs);
	                          $inputs{-text} = $inputs{$default_label};
	                          @inputs = %{removeParam($default_label, \%inputs)};
	                          last CASES;
	                       };
    $func =~/^submit$/        && do {
    	                       my $type = $func;
	                           $func ='input'; 
	                           my %inputs       = (ref($_[0])=~/HASH/) ? %{$_[0]} : @inputs;
	                           $inputs{-type} = $type;
	                           my ($labels_key) = normalizeName('labels?',keys %inputs);
	                           $inputs{-value}= $inputs{$labels_key} if defined $labels_key and exists $inputs{$labels_key}; # use value for name
	                           delete($inputs{$labels_key}) if defined $labels_key and exists $inputs{$labels_key};
	                           @inputs = (\%inputs);
	                           last CASES;
	                       };
    $func =~/^radio$/          && do {
							   my $type = $func;
							   $func ='input'; 
							   my %inputs       = (ref($_[0])=~/HASH/) ? %{$_[0]} : @inputs;
	                           $inputs{-type} = $type;
							   my ($values_key) = normalizeName('values?',keys %inputs);
							   $inputs{-value}= $inputs{$values_key};  # use value for name
							   delete($inputs{$values_key}) if defined $values_key and exists $inputs{$values_key};
							   @inputs = (\%inputs);
							   last CASES;
							   };
	$func =~/^(p|Tr|td|li|table|div|th)$/     && do { # concatenate inputs
							   my $attributes;
							   $attributes = shift @inputs if ref($inputs[0]) =~/HASH/;
							   if (ref($inputs[0]) =~/ARRAY/) { # implied group
								   $func = $func.'_group' if ref($inputs[0]) =~/ARRAY/;
							   } else { #combine inputs
								   my $text = join("", @inputs);
								   @inputs = ($text);
							   }
							   unshift @inputs, $attributes if defined $attributes;
							   last CASES;
						    };
       $func =~ /^hidden/ && do  { # handles name value pairs
                               my $type = $func;
	                           $func ='input'; 
	                           my %inputs;
	                           my $default_key = normalizeName('default', @inputs);
	                           if (@inputs == 2)  { #name value pair
								   $inputs{-type} = $type;
								   $inputs{-name} = $inputs[0];
								   $inputs{-value}= $inputs[1];
								   $inputs{-value} = 1 unless defined($inputs{-value}); 
								   @inputs = (\%inputs);
							   } elsif( ref($inputs[0])=~/HASH/ ){
							   	   $inputs[0]->{-type} = $type;
							   } else {  # labeled entries
							       %inputs = @inputs;
							   	   $inputs{-type} = $type;
							   	   if ( $default_key and defined($inputs{$default_key}) ) {
							   	   		$inputs{-value} = $inputs{$default_key};
							   	   		%inputs = %{removeParam('default',\%inputs)};
							   	   }
							   	   
							   	   @inputs = (\%inputs);
							   }
							   last CASES; 
	                        };
	                           
       $func =~/^radio_group$/ &&do {
   							   my $type = $func;
	                           $func ='input_group', 
	                           push @inputs, '-type','radio';
	                           my %inputs = @inputs;
	                           %inputs = %{removeParam('override',\%inputs)};
	                           my $labels_key = normalizeName('labels?',@inputs);
	                           my $values_key = normalizeName('values?',@inputs);
	                           my $name_key = normalizeName('name',@inputs);
	                           my $ra_value     = $inputs{$values_key};
							   my $rh_labels    = $inputs{labels_key};
							   my @values       =  @{$inputs{$values_key}};
							   my $ret = (defined($inputs{'-linebreak'}) and $inputs{'-linebreak'} )?"<br>":'';
	                           # deal with the default option
							   my $default = normalizeName('default', @inputs);
							   my $selected_button = '';
							   my $text = '';
							   my $selected_value = $values[0];
							   if (defined($default) and $default and defined($inputs{$default})) {
							        # grab the selected options
							        $selected_value  = $inputs{$default}; 
							   }  
							   %inputs = %{removeParam('default',\%inputs)};
	                            ## match labels to values
	                           my @text=();
	                           if (defined($labels_key) and $labels_key) {
								   my %labels= %{$inputs{$labels_key}}; 
								   delete($inputs{$labels_key}) if exists $inputs{$labels_key};
								   @text  = map {( exists($labels{$_}) )? $labels{$_}.$ret: $_.$ret } @values;
							   } else { # no labels
							   	  @text = map {$_ .$ret} @values;
							   }
							   my @checked = map { $selected_value eq $_ } @values;
	                           @inputs = (-type=>'radio',-name=>$inputs{$name_key}, -value=>\@values, -text=>\@text, -checked=>\@checked);
	                           last CASES;
	                        }; 
	$func =~/^(popup_menu|scrolling_list)$/   &&do{ 
							   my %inputs       = (ref($_[0])=~/HASH/) ? %{$_[0]} : @inputs;
							   %inputs = %{removeParam('override',\%inputs)};
							   my $values_key   = normalizeName('values?',keys %inputs); #get keys
							   my $labels_key   = normalizeName('labels?',keys %inputs);
							   my $ra_value     = $inputs{$values_key};
							   my $rh_labels    = $inputs{labels_key};
							   my @values       =  eval{ @{$inputs{$values_key}} }; 
							   @values          = grep {defined($_) and $_} @values;
							   warn "error in $values_key  $inputs{$values_key}",join(' ', @inputs), caller(), $@ if $@;
							   
							   # deal with the default option
							   my $default = normalizeName('default', @inputs);
							   my $selected_option = '';
							   my $text = '';
							   my %selected_values = ($values[0] => 1);  # select the first value by default
							   if (defined($default) and $default and defined($inputs{$default}) and $inputs{$default}) {
							        # grab the selected options
							        if (ref($inputs{$default})=~/ARRAY/ ) {
							        	%selected_values = map {$_ => 1 } @{$inputs{$default}};
							        } elsif ($inputs{$default}) {
							        	%selected_values = ($inputs{$default} => 1);
							        }
							   }
                               my @selected = map {(exists($selected_values{$_}) )?1 : 0 } @values;
							   %inputs = %{removeParam('default',\%inputs)};
							   ## match labels to values
							   my @text=();
							   if (defined($labels_key) and $labels_key) {
								   my %labels= %{$inputs{$labels_key}}; 
								   delete($inputs{$labels_key}) if exists $inputs{$labels_key};
								   @text  = map {( exists($labels{$_}) )? $labels{$_}: $_ } @values;
							   } else { # no labels
							   	   @text = @values;
							   }
							   delete($inputs{$values_key});
							   # end match labels to values 
							   $prolog = $html2->select_start(\%inputs).$selected_option;
							   $postlog = $html2->select_end();
							   return "$prolog$postlog" unless @values;  # don't call group if options are empty
							   $func = 'option_group'; 
							   @inputs =({-value=>\@values, -text=>\@text, -selected =>\@selected });
							   last CASES;
	                        };
    } # end CASES block
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
	if ( $prolog or $postlog ) {
		$result =~ s/^\n//;   # get rid of extra return??
		$result = "$prolog$result$postlog" ;
	}
	return $result;
}
sub normalizeName {
	my $name = shift;  #name to find
	my @inputs  = @_;   #inputs 
	my ($key) = grep /^-?$name$/, @inputs;
	return $key;
}

# possible utility subroutines.
sub removeParam {
	my $name = shift;
	my $rh_inputs = shift;
	delete($rh_inputs->{$name}) if defined $name and exists $rh_inputs->{$name};
	delete($rh_inputs->{-$name}) if defined $name and exists $rh_inputs->{-$name};
	$rh_inputs;
}
sub labelsToText {   #takes labels attached to values and distributes them into a text variable
	my $rh_labels = shift;
	my $rh_values = shift;
}	
1;