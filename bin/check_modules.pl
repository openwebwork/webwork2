#!/usr/bin/env perl

=head1 NAME

check_modules.pl - Check to ensure that applications and perl modules needed by
webwork2 are installed.

=head1 SYNOPSIS

check_modules.pl [options]

 Options:
   -m|--modules          Check that the perl modules needed by webwork2 can be loaded.
   -p|--programs         Check that the programs needed by webwork2 exist.

Both programs and modules are checked if no options are given.

=head1 DESCRIPTION

Checks that modules needed by webwork2 can be loaded and are at the sufficient
version, and that applications needed by webwork2 exist.

=cut

use strict;
use warnings;
use version;
use feature 'say';

use Getopt::Long qw(:config bundling);
use Pod::Usage;

my %modulesList = (
	'Archive::Tar' => {
		package => { deb => 'perl-modules', },
	},
	'Archive::Zip' => {
		package => { deb => 'libarchive-zip-perl', },
	},
	'Archive::Zip::SimpleZip' => {},
	'Benchmark'               => {
		package => { deb => 'perl-modules', },
	},
	'Carp' => {
		package => { deb => 'perl-modules', },
	},
	'Class::Accessor' => {
		package => { deb => 'libclass-accessor-perl', },
	},
	'Crypt::JWT' => {
		package => { deb => 'libcrypt-jwt-perl', },
	},
	'Crypt::PK::RSA' => {
		package => { deb => 'libcryptx-perl', },
	},
	'Data::Dump' => {
		package => { deb => 'libdata-dump-perl', },
	},
	'Data::Dumper' => {
		package => { deb => 'libperl', },
	},
	'Data::Structure::Util' => {
		package => { deb => 'libdata-structure-util-perl', },
	},
	'Data::UUID' => {
		package => { deb => 'libossp-uuid-perl', },
	},
	'Date::Format' => {
		package => { deb => 'libtimedate-perl', },
	},
	'Date::Parse' => {
		package => { deb => 'libtimedate-perl', },
	},
	'DateTime' => {
		package => { deb => 'libdatetime-perl', },
	},
	'DBI' => {
		package => { deb => 'libdbi-perl', },
	},
	'Digest::MD5' => {
		package => { deb => 'libperl', },
	},
	'Digest::SHA' => {
		package => { deb => 'libperl', },
	},
	'Email::Address::XS' => {
		package => { deb => 'libemail-address-xs-perl', },
	},
	'Email::Sender::Transport::SMTP' => {
		package => { deb => 'libemail-sender-perl', },
	},
	'Email::Stuffer' => {
		package => { deb => 'libemail-stuffer-perl', },
	},
	'Errno' => {
		package => { deb => 'libperl', },
	},
	'Exception::Class' => {
		package => { deb => 'libexception-class-perl', },
	},
	'File::Copy' => {
		package => { deb => 'perl-modules', },
	},
	'File::Copy::Recursive' => {
		package => { deb => 'libfile-copy-recursive-perl', },
	},
	'File::Fetch' => {
		package => { deb => 'perl-modules', },
	},
	'File::Find' => {
		package => { deb => 'perl-modules', },
	},
	'File::Find::Rule' => {
		package => { deb => 'libfile-find-rule-perl', },
	},
	'File::Path' => {
		package => { deb => 'perl-modules', },
	},
	'File::Spec' => {
		package => { deb => 'perl-base', },
	},
	'File::stat' => {
		package => { deb => 'perl-modules', },
	},
	'File::Temp' => {
		package => { deb => 'perl-modules', },
	},
	'Future::AsyncAwait' => {
		package    => { deb => 'libfuture-asyncawait-perl', },
		minversion => 0.52,
	},
	'GD' => {
		package => { deb => 'libgd-perl', },
	},
	'GD::Barcode::QRcode' => {
		package => { deb => 'libgd-barcode-perl', },
	},
	'Getopt::Long' => {
		package => { deb => 'perl-modules', },
	},
	'Getopt::Std' => {
		package => { deb => 'perl-modules', },
	},
	'HTML::Entities' => {
		package => { deb => 'libhtml-parser-perl', },
	},
	'HTTP::Async' => {
		package => { deb => 'libhttp-async-perl', },
	},
	'IO::File' => {
		package => { deb => 'perl-base', },
	},
	'Iterator' => {
		package => { deb => 'libiterator-perl', },
	},
	'Iterator::Util' => {
		package => { deb => 'libiterator-util-perl', },
	},
	'Locale::Maketext::Lexicon' => {
		package => { deb => 'liblocale-maketext-lexicon-perl', },
	},
	'Locale::Maketext::Simple' => {
		package => { deb => 'perl-modules', },
	},
	'LWP::Protocol::https' => {
		package    => { deb => 'liblwp-protocol-https-perl', },
		minversion => 6.06,
	},
	'MIME::Base32' => {
		package => { deb => 'libmime-base32-perl', },
	},
	'MIME::Base64' => {
		package => { deb => 'libperl', },
	},
	'Math::Random::Secure' => {
		package => { deb => 'libmath-random-secure-perl', },
	},
	'Minion' => {
		package => { deb => 'libminion-perl', },
	},
	'Minion::Backend::SQLite' => {
		package => { deb => 'libminion-backend-sqlite-perl', },
	},
	'Mojolicious' => {
		package    => { deb => 'libmojolicious-perl', },
		minversion => 9.34,
	},
	'Mojolicious::Plugin::NotYAMLConfig' => {
		package => { deb => 'libmojolicious-perl', },
	},
	'Mojolicious::Plugin::RenderFile' => {
		package => { deb => 'libmojolicious-plugin-renderfile-perl', },
	},
	'Net::IP' => {
		package => { deb => 'libnet-ip-perl', },
	},
	'Net::OAuth' => {
		package => { deb => 'libnet-oauth-perl', },
	},
	'Opcode' => {
		package => { deb => 'libperl', },
	},
	'Pandoc' => {
		package => { deb => 'libpandoc-wrapper-perl', },
	},
	'Perl::Critic' => {
		package => { deb => 'libperl-critic-perl', },
	},
	'Perl::Tidy' => {
		package => { deb => 'perltidy', },
	},
	'PHP::Serialization' => {
		package => { deb => 'libphp-serialization-perl', },
	},
	'Pod::Simple::Search' => {
		package => { deb => 'perl-modules', },
	},
	'Pod::Simple::XHTML' => {
		package => { deb => 'perl-modules', },
	},
	'Pod::Usage' => {
		package => { deb => 'perl-modules', },
	},
	'Pod::WSDL' => {
		package => { deb => 'libpod-wsdl-perl', },
	},
	'Scalar::Util' => {
		package => { deb => 'perl-base', },
	},
	'SOAP::Lite' => {
		package => { deb => 'libsoap-lite-perl', },
	},
	'Socket' => {
		package => { deb => 'perl-base', },
	},
	'SQL::Abstract' => {
		package    => { deb => 'libsql-abstract-perl', },
		minversion => 2.000000,
	},
	'String::ShellQuote' => {
		package => { deb => 'libstring-shellquote-perl', },
	},
	'SVG' => {
		package => { deb => 'libsvg-perl', },
	},
	'Text::CSV' => {
		package => { deb => 'libtext-csv-perl', },
	},
	'Text::Wrap' => {
		package => { deb => 'perl-base', },
	},
	'Tie::IxHash' => {
		package => { deb => 'libtie-ixhash-perl', },
	},
	'Time::HiRes' => {
		package => { deb => 'libperl', },
	},
	'Time::Zone' => {
		package => { deb => 'libtimedate-perl', },
	},
	'Types::Serialiser' => {
		package => { deb => 'libtypes-serialiser-perl', },
	},
	'URI::Escape' => {
		package => { deb => 'liburi-perl', },
	},
	'UUID::Tiny' => {
		package => { deb => 'libuuid-tiny-perl', },
	},
	'XML::LibXML' => {
		package => { deb => 'libxml-libxml-perl', },
	},
	'XML::Parser' => {
		package => { deb => 'libxml-parser-perl', },
	},
	'XML::Parser::EasyTree' => {
		package => { deb => 'libxml-parser-easytree-perl', },
	},
	'XML::Writer' => {
		package => { deb => 'libxml-writer-perl', },
	},
	'YAML::XS' => {
		package => { deb => 'libyaml-libyaml-perl', },
	},
);

my %moduleVersion = (
	'Future::AsyncAwait'   => 0.52,
	'IO::Socket::SSL'      => 2.007,
	'LWP::Protocol::https' => 6.06,
	'Mojolicious'          => 9.34,
	'SQL::Abstract'        => 2.000000
);

my @programList = qw(
	convert
	curl
	mkdir
	mv
	mysql
	mysqldump
	node
	npm
	tar
	git
	gzip
	latex
	latex2pdf
	pandoc
	dvipng
);

my ($test_modules, $test_programs, $show_help);

GetOptions(
	'm|modules'  => \$test_modules,
	'p|programs' => \$test_programs,
	'h|help'     => \$show_help,
);
pod2usage(2) if $show_help;

$test_modules = $test_programs = 1 unless $test_programs || $test_modules;

my @PATH = split(/:/, $ENV{PATH});

check_modules() if $test_modules;
say ''          if $test_modules && $test_programs;
check_apps()    if $test_programs;

sub which {
	my $program = shift;
	for my $path (@PATH) {
		return "$path/$program" if -e "$path/$program";
	}
	return;
}

sub check_modules {
	say "Checking for modules required by WeBWorK...";

	my $moduleNotFound = 0;

	my $checkModule = sub {
		my $module = shift;

		no strict 'refs';
		eval "use $module";
		if ($@) {
			$moduleNotFound = 1;
			my $file = ($module =~ s|::|/|gr) . '.pm';
			if ($@ =~ /Can't locate $file in \@INC/) {
				say "** $module not found in \@INC";
			} else {
				say "** $module found, but failed to load: $@";
			}
		} elsif (defined($modulesList{$module}{'minversion'})
			&& version->parse(${ $module . '::VERSION' }) < version->parse($modulesList{$module}{'minversion'}))
		{
			$moduleNotFound = 1;
			say "** $module found, but not version $modulesList{$module}{'minversion'} or better";
		} else {
			say "   $module found and loaded";
		}
		use strict 'refs';
	};

	for my $module (sort keys(%modulesList)) {
		$checkModule->($module);
	}

	if ($moduleNotFound) {
		say '';
		say 'Some required modules were not found, could not be loaded, or were not at the sufficient version.';
		say 'Exiting as this is required to check the database driver and programs.';
		exit 0;
	}

	say '';
	say 'Checking for the database driver required by WeBWorK...';
	my $ce     = loadCourseEnvironment();
	my $driver = $ce->{database_driver} =~ /^mysql$/i ? 'DBD::mysql' : 'DBD::MariaDB';
	say "Configured to use $driver in site.conf";
	$checkModule->($driver);

	return;
}

sub check_apps {
	my $ce = loadCourseEnvironment();

	say 'Checking external programs required by WeBWorK...';

	push(@programList, $ce->{pg}{specialPGEnvironmentVars}{latexImageSVGMethod});

	for my $program (@programList) {
		if ($ce->{externalPrograms}{$program}) {
			# Remove command line arguments (for latex and latex2pdf).
			my $executable = $ce->{externalPrograms}{$program} =~ s/ .*$//gr;
			if (-e $executable) {
				say "   $executable found for $program";
			} else {
				say "** $executable not found for $program";
			}
		} else {
			my $found = which($program);
			if ($found) {
				say "   $found found for $program";
			} else {
				say "** $program not found in \$PATH";
			}
		}
	}

	# Check that the node version is sufficient.
	my $node_version_str = qx/node -v/;
	my ($node_version) = $node_version_str =~ m/v(\d+)\./;

	say "\n**The version of node should be at least 18.  You have version $node_version."
		if $node_version < 18;

	return;
}

sub loadCourseEnvironment {
	eval 'require Mojo::File';
	die "Unable to load Mojo::File: $@" if $@;
	my $webworkRoot = Mojo::File->curfile->dirname->dirname;
	push @INC, "$webworkRoot/lib";
	eval 'require WeBWorK::CourseEnvironment';
	die "Unable to load WeBWorK::CourseEnvironment: $@" if $@;
	return WeBWorK::CourseEnvironment->new({ webwork_dir => $webworkRoot });
}

1;
