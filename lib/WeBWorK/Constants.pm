################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Constants.pm,v 1.13 2004/06/23 23:09:45 sh002i Exp $
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

################################################################################
# WeBWorK::Debug
################################################################################

# If true, WeBWorK::Debug will print debugging output.
# 
$WeBWorK::Debug::Enabled = 0;

# If non-empty, debugging output will be sent to the file named rather than STDERR.
# 
$WeBWorK::Debug::Logfile = "";

# Prevent subroutines matching the following regular expression from logging.
# 
# For example, this pattern prevents the dispatch() function from logging:
#     $WeBWorK::Debug::QuellSubroutineOutput = qr/^WeBWorK::dispatch$/;
# 
$WeBWorK::Debug::QuellSubroutineOutput = undef;

################################################################################
# WeBWorK::Timing
################################################################################

# If true, WeBWorK::Timing will print timing data.
# 
$WeBWorK::Timing::Enabled = 0;

# If non-empty, timing data will be sent to the file named rather than STDERR.
# 
$WeBWorK::Timing::Logfile = "";

################################################################################
# WeBWorK::PG::ImageGenerator
################################################################################

# Arguments to pass to dvipng. This is dependant on the version of dvipng.
# 
# For dvipng < 1.0
#     $WeBWorK::PG::ImageGenerator::DvipngArgs = "-x4000.5 -bgTransparent -Q6 -mode toshiba -D180";
# For dvipng >= 1.0
#     $WeBWorK::PG::ImageGenerator::DvipngArgs = "-bgTransparent -D120 -q -depth";
# 
$WeBWorK::PG::ImageGenerator::DvipngArgs = "-x4000.5 -bgTransparent -Q6 -mode toshiba -D180";

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
