package PSH;

use vars '$it';

$PSH::VERSION = '0.7';

#use strict; ##use only for testing !!!!!!!!

sub welcome {
    print STDOUT "Welcome to psh $PSH::VERSION by Jenda\@Krynicky.cz\nRunning under Perl $]\n\n";
}

$PSH::allowsystem = 1;
%PSH::specials = ();

eval {require 'PSH.config'};
 print STDERR "Error in psh.config : $@\n" if ($@ and $@ !~ /^Can't locate PSH.config in \@INC/i);
$@='';

sub Exec {
    my $line = shift;
    if ($PSH::allowsystem) {
        if ($line =~ s/>\s*$//) {
            ${$PSH::package.'::it'}= `$line`;
        } else {
            $line =~ /^(.*?)(?:\s(.*))?$/;
            my $cmd;
            if (defined ($cmd = $PSH::alias{lc $1})) {
                ${$PSH::package.'::it'}=system( $cmd.' '.$2 );
            } else {
                ${$PSH::package.'::it'}=system( $line );
            }
        }
    } else {
        print STDOUT "Disallowed by the script!\n";
    }
}

sub specials {
    return if @_ % 2; # I need even number of parameters
    my ($char,$fun);
    while (defined($char = shift)) {
        $fun = shift;
        if ($fun) {
            $PSH::specials{$char} = $fun;
        } else {
            delete $PSH::specials{$char};
        }
    }
    $PSH::specials = join('|', map {"\Q$_\E"} keys %PSH::specials);
}

$PSH::specials{'!'} = \&PSH::Exec;

sub prompt {
    my $prompt = shift || 'perl';
    my $eval = shift;
    $PSH::specials = join('|', map {"\Q$_\E"} keys %PSH::specials); # just for sure
    local $it='';
    my $command='';
    local ($PSH::package, $PSH::filename, $PSH::ln) = caller;
    ${$PSH::package.'::it'}='';
#    print "called from $PSH::package\n";
    print STDOUT "$prompt\$ ";

    my $line;
    while (defined ($line = <STDIN>)) {
        if (!$command and $line =~ /^$/) {
            print STDOUT "$prompt\$ ";
        } elsif (!$command and $PSH::specials and $line =~ /^\s*($PSH::specials)\s*/ and $PSH::specials{$1}) {
            $line =~ s/^\s*($PSH::specials)\s*(.*)$/$2/o;
            ${$PSH::package.'::it'}= &{$PSH::specials{$1}}($line);
            print STDOUT "\n$prompt\$ ";
        } elsif ($line =~ /^\?$/) {
            PSH::help();
            print STDOUT "\n$prompt\$ ";

        } elsif (!$command and $line =~ /^<<(.*)$/) {
            my $eoc = $1;
            print STDOUT "$prompt($eoc)\$ ";
            while (defined ($line = <STDIN>)) {
                last if $line =~ /^\Q$eoc\E\s*$/;
                $command .=$line;
                print STDOUT "$prompt($eoc)\$ ";
            }
            if ($eval) {
                ${$PSH::package.'::it'} = &$eval($command);
            } else {
                ${$PSH::package.'::it'} = eval "package $PSH::package;\n".$command;
            }
            $command = '';
            print STDOUT "\nERROR: $@\n" if $@;
            print STDOUT "\n$prompt\$ ";
        } elsif ($line =~ s/;$//) {
            if ($eval) {
                ${$PSH::package.'::it'} = &$eval($command.$line);
            } else {
                ${$PSH::package.'::it'} = eval "package $PSH::package;\n".$command.$line;
            }
            $command = '';
            print STDOUT "\nERROR: $@\n" if $@;
            print STDOUT "\n$prompt\$ ";
        } else {
            $command .= $line;
            print STDOUT "$prompt> ";
        }
    }
    return ${$PSH::package.'::it'};
}

sub PSH::help {
            print STDOUT <<"*END*";
Commands starting by ! are passed to the command prompt.
If the line ends by >, the output of the command is redirected to
variable \$it. If you want to catch both STDOUT and STDERR use this:

 perl\$ ! command 2>&1 >

All other commands are suposed to be a perl code.

The code to be evaluated may be entered in two ways
or use something like heredoc

If the first line in a new command starts with <<, the rest of the line
is considered as the heredoc delimiter. As long as you do not enter a
line containing only those characters, the lines are only appended into
a variable. As soon as you close the heredoc, the code is evaluated.

Otherwise the code you enter is evaluated as soon as you enter a line
finished by a semicolon.

The value of the last command may be found in \$it.

You may exit this "shell" by either "exit;" or CTRL+Z.
Please keep in mind that "exit;" will close the whole script, while
CTRL+Z will only close the prompt and the script will continue runing!

Therefore you should use "exit;" with caution.

psh $PSH::VERSION by Jenda\@Krynicky.cz
*END*
}

"I am an excellent programmer"; # A required file must return a true value ;-)

__END__

=head1 NAME

PSH - perl shell

Version 0.7

=head1 SYNOPSIS

 use PSH;
 ...
 PSH::prompt;

=head1 DESCRIPTION

This module provides a "perl command prompt" facility for your program.
You may do some processing and then simply call PSH::prompt to allow
the user to finish the task if something went wrong by calling the functions
of your program.

I use it for example at the end of the Golem (peoplemeter data processing software)
import script. Sometimes I get not only the new data, but also some
repairs of old ones and sometimes some stage of import fails.
This perl prompt at the end of the script allows me to fix such problems "by hand".

=head2 Usage

This module provides two functions, PSH::prompt and PSH::welcome.
The first prints the "perl$" prompt, waits for user interaction and executes the entered
commands. The user then closes the prompt by pressing CTRL-D (Unix/Mac) or CTRL-Z (Windoze).

All commands are processed in the same package from which PSH::prompt was
called. You may access all global or local() variables, but of course not
my() variables.

The call to PSH::prompt returns the value of the last executed statement.


Since version 0.4 you may pass two parameters to PSH::prompt :

 PSH::prompt [$prompttext, [ \&evalsub ] ]

The first sets the prompt used by the module, the second sets the function used
to evaluate the code you entered. Default is

 PSH::prompt 'perl', \&eval;

The second function prints out the version info.

=head2 Prompt

Commands starting by ! are passed to the command prompt,
If the line ends by >, the output of the command is redirected to
variable $it. If you want to catch both STDOUT and STDERR use this:

 perl$ ! command 2>&1 >

All other commands are supposed to be a perl code.

The code to be evaluated may be entered in two ways
or use something like heredoc

If the first line in a new command starts with <<, the rest of the line
is considered as the heredoc delimiter. As long as you do not enter a
line containing only those characters, the lines are only appended into
a variable. As soon as you close the heredoc, the code is evaluated.

Otherwise the code you enter is evaluated as soon as you enter a line
finished by a semicolon.

The value of the last command may be found in $it.

You may exit this "shell" by either "exit;" or CTRL+Z.
Please keep in mind that "exit;" will close the whole script, while
CTRL+Z will only close the prompt and the script will continue running!

Therefore you should use "exit;" with caution.

=head2 PSH.config

In the same directory as PSH.pm may be also file PSH.config.
This file will be "required" whenever you use PSH. You may add some
function definitions and variables there.

Please keep in mind that this file is required in PSH package so
the variables and functions you define therein are in this package by default!

Also keep in mind that this file is require()d!
The last statement in this file MUST return a true value!!!
And there must be some command in the file! At least

    1;

You should not do any changes to PSH.pm cause it would
be quite hard to upgrade then. If possible, do the necessary personalization
through PSH.config. If you find something that would be useful for other people,
or something you cannot do from within PSH.config, contact me.
I'm always open to suggestions and additions :-)

=head2 Options and settings

 $PSH::allowsystem = should the prompt allow executing system
 commands through "! command" ? Default = yes.

 %PSH::alias = a hash of aliases for commands.
  Every time you enter a line starting with an exclamation mark,
  the first word is looked up in this hash and if a match is found,
  this word is replaced by the value from the hash.
  All keys in this hash should be lowercase, the match is case-insensitive.

  You will probably want to populate this hash according to macros in
  your preferred shell or OS. On my pages you may find examples for
  reading doskey macros and applications registered to Windoze.

 %PSH::specials = a hash of specials
  This hash allows you to install additional special characters
  similar to "!". If PSH sees a special character (a key from
  this hash), it calls the specified function for that character
  (the value). Actually it doesn't have to be a character :-)

  Default : $PSH::specials{'!'} = \&PSH::Exec;

  You should not modify this hash directly, you'd better use function
  PSH::specials :

   PSH::specials '^' => \&foo;
   PSH::specials '!' => undef;

  Otherwise the change may be ignored !

=head2 Example

    use PSH;
    END {PSH::prompt unless $OK}
    $do->some('processing) or die "Error : $do->{error}!\n";
    some(more->commands) or die "Error : some went wrong!\n";
    $OK=1;
    __END__

This will allow the user to do some by-hand cleansing if an error occures.

    use PSH;
    PSH::prompt 'hello', sub {print $_[0]};

=head2 Ussage example

 perl$ print 45+6;
 51
 perl$ print 12
 perl>  + 15;
 27
 perl$ sub Foo {
 perl>  print "Foo called\n";

 ERROR: Missing right bracket at (eval 3) line 5, at end of line
 syntax error at (eval 3) line 5, at EOF

 perl$ sub Foo {
 perl>  print "Foo called\n"; #
 perl> };

 perl$ Foo;
 Foo called

 perl$ <<END
 perl(END)$ sub Bar {
 perl(END)$  my $arg = shift;
 perl(END)$  print "Bar called with ($arg)\n";
 perl(END)$ }
 perl(END)$ END

 perl$ Bar(45);
 Bar called with (45)

 perl$ ^Z

 c:\>

=head2 AUTHOR

Jenda@Krynicky.cz

=cut
