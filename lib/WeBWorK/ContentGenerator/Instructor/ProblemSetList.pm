package WeBWorK::ContentGenerator::Instructor::ProblemSetList;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetList - Entry point for Problem and Set editing

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(formatDateTime);
use WeBWorK::DB::Record::Set;

sub initialize {
	my $self = shift;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $courseName = $ce->{courseName};
	
	if (defined($r->param('deleteSelected'))) {
		foreach my $wannaDelete ($r->param('selectedSet')) {
			$db->deleteGlobalSet($wannaDelete);
		}
	} elsif (defined($r->param('makeNewSet'))) {
		my $newSetRecord = WeBWorK::DB::Record::Set->new();
		my $newSetName = $r->param('newSetName');
		$newSetRecord->set_id($newSetName);
		$db->addGlobalSet($newSetRecord) unless $db->getGlobalSet($newSetName);
	}

}

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
	my $URL = $r->uri;
	my $instructorBaseURL = "$root/$courseName/instructor";
	my $setEditorURL = "$instructorBaseURL/problemSetEditor/";
	my $importURL = "$instructorBaseURL/problemSetImport/";
	my $addURL = "$instructorBaseURL/problemSetAdd/";
	my $sort = $r->param('sort') ? $r->param('sort') : "due_date";
	
	# Slurp each set record for this course in @sets
	# Gather data from the database
	my @users = $db->listUsers;
	my @sets;
	my %counts;
	my %problemCounts;
	foreach my $set_id ($db->listGlobalSets) {
		my $set = $db->getGlobalSet($set_id);
		push @sets, $set;
		$problemCounts{$set_id} = scalar($db->listGlobalProblems($set_id));
		my $count = 0;
		$counts{$set_id} = $db->listSetUsers($set_id);
	}
	
	# Sort @sets based on the sort parameter
	# Invalid sort types will just cause an unpredictable ordering, which is no big deal.
	@sets = sort {
		if ($sort eq "set_id") {
			return $a->$sort cmp $b->$sort;
		}elsif ($sort =~ /_date$/) {
			return $a->$sort <=> $b->$sort;
		} elsif ($sort eq "num_probs") {
			return $problemCounts{$a->set_id} <=> $problemCounts{$b->set_id};
		} elsif ($sort eq "num_students") {
			return $counts{$a->set_id} <=> $counts{$b->set_id};
		}
	} @sets;
	
	my $table = CGI::Tr({}, 
		CGI::th("Sel.")
		. CGI::th(CGI::a({"href"=>$URL."?".$self->url_authen_args."&sort=set_id"},       "ID"))
		. CGI::th(CGI::a({"href"=>$URL."?".$self->url_authen_args."&sort=open_date"},    "Open Date"))
		. CGI::th(CGI::a({"href"=>$URL."?".$self->url_authen_args."&sort=due_date"},     "Due Date"))
		. CGI::th(CGI::a({"href"=>$URL."?".$self->url_authen_args."&sort=answer_date"},  "Answer Date"))
		. CGI::th(CGI::a({"href"=>$URL."?".$self->url_authen_args."&sort=num_probs"},    "Num. Problems"))
		. CGI::th(CGI::a({"href"=>$URL."?".$self->url_authen_args."&sort=num_students"}, "Assigned to:"))
	) . "\n";
	
	foreach my $set (@sets) {
		my $count = $counts{$set->set_id};
		
		my $userCountMessage;
		if ($count == 0) {
			$userCountMessage = "Not assigned";
		} elsif ($count == scalar(@users)) {
			$userCountMessage = "All users";
		} elsif ($count == 1) {
			$userCountMessage = "1 user";
		} elsif ($count > scalar(@users) || $count < 0) {
			$userCountMessage = CGI::em("Impossible number of users: $count");
		} else {
			$userCountMessage = "$count users";
		}
	
		$table .= CGI::Tr({}, 
			CGI::td({}, 
				CGI::checkbox({
					"name"=>"selectedSet",
					"value"=>$set->set_id,
					"label"=>"",
					"checked"=>"0"
				})
			)
			. CGI::td({}, CGI::a({href=>"$setEditorURL".$set->set_id."/?".$self->url_authen_args}, $set->set_id))
			. CGI::td({}, formatDateTime($set->open_date))
			. CGI::td({}, formatDateTime($set->due_date))
			. CGI::td({}, formatDateTime($set->answer_date))
			. CGI::td({}, $problemCounts{$set->set_id})
			. CGI::td({}, $userCountMessage)
		) . "\n"
	}
	$table = CGI::table({"border"=>"1"}, "\n".$table."\n");

	my $form = CGI::start_form({"method"=>"POST", "action"=>""})."\n" # This form is for deleting sets, and points to itself
		. $table."\n"
		. CGI::br()."\n"
		. $self->hidden_authen_fields."\n"
		. CGI::submit({"name"=>"deleteSelected", "label"=>"Delete Selected"})."\n"
		. CGI::end_form()."\n"
		. CGI::start_form({"method"=>"POST", "action"=>$addURL})."\n"
		. $self->hidden_authen_fields."\n"
		. CGI::submit({"name"=>"addSet", "label"=>"New"})."\n"
		. CGI::end_form()."\n"
		. CGI::start_form({"method"=>"POST", "action"=>$importURL})."\n"
		. $self->hidden_authen_fields."\n"
		. CGI::submit({"name"=>"importSet", "label"=>"Import"})."\n"
		. CGI::end_form()."\n";
	print $form;
	print CGI::br();
	
	return "";
}

1;
