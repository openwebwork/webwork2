#!/usr/bin/perl -w
#Construct for selection list.
#Inherits from List.pm
#VS 6/16/2000

=head1 NAME

	Select.pm -- sub-class of List that implements a select list.
	
	All items accessed by $out = $sl -> item( $in );

=head1 SYNOPSIS

Select.pm is intended to be used to create standard true/false questions
or questions where all the questions have the same set of short one to 
two word answers as possible answers. Unlike a matching list, where
answers are indicated by typing in the corresponding letter, in a select
list the actual answer is typed in.  A select list also has the option
of having a pop-up list of the answers so that the correct answer
can just be selected instead of typed. But like match lists, students
can be given different sets of questions (to avoid students sharing 
answers) by entering many questions and then having each student only
receive a sub-set of those questions by using choose.

=head1 DESCRIPTION

=head2 Variables and methods available to Select

=head3 Variables

	questions			# array of questions as entered using qa()
	answers				# array of answers as entered using qa()
	
	selected_q			# randomly selected subset of "questions"
	selected_a			# the answers for the selected questions
	
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
						# (i.e. $sl->rf_print_q = ~~&printing_routine_q)
	
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
		
	print_q				# yields a formatted string of question to be 
						# matched with answer blanks
		
	choose([3, 4], 1)	# chooses questions indexed 3 and 4 and one other 
						# randomly
		
	ra_correct_ans		# outputs a reference to the array of correct answers

=head2 Usage


=head3 Regualar Select List


Create a select list using the new_select_list call.

=for html
	<PRE>
	<I>$sl = new_select_list;</I>
	</PRE>

Use qa() to enter questions and answers in alternating pairs.

=for html
	 <PRE>
	 <I>$sl->qa(
		'\( y = x^2 \) is increasing to the right',
		'T',
		'\( y = x^3 \) is decreasing to the right',
		'F',
		'\( y = -x^2 + x^3 + 2 \) is decreasing to the right',
		'F',
		'\( y = -x^2 + x - 15 \) is decreasing to the left',
		'F',
		'\( y = 2^x \) is decreasing to the left',
		'T',
	);</I></PRE>

After calling qa, use choose to select which questions and/or how many each 
student sees. A list of numbers in brackets indicates which questions every 
student sees (counting starts with 0) and the final number outside of brackets 
is how many more questions should be randomly picked for each student.

=for html	
	<PRE>
	<I>$sl->choose([0], 1);</I></PRE>

would show the first question and a random question while

=for html
	<PRE>
	<I>$sl->choose(3);</I></PRE>

would show 3 random questions (but never call choose more than once).

If you want you can change the size of the answer boxes at any time (the default is 4).

=for html
	<PRE>
	<I>$sl->ans_rule_len = 10;</I></PRE>

Now you would start your problem with a BEGIN_TEXT tag and print the questions 
with the print_q() command. Within the BEGIN_TEXT/END_TEXT block, all calls to 
objects must be enclosed in \( \).  (The $PAR start a new paragraph by printing 
a blank line).

=for html
	<PRE>
	<I>BEGIN_TEXT
		$PAR
		\{ $sl->print_q() \}
	END_TEXT</I></PRE>

Now all that''s left is sending the students answers to the answer evaluator 
along with the correct answers so that the students answers can be checked and 
a score can be given.  This is done using ANS, an answer evaluator and the 
ra_correct_ans variable.

=for html
	<PRE>
	<I>ANS(str_cmp($sl->ra_correct_ans));</I></PRE>


=head3 Pop-Up Select List


A Pop-up select list problem is identical to a regular select list problem with
only a few exceptions.

First, you would create a pop-up select list using the new_pop_up_select_list call.

=for html
	<PRE>
	<I>$sl = new_pop_up_select_list;</I>
	</PRE>

Then you would use qa() and choose() (and optionally ans_rule_len) as normal but 
before writing the actual problem within the BEGIN_TEXT/END_TEXT headers, you could 
optionally specify value=>label pairs for the pop-up list where you first specify 
the value of an answer to one of your questions and you link it to a label (using =>) 
that will be shown to the students.  For example,

=for html
	<PRE>
	<I>$sl->ra_pop_up_list([no_answer => '  ?', T => 'True', F => 'False']);</I></PRE>
	
indicates that instead of seeing the letter T (which was used as the actual
answer), the student will see the word 'True'.  Also, before they choose
their answer the student will first see a question mark in each pop-up list 
indicating that they have not yet selected an answer there because the special 
variable no_answer has been selected.  This is optional, however, because if no
$sl->ra_pop_up_list is specified, it will default to the one shown above.  So if
this is want you want, you don't need to do any of this, but if you use ra_pop_up_list
at all, these defaults will be lost and 'T' will just be 'T'.  Also, if you don't 
specify a label for a particular answer, the label for that answer will be the 
answer (like I just said, 'T' will be 'T').

Other than those two differences, a pop-up select list problem is exactly the same
as a regular select list problem as described above.

=cut

BEGIN {
	be_strict();
}
#'
package Select;

#require "${Global::mainDirectory}courseScripts/List.pm";
@Select::ISA = qw( Exporter List );

# *** Subroutines which overload List.pm ***

#these
sub extra { warn "Select lists do not use extra answers.\n(You can't use \$sl->extra().)" }
sub choose_extra { warn "Select lists do not use extra answers.\n(You can't use \$sl->choose_extra().)" }
sub makeLast { warn "Select lists do not use extra answers.\n(You can't use \$sl->makeLast().)" }

#overload choose so that the answers don't get randomized
sub choose {
 	my $self = shift;
 	my @input = @_;
 	

 	$self->getRandoms(scalar(@{ $self->{questions} }), @input);
 	$self->selectQA();
 	$self->dumpExtra();
}

sub selectQA {
	my $self = shift;
	
	$self->{selected_q} = [ @{ $self->{questions} }[ @{ $self->{slice} } ] ];
	$self->{selected_a} = [ @{ $self->{answers} }[@{ $self->{slice} } ] ];
	$self->{inverted_shuffle} = [ &List::invert(@{ $self->{shuffle} }) ];
}

1;
