################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Template.pm,v 1.3 2006/01/25 23:13:51 sh002i Exp $
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

package WeBWorK::Template;
use base qw(Exporter);

=head1 NAME

WeBWorK::Template - apply a template to a ContentGenerator.

=head1 SYNOPSIS

 use WeBWorK::Template qw/template/;
 
 my $templateFile = "default.template";
 my $cg = WeBWorK::ContentGenerator::SomeSubclass->new($r);
 
 template($templateFile, $cg);

=head1 DESCRIPTION

WeBWorK uses templates to customize the presentation of pages. A template is a
complete HTML document, containing normal HTML code and special escape
sequences.

=head2 ESCAPE SEQUENCES

Escape sequences have a format similar to that of server-side includes (SSI).
The format is as follows:

 <!--#NAME ARG1="VALUE1" ARG2="VALUE2" ...-->

An escape's C<NAME> and arguments (C<ARG1>, C<ARG2>, etc.) are case-sensitive,
the argument values may or may not be depending on the particular escape. Most
escapes have case-sensitive values.

Escape equences are replaced by dynamically generated content from WeBWorK's
content generation system, WeBWorK::ContentGenerator. When a template escape
C<NAME> is encountered in the document, the template processor checks for a
method of the same name in the current content generator. If found, that method
is invoked as follows:

 @result = $contentGenerator->NAME(\%escapeArguments);

where %escapeArguments contains the key/value pairs of arguments in the escape
sequence (like C<ARG1="VALUE1" ARG2="VALUE2">). The method may print() output
directly to the client or return a result. If the method returns a non-empty
value, it is sent to the client.

=head2 CONDITIONAL PROCESSING

In addition to the normal escape sequences above, the escape sequences C<#if>,
C<#else>, and C<#endif> are reserved and used to conditionally include portions
of the template in the output.

The C<#if> escape sequence has the following form:

 <!--#if PRED1="VALUE1" PRED2="VALUE2" ...->

When an C<#if> escape is evaluated, each predicate (C<PRED1>, C<PRED2>, etc.) is
evaluated by calling a method named C<if_PRED> in the current content generator
with the predicate's value as the sole argument. If no such method exists, the
predicate is false. If the method returns a true value, the predicate is true.

If any predicate is true, the code between the C<#if> escape and a matching
C<#else> or C<#endif> escape is included in the output. C<#if> statements can be
nested.

For example:

 <!--#if loggedin="1"-->
 <!--#if can="loginstatus"-->
 <div class="LoginStatus">
 	<!--#loginstatus-->
 </div>
 <!--#endif-->
 <!--#endif-->
 <!--#if can="path"-->
 <div class="Path">
 	<!--#path style="text" image="<!--#url type="webwork" name="htdocs"-->/images/right_arrow.png" text=" > "-->
 </div>
 <!--#endif-->

Several predicate functions are defined in WeBWorK::ContentGenerator.

=cut

use strict;
use warnings;
use WeBWorK::Utils qw(readFile);

our @EXPORT    = ();
our @EXPORT_OK = qw(
	template
);

=head1 FUNCTIONS

=over

=item template($templatePath, $cg)

Process the template file $templatePath. Methods from $cg, an instance of
WeBWorK::ContentGenerator, are called to handle escape sequences in the
template.

=cut

sub template {
	my ($templatePath, $cg) = @_;
	
	# the truth value of the top of this stack determines if we're printing output or not.
	# we want to start off in printing mode.
	# say $ifstack[-1] to get the result of the last <#!--if-->
	my @ifstack = (1);
	
	my @template = split /\n/, readFile($templatePath);
	
	foreach my $line (@template) {
		# This is incremental regex processing.
		# the /c is so that pos($line) doesn't die when the regex fails.
		while ($line =~ m/\G(.*?)<!--#(\w*)((?:\s+.*?)?)-->/gc) {
			my ($before, $function, $raw_args) = ($1, $2, $3);
			my @args = ($raw_args =~ /\S/) ? cook_args($raw_args) : ();
			
			if ($ifstack[-1]) {
				print $before;
			}
			
			if ($function eq "if") {
				# a predicate can only be true if everything else on the ifstack is already true, for ANDing
				push @ifstack, (if_handler($cg, [@args]) && $ifstack[-1]);
				#Need to deal with the case where there are nested elses.  So an else should only become true if its inside a block that was printing.  
			} elsif ($function eq "else" and @ifstack > 2) {
				$ifstack[-1] = (not $ifstack[-1]) && $ifstack[-2];
			} elsif ($function eq "else" and @ifstack > 1) {
				$ifstack[-1] = not $ifstack[-1];
			} elsif ($function eq "endif" and @ifstack > 1) {
				pop @ifstack;
			} elsif ($ifstack[-1]) {
				if ($cg->can($function)) {
					my @result = $cg->$function({@args});
					if (@result && defined($result[0])) {
						print @result;
					} else {
						warn "Template escape $function returned an empty list.";
					}
				}
			}
		}
		
		if ($ifstack[-1]) {
			print substr($line, (defined pos $line) ? pos $line : 0), "\n";
		}
	}
}

# cook_args(STRING) - parses a string of the form ARG1="FOO" ARG2="BAR". Returns
# a list which pairs into key/values and fits nicely in {}s.
# 
sub cook_args($) { # ... also used by bin/wwdb, so watch out
	my ($raw_args) = @_;
	my @args = ();
	
	# Boy I love m//g in scalar context!  Go read the camel book, heathen.
	# First, get the whole token with the quotes on both ends...
	while ($raw_args =~ m/\G\s*(\w*)="((?:[^"\\]|\\.)*)"/g) {
		my ($key, $value) = ($1, $2);
		# ... then, rip out all the protecty backspaces
		$value =~ s/\\(.)/$1/g;
		push @args, $key => $value;
	}
	
	return @args;
}

# This is different.  It probably shouldn't print anything (except in debugging cases)
# and it should return a boolean, not a string.  &if is called in a nonstandard way
# by &template, with $args as an arrayref instead of a hashref.  this is a hack!  yay!
# 
# OK, this is a pluggin architecture.  it iterates through attributes of the "if" tag,
# and for each predicate $p, it calls &if_$p in an object-oriented way, continuing the
# grand templating theme of an object-oriented pluggable architecture using ->can($).
# 
sub if_handler {
	my ($cg, $args) = @_;
	# A single if "or"s it's components.  Nesting produces "and".
	
	my @args = @$args; # Hahahahaha, get it?!
	
	if (@args % 2 != 0) {
		# flip out and kill people, but do not commit seppuku
		print '<!--&if recieved an uneven number of arguments.  This shouldn\'t happen, but I\'ll let it slide.-->\n';
	}
	
	while (@args > 1) {
		my ($key, $value) = (shift @args, shift @args);
		
		# a non-existent &if_$key is the same as a false result, but we're ORing, so it's OK
		my $sub = "if_$key"; # perl doesn't like it when you try to construct a string right in a method invocation
		if ($cg->can("if_$key") and $cg->$sub("$value")) {
			return 1;
		}
	}
	
	return 0;
}

=back

=cut

1;
