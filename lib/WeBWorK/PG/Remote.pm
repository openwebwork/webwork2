################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/PG/Remote.pm,v 1.6 2007/08/13 22:59:58 sh002i Exp $
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

package WeBWorK::PG::Remote;
use base qw(WeBWorK::PG);

=head1 NAME

WeBWorK::PG::Remote - Use the WeBWorK::PG API to invoke a remote problem
renderer via SOAP.

=cut

use strict;
use warnings;
use SOAP::Lite;
use WeBWorK::Utils qw(readFile);

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my (
		$ce,
		$user,
		$key,
		$set,
		$problem,
		$psvn, #FIXME -- not used
		$formFields, # in CGI::Vars format
		$translationOptions, # hashref containing options for the
		                     # translator, such as whether to show
		                     # hints and the display mode to use
	) = @_;
	
	##### READ SOURCE FILE #####
	
	my $sourceFile = $problem->source_file;
	$sourceFile = $ce->{courseDirs}->{templates}."/".$sourceFile
		unless ($sourceFile =~ /^\//);
	my $source = eval { readFile($sourceFile) };
	if ($@) {
		# well, we couldn't get the problem source, for some reason.
		return bless {
			translator => undef,
			head_text  => "",
			body_text  => <<EOF,
WeBWorK::Utils::readFile($sourceFile) says:
$@
EOF
			answers    => {},
			result     => {},
			state      => {},
			errors     => "Failed to read the problem source file.",
			warnings   => "",
			flags      => {error_flag => 1},
		}, $class;
	}
	
	##### DEFINE REQUEST #####
	
	my $envir = $class->defineProblemEnvir(
		$ce,
		$user,
		$key,
		$set,
		$problem,
		$psvn, #FIXME -- not used
		$formFields,
		$translationOptions,
	);
	
	my (@modules_to_load, @extra_packages_to_load);
	my @modules = @{ $ce->{pg}->{modules} };
	foreach my $module_packages_ref (@modules) {
		my ($module, @extra_packages) = @$module_packages_ref;
		# the first item is the main package
		push @modules_to_load, $module;
		# the remaining items are "extra" packages
		push @extra_packages_to_load, @extra_packages;
	}
	
	my $request = {
		course                 => $ce->{courseName},
		source                 => $source,
		modules_to_evaluate    => [ @modules_to_load ],
		extra_packages_to_load => [ @extra_packages_to_load ],
		envir                  => $envir,
		problem_state          => {
			recorded_score       => $problem->status,
			sub_recorded_score =>   $problem->sub_status,
			num_of_correct_ans   => $problem->num_correct,
			num_of_incorrect_ans => $problem->num_incorrect,
		},
		options                => $translationOptions,
	};
	
	##### CALL REMOTE RENDERER #####
	
	my $package = __PACKAGE__;
	my $proxy = $ce->{pg}->{renderers}->{$package}->{proxy};
	
	my $soap = SOAP::Lite
		->uri("urn:RenderD")
		->proxy($proxy);
	my $query = $soap->render($request);
	
	##### HANDLE ERRORS #####
	
	if ($query->fault) {
		return bless {
			translator => undef,
			head_text  => "",
			body_text  => $query->faultstring,
			answers    => {},
			result     => {},
			state      => {},
			errors     => "Failed to call the remote renderer."
				. " (error " . $query->faultcode . ")",
			warnings   => "",
			flags      => {error_flag => 1},
		}, $class;
	}
	
	##### RETURN RESULTS #####
	
	return $query->result;
}

1;

__END__

=head1 OPERATION

WeBWorK::PG::Remote goes through the following operations when constructed:

=over

=item Read the problem source file

Reads the contents of the problem source file from disk.

=item Compile a problem environment

Use data from the user, set, and problem, as well as the course
environemnt and translation options, to compile a problem environment.
The default subroutine, &WeBWorK::PG::defineProblemEnvir, is used.

=item Compile a list of modules to load

Use the course environment to compile a list of modules to load and
extra packages to import.

=item Call the remote renderer

Use SOAP::Lite to call the C<renderd> remote rendering daemon.

=back

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=cut
