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

package WeBWorK::HTML::CodeMirrorEditor;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::HTML::CodeMirrorEditor is a module for displaying a CodeMirror editor
on a page.  This is currently used by the AchievementEditor.pm and
PGProblemEditor.pm modules.

=cut

use WeBWorK::Utils qw(getAssetURL);

our @EXPORT_OK = qw(generate_codemirror_html generate_codemirror_controls_html output_codemirror_static_files);

# Available CodeMirror themes
use constant CODEMIRROR_THEMES => [
	'3024-day',                '3024-night',         'abbott',        'abcdef',
	'ambiance',                'ambiance-mobile',    'ayu-dark',      'ayu-mirage',
	'base16-dark',             'base16-light',       'bespin',        'blackboard',
	'cobalt',                  'colorforth',         'darcula',       'dracula',
	'duotone-dark',            'duotone-light',      'eclipse',       'elegant',
	'erlang-dark',             'gruvbox-dark',       'hopscotch',     'icecoder',
	'idea',                    'isotope',            'juejin',        'lesser-dark',
	'liquibyte',               'lucario',            'material',      'material-darker',
	'material-ocean',          'material-palenight', 'mbo',           'mdn-like',
	'midnight',                'monokai',            'moxer',         'neat',
	'neo',                     'night',              'nord',          'oceanic-next',
	'panda-syntax',            'paraiso-dark',       'paraiso-light', 'pastel-on-dark',
	'railscasts',              'rubyblue',           'seti',          'shadowfox',
	'solarized',               'ssms',               'the-matrix',    'tomorrow-night-bright',
	'tomorrow-night-eighties', 'ttcn',               'twilight',      'vibrant-ink',
	'xq-dark',                 'xq-light',           'yeti',          'yonce',
	'zenburn'
];

# Available CodeMirror keymaps
use constant CODEMIRROR_KEYMAPS => [ 'emacs', 'sublime', 'vim' ];

# Javascript for addons used by the PG editor (relative to the node_modules/codemirror/addon directory).
use constant CODEMIRROR_ADDONS_CSS => [ 'dialog/dialog.css', 'search/matchesonscrollbar.css', 'fold/foldgutter.css' ];

# Javascript for addons used by the PG editor (relative to the node_modules/codemirror/addon directory).
use constant CODEMIRROR_ADDONS_JS => [
	'dialog/dialog.js',            'search/search.js',
	'search/searchcursor.js',      'search/matchesonscrollbar.js',
	'search/match-highlighter.js', 'search/match-highlighter.js',
	'scroll/annotatescrollbar.js', 'edit/matchbrackets.js',
	'fold/foldcode.js',            'fold/foldgutter.js',
	'fold/xml-fold.js'
];

sub generate_codemirror_html ($c, $name, $contents = '', $mode = 'PG') {
	# Output the textarea that will be used by CodeMirror.
	# If CodeMirror is disabled, then this is directly the editing area.
	return $c->text_area($name => $contents, id => $name, class => 'codeMirrorEditor', data => { mode => $mode });
}

sub generate_codemirror_controls_html ($c) {
	my $ce = $c->ce;

	return '' unless $ce->{options}{PGCodeMirror};

	# Construct the labels and values for the theme menu.
	my $themeValues = [ [ default => 'default', selected => 'selected' ] ];
	for (@{ CODEMIRROR_THEMES() }) {
		push @$themeValues, [ $_ => getAssetURL($ce, "node_modules/codemirror/theme/$_.css") ];
	}

	# Construct the labels and values for the keymap menu.
	my $keymapValues = [ [ default => 'default', selected => 'selected' ] ];
	for (@{ CODEMIRROR_KEYMAPS() }) {
		push @$keymapValues, [ $_ => getAssetURL($ce, "node_modules/codemirror/keymap/$_.js") ];
	}

	return $c->include('HTML/CodeMirrorEditor/controls', themeValues => $themeValues, keymapValues => $keymapValues);
}

sub output_codemirror_static_files ($c, $mode = 'PG') {
	return $c->include(
		'HTML/CodeMirrorEditor/js',
		codemirrorAddonsCSS => CODEMIRROR_ADDONS_CSS(),
		codemirrorAddonsJS  => CODEMIRROR_ADDONS_JS(),
		codemirrorModesJS   => $mode eq 'htmlmixed' ? [ 'xml', 'css', 'javascript', 'htmlmixed' ] : [$mode]
	);
}

1;
