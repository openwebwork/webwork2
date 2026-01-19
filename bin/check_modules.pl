#!/usr/bin/env perl

=head1 NAME

check_modules.pl - Check to ensure that applications and perl modules needed by
webwork2 are installed.

=head1 SYNOPSIS

check_modules.pl [options]

 Options:
   -m|--modules          Check that the perl modules needed by webwork2 can be loaded.
   -p|--programs         Check that the programs needed by webwork2 exist.
   -k|--packagetype      Specify what type of packages your system uses.
                           For debian-based systems (e.g. Ubuntu), use 'deb'
                           For Red Hat-based systems (e.g. RHEL, Oracle), use 'rpm'

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
			'deb' => 'perl-modules',
			'rpm' => 'perl-Archive-Tar'
		}
	},
	'Archive::Zip' => {
		'package' => {
			'deb' => 'libarchive-zip-perl',
			'rpm' => 'perl-Archive-Zip'
		}
	},
	'Archive::Zip::SimpleZip' => {
		'package' => {
			'rpm' => 'perl-Archive-Zip-SimpleZip'
		}
	},
	'Benchmark' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-Benchmark'
		}
	},
	'Carp' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-Carp'
		}
	},
	'Class::Accessor' => {
		'package' => {
			'deb' => 'libclass-accessor-perl',
			'rpm' => 'perl-Class-Accessor'
		}
	},
	'Crypt::JWT' => {
		'package' => {
			'deb' => 'libcrypt-jwt-perl',
			'rpm' => 'perl-Crypt-JWT'
		}
	},
	'Crypt::PK::RSA' => {
		'package' => {
			'deb' => 'libcryptx-perl',
			'rpm' => 'perl-CryptX'
		}
	},
	'DBI' => {
		'package' => {
			'deb' => 'libdbi-perl',
			'rpm' => 'perl-DBI'
		}
	},
	'Data::Dump' => {
		'package' => {
			'deb' => 'libdata-dump-perl',
			'rpm' => 'perl-Data-Dump'
		}
	},
	'Data::Dumper' => {
		'package' => {
			'deb' => 'libperl',
			'rpm' => 'perl-Data-Dumper'
		}
	},
	'Data::Structure::Util' => {
		'package' => {
			'deb' => 'libdata-structure-util-perl'
		}
	},
	'Data::UUID' => {
		'package' => {
			'deb' => 'libossp-uuid-perl',
			'rpm' => 'perl-Data-UUID'
		}
	},
	'Date::Format' => {
		'package' => {
			'deb' => 'libtimedate-perl',
			'rpm' => 'perl-TimeDate'
		}
	},
	'Date::Parse' => {
		'package' => {
			'deb' => 'libtimedate-perl',
			'rpm' => 'perl-TimeDate'
		}
	},
	'DateTime' => {
		'package' => {
			'deb' => 'libdatetime-perl',
			'rpm' => 'perl-DateTime'
		}
	},
	'Digest::MD5' => {
		'package' => {
			'deb' => 'libperl',
			'rpm' => 'perl-Digest-MD5'
		}
	},
	'Digest::SHA' => {
		'package' => {
			'deb' => 'libperl',
			'rpm' => 'perl-Digest-SHA'
		}
	},
	'Email::Address::XS' => {
		'package' => {
			'deb' => 'libemail-address-xs-perl',
			'rpm' => 'perl-Email-Address-XS'
		}
	},
	'Email::Sender::Transport::SMTP' => {
		'package' => {
			'deb' => 'libemail-sender-perl',
			'rpm' => 'perl-Email-Sender'
		}
	},
	'Email::Stuffer' => {
		'package' => {
			'deb' => 'libemail-stuffer-perl'
		}
	},
	'Errno' => {
		'package' => {
			'deb' => 'libperl',
			'rpm' => 'perl-Errno'
		}
	},
	'Exception::Class' => {
		'package' => {
			'deb' => 'libexception-class-perl',
			'rpm' => 'perl-Exception-Class'
		}
	},
	'File::Copy' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-File-Copy'
		}
	},
	'File::Copy::Recursive' => {
		'package' => {
			'deb' => 'libfile-copy-recursive-perl',
			'rpm' => 'perl-File-Copy-Recursive'
		}
	},
	'File::Fetch' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-File-Fetch'
		}
	},
	'File::Find' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-File-Find'
		}
	},
	'File::Find::Rule' => {
		'package' => {
			'deb' => 'libfile-find-rule-perl',
			'rpm' => 'perl-File-Find-Rule'
		}
	},
	'File::Path' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-File-Path'
		}
	},
	'File::Spec' => {
		'package' => {
			'deb' => 'perl-base',
			'rpm' => 'perl-PathTools'
		}
	},
	'File::Temp' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-File-Temp'
		}
	},
	'File::stat' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-File-stat'
		}
	},
	'Future::AsyncAwait' => {
		'minversion' => '0.52',
		'package'    => {
			'deb' => 'libfuture-asyncawait-perl'
		}
	},
	'GD' => {
		'package' => {
			'deb' => 'libgd-perl',
			'rpm' => 'perl-GD'
		}
	},
	'GD::Barcode::QRcode' => {
		'package' => {
			'deb' => 'libgd-barcode-perl'
		}
	},
	'Getopt::Long' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-Getopt-Long'
		}
	},
	'Getopt::Std' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-Getopt-Std'
		}
	},
	'HTML::Entities' => {
		'package' => {
			'deb' => 'libhtml-parser-perl',
			'rpm' => 'perl-HTML-Parser'
		}
	},
	'HTTP::Async' => {
		'package' => {
			'deb' => 'libhttp-async-perl'
		}
	},
	'IO::File' => {
		'package' => {
			'deb' => 'perl-base',
			'rpm' => 'perl-IO'
		}
	},
	'Iterator' => {
		'package' => {
			'deb' => 'libiterator-perl',
		}
	},
	'Iterator::Util' => {
		'package' => {
			'deb' => 'libiterator-util-perl'
		}
	},
	'LWP::Protocol::https' => {
		'minversion' => '6.06',
		'package'    => {
			'deb' => 'liblwp-protocol-https-perl',
			'rpm' => 'perl-LWP-Protocol-https'
		}
	},
	'Locale::Maketext::Lexicon' => {
		'package' => {
			'deb' => 'liblocale-maketext-lexicon-perl'
		}
	},
	'Locale::Maketext::Simple' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-Locale-Maketext-Simple'
		}
	},
	'MIME::Base32' => {
		'package' => {
			'deb' => 'libmime-base32-perl'
		}
	},
	'MIME::Base64' => {
		'package' => {
			'deb' => 'libperl',
			'rpm' => 'perl-MIME-Base64'
		}
	},
	'Math::Random::Secure' => {
		'package' => {
			'deb' => 'libmath-random-secure-perl',
			'rpm' => 'perl-Math-Random-Secure'
		}
	},
	'Minion' => {
		'package' => {
			'deb' => 'libminion-perl'
		}
	},
	'Minion::Backend::SQLite' => {
		'package' => {
			'deb' => 'libminion-backend-sqlite-perl'
		}
	},
	'Mojolicious' => {
		'minversion' => '9.34',
		'package'    => {
			'deb' => 'libmojolicious-perl',
			'rpm' => 'perl-Mojolicious'
		}
	},
	'Mojolicious::Plugin::NotYAMLConfig' => {
		'package' => {
			'deb' => 'libmojolicious-perl',
			'rpm' => 'perl-Mojolicious'
		}
	},
	'Mojolicious::Plugin::RenderFile' => {
		'package' => {
			'deb' => 'libmojolicious-plugin-renderfile-perl'
		}
	},
	'Net::IP' => {
		'package' => {
			'deb' => 'libnet-ip-perl',
			'rpm' => 'perl-Net-IP'
		}
	},
	'Net::OAuth' => {
		'package' => {
			'deb' => 'libnet-oauth-perl',
			'rpm' => 'perl-Net-OAuth'
		}
	},
	'Opcode' => {
		'package' => {
			'deb' => 'libperl',
			'rpm' => 'perl-Opcode'
		}
	},
	'PHP::Serialization' => {
		'package' => {
			'deb' => 'libphp-serialization-perl',
			'rpm' => 'perl-PHP-Serialization'
		}
	},
	'Pandoc' => {
		'package' => {
			'deb' => 'libpandoc-wrapper-perl'
		}
	},
	'Perl::Critic' => {
		'package' => {
			'deb' => 'libperl-critic-perl',
			'rpm' => 'perl-Perl-Critic'
		}
	},
	'Perl::Tidy' => {
		'package' => {
			'deb' => 'perltidy',
			'rpm' => 'perltidy'
		}
	},
	'Pod::Simple::Search' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-Pod-Simple'
		}
	},
	'Pod::Simple::XHTML' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-Pod-Simple'
		}
	},
	'Pod::Usage' => {
		'package' => {
			'deb' => 'perl-modules',
			'rpm' => 'perl-Pod-Usage'
		}
	},
	'Pod::WSDL' => {
		'package' => {
			'deb' => 'libpod-wsdl-perl'
		}
	},
	'SOAP::Lite' => {
		'package' => {
			'deb' => 'libsoap-lite-perl',
			'rpm' => 'perl-SOAP-Lite'
		}
	},
	'SQL::Abstract' => {
		'minversion' => '2',
		'package'    => {
			'deb' => 'libsql-abstract-perl',
			'rpm' => 'perl-SQL-Abstract'
		}
	},
	'SVG' => {
		'package' => {
			'deb' => 'libsvg-perl',
		}
	},
	'Scalar::Util' => {
		'package' => {
			'deb' => 'perl-base',
			'rpm' => 'perl-Scalar-List-Utils'
		}
	},
	'Socket' => {
		'package' => {
			'deb' => 'perl-base',
			'rpm' => 'perl-Socket'
		}
	},
	'String::ShellQuote' => {
		'package' => {
			'deb' => 'libstring-shellquote-perl',
			'rpm' => 'perl-String-ShellQuote'
		}
	},
	'Text::CSV' => {
		'package' => {
			'deb' => 'libtext-csv-perl',
			'rpm' => 'perl-Text-CSV'
		}
	},
	'Text::Wrap' => {
		'package' => {
			'deb' => 'perl-base',
			'rpm' => 'perl-Text-Tabs+Wrap'
		}
	},
	'Tie::IxHash' => {
		'package' => {
			'deb' => 'libtie-ixhash-perl',
			'rpm' => 'perl-Tie-IxHash'
		}
	},
	'Time::HiRes' => {
		'package' => {
			'deb' => 'libperl',
			'rpm' => 'perl-Time-HiRes'
		}
	},
	'Time::Zone' => {
		'package' => {
			'deb' => 'libtimedate-perl',
			'rpm' => 'perl-TimeDate'
		}
	},
	'Types::Serialiser' => {
		'package' => {
			'deb' => 'libtypes-serialiser-perl',
			'rpm' => 'perl-Types-Serialiser'
		}
	},
	'URI::Escape' => {
		'package' => {
			'deb' => 'liburi-perl',
			'rpm' => 'perl-URI'
		}
	},
	'UUID::Tiny' => {
		'package' => {
			'deb' => 'libuuid-tiny-perl',
			'rpm' => 'perl-UUID-Tiny'
		}
	},
	'XML::LibXML' => {
		'package' => {
			'deb' => 'libxml-libxml-perl',
			'rpm' => 'perl-XML-LibXML'
		}
	},
	'XML::Parser' => {
		'package' => {
			'deb' => 'libxml-parser-perl',
			'rpm' => 'perl-XML-Parser'
		}
	},
	'XML::Parser::EasyTree' => {
		'package' => {
			'deb' => 'libxml-parser-easytree-perl'
		}
	},
	'XML::Writer' => {
		'package' => {
			'deb' => 'libxml-writer-perl',
			'rpm' => 'perl-XML-Writer'
		}
	},
	'YAML::XS' => {
		'package' => {
			'deb' => 'libyaml-libyaml-perl',
			'rpm' => 'perl-YAML-LibYAML'
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
	'm|modules'       => \$test_modules,
	'p|programs'      => \$test_programs,
	'k|packagetype=s' => \$packagetype,
	'h|help'          => \$show_help,
);

pod2usage(2) if $show_help;

if ($packagetype && $packagetype ne 'rpm' && $packagetype ne 'deb') {
	die 'packagetype must be one of \'deb\' or \'rpm\'';
}

my %packagemgrcommand = ('deb' => 'sudo apt install ', 'rpm' => 'sudo dnf install ');

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
			say 'You can try to install the missing modules with the following command(s)';
			if (@missing_modules) {
				say 'sudo cpanm ' . join(' ', @missing_modules);
			}
			if (@missing_packages) {
				say $packagemgrcommand{$packagetype} . join(' ', @missing_packages);
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
