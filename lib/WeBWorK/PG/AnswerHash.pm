##########################################################################
## AnswerHash Package
##
## Provides a data structure for answer hashes. Currently just a wrapper
## for the hash, but that might change
####################################################################
# Copyright @ 1995-2002 WeBWorK Team
# All Rights Reserved
####################################################################
#$Id$

=head1 NAME

	AnswerHash.pm -- located in the courseScripts directory
	
	This file contains the packages/classes:
	AnswerHash   and AnswerEvaluator

=head1 SYNPOSIS

	AnswerHash  -- this class stores information related to the student's
		       answer.  It is little more than a standard perl hash with
		       a special name, butit does have some access and 
		       manipulation methods.  More of these may be added as it
		       becomes necessary.
		       
	Useage:    $rh_ans = new AnswerHash;
		       
	AnswerEvaluator -- this class organizes the construction of
			   answer evaluator subroutines which check the 
			   student's answer.  By plugging filters into the
			   answer evaluator class you can customize the way the
			   student's answer is normalized and checked.  Our hope
			   is that with properly designed filters, it will be
			   possible to reuse the filters in different
			   combinations to obtain different answer evaluators,
			   thus greatly reducing the programming and maintenance
			   required for constructing answer evaluators.
			   
	Useage: 	$ans_eval  = new AnswerEvaluator;

=cut

=head1 DESCRIPTION : AnswerHash

The answer hash class is guaranteed to contain the following instance variables:

	score			=>	$correctQ,
	correct_ans		=>	$originalCorrEqn,
	student_ans		=>	$modified_student_ans
	original_student_ans	=>	$original_student_answer,
	ans_message		=>	$PGanswerMessage,
	type			=>	'typeString',
	preview_text_string	=>	$preview_text_string,
	preview_latex_string	=>	$preview_latex_string


	$ans_hash->{score}		--	a number between 0 and 1 indicating
						whether the answer is correct. Fractions
						allow the implementation of partial
						credit for incorrect answers.

	$ans_hash->{correct_ans}		--	The correct answer, as supplied by the
						instructor and then formatted. This can
						be viewed by the student after the answer date.

	$ans_hash->{student_ans}		--	This is the student answer, after reformatting;
						for example the answer might be forced
						to capital letters for comparison with
						the instructors answer. For a numerical
						answer, it gives the evaluated answer.
						This is displayed in the section reporting
						the results of checking the student answers.

	$ans_hash->{original_student_ans}	--	This is the original student answer. 
						 This is displayed on the preview page and may be used for
						 sticky answers.

	$ans_hash->{ans_message}		--	Any error message, or hint provided by 
						the answer evaluator.
						This is also displayed in the section reporting
						the results of checking the student answers.

	$ans_hash->{type}			--	A string indicating the type of answer evaluator. 
						This helps in preprocessing the student answer for errors.
						Some examples:
							'number_with_units'
							'function'
							'frac_number'
							'arith_number'


	$ans_hash->{preview_text_string}	--
						This typically shows how the student answer was parsed. It is
						displayed on the preview page. For a student answer of 2sin(3x)
						this would be 2*sin(3*x). For string answers it is typically the
						same as $ans_hash{student_ans}.


	$ans_hash->{preview_latex_string}	--	
						THIS IS OPTIONAL. This is latex version of the student answer
						which is used to show a typeset view on the answer on the preview
						page. For a student answer of 2/3, this would be \frac{2}{3}.

						'ans_message'			=>	'', # null string
											
						'preview_text_string'	=>	undef,
						'preview_latex_string'	=>  undef,
						'error_flag'			=>  undef,
						'error_message'		    =>  '',


=head3 AnswerHash Methods:

=cut

BEGIN {
	be_strict(); # an alias for use strict.  This means that all global variable must contain main:: as a prefix.
    
}

package AnswerHash;
# initialization fields
my %fields = (		'score'					=>	undef,
					'correct_ans'			=>	undef,
					'student_ans'			=>	undef,
					'ans_message'			=>	undef,
					'type'					=>	undef,
					'preview_text_string'	=>	undef,
					'preview_latex_string'	=>	undef,
					'original_student_ans' 	=>	undef
			);

## Initializing constructor
=head4 new

	Useage		$rh_anshash = new AnswerHash;
	
	returns an object of type AnswerHash.
	
=cut

sub new {
	my $class = shift @_;
	
	my $self  = {	'score'					=>	0,
					'correct_ans'			=>	'No correct answer specified',
					'student_ans'			=>	undef,
					'ans_message'			=>	'',
					'type'					=>	'Undefined answer evaluator type',
					'preview_text_string'	=>	undef,
					'preview_latex_string'	=>	undef,
					'original_student_ans'	=>	undef,
					'error_flag'			=>  undef,
					'error_message'		    =>  '',

	};	# return a reference to	a hash.
	
	bless $self, $class;
	$self -> setKeys(@_);
	
	return $self;
}

## IN: a hash
## Checks to make sure that the keys are valid,
## then sets their value

=head4 	setKeys		
			
			$rh_ans->setKeys(score=>1, student_answer => "yes");  
			Sets standard elements in the AnswerHash (the ones defined
			above). Will give error if one attempts to set non-standard keys.
			
			To set a non-standard element in a hash use
			
			$rh_ans->{non-standard-key} = newValue;
			
			There are no safety checks when using this method.

=cut

 
sub setKeys {
    my $self = shift;
	my %inits = @_;
	foreach my $item (keys %inits) {
		if ( exists $fields{$item} ) { 
			$self -> {$item} = $inits{$item};
		}
		else {
			warn "AnswerHash cannot automatically initialize an item named $item";
		}
	}
}

# access methods

=head4 data

	Useage:     $rh_ans->data('foo');               set $rh_ans->{student_ans} = 'foo';
	            $student_input = $rh_ans->data();   retrieve value of $rh_ans->{student_ans}
	
	synonym for input

=head4  input	

	Useage:     $rh_ans->input('foo')    sets $rh_ans->{student_ans} = 'foo';
				$student_input = $rh_ans->input();
	
	synonym for data

=cut

sub data {    #$rh_ans->data('foo') is a synonym for $rh_ans->{student_ans}='foo'
	my $self = shift;
	$self->input(@_);
}

sub input {     #$rh_ans->input('foo') is a synonym for $rh_ans->{student_ans}='foo'
	my $self = shift;
    my $input = shift;
    $self->{student_ans} = $input if defined($input);
	$self->{student_ans}
}

=head4  input	

	Useage:     $rh_ans->score(1)    
				$score = $rh_ans->score();
	
	Retrieve or set $rh_ans->{score}, the student's score on the problem.

=cut

sub score {     
	my $self = shift;
    my $score = shift;
    $self->{score} = $score if defined($score);
	$self->{score}
}

# error methods

=head4 throw_error

	Useage:	$rh_ans->throw_error("FLAG", "message");
	
	FLAG is a distinctive word that describes the type of error.  
	Examples are EVAL for an evaluation error or "SYNTAX" for a syntax error.
	The entry $rh_ans->{error_flag} is set to "FLAG".
	
	The catch_error and clear_error methods use
	this entry.
	
	message is a descriptive message for the end user, defining what error occured.

=head4 catch_error

	Useage: $rh_ans->catch_error("FLAG2");
	
	Returns true (1) if  $rh_ans->{error_flag} equals "FLAG2", otherwise it returns
	false (empty string).



=head4 clear_error

	Useage:  $rh_ans->clear_error("FLAG2");
	
	If $rh_ans->{error_flag} equals "FLAG2" then the {error_flag} entry is set to 
	the empty string as is the entry {error_message}

=head4 error_flag

=head4 error_message

	Useage:   $flag = $rh_ans -> error_flag();
			
			  $message = $rh_ans -> error_message();

	Retrieve or set the {error_flag} and {error_message} entries. 
	
	Use catch_error and throw_error where possible.

=cut



sub throw_error {
	my $self = shift;
    my $flag = shift;
    my $message = shift;
    $self->{error_message} .= " $message " if defined($message);
    $self->{error_flag} = $flag if defined($flag);
	$self->{error_flag}
}
sub catch_error {
	my $self = shift;
    my $flag = shift;
    return('')  unless defined($self->{error_flag});
    return $self->{error_flag} unless $flag;    # empty input catches all errors.
    return $self->{error_flag} if $self->{error_flag} eq $flag;
	return '';   # nothing to catch
}
sub clear_error {
	my $self = shift;
	my $flag = shift;
	if (defined($flag) and $flag =~/\S/ and defined($self->{error_flag})  and $flag eq $self->{error_flag}) {
		$self->{error_flag} = undef;
		$self->{error_message} = undef;
	}
	$self;
}
sub error_flag {
	my $self = shift;
    my $flag = shift;
    $self->{error_flag} = $flag if defined($flag);
	$self->{error_flag}
}
sub error_message {
	my $self = shift;
    my $message = shift;
    $self->{error_message} = $message if defined($message);
	$self->{error_message}
}

# error print out method

=head4 pretty_print


	Useage:     $rh_ans -> pretty_print();
	
	
	Returns a string containing a representation of the AnswerHash as an HTML table.

=cut


sub pretty_print {
    my $r_input = shift;
    my $out = '';
    if ( not ref($r_input) ) {
    	$out = $r_input;    # not a reference
    } elsif (ref($r_input) =~/hash/i) {
	    local($^W) = 0;
		$out .= "<TABLE border = \"2\" cellpadding = \"3\" BGCOLOR = \"#FFFFFF\">";
		foreach my $key (sort keys %$r_input ) {
			$out .= "<tr><TD> $key</TD><TD>=&gt;</td><td>&nbsp;".pretty_print($r_input->{$key}) . "</td></tr>";
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
	} else {
		$out = $r_input;
	}
		$out;
}

# action methods	

=head4 OR

	Useage:    $rh_ans->OR($rh_ans2);
	
	Returns a new AnswerHash whose score is the maximum of the scores in $rh_ans and $rh_ans2.
	The correct answers for the two hashes are combined with "OR".  
	The types are concatenated with "OR" as well.
	Currently nothing is done with the error flags and messages.



=head4 AND


	Useage:    $rh_ans->AND($rh_ans2);
	
	Returns a new AnswerHash whose score is the minimum of the scores in $rh_ans and $rh_ans2.
	The correct answers for the two hashes are combined with "AND". 
	The types are concatenated with "AND" as well.
	 Currently nothing is done with the error flags and messages.




=cut



sub OR {
	my $self = shift;
	
	my $rh_ans2 = shift;
	my %options = @_;
	return($self) unless defined($rh_ans2) and ref($rh_ans2) eq 'AnswerHash';
	
	my $out_hash = new AnswerHash;
	# score is the maximum of the two scores
	$out_hash->{score} = ( $self->{score}  <  $rh_ans2->{score} ) ? $rh_ans2->{score} :$self->{score};
	$out_hash->{correct_ans} = join(" OR ", $self->{correct_ans}, $rh_ans2->{correct_ans} );
	$out_hash->{student_ans} = $self->{student_ans};
	$out_hash->{type} = join(" OR ", $self->{type}, $rh_ans2->{type} );
	$out_hash->{preview_text_string} = join("   ", $self->{preview_text_string}, $rh_ans2->{preview_text_string} );
	$out_hash->{original_student_ans} = $self->{original_student_ans};
	$out_hash;
}

sub AND {
	my $self = shift;
	my $rh_ans2 = shift;
	my %options = @_;
	my $out_hash = new AnswerHash;
	# score is the minimum of the two scores
	$out_hash->{score} = ( $self->{score}  >  $rh_ans2->{score} ) ? $rh_ans2->{score} :$self->{score};
	$out_hash->{correct_ans} = join(" AND ", $self->{correct_ans}, $rh_ans2->{correct_ans} );
	$out_hash->{student_ans} = $self->{student_ans};
	$out_hash->{type} = join(" AND ", $self->{type}, $rh_ans2->{type} );
	$out_hash->{preview_text_string} = join("   ", $self->{preview_text_string}, $rh_ans2->{preview_text_string} );
	$out_hash->{original_student_ans} = $self->{original_student_ans};
	$out_hash;
}


=head1 Description:  AnswerEvaluator




=cut



package AnswerEvaluator;


=head3 AnswerEvaluator Methods







=cut


=head4 new


=cut


sub new {
	my $class = shift @_;
	
	my $self  = {	pre_filters 	=>	[ [\&blank_prefilter] ],
					evaluators		=>	[],
					post_filters	=>  [ [\&blank_postfilter] ],
					debug			=>  0,
					rh_ans		=>	new AnswerHash,
					
	};
	
	bless $self, $class;
	$self->rh_ans(@_);    #initialize answer hash	
	return $self;
}

# dereference_array_ans pretty prints an answer which is stored as an anonymous array.
sub dereference_array_ans {
	my $self = shift;
	my $rh_ans = shift;
	if (defined($rh_ans->{student_ans}) and ref($rh_ans->{student_ans}) eq 'ARRAY'  ) {
		$rh_ans->{student_ans} = "( ". join(" , ",@{$rh_ans->{student_ans}} ) . " ) ";
	}
	$rh_ans;
}
	
sub get_student_answer {
	my $self 	= shift;
	my $input   = shift;
	$input = '' unless defined($input); 
	if (ref($input) =~/AnswerHash/) {
		# in this case nothing needs to be done, since the student's answer is already in an answerhash.
		# This is useful when an AnswerEvaluator is used as a filter in another answer evaluator.
	} elsif ($input =~ /\0/ ) {  # this case may occur with older versions of CGI??
	   	my @input = split(/\0/,$input);
	   	$self-> {rh_ans} -> {original_student_ans} = " ( " .join(", ",@input) . " ) ";
		$input = \@input;
		$self-> {rh_ans} -> {student_ans} = $input;
	} elsif (ref($input) eq 'ARRAY' ) {  # sometimes the answer may already be decoded into an array.   
	   	my @input = @$input;
	   	$self-> {rh_ans} -> {original_student_ans} = " ( " .join(", ",@input) . " ) ";
		$input = \@input;
		$self-> {rh_ans} -> {student_ans} = $input;
	} else {
	    
		$self-> {rh_ans} -> {original_student_ans} = $input;
		$self-> {rh_ans} -> {student_ans} = $input;
	}
	
	
	$input;
}

=head4  evaluate




=cut

sub evaluate {
	my $self 		= 	shift;
	$self->get_student_answer(shift @_);
	$self->{rh_ans}->{error_flag}=undef;  #reset the error flags in case 
	$self->{rh_ans}->{done}=undef;        #the answer evaluator is called twice
	my $rh_ans    =   $self ->{rh_ans};
    warn "<H3> Answer evaluator information: </H3>\n" if defined($self->{debug}) and $self->{debug}>0;
	my @prefilters	= @{$self -> {pre_filters}};
	my $count = -1;  # the blank filter is counted as filter 0
	foreach my $i	(@prefilters) {
	    last if defined( $self->{rh_ans}->{error_flag} );
	    my @array = @$i;
	    my $filter = shift(@array);      # the array now contains the options for the filter
	    my %options = @array;
	    if (defined($self->{debug}) and $self->{debug}>0) {
	    	
	    	$self->{rh_ans}->{rh_options} = \%options;  #include the options in the debug information
	    	warn "before pre-filter: ",++$count, $self->{rh_ans}->pretty_print();
	    }
	    $rh_ans 	= &$filter($rh_ans,@array);
	    warn "<h4>Filter Name:", $rh_ans->{_filter_name},"</h4><BR>\n" 
	    	if defined($self->{debug}) and $self->{debug}>0 and defined($rh_ans->{_filter_name});
	    $rh_ans->{_filter_name} = undef;
	}
	my @evaluators = @{$self -> {evaluators} };
	$count = 0;
	foreach my $i ( @evaluators )   {
	    last if defined($self->{rh_ans}->{error_flag});
		my @array = @$i;
	    my $evaluator = shift(@array);   # the array now contains the options for the filter
	    my %options = @array;
	    if (defined($self->{debug}) and $self->{debug}>0) {
	    	$self->{rh_ans}->{rh_options} = \%options;  #include the options in the debug information
	    	warn "before evaluator: ",++$count, $self->{rh_ans}->pretty_print();
	    }
		$rh_ans 	= &$evaluator($rh_ans,@array);
		warn "<h4>Filter Name:", $rh_ans->{_filter_name},"</h4><BR>\n" if defined($self->{debug}) and $self->{debug}>0 and defined($rh_ans->{_filter_name});
		$rh_ans->{_filter_name} = undef;
	}
	my @post_filters = @{$self -> {post_filters} };
	$count = -1;  # blank filter catcher is filter 0
	foreach my $i ( @post_filters ) {
	    last if defined($rh_ans->{done}) and $rh_ans->{done} == 1;    # no further action needed
		my @array = @$i;
		
	    my $filter = shift(@array);      # the array now contains the options for the filter
	    my %options = @array;
	    if (defined($self->{debug}) and $self->{debug}>0) {
	    	$self->{rh_ans}->{rh_options} = \%options;  #include the options in the debug information
	    	warn "before post-filter: ",++$count, $self->{rh_ans}->pretty_print(),"\n";
	    }
	   
		$rh_ans 	= &$filter($rh_ans,@array);
		warn "<h4>Filter Name:", $rh_ans->{_filter_name},"</h4><BR>\n" if defined($self->{debug}) and $self->{debug}>0 and defined($rh_ans->{_filter_name});
		$rh_ans->{_filter_name} = undef;
	}
	$rh_ans = $self->dereference_array_ans($rh_ans);   
	# make sure that the student answer is not an array so that it is reported correctly in answer section.
	warn "<h4>final result: </h4>", $self->{rh_ans}->pretty_print() if defined($self->{debug}) and $self->{debug}>0;
	$self ->{rh_ans} = $rh_ans;
	$rh_ans;
}
# This next subroutine is for checking the instructor's answer and is not yet in use.
sub correct_answer_evaluate {
	my $self 		= 	shift;
	$self-> {rh_ans} -> {correct_ans} = shift @_;
	my $rh_ans    =   $self ->{rh_ans}; 
	my @prefilters	= @{$self -> {correct_answer_pre_filters}};
	my $count = -1;  # the blank filter is counted as filter 0
	foreach my $i	(@prefilters) {
	    last if defined( $self->{rh_ans}->{error_flag} );
	    my @array = @$i;
	    my $filter = shift(@array);      # the array now contains the options for the filter
	    warn "before pre-filter: ",++$count, $self->{rh_ans}->pretty_print() if defined($self->{debug}) and $self->{debug}>0;
		$rh_ans 	= &$filter($rh_ans,@array);
		warn "Filter Name:", $rh_ans->{_filter_name},"<BR>\n" if $self->{debug}>0 and defined($rh_ans->{_filter_name})
	}
	my @evaluators = @{$self -> {correct_answer_evaluators} };
	$count = 0;
	foreach my $i ( @evaluators )   {
	    last if defined($self->{rh_ans}->{error_flag});
		my @array = @$i;
	    my $evaluator = shift(@array);   # the array now contains the options for the filter
	    warn "before evaluator: ",++$count, $self->{rh_ans}->pretty_print() if defined($self->{debug}) and $self->{debug}>0;
		$rh_ans 	= &$evaluator($rh_ans,@array);
	}
	my @post_filters = @{$self -> {correct_answer_post_filters} };
	$count = -1;  # blank filter catcher is filter 0
	foreach my $i ( @post_filters ) {
	    last if defined($rh_ans->{done}) and $rh_ans->{done} == 1;    # no further action needed
		my @array = @$i;
	    my $filter = shift(@array);      # the array now contains the options for the filter
	    warn "before post-filter: ",++$count, $self->{rh_ans}->pretty_print() if defined($self->{debug}) and $self->{debug}>0;
		$rh_ans 	= &$filter($rh_ans,@array);
		warn "Filter Name:", $rh_ans->{_filter_name},"<BR>\n" if $self->{debug}>0 and defined($rh_ans->{_filter_name})
	}
	$rh_ans = $self->dereference_array_ans($rh_ans);   
	# make sure that the student answer is not an array so that it is reported correctly in answer section.
	warn "final result: ", $self->{rh_ans}->pretty_print() if defined($self->{debug}) and $self->{debug}>0;
	$self ->{rh_ans} = $rh_ans;
	$rh_ans;
}


=head4 install_pre_filter

=head4 install_evaluator


=head4 install_post_filter


=head4 



=cut


sub install_pre_filter {
	my $self =	shift;
	if (@_ == 0) {
		# do nothing if input is empty
	} elsif ($_[0] eq 'reset' or $_[0] eq 'erase' ) {
		$self->{pre_filters} = [];
	} else {
		push(@{$self->{pre_filters}},[ @_ ]) if @_;  #install pre_filter and it's options
	}
	@{$self->{pre_filters}};  # return array of all pre_filters
}





sub install_evaluator {
	my $self =	shift;
	if (@_ == 0) {
		# do nothing if input is empty
	} elsif ($_[0] eq 'reset' or $_[0] eq 'erase' ) {
		$self->{evaluators} = [];
	} else {
		push(@{$self->{evaluators}},[ @_ ]) if @_; #install evaluator and it's options
	}
	@{$self->{'evaluators'}};  # return array of all evaluators
}


sub install_post_filter {
	my $self =	shift;
	if (@_ == 0) {
		# do nothing if input is empty
	} elsif ($_[0] eq 'reset' or $_[0] eq 'erase' ) {
		$self->{post_filters} = [];
	} else {
		push(@{$self->{post_filters}}, [ @_ ]) if @_; #install post_filter and it's options
	}
	@{$self->{post_filters}};  # return array of all post_filters
}

## filters for checking the correctAnswer
sub install_correct_answer_pre_filter {
	my $self =	shift;
	if (@_ == 0) {
		# do nothing if input is empty
	} elsif ($_[0] eq 'reset' or $_[0] eq 'erase' ) {
		$self->{correct_answer_pre_filters} = [];
	} else {
		push(@{$self->{correct_answer_pre_filters}},[ @_ ]) if @_;  #install correct_answer_pre_filter and it's options
	}
	@{$self->{correct_answer_pre_filters}};  # return array of all correct_answer_pre_filters
}

sub install_correct_answer_evaluator {
	my $self =	shift;
	if (@_ == 0) {
		# do nothing if input is empty
	} elsif ($_[0] eq 'reset' or $_[0] eq 'erase' ) {
		$self->{correct_answer_evaluators} = [];
	} else {
		push(@{$self->{correct_answer_evaluators}},[ @_ ]) if @_; #install evaluator and it's options
	}
	@{$self->{correct_answer_evaluators}};  # return array of all evaluators
}

sub install_correct_answer_post_filter {
	my $self =	shift;
	if (@_ == 0) {
		# do nothing if input is empty
	} elsif ($_[0] eq 'reset' or $_[0] eq 'erase' ) {
		$self->{correct_answer_post_filters} = [];
	} else {
		push(@{$self->{correct_answer_post_filters}}, [ @_ ]) if @_; #install post_filter and it's options
	}
	@{$self->{correct_answer_post_filters}};  # return array of all post_filters
}

sub ans_hash {  #alias for rh_ans
	my $self = shift;
	$self->rh_ans(@_);
}		
sub rh_ans {
	my $self = shift;
	my %in_hash = @_;
	foreach my $key (keys %in_hash) {
		$self->{rh_ans}->{$key} = $in_hash{$key};
	}
	$self->{rh_ans};
}

=head1 Description: Filters

A filter is a subroutine which takes one AnswerHash as an input, followed by 
a hash of options.

		Useage:  filter($ans_hash, option1 =>value1, option2=> value2 );
		

The filter performs some operations on the input AnswerHash and returns an
AnswerHash as output.

Many AnswerEvaluator objects are merely a sequence of filters placed into
three queues:

	pre_filters:	these normalize student input, prepare text and so forth
	evaluators: 	these decide whether or not an answer is correct
	post_filters:	typically these clean up error messages or process errors 
					and generate error messages.

If a filter detects an error it can throw an error message using the C<$rh_ans->throw_error()>
method.  This skips the AnswerHash by all remaining pre_filter C<$rh_ans->catch_error>,
decides how (
or whether) it is supposed to handle the error and then passes the result on
to the next post_filter.  

Setting the flag C<$rh_ans->{done} = 1> will skip 
the AnswerHash past the remaining post_filters.  


=head3 Built in filters

=head4 blank_prefilter


=head4 blank_postfilter

=cut

######################################################
#
# Built in Filters
#
######################################################


sub blank_prefilter  { # check for blanks
	my $rh_ans = shift;  
    # undefined answers are BLANKS
	( not defined($rh_ans->{student_ans}) ) && do {$rh_ans->throw_error("BLANK", 'The answer is blank');
													  return($rh_ans);};
    # answers which are arrays or hashes or some other object reference  are NOT blanks
    ( ref($rh_ans->{student_ans} )        ) && do { return( $rh_ans ) };
    # if the answer is a true variable consisting only of white space it is a BLANK
    ( ($rh_ans->{student_ans}) !~ /\S/   )    && do {$rh_ans->throw_error("BLANK", 'The answer is blank');
													  return($rh_ans);};
 	# If we get to here, we assume that the answer is not a blank. It is defined, not a reference
 	# and contains something other than whitespaces.
 	$rh_ans;
};

sub blank_postfilter  { 
	my $rh_ans=shift;
    return($rh_ans) unless defined($rh_ans->{error_flag}) and $rh_ans->{error_flag} eq 'BLANK';
    $rh_ans->{error_flag} = undef;
    $rh_ans->{error_message} = '';
    $rh_ans->{done} =1;    # no further checking is needed.
    $rh_ans;
};

1;
#package AnswerEvaluatorMaker;

