package WeBWorK::ContentGenerator::Test;

# This file will cease to be as soon as the real content generation modules
# have been written.  However, there's always reason to keep it around, as
# it showcases many things that new content generators will want to do,
# since it's generally where I dump new functionality before I put it in any
# end-user modules.

use strict;
use warnings;
use base 'WeBWorK::ContentGenerator';
use CGI qw();
use WeBWorK::Utils qw(ref2string);
use WeBWorK::Form;

sub title {
	return "Welcome to Hell";
}

sub body {
	my $self = shift;
	my $formFields = WeBWorK::Form->new_from_paramable($self->{r});
	my $courseEnvironment = $self->{courseEnvironment};
	return
		CGI->h2("Form Fields"), ref2string($formFields),
		CGI->h2("Course Environment"), ref2string($courseEnvironment);
}

1;
