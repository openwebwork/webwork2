#!/usr/bin/perl -w
#Construct for matching list.
#Inherits from List.pm
#VS 6/16/2000

=head1 NAME

Match.pm -- sub-class of List that implements a matching list.
	
All items accessed by $out = $ml -> item( $in );

=head1 SYNOPSIS

Match.pm is intended to be used to create standard matching questions in which the the student is given a list of questions and a list of answers and is asked to match the correct answers to those questions. Some answers may be used more than once while others are not used at all. The order of answers is usually random but some answers can be appended to the end of the list in a set order (i.e. 'None of the above', 'All of the above'). Answers are not directly typed in but are given a corresponding letter that is the answer that the system expects. (i.e. 'the answer to #1 is A' not 'the answer to #1 is the square root of 2').  Also, students can be given different sets of questions (to avoid students sharing answers) by entering many questions and then using choose with a number less than the total so that each student only receive a sub-set of those questions.

=head1 DESCRIPTION

=head2 Variables and methods available to Match

=head3 Variables

	questions			# array of questions as entered using qa()
	answers				# array of answers as entered using qa()
	extras				# array of extras as entered using extra()
	
	selected_q			# randomly selected subset of "questions"
	selected_a			# the answers for the selected questions
	selected_e			# randomly selected subset of "extras"
	
	ans_rule_len		# determines the length of the answer blanks 
						# default is 4
	
	slice				# index used to select specific questions
	shuffle				# permutation array which can be applied to slice 
						# to shuffle the answers
	
	inverted_shuffle	# the inverse permutation array
	
	rf_print_q			# reference to any subroutine which should
						# take ($self, @questions) as parameters and
						# output the questions in a formatted string.
						# If you want to change the way questions are
						# printed, write your own print method and set
						# this equal to a reference to to that method
						# (i.e. $sl->rf_print_q(~~&printing_routine_q) )
	
	rf_print_a			# reference to any subroutine which should
						# take ($self, @answers) as parameters and
						# output the answers in a formatted string.
						# If you want to change the way answers are
						# printed, write your own print method and set
						# this equal to a reference to to that method
						# (i.e. $sl->rf_print_a = ~~&printing_routine_a)

=head3 Methods

	qa( array )			# accepts an array of strings which can be used 
						# for questions and answers

	extra( array )		# accepts an array of strings which can be used 
						# as extra answers
		
	print_q				# yields a formatted string of question to be 
						# matched with answer blanks
	print_a				# yields a formatted string of answers
		
	choose([3, 4], 1)	# chooses questions indexed 3 and 4 and one other 
						# randomly
	choose_extra([3, 4], 1) # choooses extra answers indexed 3 and 4 and one 
						# other
	makeLast( array )	# accepts an array of strings (like qa) which will 
						# be forced to the end of the list of answers.
		
	ra_correct_ans		# outputs a reference to the array of correct answers

=head2 Usage

Create a match list using the new_match_list call.

=for html
	<PRE>
	<I>$ml = new_match_list</I></PRE>

Use qa() first to enter questions and answers in alternating pairs.  Note that 
multiple questions can have the same answer.  Any duplicates will be eliminated.

=for html
	<PRE>
	<I>$ml->qa(
		'\( x^2 \)',
		'quadratic',
		'\( x^3 \)',
		'cubic',
		'\( x^3/x \)',
		'quadratic',
		'\( log(x) \)',
		'logarithmic',
		'\( 2^x \)',
		'None of the above',
	);</I></PRE>

After you call qa you can use extra() to enter extra 'answers'.  Again all 
duplicates will be eliminated.

=for html
	<PRE>
	<I>$ml->extra(
		'linear',
		'quartic',
		'really curvy',
	);</I></PRE>

After calling extra you can use choose to select which questions and/or how many each student sees. This helps give students different sub-sets of the full question set so that students cannot cheat as easily. A list of numbers in brackets indicates which questions every student sees (counting starts with 0) and the final number outside of brackets is how many more questions should be randomly picked for each student. Though it is available, the use of selecting specific extra answers is not recommended for novices as the indexing is complicated (see below).

=for html
	<PRE>
	<I>$ml->choose([0], 1);</I></PRE>

would show the first question and a random question while

=for html
	<PRE>
	<I>$ml->choose(3);</I></PRE>

would show 3 random questions (but never call choose more than once).
	
After calling choose, use choose_extra to select which of the extra 'answers' 
will be given to each student.  Note that unused answers are dumped into the 
list of extra 'answers' so the indexing may be difficult to grasp at first. 
(This can be stopped by doing the following: $ml->dumpExtra = "";)

=for html
	<PRE>
	<I>$ml->choose_extra([0], 2);</I></PRE>

would show 3 extra answers besides the correct one note that these extra 
answers may consist of answers from the questions that were not used.
	
After calling choose_extra you can use makeLast to add specific answers to the 
end of the list of answers or to force already existing answers to be moved to 
the end of the list.  This is usually done for 'None of the above', or 'All of 
the above' type answers.

=for html
	<PRE>
	<I>$ml->makeLast(
		'All of the above',
		'None of the above'
	);</I></PRE>

If you want you can change the size of the answer boxes at any time (the default is 4).

=for html
	<PRE>
	<I>$ml->ans_rule_len(10);</I></PRE>

Now you would start your problem with a BEGIN_TEXT tag and print the questions 
and answers with the print_q() and print_a() commands. Within the 
BEGIN_TEXT/END_TEXT block, all calls to objects must be enclosed in \( \).  
(The $PAR start a new paragraph by printing a blank line).

=for html
	<PRE>
	<I>BEGIN_TEXT
		$PAR
		\{ $ml->print_q() \}
		$PAR
		\{ $ml->print_a() \}
	END_TEXT</I></PRE>

Now all that's left is sending the students answers to the answer evaluator 
along with the correct answers so that the students answers can be checked and 
a score can be given.  This is done using ANS, an answer evaluator and the 
ra_correct_ans variable.

=for html
	<PRE>
	<I>ANS(str_cmp($ml->ra_correct_ans));</I></PRE>

=cut

BEGIN {
	be_strict();
}


package Match;

@Match::ISA = qw( List );

# *** Subroutines which overload List.pm ***

#sends letters for comparison instead of actual answers
sub ra_correct_ans {
	my $self = shift;
	my @ans = &List::ALPHABET( @{$self->{inverted_shuffle}} );
	\@ans;
}

1;
