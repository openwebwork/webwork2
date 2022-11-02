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

package WeBWorK::Constants;

=head1 NAME

WeBWorK::Constants - provide constant values for other WeBWorK modules.

=cut

use strict;
use warnings;

$WeBWorK::Constants::WEBWORK_DIRECTORY = $ENV{WEBWORK_ROOT} unless defined($WeBWorK::Constants::WEBWORK_DIRECTORY);
$WeBWorK::Constants::PG_DIRECTORY      = $ENV{PG_ROOT}      unless defined($WeBWorK::Constants::PG_DIRECTORY);

################################################################################
# WeBWorK::Debug
################################################################################

# If true, WeBWorK::Debug will print debugging output.
#
$WeBWorK::Debug::Enabled = 0;

# If non-empty, debugging output will be sent to the file named rather than STDERR.
#
$WeBWorK::Debug::Logfile = $WeBWorK::Constants::WEBWORK_DIRECTORY . "/logs/debug.log";

# If defined, prevent subroutines matching the following regular expression from
# logging.
#
# For example, this pattern prevents the dispatch() function from logging:
#     $WeBWorK::Debug::DenySubroutineOutput = qr/^WeBWorK::dispatch$/;
#
$WeBWorK::Debug::DenySubroutineOutput = undef;
#$WeBWorK::Debug::DenySubroutineOutput = qr/^WeBWorK::dispatch$/;

# If defined, allow only subroutines matching the following regular expression
# to log.
#
# For example, this pattern allow only some function being worked on to log:
#     $WeBWorK::Debug::AllowSubroutineOutput = qr/^WeBWorK::SomePkg::myFunc$/;
#
# $WeBWorK::Debug::AllowSubroutineOutput = undef;
# $WeBWorK::Debug::AllowSubroutineOutput =qr/^WeBWorK::Authen::get_credentials$/;

################################################################################
# WeBWorK::ContentGenerator::Hardcopy
################################################################################

# If true, don't delete temporary files
#
$WeBWorK::ContentGenerator::Hardcopy::PreserveTempFiles = 0;

1;
