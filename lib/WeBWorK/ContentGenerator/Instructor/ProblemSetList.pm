package WeBWorK::ContentGenerator::Instructor::ProblemSetList;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetList - Entry point for Problem and Set editing

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(formatDateTime);

sub title {
	my $self = shift;
	return "Instructor Tools - Problem Set List for ".$self->{ce}->{courseName};
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $user = $r->param('user');
	my $key  = $r->param('key');
	my $effectiveUserName = $r->param('effectiveUser');
	my $urlTarget = "$root/$courseName/instructor/problemSetEditor/";
	
	# FIXME: getGlobalUser* should be getGlobal* once the database
	#        supports it, and the $user field should go away.
	my @sets;
	push @sets, $db->getGlobalUserSet($user, $_)
		foreach ($db->listUserSets($user));
		
	my $table = CGI::Tr({}, 
		CGI::th("Sel.").
		CGI::th("ID").
		CGI::th("Open Date").
		CGI::th("Due Date").
		CGI::th("Answer Date").
		CGI::th("Num. Problems").
		CGI::th("Assigned to:")
	);
	foreach my $set (@sets) {
		my @problems = $db->listUserProblems($user, $set->set_id);
		my @users = $db->listUsers();
		my $count = 0;
		foreach my $user (@users) {
			if ($db->getGlobalUserSet($user, $set->set_id)) {
				# if the user has the set assigned to her
				$count++;
			}
		}
		
		my $userCountMessage;
		if ($count == 0) {
			$userCountMessage = "Not assigned";
		} elsif ($count == 1) {
			$userCountMessage = "1 user";
		} elsif ($count == scalar(@users)) {
			$userCountMessage = "All users";
		} elsif ($count > scalar(@users) || $count < scalar(@users)) {
			$userCountMessage = CGI::em("Impossible number of users: $count");
		} else {
			$userCountMessage = "$count users";
		}
	
		$table .= CGI::Tr({}, 
			CGI::td({}, 
				CGI::checkbox({
					"name"=>"setName", # FIXME: rename "selectedSet"
					"value"=>$set->set_id,
					"label"=>"",
					"checked"=>"0"
				})
			).				
			CGI::td({}, CGI::a({href=>"$urlTarget?setName=".$set->set_id."&".$self->url_authen_args}, $set->set_id)).
			CGI::td({}, formatDateTime($set->open_date)).
			CGI::td({}, formatDateTime($set->due_date)).
			CGI::td({}, formatDateTime($set->answer_date)).
			CGI::td({}, scalar(@problems)).
			CGI::td({}, $userCountMessage)
		) . "\n"
	}
	$table = CGI::table({"border"=>"1"}, $table);
	my $form = CGI::start_form({"method"=>"POST", "action"=>$urlTarget})
		. $table
		. CGI::br()
		. $self->hidden_authen_fields
		. CGI::submit({"name"=>"editSelected", "label"=>"Edit Selected"})
		. CGI::end_form();
	print $form;
	print CGI::br();
	
	return "";
}
1;
