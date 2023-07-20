################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Login - display a login form.

=cut

use WeBWorK::Utils qw(readFile jitar_id_to_seq format_set_name_display);

sub page_title ($c) {
	# If the url is for a problem page, then the title is the set and problem id.
	my $problemID = $c->stash('problemID');
	if ($problemID) {
		my $setID = $c->stash('setID');

		# Print the pretty version of the problem id for a jitar set.
		my $set = $c->db->getGlobalSet($setID);
		if ($set && $set->assignment_type eq 'jitar') {
			$problemID = join('.', jitar_id_to_seq($problemID));
		}

		return $c->maketext('[_1]: Problem [_2]',
			$c->tag('span', dir => 'ltr', format_set_name_display($setID)), $problemID);
	}

	return $c->SUPER::page_title();
}

sub info ($c) {
	my $ce = $c->ce;

	my $result = $c->c;

	# This section should be kept in sync with the Home.pm version.

	# List the login info first.
	# Login info is relative to the templates directory.
	push(
		@$result,
		$c->output_info_file(
			$c->maketext('Login Info'),
			"$ce->{courseDirs}{templates}/$ce->{courseFiles}{login_info}"
		)
	) if ($ce->{courseFiles}{login_info});

	push(@$result, $c->output_info_file($c->maketext('Site Information'), $ce->{webworkFiles}{site_info}))
		if $ce->{webworkFiles}{site_info};

	return $result->join('');
}

sub output_info_file ($c, $info_title, $info_file) {
	if (-f $info_file) {
		my $text = eval { readFile($info_file) };
		if ($@) {
			return $c->tag('h2', $info_title) . $c->tag('div', class => 'alert alert-danger p-1 mb-2', $@);
		} elsif ($text =~ /\S/) {
			return $c->tag('h2', $info_title) . $text;
		}
	}

	return '';
}

# Override the can method to disable links for the login page.
sub can ($c, $arg) {
	return $arg eq 'links' ? 0 : $c->SUPER::can($arg);
}

sub pre_header_initialize ($c) {
	my $ce     = $c->ce;
	my $authen = $c->authen;

	if ($authen->{redirect}) {
		$c->reply_with_redirect($authen->{redirect});
		return;
	}

	# This should be set in the course environment when a sequence of authentication modules is used.
	$c->stash->{externalAuth} = $ce->{external_auth} || $authen->{external_auth};

	my $hidden_fields = '';
	my @allowedGuestUsers;

	if (!$c->stash->{externalAuth}) {
		# Preserve the form data posted to the requested URI
		my @fields_to_print = grep { !m/^(user|passwd|key|force_passwd_authen)$/ } $c->param;

		# Important note. If hidden_fields is passed an empty array it prints ALL parameters as hidden fields.
		# That is not what we want in this case, so we don't print at all if @fields_to_print is empty.
		$hidden_fields = $c->hidden_fields(@fields_to_print) if (@fields_to_print);

		# Determine if there are valid practice users.
		my @GuestUsers = $c->db->getUsersWhere({ user_id => { like => "$ce->{practiceUserPrefix}\%" } });
		for my $GuestUser (@GuestUsers) {
			next unless defined $GuestUser->status;
			next unless $GuestUser->status ne '';
			push @allowedGuestUsers, $GuestUser
				if $ce->status_abbrev_has_behavior($GuestUser->status, 'allow_course_access');
		}
	}

	$c->stash->{hidden_fields}     = $hidden_fields;
	$c->stash->{allowedGuestUsers} = \@allowedGuestUsers;

	return;
}

sub head ($c) {
	return $c->tag('meta', name => 'robots', content => $c->ce->{options}{metaRobotsContent} // 'none');
}

1;
