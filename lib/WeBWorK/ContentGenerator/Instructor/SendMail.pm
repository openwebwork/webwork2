package WeBWorK::ContentGenerator::Instructor::SendMail;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SendMail - Entry point for User-specific data editing

=cut

use strict;
use warnings;
use CGI qw();

sub initialize {
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $user = $r->param('user');

	unless ($authz->hasPermissions($user, "send_mail")) {
		$self->{submitError} = "You are not authorized to send mail to students.";
		return;
	}
	
# 	if (defined($r->param('save_classlist'))) {
# 		my @userList = $db->listUsers;
# 		foreach my $user (@userList) {
# 			my $userRecord = $db->getUser($user);
# 			my $permissionLevelRecord = $db->getPermissionLevel($user);
# 			foreach my $field ($userRecord->NONKEYFIELDS()) {
# 				my $paramName = "user.${user}.${field}";
# 				if (defined($r->param($paramName))) {
# 					$userRecord->$field($r->param($paramName));
# 				}
# 			}
# 			foreach my $field ($permissionLevelRecord->NONKEYFIELDS()) {
# 				my $paramName = "permission.${user}.${field}";
# 				if (defined($r->param($paramName))) {
# 					$permissionLevelRecord->$field($r->param($paramName));
# 				}
# 			}
# 			$db->putUser($userRecord);
# 			$db->putPermissionLevel($permissionLevelRecord);
# 		}
# 		foreach my $userID ($r->param('deleteUser')) {
# 			$db->deleteUser($userID);
# 		}
# 	} elsif (defined($r->param('addStudent'))) {
# 		my $newUser = $db->newUser;
# 		my $newPermissionLevel = $db->newPermissionLevel;
# 		my $newPassword = $db->newPassword;
# 		$newUser->user_id($r->param('newUserID'));
# 		$newPermissionLevel->user_id($r->param('newUserID'));
# 		$newPassword->user_id($r->param('newUserID'));
# 		$newUser->status('C');
# 		$newPermissionLevel->permission(0);
# 		$db->addUser($newUser);
# 		$db->addPermissionLevel($newPermissionLevel);
# 		$db->addPassword($newPassword);
# 	}
}

sub fieldEditHTML {
	my ($self, $fieldName, $value, $properties) = @_;
	my $size = $properties->{size};
	my $type = $properties->{type};
	my $access = $properties->{access};
	my $items = $properties->{items};
	my $synonyms = $properties->{synonyms};
	
	
	if ($access eq "readonly") {
		return $value;
	}
	if ($type eq "number" or $type eq "text") {
		return CGI::input({type=>"text", name=>$fieldName, value=>$value, size=>$size});
	}
	if ($type eq "enumerable") {
		my $matched = undef; # Whether a synonym match has occurred

		# Process synonyms for enumerable objects
		foreach my $synonym (keys %$synonyms) {
			if ($synonym ne "*" and $value =~ m/$synonym/) {
				$value = $synonyms->{$synonym};
				$matched = 1;
			}
		}
		if (!$matched and exists $synonyms->{"*"}) {
			$value = $synonyms->{"*"};
		}
		return CGI::popup_menu({
			name => $fieldName, 
			values => [keys %$items],
			default => $value,
			labels => $items,
		});
	}
}

sub title {
	my $self = shift;
	return 'Send mail to ' .$self->{ce}->{courseName};
}

sub path {
	my $self          = shift;
	my $args          = $_[-1];
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home"          => "$root",
		$courseName     => "$root/$courseName",
		'instructor'    => "$root/$courseName/instructor",
		"Send Mail to: $courseName"      => '',
	);
}

sub body {
	my ($self, $setID) = @_;
	my $r = $self->{r};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};

        return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	my $userTemplate = $db->newUser;
	my $permissionLevelTemplate = $db->newPermissionLevel;
	
	# This code will require changing if the permission and user tables ever have different keys.
	my @users = $db->listUsers;

	# This table can be consulted when display-ready forms of field names are needed.
	my %prettyFieldNames = map {$_ => $_} ($userTemplate->FIELDS(), $permissionLevelTemplate->FIELDS());
	@prettyFieldNames{qw(
		user_id 
		first_name 
		last_name 
		email_address 
		student_id 
		status 
		section 
		recitation 
		comment 
		permission
	)} = (
		"User ID", 
		"First Name", 
		"Last Name", 
		"E-mail", 
		"Student ID", 
		"Status", 
		"Section", 
		"Recitation", 
		"Comment", 
		"Perm. Level"
	);

	my %fieldProperties = (
		user_id => {
			type => "text",
			size => 8,
			access => "readonly",
		},
		first_name => {
			type => "text",
			size => 10,
			access => "readwrite",
		},
		last_name => {
			type => "text",
			size => 10,
			access => "readwrite",
		},
		email_address => {
			type => "text",
			size => 20,
			access => "readwrite",
		},
		student_id => {
			type => "text",
			size => 11,
			access => "readwrite",
		},
		status => {
			type => "enumerable",
			size => 4,
			access => "readwrite",
			items => {
				"C" => "Enrolled",
				"D" => "Drop",
				"A" => "Audit",
			},
			synonyms => {
				qr/^[ce]/i => "C",
				qr/^[dw]/i => "D",
				qr/^a/i => "A",
				"*" => "C",
			}
		},
		section => {
			type => "text",
			size => 4,
			access => "readwrite",
		},
		recitation => {
			type => "text",
			size => 4,
			access => "readwrite",
		},
		comment => {
			type => "text",
			size => 20,
			access => "readwrite",
		},
		permission => {
			type => "number",
			size => 2,
			access => "readwrite",
		}
	);
	
	print CGI::start_form({method=>"post", action=>$r->uri()});
	
##############################################################################################################
	
#	my ($ar_sortedNames, $hr_classlistLabels) = getClasslistFilesAndLabels($course);
#	my @sortedNames = @$ar_sortedNames;
	my %classlistLabels = ();#  %$hr_classlistLabels;
	unshift(@users, "None");
	$classlistLabels{None} = 'None';
my ($from,$subject,$replyTo,$text,$columns,$rows,$messageFileName); #FIXME
$rows = 20; $columns=120; $messageFileName='';
#create list of sudents
# show professors's name and email address
# show replyTo field and From field
    print CGI::start_table({-border=>'2', -cellpadding=>'4'});
    print CGI::Tr({-align=>'RIGHT',-valign=>'VCENTER'},
		 CGI::td("\n", CGI::p( CGI::b('From:     '), CGI::textfield(-name=>"from", -size=>40, -value=>$from, -override=>1),      ),
				 "\n", CGI::p( CGI::b('Reply-To: '), CGI::textfield(-name=>"replyTo", -size=>40, -value=>$replyTo, -override=>1), ),
				 "\n", CGI::p( CGI::b('Subject:  '), CGI::textfield(-name=>'subject', -default=>$subject, -size=>40, -override=>1),  ),
		),
		CGI::td(
		    'Select&nbsp;recipients'.CGI::br().
			CGI::popup_menu(-name=>'classList',
					   -values=>\@users,
					   -labels=>\%classlistLabels,
					   -size  => 10,
					   -multiple => 1,
					   -default=>'None'
			)
		),
		CGI::td(
		#show available macros
 				CGI::popup_menu(
						-name=>'dummyName',
						-values=>['', '$SID', '$FN', '$LN', '$SECTION', '$RECITATION','$STATUS', '$EMAIL', '$LOGIN', '$COL[3]', '$COL[-1]'],
						-labels=>{''=>'These macros can be used to insert student specific data:',
							'$SID'=>'$SID - Student ID',
							'$FN'=>'$FN - First name',
							'$LN'=>'$LN - Last name',
							'$SECTION'=>'$SECTION - Student\'s Section',
							'$RECITATION'=>'$RECITATION - Student\'s Recitation',
							'$STATUS'=>'$STATUS - C, Audit, Drop, etc.',
							'$EMAIL'=>'$EMAIL - Email address',
							'$LOGIN'=>'$LOGIN - Login',
							'$COL[3]'=>'$COL[3] - Third column in merge file',
							'$COL[-1]'=>'$COL[-1] - Last column in merge file'
							}
				), "\n",
		),

	);
	print CGI::end_table();	 
#create a textbox with the subject and a textarea with the message

#print actual body of message
    print  CGI::p( 
		 	CGI::submit(-name=>'action', -value=>'Revert to original and Resize message window'),
		 	" Rows: ", CGI::textfield(-name=>'rows', -size=>3, -value=>$rows),
		 	" Columns: ", CGI::textfield(-name=>'columns', -size=>3, -value=>$columns),CGI::br(),
		 "If you resize the message window, you will lose all unsaved changes."
	);
		  
    print  "\n", CGI::p( CGI::textarea(-name=>'body', -default=>$text, -rows=>$rows, -columns=>$columns, -override=>1)
    );
#create all necessary action buttons
	print CGI::p(CGI::submit(-name=>'action', -value=>'Open'), "\n",  
			 CGI::textfield(-name=>'savefilename', -size => 20, -value=> "$messageFileName", -override=>1), ' ',
			 CGI::submit(-name=>'action', -value=>'Save'), " \n",
			 CGI::submit(-name=>'action', -value=>'Save as'), " \n",
			 CGI::submit(-name=>'action', -value=>'Save as Default'), 
			 CGI::submit(-name=>'action', -value=>'Send Email'), "\n", CGI::br(),
			 'For "Save As" choose a new filename.', 
		 );
			   
##############################################################################################################
	# Table headings, prettied-up
# 	print CGI::start_table({});
# 	print CGI::Tr({},
# 		CGI::th({}, [
# 			"Delete?",
# 			map {$prettyFieldNames{$_}} (
# 				$userTemplate->KEYFIELDS(),
# 				$userTemplate->NONKEYFIELDS(),
# 				$permissionLevelTemplate->NONKEYFIELDS(),
# 			)
# 		])
# 	);
# 	
# 	foreach my $currentUser (@users) {
# 		my $userRecord = $db->getUser($currentUser);
# 		my $permissionLevel = $db->getPermissionLevel($currentUser);
# 		unless (defined $permissionLevel) {
# 			warn "No permissionLevel record for user $currentUser" ;
# 			next;  
# 		}
# 		
# 		# A concise way of printing a row containing a cell for each field, editable unless it's a key
# 		print CGI::Tr({},
# 			CGI::td({}, [
# 				CGI::input({type=>"checkbox", name=>"deleteUser", value=>$currentUser}),
# 				(
# 					map {
# 						my $changeEUserURL = "$root/$courseName?user=".$r->param("user")."&effectiveUser=".$userRecord->user_id()."&key=".$r->param("key");
# 						CGI::a({href=>$changeEUserURL}, $userRecord->$_)
# 					} $userRecord->KEYFIELDS
# 				),
# 				(map {
# #					CGI::input({type=>"text", size=>"8", name=> "user.".$userRecord->user_id().".".$_, value=>$userRecord->$_})
# 					$self->fieldEditHTML("user.".$userRecord->user_id().".".$_, $userRecord->$_, $fieldProperties{$_});
# 				} $userRecord->NONKEYFIELDS()), 
# 				(map {
# #					CGI::input({type=>"text", size=>"8", name => "permission.".$permissionLevel->user_id().".".$_, value=>$permissionLevel->$_})
# 					$self->fieldEditHTML("permission.".$permissionLevel->user_id().".".$_, $permissionLevel->$_, $fieldProperties{$_});
# 				} $permissionLevel->NONKEYFIELDS()),
# 			])
# 		);
# 	}
# 	
# 	print CGI::end_table();
	print $self->hidden_authen_fields();
	print CGI::submit({name=>"save_classlist", value=>"Save Changes to Users"});
	print CGI::end_form();
	
	# Add a student form
# 	print CGI::start_form({method=>"post", action=>$r->uri()});
# 	print $self->hidden_authen_fields();
# 	print "User ID:";
# 	print CGI::input({type=>"text", name=>"newUserID", value=>"", size=>"20"});
# 	print CGI::submit({name=>"addStudent", value=>"Add Student"});
# 	print CGI::end_form();
	
	return "";
}

1;
