################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/URLPath.pm,v 1.3 2004/03/06 18:50:00 gage Exp $
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

package WeBWorK::URLPath;

=head1 NAME

WeBWorK::URLPath - the WeBWorK virtual URL heirarchy.

=cut

use strict;
use warnings;

sub debug {
	my ($label, $indent, @message) = @_;
	print STDERR " "x$indent;
	print STDERR "$label: " if $label ne "";
	print STDERR @message;
}

=head1 VIRTUAL HEIRARCHY

 root                                /
 
 set_list                            /$courseID/
 
 equation_display                    /$courseID/equation/
 feedback                            /$courseID/feedback/
 gateway_quiz                        /$courseID/quiz_mode/$setID/
 grades                              /$courseID/grades/
 hardcopy                            /$courseID/hardcopy/
 hardcopy_preselect_set              /$courseID/hardcopy/$setID/
 logout                              /$courseID/logout/
 options                             /$courseID/options/
 
 instructor_tools                    /$courseID/instructor/
 
 instructor_user_list                /$courseID/instructor/users/
 instructor_user_detail              /$courseID/instructor/users/$userID/
 instructor_sets_assigned_to_user    /$courseID/instructor/users/$userID/sets/
 
 instructor_set_list                 /$courseID/instructor/sets/
 instructor_set_detail               /$courseID/instructor/sets/$setID/
 instructor_problem_list             /$courseID/instructor/sets/$setID/problems/
 [instructor_problem_detail]         /$courseID/instructor/sets/$setID/problems/$problemID/
 instructor_users_assigned_to_set    /$courseID/instructor/sets/$setID/users/
 
 instructor_add_users                /$courseID/instructor/add_users/
 instructor_set_assigner             /$courseID/instructor/assigner/
 instructor_file_transfer            /$courseID/instructor/files/
 
 instructor_problem_editor           /$courseID/instructor/pgProblemEditor/
 instructor_problem_editor_withset   /$courseID/instructor/pgProblemEditor/$setID/
 instructor_problem_editor_withset_withproblem
                                     /$courseID/instructor/pgProblemEditor/$setID/$problemID/
 
 instructor_scoring                  /$courseID/instructor/scoring/
 instructor_scoring_download         /$courseID/instructor/scoringDownload/
 instructor_mail_merge               /$courseID/instructor/send_mail/
 instructor_answer_log               /$courseID/instructor/show_answers/
 instructor_statistics               /$courseID/instructor/stats/
 
 problem_list                        /$courseID/$setID/
 problem_detail                      /$courseID/$setID/$problemID/
     
=cut

################################################################################
# tree of path types
################################################################################

our %pathTypes = (
	root => {
		name    => 'WeBWorK',
		parent  => '',
		kids    => [ qw/set_list/ ],
		match   => qr|^/|,
		capture => [ qw// ],
		produce => '/',
		display => 'WeBWorK::ContentGenerator::Home',
	},
	
	################################################################################
	
	set_list => {
		name    => '$courseID',
		parent  => 'root',
		kids    => [ qw/equation_display feedback gateway_quiz grades hardcopy
			logout options instructor_tools problem_list
		/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/courseID/ ],
		produce => '$courseID/',
		display => 'WeBWorK::ContentGenerator::ProblemSets',
	},
	
	################################################################################
	
	equation_display => {
		name    => 'Equation Display',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^equation/|,
		capture => [ qw// ],
		produce => 'equation/',
		display => 'WeBWorK::ContentGenerator::EquationDisplay',
	},
	feedback => {
		name    => 'Feedback',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^feedback/|,
		capture => [ qw// ],
		produce => 'feedback/',
		display => 'WeBWorK::ContentGenerator::Feedback',
	},
	gateway_quiz => {
		name    => 'Gateway Quiz $setID',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^quiz_mode/([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => 'quiz_mode/$setID/',
		display => 'WeBWorK::ContentGenerator::GatewayQuiz',
	},
	grades => {
		name    => 'Student Grades',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^grades/|,
		capture => [ qw// ],
		produce => 'grades/',
		display => 'WeBWorK::ContentGenerator::Grades',
	},
	hardcopy => {
		name    => 'Hardcopy Generator',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^hardcopy/|,
		capture => [ qw// ],
		produce => 'hardcopy/',
		display => 'WeBWorK::ContentGenerator::Hardcopy',
	},
	hardcopy_preselect_set => {
		name    => 'Hardcopy Generator',
		parent  => 'hardcopy',
		kids    => [ qw// ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => '$setID/',
		display => 'WeBWorK::ContentGenerator::Hardcopy',
	},
	logout => {
		name    => 'Log Out',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^logout/|,
		capture => [ qw// ],
		produce => 'logout/',
		display => 'WeBWorK::ContentGenerator::Logout',
	},
	options => {
		name    => 'User Options',
		parent  => 'set_list',
		kids    => [ qw// ],
		match   => qr|^options/|,
		capture => [ qw// ],
		produce => 'options/',
		display => 'WeBWorK::ContentGenerator::Options',
	},
	
	################################################################################
	
	instructor_tools => {
		name    => 'Instructor Tools',
		parent  => 'set_list',
		kids    => [ qw/instructor_user_list instructor_set_list instructor_add_users
			instructor_set_assigner instructor_file_transfer instructor_problem_editor
			instructor_scoring instructor_scoring_download instructor_mail_merge
			instructor_answer_log instructor_statistics
		/ ],
		match   => qr|^instructor/|,
		capture => [ qw// ],
		produce => 'instructor/',
		display => 'WeBWorK::ContentGenerator::Instructor::Index',
	},
	
	################################################################################
	
	instructor_user_list => {
		name    => 'User List',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_user_detail/ ],
		match   => qr|^users/|,
		capture => [ qw// ],
		produce => 'users/',
		display => 'WeBWorK::ContentGenerator::Instructor::UserList',
	},
	instructor_user_detail => {
		name    => '$userID',
		parent  => 'instructor_user_list',
		kids    => [ qw/instructor_sets_assigned_to_user/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/userID/ ],
		produce => '$userID/',
		display => 'WeBWorK::ContentGenerator::Instructor::UserDetail',
	},
	instructor_sets_assigned_to_user => {
		name    => 'Sets Assigned to User',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_user_detail/ ],
		match   => qr|^sets/|,
		capture => [ qw// ],
		produce => 'sets/',
		display => 'WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser',
	},
	
	################################################################################
	
	instructor_set_list => {
		name    => 'Set List',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_set_detail/ ],
		match   => qr|^sets/|,
		capture => [ qw// ],
		produce => 'sets/',
		display => 'WeBWorK::ContentGenerator::Instructor::ProblemSetList',
	},
	instructor_set_detail => {
		name    => '$setID',
		parent  => 'instructor_set_list',
		kids    => [ qw/instructor_problem_list instructor_users_assigned_to_set/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => '$setID/',
		display => 'WeBWorK::ContentGenerator::Instructor::ProblemSetEditor',
	},
	instructor_problem_list => {
		name    => 'Problems',
		parent  => 'instructor_set_detail',
		kids    => [ qw// ],
		match   => qr|^problems/|,
		capture => [ qw// ],
		produce => 'problems/',
		display => 'WeBWorK::ContentGenerator::Instructor::ProblemList',
	},
	instructor_users_assigned_to_set => {
		name    => 'Users Assigned to Set',
		parent  => 'instructor_set_detail',
		kids    => [ qw// ],
		match   => qr|^users/|,
		capture => [ qw// ],
		produce => 'users/',
		display => 'WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet',
	},
	
	################################################################################
	
	instructor_add_users => {
		name    => 'Add Users',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^add_users/|,
		capture => [ qw// ],
		produce => 'add_users/',
		display => 'WeBWorK::ContentGenerator::Instructor::AddUsers',
	},
	instructor_set_assigner => {
		name    => 'Set Assigner',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^assigner/|,
		capture => [ qw// ],
		produce => 'assigner/',
		display => 'WeBWorK::ContentGenerator::Instructor::Assigner',
	},
	instructor_file_transfer => {
		name    => 'File Transfer',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^files/|,
		capture => [ qw// ],
		produce => 'files/',
		display => 'WeBWorK::ContentGenerator::Instructor::FileXfer',
	},
	instructor_problem_editor => {
		name    => 'Problem Editor',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_problem_editor_withset/ ],
		match   => qr|^pgProblemEditor/|,
		capture => [ qw// ],
		produce => 'pgProblemEditor/',
		display => '',
	},
	instructor_problem_editor_withset => {
		name    => 'Problem Editor',
		parent  => 'instructor_problem_editor',
		kids    => [ qw/instructor_problem_editor_withset_withproblem/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => '$setID/',
		display => '',
	},
	instructor_problem_editor_withset_withproblem => {
		name    => 'Problem Editor',
		parent  => 'instructor_problem_editor_withset',
		kids    => [ qw// ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/problemID/ ],
		produce => '$problemID/',
		display => 'WeBWorK::ContentGenerator::Instructor::PGProblemEditor',
	},
	instructor_scoring => {
		name    => 'Scoring Tools',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^scoring/|,
		capture => [ qw// ],
		produce => 'scoring/',
		display => 'WeBWorK::ContentGenerator::Instructor::Scoring',
	},
	instructor_scoring_download => {
		name    => 'Scoring Download',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^scoringDownload/|,
		capture => [ qw// ],
		produce => 'scoringDownload/',
		display => 'WeBWorK::ContentGenerator::Instructor::ScoringDownload',
	},
	instructor_mail_merge => {
		name    => 'Mail Merge',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^send_mail/|,
		capture => [ qw// ],
		produce => 'send_mail/',
		display => 'WeBWorK::ContentGenerator::Instructor::SendMail',
	},
	instructor_answer_log => {
		name    => 'Answer Log',
		parent  => 'instructor_tools',
		kids    => [ qw// ],
		match   => qr|^show_answers/|,
		capture => [ qw// ],
		produce => 'show_answers/',
		display => 'WeBWorK::ContentGenerator::Instructor::ShowAnswers',
	},
	
	################################################################################
	
	instructor_statistics => {
		name    => 'Statistics',
		parent  => 'instructor_tools',
		kids    => [ qw/instructor_set_statistics instructor_user_statistics/ ],
		match   => qr|^stats/|,
		capture => [ qw// ],
		produce => 'stats/',
		display => 'WeBWorK::ContentGenerator::Instructor::Stats',
	},
	instructor_set_statistics => {
		name    => 'Statistics',
		parent  => 'instructor_statistics',
		kids    => [ qw// ],
		match   => qr|^(set)/([^/]+)/|,
		capture => [ qw/statType setID/ ],
		produce => 'set/$setID/',
		display => 'WeBWorK::ContentGenerator::Instructor::Stats',
	},
	instructor_user_statistics => {
		name    => 'Statistics',
		parent  => 'instructor_statistics',
		kids    => [ qw// ],
		match   => qr|^(student)/([^/]+)/|,
		capture => [ qw/statType userID/ ],
		produce => 'student/$userID/',
		display => 'WeBWorK::ContentGenerator::Instructor::Stats',
	},
	
	################################################################################
	
	problem_list => {
		name    => '$setID',
		parent  => 'set_list',
		kids    => [ qw/problem_detail/ ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/setID/ ],
		produce => '$setID/',
		display => 'WeBWorK::ContentGenerator::ProblemSet',
	},
	problem_detail => {
		name    => '$problemID',
		parent  => 'problem_list',
		kids    => [ qw// ],
		match   => qr|^([^/]+)/|,
		capture => [ qw/problemID/ ],
		produce => '$problemID/',
		display => 'WeBWorK::ContentGenerator::Problem',
	},
	
);

=for comment

a handy template:

	id => {
		name    => '',
		parent  => '',
		kids    => [ qw// ],
		match   => qr|^/|,
		capture => [ qw// ],
		produce => '',
		display => '',
	},

=cut

################################################################################

=head1 CONSTRUCTORS

=over

=item new(%fields)

Creates a new WeBWorK::URLPath. %fields may contain the following:

 type => the internal path type associated with this 
 args => a reference to a hash associating path arguments with values

This constructor is used internally. Refer to newFromPath() and newFromModule()
for more useful constructors.

=cut

sub new {
	my ($invocant, %fields) = @_;
	my $class = ref $invocant || $invocant;
	my $self = {
		type => undef,
		args => {},
		%fields,
	};
	return bless $self, $class;
}

=item newFromPath($path)

Creates a new WeBWorK::URLPath by parsing the path given in $path. It the path
is invalid, an exception is thrown.

=cut

sub newFromPath {
	my ($invocant, $path) = @_;
	
	my ($type, %args) = getPathType($path);
	die "no type matches path $path" unless $type;
	
	return $invocant->new(
		type => $type,
		args => \%args,
	);
}

=item newFromModule($module, %args)

Creates a new WeBWorK::URLPath by finding a path type which matches the module
and path arguments given. If no type matches, an exception is thrown.

=cut

sub newFromModule {
	my ($invocant, $module, %args) = @_;
	
	my $type = getModuleType($module, keys %args);
	die "no type matches module $module with args", map { " $_=>$args{$_}" } keys %args unless $type;
	
	return $invocant->new(
		type => $type,
		args => \%args
	);
}

=back

=cut

################################################################################

=head1 METHODS

=head2 Methods that return information from the object itself

=over

=item type()

Returns the path type of the WeBWorK::URLPath.

=cut

sub type {
	my ($self) = @_;
	my $type = $self->{type};
	
	return $type;
}

=item args()

Returns a hash of arguments derived from the WeBWorK::URLPath.

=cut

sub args {
	my ($self) = @_;
	my %args = %{ $self->{args} };
	
	return %args;
}

=item arg($name)

Returns the named argument, as derived from the WeBWorK::URLPath.

=cut

sub arg {
	my ($self, $name) = @_;
	my %args = %{ $self->{args} };
	
	return $args{$name};
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Methods that return information from path node associated with the object

=over

=item name()

Returns the human-readable name of this WeBWorK::URLPath.

=cut

sub name {
	my ($self) = @_;
	my $type = $self->{type};
	my %args = $self->args;
	
	my $name = $pathTypes{$type}->{name};
	$name = interpolate($name, %args);
	
	return $name;
}

=item module()

Returns the name of the module that will handle this WeBWorK::URLPath.

=cut

sub module {
	my ($self) = @_;
	my $type = $self->{type};
	
	return $pathTypes{$type}->{display};
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 Methods that search the virtual heirarchy

=over

=item parent()

Returns a new WeBWorK::URLPath representing the parent of the current URLPath.
Returns an undefined value if the URLPath has no parent.

=cut

sub parent {
	my ($self) = @_;
	my $type = $self->{type};
	
	my $newType = $pathTypes{$self->{type}}->{parent};
	return undef unless $newType;
	
	# remove any arguments added by the current node (and therefore not needed by the parent)
	my @currArgs = @{ $pathTypes{$type}->{capture} };
	my %newArgs = %{ $self->{args} };
	delete @newArgs{@currArgs} if @currArgs;
	
	return $self->new(type => $newType, args => \%newArgs);
}

=item child($module, %newArgs)

Returns a new WeBWorK::URLPath representing the child of the current URLPath
whose module is C<$module>. If no child matches, an undefined value is returned.
Pass additional arguments needed by the child in C<%newArgs>.

=cut

sub child {
	my ($self, $module, %newArgs) = @_;
	my $type = $self->{type};
	
	my @kids = @{ $pathTypes{$type}->{kids} };
	my $newType;
	foreach my $kid (@kids) {
		if ($pathTypes{$kid}->{module} eq $module) {
			$newType = $kid;
			last;
		}
	}
	
	if ($newType) {
		return $self->new(type => $newType, args => \%newArgs);
	} else {
		return undef;
	}
}

=item path()

Reconstructs the path string from a WeBWorK::URLPath.

=cut

sub path {
	my ($self) = @_;
	my $type = $self->type;
	my %args = %{ $self->{args} };
	
	my $path = buildPathFromType($type);
	$path = interpolate($path, %args);
	
	return $path;
}

=back

=cut

################################################################################

=head1 UTILITY FUNCTIONS

=head2 

=over

=item interpolate($string, %symbols)

Replaces simple scalars (\$\w+) in $string with values in %symbols. If a scalar
does not exist in %symbols, it is left alone.

=cut

sub interpolate {
	my ($string, %symbols) = @_;
	
	$string =~ s/\$(\w+)/exists $symbols{$1} ? $symbols{$1} : "\$$1"/eg;
	
	return $string;
}

=back

=cut

# ------------------------------------------------------------------------------

=head2 

=over

=item getPathType($path)

Parse the string $path, determining the path type. Returns ($type, %args), where
$type is the type of the path and %args contains any extracted path arguments.
If conversion fails, a false value is returned.

=cut

sub getPathType($) {
	my ($path) = @_;
	
	my %args;
	my $context = visitPathTypeNode("root", $path, \%args, 0);
	
	return $context, %args;
}

=item getModuleType($module, @args)

Returns the path type matching the given module and argument names, or a false
value if no type matches.

=cut

sub getModuleType {
	my ($module, @args) = @_;
	@args = sort @args;
	my %args;
	@args{@args} = ();
	
	NODE: foreach my $nodeID (keys %pathTypes) {
		my $node = $pathTypes{$nodeID};
		
		# module name matches?
		next NODE unless $node->{display} eq $module;
		
		# collect all captures from here to root
		my @captures;
		my $tmpNodeID = $nodeID;
		while ($tmpNodeID) {
			my $tmpNode = $pathTypes{$tmpNodeID};
			push @captures, @{ $tmpNode->{capture} };
			$tmpNodeID = $tmpNode->{parent};
		}
		
		# same number of captures?
		next NODE unless @captures == @args;
		
		# same captures?
		@captures = sort @captures;
		for (my $i = 0; $i < @args; $i++) {
			next NODE unless $args[$i] eq $captures[$i];
		}
		
		# if we got here, this node matches
		return $nodeID;
	}
	
	return 0; # no node matches
}

=item buildPathFromType($type)

Returns a string path for the given path type. Since arguments are not supplied,
the string may contain scalar variables ripe for interpolation.

=cut

sub buildPathFromType($) {
	my ($type) = @_;
	
	my $path = "";
	
	while ($type) {
		$path = $pathTypes{$type}->{produce} . $path;
		$type = $pathTypes{$type}->{parent};
	};
	
	return $path;
}

=item visitPathTypeNode($nodeID, $path, $argsRef, $indent)

Internal search function. See getPathType().

=cut

sub visitPathTypeNode($$$$);

sub visitPathTypeNode($$$$) {
	my ($nodeID, $path, $argsRef, $indent) = @_;
	debug("visitPathTypeNode", $indent, "visiting node $nodeID with path $path\n");
	
	unless (exists $pathTypes{$nodeID}) {
		debug("visitPathTypeNode", $indent, "node $nodeID doesn't exist in node list: failed\n");
		die "node $nodeID doesn't exist in node list: failed";
	}
	
	my %node = %{ $pathTypes{$nodeID} };
	my $match = $node{match};
	my @capture_names = @{ $node{capture} };
	
	debug("visitPathTypeNode", $indent, "trying to match $match: ");
	if ($path =~ s/($match)//) {
		debug("", 0, "success!\n");
		my @capture_values = $1 =~ m/$match/;
		if (@capture_names) {
			my $nexpected = @capture_names;
			my $ncaptured = @capture_values;
			my $max = $nexpected > $ncaptured ? $nexpected : $ncaptured;
			warn "captured $ncaptured arguments, expected $nexpected." unless $ncaptured == $nexpected;
			for (my $i = 0; $i < $max; $i++) {
				my $name = $capture_names[$i];
				my $value = $capture_values[$i];
				if ($i > $nexpected) {
					warn "captured an unexpected argument: $value -- ignoring it.";
					next;
				}
				if ($i > $ncaptured) {
					warn "expected an uncaptured argument named: $name -- ignoring it.";
					next;
				}
				if (exists $argsRef->{$name}) {
					my $old = $argsRef->{$name};
					warn "encountered an existing argument again, old value: $old new value: $value -- replacing.";
				}
				debug("visitPathTypeNode", $indent, "setting argument $name => $value.\n");
				$argsRef->{$name} = $value;
			}
		}
	} else {
		debug("", 0, "failed.\n");
		return 0;
	}
	
	if ($path eq "") {
		debug("visitPathTypeNode", $indent, "no path left, type is $nodeID\n");
		return $nodeID;
	}
	
	debug("visitPathTypeNode", $indent, "but path remains: $path\n");
	my @kids = @{ $node{kids} };
	if (@kids) {
		foreach my $kid (@kids) {
			debug("visitPathTypeNode", $indent, "trying child $kid:\n");
			my $result = visitPathTypeNode($kid, $path, $argsRef, $indent+1);
			return $result if $result;
		}
		debug("visitPathTypeNode", $indent, "no children claimed the remaining path: failed.\n");
	} else {
		debug("visitPathTypeNode", $indent, "no children to claim the remaining path: failed.\n");
	}
	return 0;
}

=back

=cut

1;
