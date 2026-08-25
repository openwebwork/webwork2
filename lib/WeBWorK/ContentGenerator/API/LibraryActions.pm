package WeBWorK::ContentGenerator::API::LibraryActions;
use Mojo::Base 'WeBWorK::ContentGenerator::API', -signatures;

use File::Find;

use WeBWorK::Utils::ListingDB;

our @apiCalls = qw(
	listLib
	searchLib
	getProblemTags
	setProblemTags
);

sub apiCall ($invocant, $command) {
	return (grep { $_ eq $command } @apiCalls) && $invocant->can($command);
}

# Idea from http://www.perlmonks.org/index.pl?node=How%20to%20map%20a%20directory%20tree%20to%20a%20perl%20hash%20tree
sub build_tree ($dirPath) {
	my $tree = {};
	my $node = $tree;
	my @s;
	find(
		{
			wanted => sub {
				unless ($File::Find::dir =~ /.svn/ || $File::Find::name =~ /.svn/) {
					$node = (pop @s)->[1] while @s && $File::Find::dir ne $s[-1][0];
					return $node->{$_} = -s if -f;
					push @s, [ $File::Find::name, $node ];
					$node = $node->{$_} = {};
				}
			},
			follow_fast => 1
		},
		$dirPath
	);
	return { $dirPath => $tree->{'.'} };
}

sub listLib ($c) {
	return $c->renderError('You do not have permission for the listLib API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	my $rh = $c->req->params->to_hash;
	$rh->{library_name} //= 'Library';
	$rh->{library_name} =~ s|^/||;
	my $dirPath  = $c->ce->{courseDirs}{templates} . '/' . $rh->{library_name};
	my $maxdepth = $rh->{maxdepth} // 2;
	my $dirPath2 = $dirPath . (($rh->{dirPath}) ? '/' . $rh->{dirPath} : '');

	my @tare = $dirPath2 =~ m|/|g;
	my @outListLib;
	my %libDirectoryList;

	# Counts depth below the current directory.
	my $depthfinder = sub {
		my $path  = shift;
		my @count = $path =~ m|/|g;
		my $depth = @count;
		return $depth - @tare;
	};

	# Find .pg files.
	my $wanted = sub {
		my $name = $File::Find::name;
		push(@outListLib, $name) if $name =~ /\.pg$/;
	};

	my $wanted_directory = sub {
		my $dir = $File::Find::dir;
		$File::Find::prune = 1 if $depthfinder->($dir) > $maxdepth;
		if ($dir =~ /\S/) {
			$dir =~ s|^$dirPath2/*||;
			$libDirectoryList{$dir} = {};
		}
	};

	my $command = $rh->{command} // 'all';

	if ($command eq 'all') {
		find({ wanted => $wanted, follow_fast => 1 }, $dirPath);
		return $c->render(json => [ sort @outListLib ]);
	}

	if ($command eq 'dirOnly') {
		if (-e $dirPath2 && $dirPath2 !~ m|//|) {
			find({ wanted => $wanted_directory, follow_fast => 1 }, $dirPath2);
			delete $libDirectoryList{''};
			return $c->render(json => \%libDirectoryList);
		} else {
			return $c->renderError("Can't open directory $dirPath2");
		}
	}

	return $c->render(json => build_tree($dirPath)) if $command eq 'buildtree';

	if ($command eq 'files') {
		if (-e $dirPath2 && $dirPath2 !~ m|//|) {
			find({ wanted => $wanted, follow_fast => 1 }, $dirPath2);
			return $c->render(json => [ sort @outListLib ]);
		} else {
			return $c->renderError("Can't open directory  $dirPath2");
		}
	}

	return $c->renderError("Unrecognized command $command");
}

# API for searching the OPL database
sub searchLib ($c) {
	return $c->renderError('You do not have permission for the searchLib API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	my $rh = $c->req->params->to_hash;
	$c->{level} = [ split(//, $rh->{library_levels}) ] if $rh->{library_levels};
	return $c->render(json => [ WeBWorK::Utils::ListingDB::getDBTextbooks($c) ]) if $rh->{command} eq 'getDBTextbooks';
	return $c->render(json => [ WeBWorK::Utils::ListingDB::getAllDBsubjects($c) ])
		if $rh->{command} eq 'getAllDBsubjects';
	return $c->render(json => [ WeBWorK::Utils::ListingDB::getAllDBchapters($c) ])
		if $rh->{command} eq 'getAllDBchapters';
	return $c->render(
		json => [
			map { $c->ce->{courseDirs}{templates} . "/$_->{filepath}" } WeBWorK::Utils::ListingDB::getDBListings($c)
		]
	) if $rh->{command} eq 'getDBListings';
	return $c->render(json => [ WeBWorK::Utils::ListingDB::getAllDBsections($c) ])
		if $rh->{command} eq 'getSectionListings';
	return $c->render(json => [ WeBWorK::Utils::ListingDB::countDBListings($c) ])
		if $rh->{command} eq 'countDBListings';

	return $c->renderError("Unrecognized command $rh->{command}");
}

sub getProblemTags ($c) {
	return $c->renderError('You do not have permission for the getProblemTags API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render(json => WeBWorK::Utils::ListingDB::getProblemTags($c->req->param('command')));
}

sub setProblemTags ($c) {
	return $c->renderError('You do not have permission for the setProblemTags API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_tags');

	# result is [success, message] with success = 0 or 1
	my $result = WeBWorK::Utils::ListingDB::setProblemTags(
		$c->req->param('command'),         $c->req->param('library_subject'),
		$c->req->param('library_chapter'), $c->req->param('library_section'),
		$c->req->param('library_levels'),  $c->req->param('library_status')
	);
	return $c->render(json => { message => $result->[1] });
}

1;
