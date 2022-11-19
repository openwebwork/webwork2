################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::Login;
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Login - display a login form.

=cut

use strict;
use warnings;

use WeBWorK::Utils qw(readFile jitar_id_to_seq format_set_name_display);

sub title {
	my ($self) = @_;
	my $r = $self->r;

	# If the url is for a problem page, then the title is the set and problem id.
	my $problemID = $self->r->urlpath->arg('problemID');
	if ($problemID) {
		my $setID = $self->r->urlpath->arg('setID');

		# Print the pretty version of the problem id for a jitar set.
		my $set = $r->db->getGlobalSet($setID);
		if ($set && $set->assignment_type eq 'jitar') {
			$problemID = join('.', jitar_id_to_seq($problemID));
		}

		return $r->maketext('[_1]: Problem [_2]',
			$r->tag('span', dir => 'ltr', format_set_name_display($setID)), $problemID);
	}

	return $self->SUPER::title();
}

sub info {
	my $self = shift;
	my $r    = $self->r;
	my $ce   = $r->ce;

	my $result = $r->c;

	# This section should be kept in sync with the Home.pm version.

	# List the login info first.
	# Login info is relative to the templates directory.
	push(
		@$result,
		$self->output_info_file(
			$r->maketext('Login Info'),
			"$ce->{courseDirs}{templates}/$ce->{courseFiles}{login_info}"
		)
	) if ($ce->{courseFiles}{login_info});

	push(@$result, $self->output_info_file($r->maketext('Site Information'), $ce->{webworkFiles}{site_info}))
		if $ce->{webworkFiles}{site_info};

	return $result->join('');
}

sub output_info_file {
	my ($self, $info_title, $info_file) = @_;
	my $r = $self->r;

	if (-f $info_file) {
		my $text = eval { readFile($info_file) };
		if ($@) {
			return $r->tag('h2', $info_title) . $r->tag('div', class => 'alert alert-danger p-1 mb-2', $@);
		} elsif ($text =~ /\S/) {
			return $r->tag('h2', $info_title) . $text;
		}
	}

	return '';
}

# Override the can method to disable links for the login page.
sub can {
	my ($self, $arg) = @_;
	return $arg eq 'links' ? 0 : $self->SUPER::can($arg);
}

async sub pre_header_initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $authen = $r->authen;

	if ($authen->{redirect}) {
		$self->reply_with_redirect($authen->{redirect});
		return;
	}

	# The following check may not work when a sequence of authentication modules are used, because the preferred module
	# might be external, e.g., LTIBasic, but a non-external one, e.g., Basic_TheLastChance or even just WeBWorK::Authen,
	# might handle the ongoing session management.  So this should be set in the course environment when a sequence of
	# authentication modules is used.
	$r->stash->{externalAuth} = $ce->{external_auth} || $authen->{external_auth};

	my $hidden_fields = '';
	my @allowedGuestUsers;

	if (!$r->stash->{externalAuth}) {
		# Preserve the form data posted to the requested URI
		my @fields_to_print = grep { !m/^(user|passwd|key|force_passwd_authen)$/ } $r->param;

		# Important note. If hidden_fields is passed an empty array it prints ALL parameters as hidden fields.
		# That is not what we want in this case, so we don't print at all if @fields_to_print is empty.
		$hidden_fields = $self->hidden_fields(@fields_to_print) if (@fields_to_print);

		# Determine if there are valid practice users.
		my @GuestUsers = $r->db->getUsersWhere({ user_id => { like => "$ce->{practiceUserPrefix}\%" } });
		for my $GuestUser (@GuestUsers) {
			next unless defined $GuestUser->status;
			next unless $GuestUser->status ne '';
			push @allowedGuestUsers, $GuestUser
				if $ce->status_abbrev_has_behavior($GuestUser->status, 'allow_course_access');
		}
	}

	$r->stash->{hidden_fields}     = $hidden_fields;
	$r->stash->{allowedGuestUsers} = \@allowedGuestUsers;

	return;
}

sub head {
	my ($self) = @_;
	my $r = $self->r;
	return $r->tag('meta', name => 'robots', content => $r->ce->{options}{metaRobotsContent} // 'none');
}

1;
