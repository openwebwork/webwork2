#!/usr/bin/env perl

=head1 NAME

check_modules.pl - Check to ensure that applications and perl modules needed by
webwork2 are installed.

=head1 SYNOPSIS

check_modules.pl [options]

 Options:
   -m|--modules          Check that the perl modules needed by webwork2 can be loaded.
   -p|--programs         Check that the programs needed by webwork2 exist.
   -d|--distribution     Specify your linux distribution.  Currently supported options are
                           'ubuntu' - tested on ubuntu 24. May work for other distributions
				using the apt package manager
                           'rhel' - for RedHat Enterprise Linux and equivalents with the 
				EPEL and CodeReady Builder repositories enabled
				(e.g. Rocky Linux, Oracle Linux)

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
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Archive-Tar'
		}
	},
	'Archive::Zip' => {
		'package' => {
			'ubuntu' => 'libarchive-zip-perl',
			'rhel'   => 'perl-Archive-Zip'
		}
	},
	'Archive::Zip::SimpleZip' => {
		'package' => {
			'rhel' => 'perl-Archive-Zip-SimpleZip'
		}
	},
	'Benchmark' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Benchmark'
		}
	},
	'Carp' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Carp'
		}
	},
	'Class::Accessor' => {
		'package' => {
			'ubuntu' => 'libclass-accessor-perl',
			'rhel'   => 'perl-Class-Accessor'
		}
	},
	'Crypt::JWT' => {
		'package' => {
			'ubuntu' => 'libcrypt-jwt-perl',
			'rhel'   => 'perl-Crypt-JWT'
		}
	},
	'Crypt::PK::RSA' => {
		'package' => {
			'ubuntu' => 'libcryptx-perl',
			'rhel'   => 'perl-CryptX'
		}
	},
	'DBI' => {
		'package' => {
			'ubuntu' => 'libdbi-perl',
			'rhel'   => 'perl-DBI'
		}
	},
	'Data::Dump' => {
		'package' => {
			'ubuntu' => 'libdata-dump-perl',
			'rhel'   => 'perl-Data-Dump'
		}
	},
	'Data::Dumper' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Data-Dumper'
		}
	},
	'Data::Structure::Util' => {
		'package' => {
			'ubuntu' => 'libdata-structure-util-perl'
		}
	},
	'Data::UUID' => {
		'package' => {
			'ubuntu' => 'libossp-uuid-perl',
			'rhel'   => 'perl-Data-UUID'
		}
	},
	'Date::Format' => {
		'package' => {
			'ubuntu' => 'libtimedate-perl',
			'rhel'   => 'perl-TimeDate'
		}
	},
	'Date::Parse' => {
		'package' => {
			'ubuntu' => 'libtimedate-perl',
			'rhel'   => 'perl-TimeDate'
		}
	},
	'DateTime' => {
		'package' => {
			'ubuntu' => 'libdatetime-perl',
			'rhel'   => 'perl-DateTime'
		}
	},
	'Digest::MD5' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Digest-MD5'
		}
	},
	'Digest::SHA' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Digest-SHA'
		}
	},
	'Email::Address::XS' => {
		'package' => {
			'ubuntu' => 'libemail-address-xs-perl',
			'rhel'   => 'perl-Email-Address-XS'
		}
	},
	'Email::Sender::Transport::SMTP' => {
		'package' => {
			'ubuntu' => 'libemail-sender-perl',
			'rhel'   => 'perl-Email-Sender'
		}
	},
	'Email::Stuffer' => {
		'package' => {
			'ubuntu' => 'libemail-stuffer-perl'
		}
	},
	'Errno' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Errno'
		}
	},
	'Exception::Class' => {
		'package' => {
			'ubuntu' => 'libexception-class-perl',
			'rhel'   => 'perl-Exception-Class'
		}
	},
	'File::Copy' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-File-Copy'
		}
	},
	'File::Copy::Recursive' => {
		'package' => {
			'ubuntu' => 'libfile-copy-recursive-perl',
			'rhel'   => 'perl-File-Copy-Recursive'
		}
	},
	'File::Fetch' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-File-Fetch'
		}
	},
	'File::Find' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-File-Find'
		}
	},
	'File::Find::Rule' => {
		'package' => {
			'ubuntu' => 'libfile-find-rule-perl',
			'rhel'   => 'perl-File-Find-Rule'
		}
	},
	'File::Path' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-File-Path'
		}
	},
	'File::Spec' => {
		'package' => {
			'ubuntu' => 'perl-base',
			'rhel'   => 'perl-PathTools'
		}
	},
	'File::Temp' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-File-Temp'
		}
	},
	'File::stat' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-File-stat'
		}
	},
	'Future::AsyncAwait' => {
		'minversion' => '0.52',
		'package'    => {
			'ubuntu' => 'libfuture-asyncawait-perl'
		}
	},
	'GD' => {
		'package' => {
			'ubuntu' => 'libgd-perl',
			'rhel'   => 'perl-GD'
		}
	},
	'GD::Barcode::QRcode' => {
		'package' => {
			'ubuntu' => 'libgd-barcode-perl'
		}
	},
	'Getopt::Long' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Getopt-Long'
		}
	},
	'Getopt::Std' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Getopt-Std'
		}
	},
	'HTML::Entities' => {
		'package' => {
			'ubuntu' => 'libhtml-parser-perl',
			'rhel'   => 'perl-HTML-Parser'
		}
	},
	'HTTP::Async' => {
		'package' => {
			'ubuntu' => 'libhttp-async-perl'
		}
	},
	'IO::File' => {
		'package' => {
			'ubuntu' => 'perl-base',
			'rhel'   => 'perl-IO'
		}
	},
	'Iterator' => {
		'package' => {
			'ubuntu' => 'libiterator-perl',
		}
	},
	'Iterator::Util' => {
		'package' => {
			'ubuntu' => 'libiterator-util-perl'
		}
	},
	'LWP::Protocol::https' => {
		'minversion' => '6.06',
		'package'    => {
			'ubuntu' => 'liblwp-protocol-https-perl',
			'rhel'   => 'perl-LWP-Protocol-https'
		}
	},
	'Locale::Maketext::Lexicon' => {
		'package' => {
			'ubuntu' => 'liblocale-maketext-lexicon-perl'
		}
	},
	'Locale::Maketext::Simple' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Locale-Maketext-Simple'
		}
	},
	'MIME::Base32' => {
		'package' => {
			'ubuntu' => 'libmime-base32-perl'
		}
	},
	'MIME::Base64' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-MIME-Base64'
		}
	},
	'Math::Random::Secure' => {
		'package' => {
			'ubuntu' => 'libmath-random-secure-perl',
			'rhel'   => 'perl-Math-Random-Secure'
		}
	},
	'Minion' => {
		'package' => {
			'ubuntu' => 'libminion-perl'
		}
	},
	'Minion::Backend::SQLite' => {
		'package' => {
			'ubuntu' => 'libminion-backend-sqlite-perl'
		}
	},
	'Mojolicious' => {
		'minversion' => '9.34',
		'package'    => {
			'ubuntu' => 'libmojolicious-perl',
			'rhel'   => 'perl-Mojolicious'
		}
	},
	'Mojolicious::Plugin::NotYAMLConfig' => {
		'package' => {
			'ubuntu' => 'libmojolicious-perl',
			'rhel'   => 'perl-Mojolicious'
		}
	},
	'Mojolicious::Plugin::RenderFile' => {
		'package' => {
			'ubuntu' => 'libmojolicious-plugin-renderfile-perl'
		}
	},
	'Net::IP' => {
		'package' => {
			'ubuntu' => 'libnet-ip-perl',
			'rhel'   => 'perl-Net-IP'
		}
	},
	'Net::OAuth' => {
		'package' => {
			'ubuntu' => 'libnet-oauth-perl',
			'rhel'   => 'perl-Net-OAuth'
		}
	},
	'Opcode' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Opcode'
		}
	},
	'PHP::Serialization' => {
		'package' => {
			'ubuntu' => 'libphp-serialization-perl',
			'rhel'   => 'perl-PHP-Serialization'
		}
	},
	'Pandoc' => {
		'package' => {
			'ubuntu' => 'libpandoc-wrapper-perl'
		}
	},
	'Perl::Critic' => {
		'package' => {
			'ubuntu' => 'libperl-critic-perl',
			'rhel'   => 'perl-Perl-Critic'
		}
	},
	'Perl::Tidy' => {
		'package' => {
			'ubuntu' => 'perltidy',
			'rhel'   => 'perltidy'
		}
	},
	'Pod::Simple::Search' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Pod-Simple'
		}
	},
	'Pod::Simple::XHTML' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Pod-Simple'
		}
	},
	'Pod::Usage' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Pod-Usage'
		}
	},
	'Pod::WSDL' => {
		'package' => {
			'ubuntu' => 'libpod-wsdl-perl'
		}
	},
	'SOAP::Lite' => {
		'package' => {
			'ubuntu' => 'libsoap-lite-perl',
			'rhel'   => 'perl-SOAP-Lite'
		}
	},
	'SQL::Abstract' => {
		'minversion' => '2',
		'package'    => {
			'ubuntu' => 'libsql-abstract-perl',
			'rhel'   => 'perl-SQL-Abstract'
		}
	},
	'SVG' => {
		'package' => {
			'ubuntu' => 'libsvg-perl',
		}
	},
	'Scalar::Util' => {
		'package' => {
			'ubuntu' => 'perl-base',
			'rhel'   => 'perl-Scalar-List-Utils'
		}
	},
	'Socket' => {
		'package' => {
			'ubuntu' => 'perl-base',
			'rhel'   => 'perl-Socket'
		}
	},
	'String::ShellQuote' => {
		'package' => {
			'ubuntu' => 'libstring-shellquote-perl',
			'rhel'   => 'perl-String-ShellQuote'
		}
	},
	'Text::CSV' => {
		'package' => {
			'ubuntu' => 'libtext-csv-perl',
			'rhel'   => 'perl-Text-CSV'
		}
	},
	'Text::Wrap' => {
		'package' => {
			'ubuntu' => 'perl-base',
			'rhel'   => 'perl-Text-Tabs+Wrap'
		}
	},
	'Tie::IxHash' => {
		'package' => {
			'ubuntu' => 'libtie-ixhash-perl',
			'rhel'   => 'perl-Tie-IxHash'
		}
	},
	'Time::HiRes' => {
		'package' => {
			'ubuntu' => 'perl',
			'rhel'   => 'perl-Time-HiRes'
		}
	},
	'Time::Zone' => {
		'package' => {
			'ubuntu' => 'libtimedate-perl',
			'rhel'   => 'perl-TimeDate'
		}
	},
	'Types::Serialiser' => {
		'package' => {
			'ubuntu' => 'libtypes-serialiser-perl',
			'rhel'   => 'perl-Types-Serialiser'
		}
	},
	'URI::Escape' => {
		'package' => {
			'ubuntu' => 'liburi-perl',
			'rhel'   => 'perl-URI'
		}
	},
	'UUID::Tiny' => {
		'package' => {
			'ubuntu' => 'libuuid-tiny-perl',
			'rhel'   => 'perl-UUID-Tiny'
		}
	},
	'XML::LibXML' => {
		'package' => {
			'ubuntu' => 'libxml-libxml-perl',
			'rhel'   => 'perl-XML-LibXML'
		}
	},
	'XML::Parser' => {
		'package' => {
			'ubuntu' => 'libxml-parser-perl',
			'rhel'   => 'perl-XML-Parser'
		}
	},
	'XML::Parser::EasyTree' => {
		'package' => {
			'ubuntu' => 'libxml-parser-easytree-perl'
		}
	},
	'XML::Writer' => {
		'package' => {
			'ubuntu' => 'libxml-writer-perl',
			'rhel'   => 'perl-XML-Writer'
		}
	},
	'YAML::XS' => {
		'package' => {
			'ubuntu' => 'libyaml-libyaml-perl',
			'rhel'   => 'perl-YAML-LibYAML'
		}
	}
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

my ($test_modules, $test_programs, $packagetype, $show_help);

GetOptions(
	'm|modules'        => \$test_modules,
	'p|programs'       => \$test_programs,
	'd|distribution=s' => \$packagetype,
	'h|help'           => \$show_help,
);

pod2usage(2) if $show_help;

if ($packagetype && $packagetype ne 'rhel' && $packagetype ne 'ubuntu') {
	die 'packagetype must be one of \'ubuntu\' or \'rhel\'';
}

my %packagemgrcommand = ('ubuntu' => 'sudo apt install ', 'rhel' => 'sudo dnf install ');

$test_modules = $test_programs = 1 unless $test_programs || $test_modules;

my @PATH = split(/:/, $ENV{PATH});

my (@missing_packages, @missing_modules);

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
				if ($packagetype) {
					if ($modulesList{$module}{package}{$packagetype}) {
						push(@missing_packages, $modulesList{$module}{package}{$packagetype});
					} else {
						push(@missing_modules, $module);
					}
				}
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
		if (@missing_modules || @missing_packages) {
			say 'You can try to install the missing modules with the following command(s):' . "\n";
			if (@missing_modules) {
				say 'sudo cpanm ' . join(' ', @missing_modules) . "\n";
			}
			if (@missing_packages) {
				say $packagemgrcommand{$packagetype} . join(' ', @missing_packages) . "\n";
			}
		}
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
