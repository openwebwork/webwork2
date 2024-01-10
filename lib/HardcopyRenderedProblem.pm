################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

=head1 NAME

HardcopyRenderedProblem.pm -- Generate a pdf file or zip file containing a tex
file and the neccessary files to generate the pdf file from the result of the
renderProblem method.

=cut

package HardcopyRenderedProblem;

use strict;
use warnings;

use File::Path;
use String::ShellQuote;
use Archive::Zip qw(:ERROR_CODES);
use Mojo::File qw(path tempdir);
use XML::LibXML;

sub hardcopyRenderedProblem {
	my $ws = shift;     # $ws is a WebworkWebservice object.
	my $c  = $ws->c;
	my $ce = $ws->ce;

	my $rh_result = $ws->return_object;

	# Deal with PG errors
	return $rh_result->{errors} if $rh_result->{flags}{error_flag};

	return 'This problem has no content.' unless $rh_result->{text};

	my @errors;

	my $courseID = $ws->{inputs_ref}{courseID};
	my $userID   = $ws->{inputs_ref}{user};

	# Create the parent directory for the temporary working directory.
	my $temp_dir_parent_path = path("$ce->{webworkDirs}{tmp}/$courseID/hardcopy/$userID");
	eval { $temp_dir_parent_path->make_path };
	if ($@) {
		push(@errors, "Couldn't create hardcopy directory $temp_dir_parent_path: $@");
		return join("\n", @errors);
	}

	# Create a randomly named directory in the hardcopy directory.
	my $temp_dir_path = eval { tempdir('work.XXXXXXXX', DIR => $temp_dir_parent_path) };
	if ($@) {
		push(@errors, "Couldn't create temporary directory: $@");
		return join("\n", @errors);
	}

	# Use the basename of the source file path without the extension prefixed with the course id and user id for the
	# working directory namd and download filename.
	my $returnFileName =
		"$courseID.$userID." . ((($ws->{inputs_ref}{sourceFilePath} =~ s/^.*\///r) =~ s/\.[^.]*$//r) || 'hardcopy');

	# Create a subdirectory of that to do all of the work in.  This directory will be zipped
	# if the tex outputformat is specified or if pdf generation fails or has errors.
	my $working_dir = $temp_dir_path->child($returnFileName);
	eval { $working_dir->make_path };
	if ($@) {
		push(@errors, "Couldn't create working directory $working_dir: $@");
		return join("\n", @errors);
	}

	# Create TeX file.
	my $tex_file = $working_dir->child('hardcopy.tex');
	my $fh       = $tex_file->open('>:encoding(UTF-8)');
	unless ($fh) {
		push(@errors, qq{Failed to open file "$tex_file" for writing: $!});
		return join("\n", @errors);
	}
	write_tex($ws, $fh, \@errors);
	$fh->close;

	# Call the pdf generation subroutine if the pdf outputformat was specified or if no outputformat was specified.
	if (!$ws->{inputs_ref}{outputformat} || $ws->{inputs_ref}{outputformat} eq 'pdf') {
		generate_hardcopy_pdf($ws, $working_dir, \@errors);

		# Send the pdf file if it was successfully generated with no errors.
		my $pdf_file = $working_dir->child('hardcopy.pdf');
		if (-e $pdf_file && !@errors) {
			$c->res->headers->content_type('application/pdf');
			$c->res->headers->add('Content-Disposition' => qq{attachment; filename=$returnFileName.pdf});
			$c->reply->file($pdf_file);
			return;
		}
	}

	# Call the tex generation subroutine if the tex outputformat was specified,
	# or if there were errors in generating the pdf file.
	generate_hardcopy_tex($ws, $working_dir, \@errors);

	# Send the zip file if it exists.
	my $zip_file = $temp_dir_path->child('hardcopy.zip');
	if (-e $zip_file) {
		$c->res->headers->content_type('application/zip');
		$c->res->headers->add('Content-Disposition' => qq{attachment; filename=$returnFileName.zip});
		$c->reply->file($zip_file);
		return;
	}

	# Something has really gone wrong.  A tex file was written, but hardcopy generation failed or had errors, and a zip
	# file could not be created.  Just return the errors that have accumulated.  Probably a lengthy list.
	return join("\n", @errors);
}

# This subroutine assumes that the TeX source file is located at $working_dir/hardcopy.tex.
sub generate_hardcopy_tex {
	my ($ws, $working_dir, $errors) = @_;
	my $src_file = $working_dir->child('hardcopy.tex');

	# Copy the common tex files into the working directory
	my $ce            = $ws->c->ce;
	my $assetsTex_dir = path($ce->{webworkDirs}{assetsTex});
	for (qw{webwork2.sty webwork_logo.png}) {
		eval { $assetsTex_dir->child($_)->copy_to($working_dir) };
		push(@$errors, qq{Failed to copy "$ce->{webworkDirs}{assetsTex}/$_" into directory "$working_dir": $@})
			if $@;
	}
	my $pgAssetsTex_dir = path($ce->{pg}{directories}{assetsTex});
	for (qw{pg.sty PGML.tex CAPA.tex}) {
		eval { $pgAssetsTex_dir->child($_)->copy_to($working_dir) };
		push(@$errors, qq{Failed to copy "$ce->{pg}{directories}{assetsTex}/$_" into directory "$working_dir": $@})
			if $@;
	}
	my $pgsty = path("$ce->{pg}{directories}{assetsTex}/pg.sty");
	eval { $pgsty->copy_to($working_dir) };
	push(@$errors, qq{Failed to copy "$ce->{pg}{directories}{assetsTex}/pg.sty" into directory "$working_dir": $@})
		if $@;

	# Attempt to copy image files used into the working directory.
	my $resource_list = $ws->return_object->{resource_list};
	if ($resource_list && keys %$resource_list) {
		my $data = eval { $src_file->slurp };
		unless ($@) {
			for my $resource (keys %$resource_list) {
				my $file_path = path($resource_list->{$resource});
				$data =~ s{$file_path}{$file_path->basename}ge;

				eval { $file_path->copy_to($working_dir) };
				push(@$errors, qq{Failed to copy image "$file_path" into directory "$working_dir": $@}) if $@;
			}

			# Rewrite the tex file with the image paths stripped.
			eval { $src_file->spurt($data) };
			push(@$errors, "Error rewriting $src_file: $@") if $@;
		} else {
			push(@$errors, qq{Failed to open "$$src_file" for reading: $@});
		}
	}

	# Write any errors to a file to include in the zip file.
	eval { $working_dir->child('hardcopy-generation-errors.log')->spurt(join("\n", @$errors)) } if @$errors;
	push(@$errors, "Failed to generate error log file: $@")                                     if $@;

	# Create a zip archive of the bundle directory
	my $zip = Archive::Zip->new;
	$zip->addTree($working_dir->dirname->to_string);

	push(@$errors, qq{Failed to create zip archive of directory "$working_dir"})
		unless ($zip->writeToFileNamed($working_dir->dirname->child('hardcopy.zip')->to_string) == AZ_OK);
	return;
}

# This subroutine assumes that the TeX source file is located at $working_dir/hardcopy.tex.
sub generate_hardcopy_pdf {
	my ($ws, $working_dir, $errors) = @_;

	# Save the current working directory and change to the temporary directory.
	my $cwd = path->to_abs;
	chdir($working_dir);

	# Call pdflatex
	my $pdflatex_cmd =
		'TEXINPUTS=.:'
		. shell_quote($ws->c->ce->{webworkDirs}{assetsTex}) . ':'
		. shell_quote($ws->c->ce->{pg}{directories}{assetsTex}) . ': '
		. $ws->c->ce->{externalPrograms}{pdflatex}
		. ' > pdflatex.stdout 2> pdflatex.stderr hardcopy';

	if (my $rawexit = system $pdflatex_cmd) {
		my $exit   = $rawexit >> 8;
		my $signal = $rawexit & 127;
		my $core   = $rawexit & 128;
		push(@$errors,
			qq{Failed to convert TeX to PDF with command "$pdflatex_cmd" (exit=$exit signal=$signal core=$core).},
			q{See the "hardcopy.log" file for details.});
	}

	# Restore the current working directory to what it was before.
	chdir($cwd);

	return;
}

sub write_tex {
	my ($ws, $FH, $errors) = @_;
	my $c  = $ws->c;
	my $ce = $c->ce;

	# get theme
	my $theme = $c->param('hardcopy_theme') // $ce->{hardcopyThemePGEditor};
	my $themeFile;
	if (-e "$ce->{courseDirs}{hardcopyThemes}/$theme") {
		$themeFile = "$ce->{courseDirs}{hardcopyThemes}/$theme";
	} elsif (-e "$ce->{webworkDirs}{hardcopyThemes}/$theme") {
		$themeFile = "$ce->{webworkDirs}{hardcopyThemes}/$theme";
	} else {
		push(@$errors, "Couldn't locate file for theme $theme.");
		return join("\n", @$errors);
	}
	my $themeTree = XML::LibXML->load_xml(location => $themeFile);

	print $FH '\\batchmode';
	print $FH $themeTree->findvalue('/theme/preamble');
	print $FH $themeTree->findvalue('/theme/presetheader');
	print $FH $themeTree->findvalue('/theme/postsetheader');
	print $FH $themeTree->findvalue('/theme/problemheader');
	write_problem_tex($ws, $FH);
	print $FH $themeTree->findvalue('/theme/problemfooter');
	print $FH $themeTree->findvalue('/theme/setfooter');
	print $FH $themeTree->findvalue('/theme/postamble');

	return;
}

sub write_problem_tex {
	my ($ws, $FH) = @_;
	my $c = $ws->c;

	my $rh_result = $ws->return_object;

	print $FH " {\\footnotesize\\path|$ws->{inputs_ref}{sourceFilePath}|}\n\n\\vspace{\\baselineskip}"
		if ($ws->{inputs_ref}{showSourceFile});

	print $FH $rh_result->{text};

	# Write the correct answers if requested and there are answers to write.
	if ($ws->{inputs_ref}{WWcorrectAns}) {
		my @ans_entry_order = @{ $rh_result->{flags}{ANSWER_ENTRY_ORDER} // [] };
		if (@ans_entry_order) {
			my $correctTeX =
				"\n\n\\vspace{\\baselineskip}\\par{\\small{\\it "
				. $c->maketext("Correct Answers:")
				. "}\n\\begin{itemize}\n";

			for (@ans_entry_order) {
				$correctTeX .=
					"\\item\n\$\\displaystyle "
					. ($rh_result->{answers}{$_}{correct_ans_latex_string}
						|| "\\text{$rh_result->{answers}{$_}{correct_ans}}")
					. "\$\n";
			}

			$correctTeX .= "\\end{itemize}}\\par\n";

			print $FH $correctTeX;
		}
	}

	# If there are any PG warnings and the view_problem_debugging_info parameter was set,
	# then append the warnings to end of the tex file.
	if ($ws->{inputs_ref}{view_problem_debugging_info} && $rh_result->{pg_warnings}) {
		print $FH "\n\n\\vspace{\\baselineskip}\\par\n" . $c->maketext('Warning messages:') . "\n\\begin{itemize}\n";
		for (split("\n", $rh_result->{pg_warnings})) {
			print $FH "\\item \\verb|$_|\n";
		}
		print $FH "\\end{itemize}\n";
	}

	return;
}

1;
