################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/

# $CVSHeader: webwork-modperl/lib/WeBWorK/CGIeasytags.pm,v 1.1 2006/07/15 16:35:32 gage Exp $
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

=head1 NAME

WeBWorK::CGI - Front end for HTML::EasyTags which imitates some of CGI.pm's constructions

=cut
=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	I<HTML::EasyTags>

=head1 SYNOPSIS

	CGI::tag({name=>value pairs});
	CGI::tag({name=>value pairs},text1, text2,); # string arguments are concatenated for text
	CGI::tag({},text1, text2,);                  # string arguments are concatenated for text
	CGI::tag([ text1, text2 });                  # tag is applied iteratively to array elements
	CGI::tag({name=>value pairs},[ text1, text2 });    # tag , with parameters 
	                                             #in hash are applied iteratively to array elements
	CGI::tag("attribute1", "attribute2");        # same as CGI::tag(name=>"attribute1", value=>"attribute2");
	                                             # the key names  depend on the tag
	CGI::tag(name1=>value1,...nameN=>valueN);    # same as CGI::tag({name1=>value1,...nameN=>valueN});

There are CGI like versions of the various input HTML tags

	CGI::textfield
	CGI::hidden
	CGI::submit
	CGI::password_field
	CGI::scrolling_list
	CGI::popup_menu
	
See HTML::EasyTags for other syntax
	
=head1 DESCRIPTION

=cut

######################################################################


use HTML::EasyTags;
use WeBWorK::Utils;
use strict;
package CGI; # (override standard CGI namespace!!)

#@CGI::ISA = qw(HTML::EasyTags);
our $html2 = HTML::EasyTags->new();
our $AUTOLOAD;

# There are six  goals:  
#     To provide CGI like support of scrolling_list, popup_menu.
#     To allow implied iteration of tags when first or second element is a hash.
#     To allow tagname switching: principally for various versions of input.
#     To accomodate label switching such as default to value in CGI::hidden.
#     To allow concatenation of inputs in limited cases, particularly if first element is a hash.
#     To allow a small number of unnamed arguments for a limited number of tags

#From HTML::EasyTags
####################################################################
# #  _params_to_hash( ARGS )
# #  Input arguments, 
# #  provided in ARGS, are usually in named format, and the names can be any case or 
# #  optionally begin with a "-".  

# #  We know that ARGS is named format if the first 
# #  element is a hash ref or there is more than one element; 
# #  If the first ARGS element is a hash and there are more elements, then the 
# #  second one is implicitely named 'text' and inserted into the returned hash.
####### We modify this in two ways: 
####### (1) if the second argumment is an ARRAY we iterate and
####### (2) otherwise we concatenate the 2nd and remaining arguments labeling these as text.

# #  ARGS is not in named 
# #  format if there is only one element and it is not a hash ref.  
# #  This single element is implicitely named 'text' and returned that way.

our $LEGAL_KEYS ='name|values?|id|size|defaults?|checked|labels?|selected|type|text|linebreak|override'.
                 '|multiple|rows|cols|align|valign|class|onchange|onclick'.
                 '|action|method|style|disabled|colspan|width|height|onDblClick|enctype';
#print 'test', join("|", grep !/^-?($LEGAL_KEYS)$/, qw(name3 bar) );
sub AUTOLOAD {
	my $func = $AUTOLOAD;
	$func =~ s/^CGI:://;
	my $result;
	my @inputs = @_;

	# normalize @inputs;
	if ( ref($inputs[0]) =~/HASH/ ) { 
	    # attributes or all parameters have been defined
	    # CGI::tag({hash of arguments})
	    # CGI::tag({hash of arguments}, text1, text2, text3 );
	    # CGI::tag({}, text1, text2, text3);
	    # CGI::tag({},[ HTML to be iteratively placed tag ] ):
	    # 1. all arguments have been defined in the initial tag, 
	    # 2. remaining string arguments are concatenated together to form an implied text tag
	    #    which is wrapped by the paired HTML tag.
	    # 3. an array reference in the second position signals that the tag
	    #    is to be applied iteratively to the elements in the array using
	    #    the arguments in the initial hash.
	  
	    # get a local copy of the attributes hash -- other wise we'll modify the original
	        my %attributes = %{shift @inputs};
			my $attributes = \%attributes;
			if ( @inputs == 0 ) {
			 # do nothing -- verything was defined in the attributes
			} elsif (ref($inputs[0]) =~/ARRAY/) { # implied group  is this case legal?
			   #print "array is here";
			   warn "can't follow an ARRAY by other inputs $func @inputs " if @inputs >1;
			} else { #combine remaining inputs for text field, it's safe in this case
			   my $text = join("", @inputs);
			   @inputs = ($text);
			}
			unshift @inputs, $attributes;
			#print "next inputs @inputs";
	} elsif (ref($inputs[0]) =~/ARRAY/) { 
	     # implied iteration group no other terms allowed
	     # CGI::tag( HASH, ARRAY);
	        $func = $func.'_group';
			@inputs = ($inputs[0]);
			warn "can't follow an unnamed ARRAY by other inputs $func  @inputs " if @inputs >1;
			# this is ready for direct processing by HTML::EasyTags
	} elsif (@inputs <=1 ) {
	    # CGI::tag(string entry); is
	    # the argument is the text argument which will be wrapped by the tag
	    # No concatenation takes place
		# do nothing -- this is something like CGI::p();
		# this is ready for EasyTag
	} else  {  # try to create name value pairs
#	    print "handle unnamed inputs @inputs\n";
		if (@inputs%2==0) {
		# CGI::tag( "string1", "string2");
		# treated as CGI::tag( name=>"string1", value=>"string2");
		# CGI::tag(name1 => value1, ...nameN=>valueN);
		# treated as CGI::tag({ name1 => value1, ...nameN=>valueN} );
        # form a hash of name value pairs from the entries
        # entries of names without values, e.g.   checked   are not allowed
        # use  checked=>1 instead
		    my %inputs;
			my %check_keys = @inputs;
			# check that keys make sense
			my @bad_keys = grep !/^-?($LEGAL_KEYS)$/i, keys %check_keys;

			if (@bad_keys and @inputs<=4) { 
			    # assume name/value pairs if there are more than 4 inputs
			    # even if we don't recognize the keys
			    # for debugging only
#				warn "the following keys don't make sense |", join(" ", @bad_keys), "|  Use name value pairs when possible. $func inputs: ", join(" ", %inputs);
				# handle the case where there are only two value inputs
				$inputs{name}  = $inputs[0];
				$inputs{value} = $inputs[1];
				if (@inputs > 2 ) {
					my ($pkg, $file, $line) = caller();
					warn "Perhaps you have used an illegal key? Please use named parameters for more than two entries.";
					warn "$func(".join(' ', @inputs). ") at line:$line package:$pkg file:$file";
					warn "You can use the construction $func({ ...inputs...}) to prevent checking of key names.";
				}
				@inputs = (\%inputs);
			} else {
			    # there are more than 4 inputs or, there are less than 4 but all of the key names are recognized
			    # we assume that the entries are all name/value pairs.
			    my %inputs = @inputs;
				@inputs = (\%inputs); 
			}
		} elsif( @inputs >2) {  # error message. can't form name value pairs from these arguments
			my ($pkg, $file, $line) = caller();
			warn "Please use named parameters for more than two entries. $func(",join(' ', @inputs), 
			") at line:$line package:$pkg file:$file ";
			warn " You can force concatenation of text entries by using an initial {}";
		}
	}
#   print "\ninputs is ", join(" ", @inputs), "\n",join(" ", %{$inputs[0]}),"\n";
	my $attributes = undef;
	if ( ref($inputs[0]) =~/HASH/ ) {
		$attributes =  shift @inputs;
	} else {
		$attributes = undef;
	}
	# check 
#	print "\n\n###$func inputs:|",  join(" ",@inputs), "| attributes: ",  (defined $attributes) ? join(" ", %{$attributes}):(), "\n";

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
		unless (defined $attributes) { # name and value are required entries
			my ($pkg, $file, $line) = caller();
			warn "Please used named parameters $type(",join(' ', @inputs), 
			") at line:$line package:$pkg file:$file ";		
		}
		$attributes->{-type} = $type;
		my $labels_key = normalizeName('labels?',keys %{$attributes});
		my $name_key  = normalizeName('name',keys %{$attributes});
		my $value_key  = normalizeName('values?',keys %{$attributes});
		my $label = ($labels_key)?$attributes->{$labels_key}:'';
		delete($attributes->{$labels_key}) if defined $labels_key and exists($attributes->{$labels_key});
		# rescue case where value is not given.
		$attributes->{-value} = $attributes->{$name_key} unless $attributes->{$value_key};  
		
		unless ( ($attributes->{-name} and $attributes->{-value}) or ($attributes->{name} and $attributes->{value}) ) {
			my ($pkg, $file, $line) = caller();
			warn "name and value parameters are required $type(",join(' ', @inputs), 
			") at line:$line package:$pkg file:$file ";
		}
		@inputs = ();
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
		unless (defined $attributes) { # name and value are required entries
			my ($pkg, $file, $line) = caller();
			warn "Please use named parameters for more than two entries. $type(",join(' ', @inputs), 
			") at line:$line package:$pkg file:$file ";		
		}
		$attributes->{type} = $type;
		@inputs = ();
		last CASES;
	};

	$func =~/^submit$/	   && do {
		my $type = $func;
		$func ='input'; 
		unless (defined $attributes) { # name and value are required entries
			my ($pkg, $file, $line) = caller();
			warn "Please use named parameters for more than two entries. $type(",join(' ', @inputs), 
			") at line:$line package:$pkg file:$file ";		
		}
		$attributes->{-type} = $type;
		my ($labels_key) = normalizeName('labels?',keys %{$attributes});
		$attributes->{-value}= $attributes->{$labels_key} if defined $labels_key and exists $attributes->{$labels_key}; # use value for name
		delete($attributes->{$labels_key}) if defined $labels_key and exists $attributes->{$labels_key};
		@inputs = ();
		last CASES;
	};
	$func =~ /^hidden$/ && do  { # handles name value pairs
		my $type = $func;
		$func ='input'; 
		unless (defined $attributes) { # name and value are required entries
			my ($pkg, $file, $line) = caller();
			warn "Please use named parameters for more than two entries. $type(",join(' ', @inputs), 
			") at line:$line package:$pkg file:$file ";		
		}
		$attributes->{-type} = $type;
		my $default_label = normalizeName('defaults?',keys %{$attributes});
		$attributes->{-value} = $attributes->{$default_label} if defined $default_label;
		$attributes = removeParam($default_label, $attributes);
		unless ( (exists($attributes->{-name}) and exists($attributes->{-value})) 
		 or (exists($attributes->{name}) and exists($attributes->{value})) ) {
			my ($pkg, $file, $line) = caller();
			warn "name and value parameters are required $type(",join(' ', %$attributes), 
			") at line:$line package:$pkg file:$file ";
		}
		@inputs = ( );
	};
	$func =~/^radio$/		&& do {
		my $type = $func;
		$func ='input'; 
		my %inputs=();
		unless (defined $attributes) { # inputs are un named pairs
			$attributes->{name} = $inputs[0];
			$attributes->{value} = $inputs[1];

		}
		$attributes->{-type} = $type;
		my ($values_key) = normalizeName('values?',keys %{$attributes});
		$attributes->{-value}= $attributes->{$values_key};  # use value for name
		delete($attributes->{$values_key}) if defined $values_key and exists $attributes->{$values_key};
		@inputs = ();
		last CASES;
	};
	$func =~/^textarea$/	&& do {
		my %inputs=();
		unless (defined $attributes) { # name and value are required entries
			my ($pkg, $file, $line) = caller();
			warn "Please use named parameters for more than two entries. $func(",join(' ', @inputs), 
			") at line:$line package:$pkg file:$file ";		
		}
		my $default_label = normalizeName('defaults?',keys %{$attributes});
		$attributes->{-text} = $attributes->{$default_label} if defined $default_label;
		$attributes = removeParam($default_label, $attributes);
		@inputs = ( );
		last CASES;
	};
	$func =~/^(b|i|p|Tr|td|li|table|div|th)$/	&& do { # concatenate inputs
		#print "previous inputs @inputs";
		if ($attributes ) { #
			if (ref($inputs[0]) =~/ARRAY/) { # iterate over this
#			    print "we have an array in the second possition";
				my @values = @{$inputs[0]};
				foreach my $attribute (keys %{$attributes} ){
					 $attributes->{$attribute} = [ map { $attributes->{$attribute} } @values ];
					 #print "$attribute is ", @{$inputs{$attribute}},"\n";
				}
				$attributes->{text} = \@values;
				@inputs = ();
			    $func = $func."_group";
			} else {
			    #print "\nfirst inputs @inputs\n";
			    my $text =  join(" ",@inputs);
				@inputs = ( $text);
				#print "\ninputs @inputs\n";
			}
		} elsif (ref($inputs[0]) =~/ARRAY/ ) {
			# do nothing
			warn "inputs which start with an array reference should have only on element" if @inputs >1;
		} else {
			@inputs = (join("",@inputs));
		}
		last CASES;
	};

			
	$func =~/^radio_group$/ &&do {
		my $type = $func;
		$func ='input_group'; 
		$type =~ s/_group$//;
		unless (defined $attributes) {
				warn "probable error $func @inputs ";
		}
		$attributes->{type}=$type;
		$attributes = removeParam('override',$attributes);
		my $labels_key = normalizeName('labels?',keys %{$attributes});
		my $values_key = normalizeName('values?',keys %{$attributes});
		my $name_key = normalizeName('name', keys %{$attributes});
		my $default_key = normalizeName('defaults?', keys %{$attributes});
		my $linebreak_key = normalizeName('linebreaks?', keys %{$attributes});
		my $ra_value	= $attributes->{$values_key};
		my $rh_labels	= $attributes->{labels_key};
		my @values	  =  @{$attributes->{$values_key}};
		my $ret = (defined($linebreak_key) and defined($attributes->{$linebreak_key}) and $attributes->{$linebreak_key} )?"<br/>":"";
		# deal with the default option
		my $selected_button = '';
		my $text = '';
		my $selected_value = $values[0];
		if (defined($default_key) and $default_key and defined($attributes->{$default_key})) {
		   # grab the selected options
		   $selected_value  = $attributes->{$default_key}; 
		}  
		## match labels to values
		my @text=();
		if (defined($labels_key) and $labels_key) {
		   my %labels= %{$attributes->{$labels_key}}; 
		   delete($attributes->{$labels_key}) if exists $attributes->{$labels_key};
		   @text  = map {( exists($labels{$_}) )? $labels{$_}.$ret: $_.$ret } @values;
		} else { # no labels
		  @text = map {$_ .$ret} @values;
		}
		my @checked = map { $selected_value eq $_ } @values;
		$attributes->{checked} = \@checked;
		$attributes->{-text} = \@text;
		$attributes = removeParam($linebreak_key,$attributes);
		$attributes = removeParam($default_key,$attributes);

		@inputs = ( );
		last CASES;
	}; 
	$func =~/^(popup_menu|scrolling_list)$/   &&do{  
		unless (defined $attributes) {
				warn "probable error $func @inputs ";
		}
		#$attributes = removeParam('override',$attributes);
		my $values_key   = normalizeName('values?',keys %{$attributes}); #get keys
		my $labels_key   = normalizeName('labels?',keys %{$attributes});
		my $default_key  = normalizeName('defaults?', keys %{$attributes});
		warn "values are required ",join(' ',%{$attributes})  unless $values_key;
		my $ra_value	= $attributes->{$values_key};
		my $rh_labels	= $attributes->{$labels_key} if defined $labels_key;
		my @values	  =  eval{ @{$attributes->{$values_key}} }; 
		@values		= grep {defined($_) and $_} @values;
		push @values, " " unless @values;  # add blank if no values are given
		#warn "error in $values_key  ". $attributes->{$values_key},join(' ', @inputs), caller(), $@ if $@;
		
		# deal with the default option
		
		my $selected_option = '';
		my $text = '';
		my %selected_values = ($values[0] => 1);  # select the first value by default
		if (defined($default_key) and $default_key and defined($attributes->{$default_key}) and $attributes->{$default_key}) {
		   # grab the selected options
		   if (ref($attributes->{$default_key})=~/ARRAY/ ) {
			%selected_values = map {$_ => 1 } @{$attributes->{$default_key}};
		   } elsif ($attributes->{$default_key}) {
			%selected_values = ($attributes->{$default_key} => 1);
		   }
		}
		my @selected = map {(exists($selected_values{$_}) )?1 : 0 } @values;
		$attributes = removeParam($default_key,$attributes);
		## match labels to values if labels defined
		my @text=();
		if (defined($labels_key) and $labels_key) { # make sure there are values and labels
		   my %labels= %{$attributes->{$labels_key}}; 
		   delete($attributes->{$labels_key}) if exists $attributes->{$labels_key};
		   @text  = map {( exists($labels{$_}) )? $labels{$_}: $_ } @values;
		} else { # no labels
		   @text = @values;
		}
		$attributes = removeParam($labels_key,$attributes);
		$attributes = removeParam($values_key,$attributes);
		# end match labels to values 
		$prolog = $html2->select_start($attributes)."\n".$selected_option;
		$postlog = $html2->select_end();
		$func = 'option_group';
		$attributes = undef;  # don't need to pass these to EasyTags
		@inputs =({-value=>\@values, -text=>\@text, -selected =>\@selected });
		last CASES;
	};
} # end CASES block
	# restore attributes
	unshift @inputs,$attributes if defined $attributes;
#	print "\n\nto EasyTags $func @inputs ";
    # check attributes
    { # warning block
    	local $SIG{__WARN__} =sub{die $_[0]};
    	$result = eval {  $html2->$func(@inputs) };
    	warn "problem evaluating $func ", join(" ",@inputs), " from ", caller(), $@, WeBWorK::Utils::pretty_print_rh({\@inputs}) if $@;
    }
	
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