################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/

# $CVSHeader: webwork2/lib/WeBWorK/CGI.pm,v 1.20 2006/07/13 19:38:19 gage Exp $
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
	# normalize @inputs;
	if ( ref($inputs[0]) =~/HASH/ ) {  #attributes or all parameters have been defined
			my $attributes = shift @inputs;
			if ( @inputs == 0 ) {
			 # do nothing -- verything was defined in the attributes
			} elsif (ref($inputs[0]) =~/ARRAY/) { # implied group  is this case legal?
			   $func = $func.'_group';
			   warn "can't follow an ARRAY by other inputs $func @inputs " if @inputs >1;
			} else { #combine remaining inputs for text field
			   my $text = join("", @inputs);
			   $attributes->{text} =$text;
			   @inputs = ();
			}
			@inputs= ($attributes);
	} elsif (ref($inputs[0]) =~/ARRAY/) { # implied group no other terms allowed
			$func = $func.'_group';
			@inputs = ($inputs[0]);
			warn "can't follow an unnamed ARRAY by other inputs $func  @inputs " if @inputs >1;
	} elsif (@inputs <=1 ) {
		# do nothing -- this is something like CGI::p();
	} elsif (@inputs ==2) { # could be two values or a name value pair
		if ($inputs[0] =~ /^-?(name|value)$/ ) {  # it's a name value pair;
			my %inputs = @inputs;
			@inputs = (\%inputs); # everything is packaged
		} else {
#		    print "\n#########two values case $func @inputs##########";  # this is for debugging it's actually ok
			# this has to be handled individually for each value of $func
		}
	} elsif (grep /^-?(name|value)$/ , @inputs ) {  # -name or -value appears
		if (@inputs%2 ==1 ) {
			warn "CGI call with named parameters  has an odd number of inputs $func, @inputs ";
		} else { 
			my %inputs = @inputs;
			@inputs = (\%inputs);
		}
	} else {
		# pass inputs directly to EasyTags
	}
	# check 
#	print "\n\n$func inputs:",  join(" ",@inputs), " ",  (ref($inputs[0]) =~/HASH/)?join(" ", %{$inputs[0]}):'', "\n";

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
		my %inputs=();
		if (ref($inputs[0]) =~/HASH/ ) { #
			%inputs = %{$inputs[0]};
		} else {
			$inputs{name} = $inputs[0];
			$inputs{value} = $inputs[1];
		}
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
	$func =~/^(textfield|password_field)$/	&& do {
		my $type = 'text';
		$func ='input';
		my %inputs=();
		if (ref($inputs[0]) =~/HASH/ ) { #
			%inputs = %{$inputs[0]};
		} else {
			$inputs{name} = $inputs[0];
			$inputs{value} = $inputs[1];
		}
		$inputs{type} = $type;
		last CASES;
	};
	$func =~/^textarea$/	&& do {
		my %inputs=();
		if (ref($inputs[0]) =~/HASH/ ) { #
			%inputs = %{$inputs[0]};
		} else {
			$inputs{name} = $inputs[0];
			$inputs{value} = $inputs[1];
		}
		my $default_label = normalizeName('defaults?',keys %inputs);
		$inputs{-text} = $inputs{$default_label} if defined $default_label;
		%inputs = %{removeParam($default_label, \%inputs)};
		@inputs = (\%inputs );
		last CASES;
	};
	$func =~/^submit$/	   && do {
		my $type = $func;
		$func ='input'; 
		my %inputs=();
		if (ref($inputs[0]) =~/HASH/ ) { #
			%inputs = %{$inputs[0]};
		} else {
			$inputs{name} = $inputs[0];
			$inputs{value} = $inputs[1];
		}
		$inputs{-type} = $type;
		my ($labels_key) = normalizeName('labels?',keys %inputs);
		$inputs{-value}= $inputs{$labels_key} if defined $labels_key and exists $inputs{$labels_key}; # use value for name
		delete($inputs{$labels_key}) if defined $labels_key and exists $inputs{$labels_key};
		@inputs = (\%inputs);
		last CASES;
	};
	$func =~/^radio$/		&& do {
		my $type = $func;
		$func ='input'; 
		my %inputs=();
		if (ref($inputs[0]) =~/HASH/ ) { #
			%inputs = %{$inputs[0]};
		} else {
			$inputs{name} = $inputs[0];
			$inputs{value} = $inputs[1];
		}
		$inputs{-type} = $type;
		my ($values_key) = normalizeName('values?',keys %inputs);
		$inputs{-value}= $inputs{$values_key};  # use value for name
		delete($inputs{$values_key}) if defined $values_key and exists $inputs{$values_key};
		@inputs = (\%inputs);
		last CASES;
	};
	$func =~/^(p|Tr|td|li|table|div|th)$/	&& do { # concatenate inputs
		my %inputs=();
		if (ref($inputs[0]) =~/HASH/ ) { #
			%inputs = %{$inputs[0]};
		} else {
			@inputs = (join("",@inputs));
		}	    
		last CASES;
	};
		$func =~ /^hidden/ && do  { # handles name value pairs
		my $type = $func;
		$func ='input'; 
		my %inputs=();
		if (ref($inputs[0]) =~/HASH/ ) { #
			%inputs = %{$inputs[0]};
		} else {
			$inputs{name} = $inputs[0];
			$inputs{value} = $inputs[1];
		}
		$inputs{-type} = $type;
		my $default_label = normalizeName('defaults?',keys %inputs);
		$inputs{-text} = $inputs{$default_label} if defined $default_label;
		%inputs = %{removeParam($default_label, \%inputs)};
		@inputs = (\%inputs );
	};
			
	$func =~/^radio_group$/ &&do {
		my $type = $func;
		$func ='input_group', 
		my %inputs=();
		if (ref($inputs[0]) =~/HASH/ ) { #
			%inputs = %{$inputs[0]};
		} else {
				warn "probable error $func @inputs ";
		}
		$inputs{type}=$type;
		%inputs = %{removeParam('override',\%inputs)};
		my $labels_key = normalizeName('labels?',keys %inputs);
		my $values_key = normalizeName('values?',keys %inputs);
		my $name_key = normalizeName('name', keys %inputs);
		my $default_key = normalizeName('defaults?', keys %inputs);
		my $linebreak_key = normalizeName('linebreaks?', keys %inputs);
		my $ra_value	= $inputs{$values_key};
		my $rh_labels	= $inputs{labels_key};
		my @values	  =  @{$inputs{$values_key}};
		my $ret = (defined($linebreak_key) and defined($inputs{$linebreak_key}) and $inputs{$linebreak_key} )?"<br>":'';
		# deal with the default option
		my $selected_button = '';
		my $text = '';
		my $selected_value = $values[0];
		if (defined($default_key) and $default_key and defined($inputs{$default_key})) {
		   # grab the selected options
		   $selected_value  = $inputs{$default_key}; 
		}  
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
		$inputs{-text} = \@text;
		%inputs = %{removeParam($linebreak_key,\%inputs)};
		%inputs = %{removeParam($default_key,\%inputs)};

		@inputs = (\%inputs );
		last CASES;
	}; 
	$func =~/^(popup_menu|scrolling_list)$/   &&do{  
		my %inputs=();
		if (ref($inputs[0]) =~/HASH/ ) { #
			%inputs = %{$inputs[0]};
		} else {
				warn "probable error $func @inputs ";
		}
		%inputs = %{removeParam('override',\%inputs)};
		my $values_key   = normalizeName('values?',keys %inputs); #get keys
		my $labels_key   = normalizeName('labels?',keys %inputs);
		my $default_key  = normalizeName('defaults?', keys %inputs);
		my $ra_value	= $inputs{$values_key};
		my $rh_labels	= $inputs{labels_key};
		my @values	  =  eval{ @{$inputs{$values_key}} }; 
		@values		= grep {defined($_) and $_} @values;
		warn "error in $values_key  $inputs{$values_key}",join(' ', @inputs), caller(), $@ if $@;
		
		# deal with the default option
		
		my $selected_option = '';
		my $text = '';
		my %selected_values = ($values[0] => 1);  # select the first value by default
		if (defined($default_key) and $default_key and defined($inputs{$default_key}) and $inputs{$default_key}) {
		   # grab the selected options
		   if (ref($inputs{$default_key})=~/ARRAY/ ) {
			%selected_values = map {$_ => 1 } @{$inputs{$default_key}};
		   } elsif ($inputs{$default_key}) {
			%selected_values = ($inputs{$default_key} => 1);
		   }
		}
		my @selected = map {(exists($selected_values{$_}) )?1 : 0 } @values;
		%inputs = %{removeParam($default_key,\%inputs)};
		## match labels to values
		my @text=();
		if (defined($labels_key) and $labels_key) {
		   my %labels= %{$inputs{$labels_key}}; 
		   delete($inputs{$labels_key}) if exists $inputs{$labels_key};
		   @text  = map {( exists($labels{$_}) )? $labels{$_}: $_ } @values;
		} else { # no labels
		   @text = @values;
		}
		%inputs = %{removeParam($labels_key,\%inputs)};
		%inputs = %{removeParam($values_key,\%inputs)};
		# end match labels to values 
		$prolog = $html2->select_start(\%inputs)."\n".$selected_option;
		$postlog = $html2->select_end();
		$func = 'option_group';
		@inputs =({-value=>\@values, -text=>\@text, -selected =>\@selected });
		last CASES;
	};
	} # end CASES block

#	print "to EasyTags $func ", join(" ", @inputs);


# 	if (ref($inputs[0])) {  # even number of hash elements
# 		#$result = "OK: $func( @inputs )"; 
# 		$result = eval {  $html2->$func(@inputs) };
# 	} else {
# 		$result = "ERROR: bad  inputs $func(   " .join(" ", @_)." )";
# 	}
    $result = eval {  $html2->$func(@inputs) };
	#$result = eval { use WeBWorK::CGI; $html2->$func(@_) };
	#handle special cases
	if ( $prolog or $postlog ) {
		$result =~ s/\n/\n  /g;   
		$result =~s/^\n//;  # get rid of extra return??
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