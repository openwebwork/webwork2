#!/usr/bin/perl -w
#New highly object-oriented list construct
#This List.pm is the super class for all types of lists
#As of 6/5/2000 the three list sub-classes are Match, Select, Multiple
#RDV

=head1 NAME

	List.pm  -- super-class for all list structures

=head1 SYNOPSIS

=pod

List.pm is not intended to be used as a stand alone object.

It is a super-class designed to be inherited by sub-classes that, 
through small changes, can be used for a variety of different 
questions that involve some sort of list of questions and/or answers.

List.pm has been used to construct Match.pm, Select.pm, and Multiple.pm.

These three classes are objects that can be used to create the 
following question types:

B<Matching list:>
Given a list of questions and answers, match the correct answers to the 
questions. Some answers may be used more than once and some may not be used at 
all. The order of the answers is usually random but some answers can be 
appended to the end in a set order (i.e. 'None of the above'). Answers are 
given corresponding letters as shortcuts to typing in the full answer. (i.e. 
the answer to #1 is A).

B<Select list:>	
Given a list of questions and (usually) implied answers, give the correct 
answer to each question. This is intended mainly for true/false questions or 
other types of questions where the answers are short and can therefore be typed 
in by the user easily.  If a select list is desired but the answers are too long 
to really type in, a popup-list of the answers can be used.	

B<Multiple choice:> 
Given a single question and a list of answers, select the single correct answer. 
This structure creates a standard multiple choice question as would be seen on a 
standardize test.  Extra answers are entered along with the question in a simple 
format and (as with Match.pm), if necessary, can be appended in order at the end 
(i.e. 'None of the above')

=for html
<P>See <a href="Match">Match.pm</a>, <a href="Select">Select.pm</a>, <a href="Multiple">Multiple.pm</a>, and <a href="PGchoicemacros">PGchoicemacros.pl</a>


=head1 DESCRIPTION

=head2 Variables and methods available to sub-classes 

=head3 Variables

	questions				# array of questions as entered using qa()
	answers					# array of answers as entered using qa()
	extras					# array of extras as entered using extra()
	
	selected_q				# randomly selected subset of "questions"
	selected_a				# the answers for the selected questions
	selected_e				# randomly selected subset of "extras"
	
	ans_rule_len			# determines the length of the answer blanks 
							# default is 4
	
	slice					# index used to select specific questions
	shuffle					# permutation array which can be applied to slice 
							# to shuffle the answers
	
	inverted_shuffle		# the inverse permutation array
	
	rf_print_q				# reference to any subroutine which should
							# take ($self, @questions) as parameters and
							# output the questions in a formatted string.
							# If you want to change the way questions are
							# printed, write your own print method and set
							# this equal to a reference to to that method
							# (i.e. $sl->rf_print_q = ~~&printing_routine_q)
	
	rf_print_a				# reference to any subroutine which should
							# take ($self, @answers) as parameters and
							# output the answers in a formatted string.
							# If you want to change the way answers are
							# printed, write your own print method and set
							# this equal to a reference to to that method
							# (i.e. $sl->rf_print_a = ~~&printing_routine_a)
							
	ra_pop_up_list		    # Field used in sub classes that use pop_up_list_print_q
							# to format the questions. (Placing a pop_up_list next to
							# each question instead of an answer blank.
							# It is initialized to
							# => [no_answer =>'  ?', T => 'True', F => 'False']
							
	ans_rule_len			# field which can be used in the question printing routines
							# to determine the length of the answer blanks before the questions.

=head3 Methods

	qa( array )				# accepts an array of strings which can be used 
							# for questions and answers

	extra( array )			# accepts an array of strings which can be used 
							# as extra answers
		
	print_q					# yields a formatted string of question to be 
							# matched with answer blanks
	print_a					# yields a formatted string of answers
		
	choose([3, 4], 1)		# chooses questions indexed 3 and 4 and one other 
							# randomly
	choose_extra([3, 4], 1) # choooses extra answers indexed 3 and 4 and one 
							# other
	makeLast( array )		# accepts an array of strings (like qa) which will 
							# be forced to the end of the list of answers.
		
	ra_correct_ans			# outputs a reference to the array of correct answers
	correct_ans				# outputs a concatenated string of correct answers (only for Multiple)

=head2 Usage

	None -- see SYNOPSIS above


=cut

BEGIN {
	be_strict();
}
#use strict;

package List;



@List::ISA = qw( Exporter );

my %fields = (
			questions			=>	undef,
			answers				=>	undef,
			extras				=>	undef,
			selected_q			=>	undef,
			selected_a			=>	undef,
			selected_e			=>	undef,
			ans_rule_len		=>	undef,
			ra_pop_up_list		=>	undef,
			rf_print_q			=>	undef,
			rf_print_a			=>	undef,
			slice				=>	undef,
			shuffle				=>	undef,
			inverted_shuffle	=>	undef,
			rand_gen			=>	undef,
);

#used to initialize variables and create an instance of the class
sub new {
	my $class = shift;
	my $seed  = shift;
	
	warn "List requires a random number: new List(random(1,2000,1)" unless defined $seed;
	
	my $self = { 	_permitted => \%fields,
	
				questions			=> [],
				answers				=> [],
				extras				=> [],
				selected_q			=> [],
				selected_a			=> [],
				selected_e			=> [],
				ans_rule_len		=>  4,
				ra_pop_up_list		=> [no_answer =>'  ?', T => 'True', F => 'False'],
				rf_print_q			=>  0,
				rf_print_a			=>  0,
				slice				=> [],
				shuffle				=> [],
				inverted_shuffle	=> [],
				rand_gen			=> new PGrandom,
	};
	
	bless $self, $class;
	
	$self->{rand_gen}->srand($seed);
	
	$self->{rf_print_q} = shift;
	$self->{rf_print_a} = shift;
	
	return $self;
}

# AUTOLOAD allows variables to be set and accessed like methods 
# returning the value of the variable
sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) or die "$self is not an object";
	
	# $AUTOLOAD is sent in by Perl and is the full name of the object (i.e. main::blah::blah_more)
	my $name = $List::AUTOLOAD;
	$name =~ s/.*://; #strips fully-qualified portion
	
	unless ( exists $self->{'_permitted'}->{$name} ) { 
		die "Can't find '$name' field in object of class '$type'"; 
	}
	
	if (@_) {
		return $self->{$name} = shift; #set the variable to the first parameter 
	} else {
		return $self->{$name}; #if no parameters just return the value
	}
}

sub DESTROY {
	# doing nothing about destruction, hope that isn't dangerous
}


# *** Utility methods ***


#choose k random numbers out of n
sub NchooseK {
	my $self = shift;
	my ($n, $k) = @_;

	die "method NchooseK: n = $n cannot be less than k=$k\n
	     You probably did a 'choose($k)' with only $n questions!" if $k > $n;
		
	my @array = 0..($n-1);
	my @out = ();
	
	while (@out < $k) {
		push(@out, splice(@array, $self->{rand_gen}->random(0, $#array, 1), 1) );
	}
	
	return @out;
}

#return an array of random numbers
sub shuffle {
	my $self = shift;
	my $i = @_;
	my @out = $self->NchooseK($i, $i);
	
	return @out;
}


# *** Utility subroutines ***


#swap subscripts with their respective values
sub invert {
	my @array = @_;
	my @out = ();
	
	for (my $i=0; $i<@array; $i++) {
		$out[$array[$i]] = $i;
	}

	return @out;
}

#slice of the alphabet
sub ALPHABET {
	return ('A'..'ZZ')[@_];
}

#given a universe of subscripts and a subset of the universe, 
#return the complement of that set in the universe
sub complement {
	my $ra_univ = shift;
	my $ra_set = shift;
	my @univ = @$ra_univ;
	my @set = @$ra_set;
	
	my %set = ();
	
	foreach my $i (@set) {
		$set{$i} = 1;
	}
	
	my @out = ();
	
	foreach my $i (@univ) {
		push(@out, $i) unless exists( $set{$i} );
	}
	
	return @out;
}



# *** Input and Output subroutines ***
#From here down are the ones that should be overloaded by sub-classes

#Input answers
#defaults to inputting 'question', 'answer', 'question', etc (should be overloaded for other types of questions)
sub qa {
	my $self = shift;
	my @questANDanswer = @_;
	
	while (@questANDanswer) {
		push (@{ $self->{questions} }, shift(@questANDanswer) );
		push (@{ $self->{answers} },   shift(@questANDanswer) );
	}
}
	
#Input extra answers
sub extra {
	my $self = shift;
	push(@{ $self->{extras} }, @_); #pushing allows multiple calls without overwriting old "extras"
}


#Output questions
#Doesn't do actual output, refers to method given in call to 'new' (rf_print_q)
sub print_q {
	my $self = shift;
	
	&{ $self->{rf_print_q} }( $self, @{ $self->{selected_q} } );
}

#Output answers
#Doesn't do actual output, refers to method given in call to 'new' (rf_print_a)
sub print_a {
	my $self = shift;
	
	&{ $self->{rf_print_a} }( $self, @{ $self->{selected_a} } );
}

#return array of answers to be checked against the students answers
#defaults to returning the actual selected answers (should be overloaded for other types of answers)
sub ra_correct_ans {
	my $self = shift;
	return $self->{selected_a};
}

#Match and Select return references to arrays while Multiple justs returns a string
#so Match and Select use ra_correct_ans while Multiple uses correct_ans
sub correct_ans {
	warn "Match and/or Select do not use correct_ans.\nYou should use ra_correct_ans instead.";
}

# *** Question and Answer Manipulation Subroutines ***


#calls methods that deal with list specific methods of picking random questions and answers
#mainly exists for backward compatibility and to hide some of the activity from the naive user
sub choose {
	my $self = shift;
	my @input = @_;
	
	$self->getRandoms(scalar(@{$self->{questions}}), @input);	#pick random numbers
	$self->selectQA();			#select questions and answers
	$self->dumpExtra();			#dump extra answers into "extras"
	$self->condense();			#eliminate duplicate answers"
}
	
#randomly inserts the selected extra answers into selected_a and 
#updates inverted_shuffle accordingly
sub choose_extra {
	my $self = shift;
	my @input = @_;
	
	$self->getRandoms(scalar(@{ $self->{extras} }), @input);
	$self->{selected_e} = [ @{ $self->{extras} }[ @{ $self->{slice} }[ @{ $self->{shuffle} } ] ] ];	
	my $length = 0;
	
	my $random = 0;
	foreach my $extra_ans ( invert(@{ $self->{shuffle} }) ) {
		#warn "Selected Answers: @{ $self->{selected_a} }<BR>
		#      Inverted Shuffle: @{ $self->{inverted_shuffle} }<BR>
		#      Random: $random";	
		$random = $self->{rand_gen}->random(0, scalar(@{ $self->{selected_a} }), 1);
		for (my $pos = 0; $pos < @{ $self->{inverted_shuffle} }; $pos++) {
			@{ $self->{inverted_shuffle} }[$pos]++ unless @{ $self->{inverted_shuffle} }[$pos] < $random;
		}
		my @temp = ( @{ $self->{selected_a} }[0..$random-1], @{ $self->{selected_e} }[$extra_ans], @{$self->{selected_a} }[$random..$#{ $self->{selected_a} } ] );
		@{ $self->{selected_a} } = @temp;
	}
}

#create random @slice and @shuffle to randomize questions and answers
sub getRandoms {
	my $self = shift;
	my $N = shift;
	my @input = @_;
	my $K = 0;
	
	my @fixed_choices = (); # questions forced by the user
	foreach my $i (@input) { #input is of the form ([3, 5, 6], 3)
		if (ref($i) eq 'ARRAY') {
			push(@fixed_choices, @{$i});
		} else {
			$K += $i;
		}
	}
	
#	my $N = @{ $self->{questions} };
	my @remaining = complement( [0..$N-1], [@fixed_choices] );
	
	my @slice = @fixed_choices;
	push (@slice, @remaining[ $self->NchooseK(scalar(@remaining), $K) ] ); #slice of remaing choices
	@slice = @slice[ $self->NchooseK( scalar(@slice), scalar(@slice) ) ]; #randomize the slice (the questions)
	
	#shuffle will be used to randomize the answers a second time (so they don't coincide with the questions)
	my @shuffle = $self->NchooseK( scalar(@slice), scalar(@slice) );
	
	$self->{slice} = \@slice; #keep track of the slice and shuffle
	$self->{shuffle} = \@shuffle;	
}

#select questions and answers according to slice and shuffle
sub selectQA {
	my $self = shift;
	
	$self->{selected_q} = [ @{ $self->{questions} }[ @{ $self->{slice} } ] ];
	$self->{selected_a} = [ @{ $self->{answers} }[@{ $self->{slice} }[@{ $self->{shuffle} } ] ] ];
	$self->{inverted_shuffle} = [ invert(@{ $self->{shuffle} }) ];
}

#dump unused answers into list of extra answers
sub dumpExtra {
	my $self = shift;
	my @more_extras = complement([0..scalar(@{ $self->{answers} })-1], [@{ $self->{slice} }]);
	push( @{ $self->{extras} }, @{ $self->{answers} }[@more_extras] );
}

#Allows answers to be added to the end of the selected answers
#This can be used to force answers like "None of the above" and/or "All of the above" to still occur at the 
#end of the list instead of being randomized like the rest of the answers
sub makeLast {
	my $self = shift;
	my @input = @_;
	
	push(@{ $self->{selected_a} }, @input);
	$self->condense(); 	#make sure that the user has not accidentally forced a duplicate answer
				#note: condense was changed to eliminate the first occurence of a duplicate 
				#instead of the last occurence so that it could be used in this case and
				#would not negate the fact that one of the answers needs to be at the end
}

#Eliminates duplicates answers and rearranges inverted_shuffle so that all questions with the same answer 
#point to one and only one copy of that answer
sub old_condense {
	my $self = shift;
	for (my $outer = 0; $outer < @{ $self->{selected_a} }; $outer++) {
		for (my $inner = $outer+1; $inner < @{ $self->{selected_a} }; $inner++) {
			if (@{ $self->{selected_a} }[$outer] eq @{ $self->{selected_a} }[$inner]) {
				#then delete the duplicate answer at subscript $outer
				@{ $self->{selected_a} } = ( @{ $self->{selected_a} }[0..$outer-1], @{ $self->{selected_a} }[$outer+1..$#{ $self->{selected_a} }] );
				
				#the values of inverted_shuffle point to the position elements in selected_a
				#so in order to delete something from selected_a, each element with a position
				#greater than $outer must have its position be decremented by one
				$inner--; #$inner must be greater than outer so decrement $inner first
				for (my $pos = 0; $pos < @{ $self->{inverted_shuffle} }; $pos++) {
					if ( @{ $self->{inverted_shuffle} }[$pos] == $outer ) {
						@{ $self->{inverted_shuffle} }[$pos] = $inner;
					} elsif ( @{ $self->{inverted_shuffle} }[$pos] > $outer ) {
						@{ $self->{inverted_shuffle} }[$pos]--;
					}
				}
				#we just changed a bunch of pointers so we need to go back over the same answers again 
				#(so we decrement $inner (which we already did) and $outer to counter-act the for loop))
				#this could probably be done slightly less hackish with while loops instead of for loops
				#$outer--;
			}
		}
	}
}

#re-written RDV 10/4/2000
#Eliminates duplicate answers and rearranges inverted_shuffle so that all questions with the same answer
#point to one and only one copy of that answer
sub condense {
	my $self = shift;
	my ($outer, $inner) = (0, 0);
	my $repeat = 0;

	while ($outer < @{ $self->{selected_a} }) {
		$inner = $outer + 1;
		$repeat = 0; #loop again if we find a match
		while ($inner < @{ $self->{selected_a}}) {
			$repeat = 0; #loop again if we find a match
			if (@{ $self->{selected_a} }[$outer] eq @{$self->{selected_a} }[$inner]) {

				#then delete the duplicate answer at subscript $outer by combining everything before and after it
				@{ $self->{selected_a} } = ( @{ $self->{selected_a} }[0..$outer-1], @{ $self->{selected_a} }[$outer+1..$#{ $self->{selected_a} }] );

				#the values of inverted_shuffle to point the _subscript_ of elements in selected_a
				#so in order to delete something from selected_a, each element with a subscript
				#greater than $outer (where the deletion occurred) must have its position decremented by one
				#This also means we need to "slide" $inner down so that it points to the new position
				#of the duplicate answer
				$inner--;

				for (my $pos = 0; $pos < @{ $self->{inverted_shuffle} }; $pos++) {
					if ( @{ $self->{inverted_shuffle} }[$pos] == $outer) {
						@{ $self->{inverted_shuffle} }[$pos] = $inner;
					} elsif ( @{ $self->{inverted_shuffle} }[$pos] > $outer ) {
						@{ $self->{inverted_shuffle} }[$pos]--;
					}
				}

				#because we just changed the element that $outer points to
				#we need to run throught the loop to make sure that the new value at $outer has
				#no duplicates as well
				#This means that we don't want to increment either counter (and we need to reset $inner)
				$repeat = 1;
				$inner = $outer + 1; 
			}
			$inner++ unless $repeat;
		}
		$outer++ unless $repeat;
	}
}


# This condense didn't repeat the inner loop after deleting the element at $outer (so that $outer now pointed to a new value)
# so if the new value at $outer also had a duplicate then it was just skipped.
# This shouldn't work but i'll leave it in for a while just in case

##Eliminates duplicates answers and rearranges inverted_shuffle so that all questions with the same answer
##point to one and only one copy of that answer
#sub old_condense {       
#        my $self = shift;
#        for (my $outer = 0; $outer < @{ $self->{selected_a} }; $outer++) {
#                for (my $inner = $outer+1; $inner < @{ $self->{selected_a} }; $inner++) {
#                        if (@{ $self->{selected_a} }[$outer] eq @{ $self->{selected_a} }[$inner]) {
#                                #then delete the duplicate answer at subscript $outer
#                                @{ $self->{selected_a} } = ( @{ $self->{selected_a} }[0..$outer-1], @{ $self->{selected_a} }[$outer
#
#                                #the values of inverted_shuffle point to the position elements in selected_a
#                                #so in order to delete something from selected_a, each element with a position
#                                #greater than $outer must have its position be decremented by one
#                                $inner--; #$inner must be greater than outer so decrement $inner first
#                                for (my $pos = 0; $pos < @{ $self->{inverted_shuffle} }; $pos++) {
#                                        if ( @{ $self->{inverted_shuffle} }[$pos] == $outer ) {
#                                                @{ $self->{inverted_shuffle} }[$pos] = $inner;
#                                        } elsif ( @{ $self->{inverted_shuffle} }[$pos] > $outer ) {
#                                                @{ $self->{inverted_shuffle} }[$pos]--;
#                                        }
#                                }
#                        }
#                }
#        }
#}
sub pretty_print {
    my $r_input = shift;
    my $out = '';
    if ( not ref($r_input) ) {
    	$out = $r_input;    # not a reference
    } elsif ("$r_input" =~/hash/i ) {  # this will pick up objects whose '$self' is hash and so works better than ref($r_iput).
	    local($^W) = 0;
		$out .= "$r_input " ."<TABLE border = \"2\" cellpadding = \"3\" BGCOLOR = \"#FFFFFF\">";
		foreach my $key (sort keys %$r_input ) {
			$out .= "<tr><TD> $key</TD><TD> =&gt; </td><td>".pretty_print($r_input->{$key}) . "</td></tr>";
		}
		$out .="</table>";
	} elsif (ref($r_input) eq 'ARRAY' ) {
		my @array = @$r_input;
		$out .= "( " ;
		while (@array) {
			$out .= pretty_print(shift @array) . " , ";
		}
		$out .= " )"; 
	} elsif (ref($r_input) eq 'CODE') {
		$out = "$r_input";
# 	} elsif (ref($r_input) =~/list/i  or ref($r_input) =~/match/i or ref($r_input) =~/multiple/i) {
# 		local($^W) = 0;
# 		$out .= ref($r_input) . " <BR>" ."<TABLE BGCOLOR = \"#FFFFFF\">";
# 		foreach my $key (sort keys %$r_input ) {
# 			$out .= "<tr><TD> $key</TD><TD> =&gt; </td><td>".pretty_print($r_input->{$key}) . "</td></tr>";
# 		}
# 		$out .="</table>";
	} else {
		$out = $r_input;
	}
		$out;
}

1;
