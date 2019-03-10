################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Constants.pm,v 1.62 2010/02/01 01:57:56 apizer Exp $
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

################################################################################
# WeBWorK::PG::Local
################################################################################
# The maximum amount of time (in seconds) to work on a single problem.
# At the end of this time a timeout message is sent to the browser.

$WeBWorK::PG::Local::TIMEOUT = 60;

################################################################################
# WeBWorK::PG::ImageGenerator
################################################################################

# Arguments to pass to dvipng. This is dependant on the version of dvipng.
#
# For dvipng versions 0.x
#     $WeBWorK::PG::ImageGenerator::DvipngArgs = "-x4000.5 -bgTransparent -Q6 -mode toshiba -D180";
# For dvipng versions 1.0 to 1.5
#     $WeBWorK::PG::ImageGenerator::DvipngArgs = "-bgTransparent -D120 -q -depth";
#
# For dvipng versions 1.6 (and probably above)
#     $WeBWorK::PG::ImageGenerator::DvipngArgs = "-bgtransparent -D120 -q -depth";
# Note: In 1.6 and later, bgTransparent gives alpha-channel transparency while
# bgtransparent gives single-bit transparency. If you use alpha-channel transparency,
# the images will not be viewable with MSIE.  bgtransparent works for version 1.5,
# but does not give transparent backgrounds. It does not work for version 1.2. It has not
# been tested with other versions.
#
$WeBWorK::PG::ImageGenerator::DvipngArgs = "-bgTransparent -D120 -q -depth";

# If true, don't delete temporary files
#
$WeBWorK::PG::ImageGenerator::PreserveTempFiles = 0; 
# TeX to prepend to equations to be processed.
#
$WeBWorK::PG::ImageGenerator::TexPreamble = <<'EOF';
\documentclass[12pt]{article}
\nonstopmode
\usepackage{amsmath,amsfonts,amssymb}
\def\gt{>}
\def\lt{<}
\usepackage[active,textmath,displaymath]{preview}
\begin{document}
EOF

# TeX to append to equations to be processed.
#
$WeBWorK::PG::ImageGenerator::TexPostamble = <<'EOF';
\end{document}
EOF


1;
