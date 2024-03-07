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

package Mojolicious::WeBWorK;
use Mojo::Base 'Mojolicious', -signatures, -async_await;

=head1 NAME

Mojolicious::WeBWorK - Mojolicious app for WeBWorK 2.

=cut

use Env qw(WEBWORK_SERVER_ADMIN);

use WeBWorK;
use WeBWorK::CourseEnvironment;
use WeBWorK::Utils qw(writeTimingLogEntry);
use WeBWorK::Utils::Routes qw(setup_content_generator_routes);

sub startup ($app) {
	# Set up logging.
	$app->log->path($app->home->child('logs', 'webwork2.log')) if $app->mode eq 'production';

	# Load configuration from config file
	my $config_file = "$ENV{WEBWORK_ROOT}/conf/webwork2.mojolicious.yml";
	$config_file = "$ENV{WEBWORK_ROOT}/conf/webwork2.mojolicious.dist.yml" unless -e $config_file;
	my $config = $app->plugin('NotYAMLConfig', { file => $config_file });

	# Configure the application
	$app->secrets($config->{secrets});

	# Set constants from the configuration.
	$WeBWorK::Debug::Enabled                                = $config->{debug}{enabled} // 0;
	$WeBWorK::Debug::Logfile                                = $config->{debug}{logfile} // '';
	$WeBWorK::Debug::DenySubroutineOutput                   = $config->{debug}{deny_subroutine_output};
	$WeBWorK::Debug::AllowSubroutineOutput                  = $config->{debug}{allow_subroutine_output};
	$WeBWorK::ContentGenerator::Hardcopy::PreserveTempFiles = $config->{hardcopy}{preserve_temp_files} // 0;

	# Load the plugin that switches the server to the non-root server user and group
	# if the app is run as root and is in production mode.
	$app->plugin(SetUserGroup => { user => $config->{server_user}, group => $config->{server_group} })
		if $app->mode eq 'production' && $> == 0;

	# Load a minimal course environment
	my $ce = WeBWorK::CourseEnvironment->new;

	# Set important configuration variables
	my $webwork_url         = $ce->{webwork_url};
	my $webwork_htdocs_url  = $ce->{webwork_htdocs_url};
	my $pg_htdocs_url       = $ce->{pg_htdocs_url} // '/pg_files';
	my $webwork_htdocs_dir  = $ce->{webwork_htdocs_dir};
	my $webwork_courses_url = $ce->{webwork_courses_url};
	my $webwork_courses_dir = $ce->{webwork_courses_dir};
	my $server_root_url     = $ce->{server_root_url};

	$app->log->info('WeBWorK server is starting');
	$app->log->info("WeBWorK root directory set to $ENV{WEBWORK_ROOT}");
	$app->log->info("PG root directory set to $ENV{PG_ROOT}");
	$app->log->info("The webwork url on this site is ${server_root_url}$webwork_url");

	$WEBWORK_SERVER_ADMIN = $ce->{webwork_server_admin_email};
	if ($WEBWORK_SERVER_ADMIN) {
		$app->log->info(
			"webwork_server_admin_email for reporting bugs has been set to $WEBWORK_SERVER_ADMIN in site.conf");
	}

	# Make the htdocs directory the first place to search for static files.  At this point this is only used by the
	# exception templates, but it could be used to improve the getAssetURL method together with the Mojolicious
	# url_for_asset controller method.
	unshift(@{ $app->static->paths }, $webwork_htdocs_dir);

	# Setup the Minion job queue. Make sure that any task added here is represented in the TASK_NAMES hash in
	# WeBWorK::ContentGenerator::Instructor::JobManager.
	$app->plugin(Minion => { $ce->{job_queue}{backend} => $ce->{job_queue}{database_dsn} });
	$app->minion->add_task(lti_mass_update        => 'Mojolicious::WeBWorK::Tasks::LTIMassUpdate');
	$app->minion->add_task(send_instructor_email  => 'Mojolicious::WeBWorK::Tasks::SendInstructorEmail');
	$app->minion->add_task(send_achievement_email => 'Mojolicious::WeBWorK::Tasks::AchievementNotification');

	# Provide the ability to serve data as a file download.
	$app->plugin('RenderFile');

	# Helpers

	# This replaces the previous Apache2::RequestUtil method that was overridden in
	# the WeBWorK::Request module to return the empty string for '/'.
	$app->helper(location => sub ($) { return $webwork_url eq '/' ? '' : $webwork_url });

	$app->helper(server_root_url => sub ($) { return $server_root_url; });
	$app->helper(webwork_url     => sub ($) { return $webwork_url; });

	$app->helper(
		maketext => sub ($c, @args) {
			return $args[0] unless $c->stash->{language_handle};
			return $c->stash->{language_handle}->(@args);
			# Comment out the above line and uncomment below to check that your strings are run through maketext.
			#return 'xXx' . $c->stash->{language_handle}->(@args) . 'xXx';
		}
	);

	# Add a hook to add extra headers if set in the config file.
	if (ref $config->{extra_headers} eq 'HASH') {
		$app->hook(
			before_dispatch => sub ($c) {
				for my $path (keys %{ $config->{extra_headers} }) {
					if ($c->req->url->path =~ /^$path/) {
						for (keys %{ $config->{extra_headers}{$path} }) {
							$c->res->headers->header($_ => $config->{extra_headers}{$path}{$_});
						}
					}
				}
			}
		);
	}

	# Add a hook that redirects http to https if configured to do so.
	if ($config->{redirect_http_to_https}) {
		$app->hook(
			before_dispatch => sub ($c) {
				my $request_url = $c->req->url->to_abs;
				if ($request_url->scheme eq 'http') {
					$request_url->scheme('https');
					$c->redirect_to($request_url);
				}
			}
		);
	}

	$app->hook(
		around_action => async sub ($next, $c, $action, $last) {
			return $next->() unless $c->isa('WeBWorK::ContentGenerator');

			my $uri = $c->req->url->path->to_string;
			$c->stash->{warnings} //= '';

			$c->stash->{orig_sig_warn} = $SIG{__WARN__};

			$SIG{__WARN__} = sub {
				my ($warning) = @_;
				chomp $warning;
				$c->stash->{warnings} .= "$warning\n";
				$c->log->warn("[$uri] $warning");
			};

			$c->timing->begin('content_generator_rendering');

			my ($result, $message) = eval { await WeBWorK::dispatch($c) };
			return $c->reply->exception($@)                    if $@;
			return $c->render(text => $message, status => 404) if !$result && $message;
			return $next->()                                   if $result;

			return 0;
		}
	);

	$app->hook(
		after_dispatch => sub ($c) {
			$SIG{__WARN__} = $c->stash->{orig_sig_warn} if defined $c->stash->{orig_sig_warn};

			if ($c->isa('WeBWorK::ContentGenerator') && $c->ce) {
				$c->authen->store_session if $c->authen;
				writeTimingLogEntry(
					$c->ce,
					'[' . $c->url_for . ']',
					sprintf('runTime = %.3f sec', $c->timing->elapsed('content_generator_rendering')) . ' '
						. $c->ce->{dbLayoutName},
					''
				);
			}
		}
	);

	# Router
	my $r = $app->routes;
	push(@{ $r->namespaces }, 'WeBWorK::ContentGenerator');

	# Provide access to webwork2 and pg resources.  A resource from $webwork_htdocs_dir is used if present, then
	# $pg_dir/htdocs is checked if the file is not found there.
	$r->any(
		"$webwork_htdocs_url/*static" => sub ($c) {
			my $webwork_htdocs_file = "$webwork_htdocs_dir/" . $c->stash('static');
			return $c->reply->file($webwork_htdocs_file) if -r $webwork_htdocs_file;
			my $pg_htdocs_file = "$ENV{PG_ROOT}/htdocs/" . $c->stash('static');
			return $c->reply->file($pg_htdocs_file) if -r $pg_htdocs_file;
			return $c->render(data => 'File not found', status => 404);
		}
	);

	# Provide direct access to the pg htdocs location.
	$r->any(
		"$pg_htdocs_url/*static" => sub ($c) {
			my $pg_htdocs_file = "$ENV{PG_ROOT}/htdocs/" . $c->stash('static');
			return $c->reply->file($pg_htdocs_file) if -r $pg_htdocs_file;
			return $c->render(data => 'File not found', status => 404);
		}
	);

	# Provide access to course-specific resources.
	$r->any(
		"$webwork_courses_url/#course/*static" => sub ($c) {
			my $file = "$webwork_courses_dir/" . $c->stash('course') . '/html/' . $c->stash('static');
			return $c->reply->file($file) if -r $file;
			return $c->render(data => 'File not found', status => 404);
		}
	);

	# Provide access to the htdocs temp url in case it is not actually located in htdocs.
	$r->any(
		"$ce->{webworkURLs}{htdocs_temp}/*static" => sub ($c) {
			my $file = "$ce->{webworkDirs}{htdocs_temp}/" . $c->stash('static');
			return $c->reply->file($file) if -r $file;
			return $c->render(data => 'File not found', status => 404);
		}
	);

	if ($config->{soap_authen_key}) {
		# Only allow an authen key that consists entirely of digits.  The WebworkSOAP module uses a numeric != for
		# comparison, and in perl all strings containing alphabetic characters are numerically equal.  So if this is not
		# numeric all keys that are passed in will succeed in authentication.  Very dangerous!
		if ($config->{soap_authen_key} =~ /^\d*$/) {
			$app->log->info('SOAP endpoints enabled');
			$WeBWorK::SeedCE{soap_authen_key} = $config->{soap_authen_key};

			push(@{ $r->namespaces }, 'WebworkSOAP');
			$r->any('/webwork2_wsdl')->to('SOAP#wsdl');
			$r->post('/webwork2_rpc')->to('SOAP#dispatch');
		} else {
			$app->log->info(qq{Invalid soap_authen_key "$config->{soap_authen_key}". }
					. 'It must consist entirely of digits.  SOAP endpoints NOT enabled.');
		}
	}

	# Letsencrypt renewal route.
	if ($config->{enable_certbot_webroot_routes}) {
		$r->any(
			"/.well-known/*static" => sub ($c) {
				my $file = "$ce->{webworkDirs}{tmp}/.well-known/" . $c->stash('static');
				return $c->reply->file($file) if -r $file;
				return $c->render(data => 'File not found', status => 404);
			}
		);
	}

	# Note that these routes must come last to support the case that $webwork_url is '/'.

	my $cg_r = $r->under($webwork_url)->name('root');
	$cg_r->get('/')->to('Home#go')->name('root');

	# The course admin route is set up here because of its special stash value.
	$cg_r->any("/$ce->{admin_course_id}")->to('CourseAdmin#go', courseID => $ce->{admin_course_id})
		->name('course_admin');

	setup_content_generator_routes($cg_r);

	$r->any(
		'/' => sub ($c) {
			return $c->redirect_to($config->{server_root_url_redirect}) if ($config->{server_root_url_redirect});
			return $c->reply->file("$ENV{WEBWORK_ROOT}/htdocs/index.html")
				if (-e "$ENV{WEBWORK_ROOT}/htdocs/index.html");
			return $c->reply->file("$ENV{WEBWORK_ROOT}/htdocs/index.dist.html");
		}
	);

	# Catch-all page not found route
	$r->any(
		'/*' => sub ($c) {
			return $c->render(text => 'Page not found', status => 404) if $c->accepts('', 'html');
			return $c->respond_to(any => { text => 'Invalid request endpoint', status => 404 });
		}
	);

	return;
}

1;
