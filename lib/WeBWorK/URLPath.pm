################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK.pm,v 1.49 2004/02/21 10:15:58 toenail Exp $
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

=head1 VIRTUAL HEIRARCHY

 root                                /
 
 set_list                            /$courseID/
 
 equation_display                    /$courseID/equation/
 feedback                            /$courseID/feedback/
 gateway_quiz                        /$courseID/quiz_mode/$setID/
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

# 
# NOTE: see below for the implementation of the WeBWorK::URLPath class.
# 

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
		kids    => [ qw/equation_display feedback gateway_quiz hardcopy logout
			options instructor_tools problem_list
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
		name    => 'Logout',
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
# low level functions for traversing the path types tree
################################################################################

sub getpathType($) {
	my ($path) = @_;
	
	my %args;
	my $context = visitPathTypeNode("root", $path, \%args, 0);
	
	return $context, %args;
}

sub reconstructPath($) {
	my ($type) = @_;
	
	my $path = "";
	
	while ($type) {
		$path = $pathTypes{$type}->{produce} . $path;
		$type = $pathTypes{$type}->{parent};
	};
	
	return $path;
}

sub debug { print STDERR "visitPathTypeNode: ", @_; }

sub visitPathTypeNode($$$$);

sub visitPathTypeNode($$$$) {
	my ($nodeID, $path, $argsRef, $indent) = @_;
	debug("\t"x$indent, "visiting node $nodeID with path $path\n");
	
	unless (exists $pathTypes{$nodeID}) {
		debug("\t"x$indent, "node $nodeID doesn't exist in node list: failed\n");
		die "node $nodeID doesn't exist in node list: failed";
	}
	
	my %node = %{ $pathTypes{$nodeID} };
	my $match = $node{match};
	my @capture_names = @{ $node{capture} };
	
	debug("\t"x$indent, "trying to match $match: ");
	# FIXME: we need to test for match success and collect captures
	# perhaps we could use m// to get captures, and then use s/// to get rid of the match
	# this would be two REs per node, but they're already precompiled
	if ($path =~ s/($match)//) {
		debug("success!\n");
		my @capture_values = $1 =~ m/$match/;
		#debug("\t"x$indent, "\@capture_names=@capture_names\n");
		#debug("\t"x$indent, "\@capture_values=@capture_values\n");
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
				debug("\t"x$indent, "setting argument $name => $value.\n");
				$argsRef->{$name} = $value;
			}
		}
	} else {
		debug("failed.\n");
		return 0;
	}
	
	if ($path eq "") {
		debug("\t"x$indent, "no path left, type is $nodeID\n");
		return $nodeID;
	}
	
	debug("\t"x$indent, "but path remains: $path\n");
	my @kids = @{ $node{kids} };
	if (@kids) {
		foreach my $kid (@kids) {
			debug("\t"x$indent, "trying child $kid:\n");
			my $result = visitPathTypeNode($kid, $path, $argsRef, $indent+1);
			return $result if $result;
		}
		debug("\t"x$indent, "no children claimed the remaining path: failed.\n");
	} else {
		debug("\t"x$indent, "no children to claim the remaining path: failed.\n");
	}
	return 0;
}

################################################################################
# the WeBWorK::URLPath class
################################################################################

=head1 CONSTRUCTORS

=over

=item new

Creates an empty WeBWorK::URLPath. Don't use this, use C<newFromPath> instead.

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

=item newFromType($type, $argsRef)

Creates a new WeBWorK::URLPath given a type name and a hashref containing type
arguments. You will probably never use this. Use C<newFromPath> instead.

=cut

sub newFromType {
	my ($invocant, $type, %args) = @_;
	return $invocant->new(
		type => $type,
		args => \%args,
	);
}

=item newFromPath($path)

Creates a new WeBWorK::URLPath by parsing the path given in C<$path>. It the
path is invalid, an undefined value is returned.

=cut

sub newFromPath {
	my ($invocant, $path) = @_;
	my ($type, %args) = getpathType($path);
	return undef unless $type;
	return $invocant->new(
		type => $type,
		args => \%args,
	);
}

=back

=head1 METHODS

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
	
	return $self->newFromType($newType, %newArgs);
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
		return $self->newFromType($newType, %newArgs);
	} else {
		return undef;
	}
}

=item name()

Returns the name of this WeBWorK::URLPath.

=cut

sub name {
	my ($self) = @_;
	my $type = $self->{type};
	my %args = $self->args;
	my $name = $pathTypes{$type}->{name};
	$name =~ s/\$(\w+)/$args{$1} || "\$$1"/eg; # variable interpolation
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

=item args()

Returns a hash of arguments derived from the WeBWorK::URLPath.

=cut

sub args {
	my ($self) = @_;
	return %{ $self->{args} };
}

=item arg($name)

Returns the named argument, as derived from the WeBWorK::URLPath.

=cut

sub arg {
	my ($self, $name) = @_;
	return $self->{args}->{$name};
}

=item path(%newArgs)

Reconstructs the path string from a WeBWorK::URLPath. The contents of
C<%newArgs> will override the arguments stored in the URLPath.

=cut

sub path {
	my ($self, %newArgs) = @_;
	
	my %args = (
		%{ $self->{args} },
		%newArgs,
	);
	
	my $path = reconstructPath($self->{type});
	$path =~ s/\$(\w+)/$args{$1} || "\$$1"/eg; # variable interpolation
	return $path;
}

1;
