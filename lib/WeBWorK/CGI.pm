################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/CGI.pm,v 1.4 2006/07/11 12:29:16 gage Exp $
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
	$func =~/^(checkbox|hidden)$/  && do {
	                           my $type = $func;
	                           $func ='input', 
	                           push @inputs, '-type',$type;
	                           my %inputs = @inputs;
	                           my ($key) = grep /-?label/, @inputs;
	                           my $label = ($key)?$inputs{$key}:'';
	                           delete($inputs{$key}) if defined $key and exists($inputs{$key});
	                           @inputs = (\%inputs);
	                           if (defined($label) and $label) {
	                           		$prolog = "<label>";
	                           		$postlog = "$label</label>";
	                           }
	                       };
    $func =~/^submit$/        && do {
    	                       my $type = $func;
	                           $func ='input', 
	                           push @inputs, '-type',$type;
	                           my %inputs = @inputs;
	                           my ($key) = grep /-?label/, @inputs;
	                           $inputs{-value}= $inputs{$key} if defined $key and exists $inputs{$key}; # use value for name
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
	$func =~/^(p|Tr|td|li|hidden|table|div)$/     && do { # concatenate inputs
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
	                           %inputs = %{removeParam('override',\%inputs)};
	                           my $labels_key = normalizeName('labels',@inputs);
	                           my $values_key = normalizeName('values',@inputs);
	                           my $name_key = normalizeName('name',@inputs);
	                           my $ra_value     = $inputs{$values_key};
							   my $rh_labels    = $inputs{labels_key};
							   my @values       =  @{$inputs{$values_key}};
							   my $ret = (defined($inputs{'-linebreak'}) and $inputs{'-linebreak'} )?"<br>":'';
	                           # deal with the default option
							   my $default = normalizeName('default', @inputs);
							   my $selected_button = '';
							   my $text = '';
							   if (defined($default) and $default and defined($inputs{$default})) {
							        # grab the selected options
							        my $selected_value  = $inputs{$default}; 
							        
										if (defined $labels_key) {
											$text = $inputs{$labels_key}->{$selected_value}.$ret;
											delete($inputs{$labels_key}->{$selected_value});
										} else {
											$text = $selected_value;
										}
										@values = grep !/$selected_value/, @values; 
										$prolog.= $html2->input({-name=>$inputs{$name_key},-type=>'radio',
										                                   -checked=>1, -text=>$text, 
										                                   -value=>$selected_value})."\n";
									
							   } 
							   %inputs = %{removeParam('default',\%inputs)};
	                            ## match labels to values
	                           my @text=();
	                           if (defined($labels_key) and $labels_key) {
								   my %labels= %{$inputs{$labels_key}}; 
								   delete($inputs{$labels_key}) if exists $inputs{$labels_key};
								   @text  = map {$labels{$_}.$ret} @values;
							   } else { # no labels
							   	  @text = map {$_ .$ret} @values;
							   }
	                           @inputs = (-value=>\@values, -text=>\@text);
	                        }; 
	$func =~/^(popup_menu|scrolling_list)$/   &&do{
							   my %inputs       = @inputs;
							   %inputs = %{removeParam('override',\%inputs)};
							   my $values_key   = normalizeName('values',@inputs); #get keys
							   my $labels_key   = normalizeName('labels',@inputs);
							   my $ra_value     = $inputs{$values_key};
							   my $rh_labels    = $inputs{labels_key};
							   my @values       =  @{$inputs{$values_key}};
							   
							   # deal with the default option
							   my $default = normalizeName('default', @inputs);
							   my $selected_option = '';
							   my $text = '';
							   if (defined($default) and $default and defined($inputs{$default})) {
							        # grab the selected options
							        my @selected_values  = (ref($inputs{$default})=~/ARRAY/) ? 
							                   @{$inputs{$default}}:($inputs{$default}); 
							        foreach my $selected_value (@selected_values) {
										if (defined $labels_key) {
											$text = $inputs{$labels_key}->{$selected_value};
											delete($inputs{$labels_key}->{$selected_value});
										} else {
											$text = $selected_value;
										}
										@values = grep !/$selected_value/, @values; 
										$selected_option .= $html2->option({-selected=>1, -text=>$text, -value=>$selected_value})."\n";
									}
							   } 
							   %inputs = %{removeParam('default',\%inputs)};
							   ## match labels to values
							   my @text=();
							   if (defined($labels_key) and $labels_key) {
								   my %labels= %{$inputs{$labels_key}}; 
								   delete($inputs{$labels_key}) if exists $inputs{$labels_key};
								   @text  = map {$labels{$_}} @values;
							   } else { # no labels
							   	   @text = @values;
							   }
							   delete($inputs{$values_key});
							   # end match labels to values
							   $prolog = $html2->select_start(\%inputs).$selected_option;
							   $postlog = $html2->select_end();
							   $func = 'option_group';
							   @inputs =({-value=>\@values, -text=>\@text });
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
	if ( $prolog or $postlog ) {
		$result =~ s/^\n//;   # get rid of extra return??
		$result = "$prolog$result$postlog" ;
	}
	return $result;
}
sub normalizeName {
	my $name = shift;  #name to find
	my @inputs  = @_;   #inputs 
	my ($key) = grep /-?$name/, @inputs;
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