#!/usr/bin/perl -w
#Construct for Multiple Choice.
#Inherits from List.pm
#VS 6/16/2000


=head1 NAME

Multiple.pm -- sub-class of List that implements a multiple choice question.

All items accessed by $out=$mc->item($in);

=head1 SYNOPSIS

Multiple.pm is intended to be used to create one of two types of multiple choice
questions. The regular multiple choice question is one question followed by a
list of answers, only one of which is correct, printed in a bulleted form with 
radio buttons to select the correct answer.  The second type of of multiple choice 
question consists of one question followed by several answers bulleted with check
boxes so that more than one answer can be selected if more than one answer exists.
Each student will receive the same set of answers in a mostly random order (some 
answers can be forced to be at the end of list of answers, see makeLast() below).

=head1 DESCRIPTION

=head2 Variables and methods available to Multiple

=head3 Variables

	questions			# array of questions as entered using qa()
	answers				# array of answers as entered using qa()

	selected_q			# randomly selected subset of "questions"
	selected_a			# the answers for the selected questions

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
						# for the question and answers

	extra( array )		# accepts an array of strings which can be used 
						# as extra answers
		
	print_q				# yields a formatted string of question to be 
						# matched with answer blanks
	print_a				# yields a formatted string of answers
		
	choose([3, 4], 1)	# chooses questions indexed 3 and 4 and one other 
						# randomly
	makeLast( array )	# accepts an array of strings (like qa) which will 
						# be forced to the end of the list of answers.
		
	correct_ans			# outputs a reference to the array of correct answers


=head2 Usage


=head3 Regular Multiple Choice

Create a multiple choice question using the new_multiple_choice call.

=for html
	<PRE>
	<I>$mc = new_multiple_choice</I>
	</PRE>

Use qa() to enter the question and the correct answer. Any duplicates will be eliminated.

=for html
	 <PRE>
	 <I>$mc->qa('\( x^2 \) is:', 'quadratic');</I></PRE>
	
After calling qa you can use extra() to add in extra incorrect answers that (along with the
correct answer) will be made into a random list of answers shown to the student.

=for html
	<PRE>
	<I>$mc->extra(
		'cubic',
		'logarithmic',
		'exponential'
	);</I></PRE>


If you want certain answers to be at the end of the list instead of having them be randomized
you can use makeLast to add specific answers to the end of the list of answers or to force 
already existing answers to be moved to the end of the list.  This is usually done for 
'None of the above', or 'All of the above' type answers.  Note that if 'None of the above'
is the correct answer then you must put it in qa() and then also makeLast() but the duplicate
will be eliminated.  If more than one extra answer is added via makeLast, they are added
in the same order they are given in makeLast.

=for html
	<PRE>
	<I>$mc->makeLast(
		'All of the above',
		'None of the above'
	);</I></PRE>

Now you would start your problem with a C<BEGIN_TEXT> tag and print the questions 
and answers with the print_q() and print_a() commands. Within the C<BEGIN_TEXT/END_TEXT block>, 
all calls to objects must be enclosed in \( \).  
(The $PAR start a new paragraph by printing a blank line).

=for html
	<PRE>
	<I>BEGIN_TEXT
		$PAR
		\{ $mc->print_q() \}
		$PAR
		\{ $mc->print_a() \}
	END_TEXT</I></PRE>

Now all that''s left is sending the students answers to the answer evaluator 
along with the correct answers so that the students answers can be checked and 
a score can be given.  This is done using C<ANS>, an answer evaluator and the 
C<correct_ans> variable.

=for html
	<PRE>
	<I>ANS(radio_cmp($mc->correct_ans))</I></PRE>


=head3 Checkbox Multiple Choice


A checkbox multiple choice problem is identical to a regular multiple choice problem with only
a few exceptions.

First, you create the checkbox multiple choice object using the command:

=for html
	<PRE>
	<I>$cmc = new_checkbox_multiple_choice</I></PRE>
	
Then you would call qa() just as in a regular multiple choice object except that this time
you can provide more than one answer

=for html
	 <PRE>
	 <I>$cmc->qa(
	 			'Indicate all the functions that are anti-derivatives of \( 3x^2 \)', 
				'\( x^3 \)',
				'\( x^3 - 57 \)',
				'\( 27 + x^3 \)'
	);</I></PRE>
	
Then you would use extra() and makeLast() and create the problem just as with a regular multiple 
choice.  The only other difference is that at then end of the problem you would use checkbox_cmp()
instead of radio_cmp().

=for html
	<PRE>
	<I>ANS(radio_cmp($cmc->correct_ans))</I></PRE>


=cut

BEGIN {
	be_strict();
}

#use strict;
package Multiple;

@Multiple::ISA = undef;
#require "${Global::mainDirectory}courseScripts/List.pm";
@Multiple::ISA = qw( Exporter List );

# *** Subroutines which overload List.pm ***
sub choose { warn "Multiple choice does not support choosing answers.\n(You can't use \$mc->choose().)"; }
sub choose_extra { warn "Multiple choice does not support choosing answers.\n(You can't use \$mc->choose_extra().)"; }
sub extras { warn "Extras() is not a method of Multiple.pm.\nUse the extra() method to add extra answers."; }

sub qa {
	my $self = shift;
	my @input = @_;
	
	push( @{ $self->{questions} }, shift(@input) );	#one question
	push( @{ $self->{answers} }, @input );	#correct answer(s)
	
	$self->choose2(scalar(@{ $self->{answers} }));
}

sub extra {
	my $self = shift;
	my @input = @_;
	
	push( @{ $self->{extras} }, @input);

	#call as a method of $self
	&List::choose_extra($self, scalar(@{ $self->{extras} }));
}

#This means rf_print_q is not used but still exists for user customization
sub print_q {
	my $self = shift;
	
	@{ $self->{questions} }[0];
}


#This is called choose2 because it needs to be called internally 
#but i didn't want it available to the user (hence choose being
#overloaded to give a error message above).
sub choose2 {
 	my $self = shift;
 	my @input = @_;
 	
	$self->getRandoms(scalar(@{ $self->{answers} }), @input);
 	$self->selectQA();
}

sub selectQA {
	my $self = shift;
	
	$self->{selected_q} = $self->{questions};
	$self->{selected_a} = [ @{ $self->{answers} }[@{ $self->{shuffle} }] ];
	$self->{inverted_shuffle} = [ &List::invert(@{ $self->{shuffle} }) ];
}

#Multiple 
sub ra_correct_ans {
	warn "Multiple does not use ra_correct_ans because radio_cmp and checkbox_cmp expect a string.\nYou should use correct_ans instead.";
}

#sends letters for comparison instead of actual answers
#actual answers aren't used because they might contain LaTeX or HTML
sub correct_ans {
	my $self = shift;
	my @ans = &List::ALPHABET( sort { $a <=> $b } @{$self->{inverted_shuffle}} );
	
	#radio_cmp and checkbox_cmp expect a string, not a reference to an array like str_cmp, etc
	join "", @ans;
}

1;
