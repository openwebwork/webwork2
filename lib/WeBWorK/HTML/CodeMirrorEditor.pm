################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::HTML::CodeMirrorEditor;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::HTML::CodeMirrorEditor is a module for displaying a CodeMirror editor
on a page.  This is currently used by the AchievementEditor.pm and
PGProblemEditor.pm modules.

=cut

our @EXPORT_OK = qw(generate_codemirror_html output_codemirror_static_files);

sub generate_codemirror_html ($c, $name, $contents = '', $language = 'pg') {
	if ($c->ce->{options}{PGCodeMirror}) {
		# Output the div that will be used by CodeMirror and a hidden input containing the contents.
		return $c->c(
			$c->hidden_field($name => $contents),
			$c->tag(
				'div',
				id    => $name,
				class => 'code-mirror-editor tex2jax_ignore',
				data  => { language => $language }
			)
		)->join('');
	} else {
		# If CodeMirror is disabled, then a text area is used instead.
		return $c->text_area(
			$name => $contents,
			id    => $name,
			class => 'text-area-editor',
			data  => { language => $language }
		);
	}
}

sub output_codemirror_static_files ($c) {
	return $c->include('HTML/CodeMirrorEditor/js');
}

1;
