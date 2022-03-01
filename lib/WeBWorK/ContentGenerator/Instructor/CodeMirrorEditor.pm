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

package WeBWorK::ContentGenerator::Instructor::CodeMirrorEditor;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::CodeMirrorEditor is a module for
displaying a CodeMirror editor on a page.  This is currently used by the
AchievementEditor.pm and PGProblemEditor.pm modules.

=cut

use CGI;
use WeBWorK::Utils qw(getAssetURL);

use strict;
use warnings;

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
use constant CODEMIRROR_ADDONS_CSS => [ 'dialog/dialog.css', 'search/matchesonscrollbar.css' ];

# Javascript for addons used by the PG editor (relative to the node_modules/codemirror/addon directory).
use constant CODEMIRROR_ADDONS_JS => [
	'dialog/dialog.js',            'search/search.js',
	'search/searchcursor.js',      'search/matchesonscrollbar.js',
	'search/match-highlighter.js', 'search/match-highlighter.js',
	'scroll/annotatescrollbar.js', 'edit/matchbrackets.js'
];

sub output_codemirror_html {
	my ($r, $name, $contents) = @_;

	if ($r->ce->{options}{PGCodeMirror}) {
		# Output the textarea that will be used by CodeMirror.
		print CGI::div(
			{ class => 'mb-2' },
			CGI::textarea({
				id       => $name,
				name     => $name,
				default  => $contents,
				class    => 'codeMirrorEditor',
				override => 1,
			}),
		);

		# Output the html elements for setting the CodeMirror options.
		print CGI::div(
			{ class => 'row align-items-center' },
			CGI::div(
				{ class => 'col-sm-auto mb-2' },
				CGI::div(
					{ class => 'row align-items-center' },
					CGI::label(
						{ for => 'selectTheme', class => 'col-form-label col-auto' },
						$r->maketext('Theme:')
					),
					CGI::div(
						{ class => 'col-auto' },
						CGI::popup_menu({
							name    => 'selectTheme',
							id      => 'selectTheme',
							values  => [ 'default', @{ CODEMIRROR_THEMES() } ],
							default => 'default',
							class   => 'form-select form-select-sm d-inline w-auto'
						})
					)
				)
			),
			CGI::div(
				{ class => 'col-sm-auto mb-2' },
				CGI::div(
					{ class => 'row align-items-center' },
					CGI::label(
						{ for => 'selectKeymap', class => 'col-form-label col-auto' },
						$r->maketext('Key Map:')
					),
					CGI::div(
						{ class => 'col-auto' },
						CGI::popup_menu({
							name    => 'selectKeymap',
							id      => 'selectKeymap',
							values  => [ 'default', @{ CODEMIRROR_KEYMAPS() } ],
							default => 'default',
							class   => 'form-select form-select-sm d-inline w-auto'
						})
					)
				)
			),
			CGI::div(
				{ class => 'col-sm-auto mb-2' },
				CGI::div(
					{ class => 'form-check mb-0' },
					CGI::input({
						type  => 'checkbox',
						id    => 'enableSpell',
						class => 'form-check-input'
					}),
					CGI::label(
						{ for => 'enableSpell', class => 'form-check-label' },
						$r->maketext('Enable Spell Checking')
					)
				)
			)
		);
	}
}

sub output_codemirror_static_files {
	my $ce = shift;

	if ($ce->{options}{PGCodeMirror}) {
		print CGI::Link(
			{ href => getAssetURL($ce, 'node_modules/codemirror/lib/codemirror.css'), rel => 'stylesheet' });

		for my $addon (@{ CODEMIRROR_ADDONS_CSS() }) {
			print CGI::Link({ href => getAssetURL($ce, "node_modules/codemirror/addon/$addon"), rel => 'stylesheet' });
		}
		for my $theme (@{ CODEMIRROR_THEMES() }) {
			print CGI::Link({
				href => getAssetURL($ce, "node_modules/codemirror/theme/$theme.css"),
				rel  => 'stylesheet'
			});
		}
		print CGI::Link({ href => getAssetURL($ce, 'js/apps/PGCodeMirror/pgeditor.css'), rel => 'stylesheet' });

		print CGI::script({ src => getAssetURL($ce, 'node_modules/codemirror/lib/codemirror.js'), defer => undef }, '');

		for my $keymap (@{ CODEMIRROR_KEYMAPS() }) {
			print CGI::script({ src => getAssetURL($ce, "node_modules/codemirror/keymap/$keymap.js"), defer => undef },
				'');
		}

		for my $addon (@{ CODEMIRROR_ADDONS_JS() }) {
			print CGI::script({ src => getAssetURL($ce, "node_modules/codemirror/addon/$addon"), defer => undef }, '');
		}

		print CGI::script({ src => getAssetURL($ce, 'js/apps/PGCodeMirror/PG.js'),       defer => undef }, '');
		print CGI::script({ src => getAssetURL($ce, 'js/apps/PGCodeMirror/pgeditor.js'), defer => undef }, '');
	}
}

1;
