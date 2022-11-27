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

package Mojolicious::WeBWorK;

=head1 NAME

Mojolicious::WeBWorK - Mojolicious app for WeBWorK 2.

=cut

use Mojo::Base 'Mojolicious', -signatures, -async_await;
use Env qw(WEBWORK_SERVER_ADMIN);

use WeBWorK;
use WeBWorK::CourseEnvironment;

sub startup ($app) {
	# Set up logging.
	$app->log->path($app->home->child('logs', 'webwork2.log')) if $ENV{MOJO_MODE} && $ENV{MOJO_MODE} eq 'production';

	# Load configuration from config file
	my $config_file = "$ENV{WEBWORK_ROOT}/conf/webwork2.mojolicious.yml";
	$config_file = "$ENV{WEBWORK_ROOT}/conf/webwork2.mojolicious.dist.yml" unless -e $config_file;
	my $config = $app->plugin('NotYAMLConfig', { file => $config_file });

	# Configure the application
	$app->secrets($config->{secrets});

	# Load a minimal course environment
	my $ce = WeBWorK::CourseEnvironment->new({ webwork_dir => $ENV{WEBWORK_ROOT} });

	# Set important configuration variables
	my $webwork_url         = $ce->{webwork_url};
	my $webwork_htdocs_url  = $ce->{webwork_htdocs_url};
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

	# Setup the Minion job queue.
	$app->plugin(Minion => { $ce->{job_queue}{backend} => $ce->{job_queue}{database_dsn} });
	$app->minion->add_task(lti_mass_update       => 'Mojolicious::WeBWorK::Tasks::LTIMassUpdate');
	$app->minion->add_task(send_instructor_email => 'Mojolicious::WeBWorK::Tasks::SendInstructorEmail');

	# Helpers

	# This replaces the previous Apache2::RequestUtil method that was overriden in the WeBWorK::Request module to return
	# the empty string for '/'.
	$app->helper(location => sub ($) { return $webwork_url eq '/' ? '' : $webwork_url });

	$app->helper(server_root_url => sub ($) { return $server_root_url; });
	$app->helper(webwork_url     => sub ($) { return $webwork_url; });

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

	# Router
	my $r = $app->routes;

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

	# Provide direct access to pg_files.
	$r->any(
		'pg_files/*static' => sub ($c) {
			my $pg_htdocs_file = "$ENV{PG_ROOT}/htdocs/" . $c->stash('static');
			return $c->reply->file($pg_htdocs_file) if -r $pg_htdocs_file;
			return $c->render(data => 'File not found', status => 404);
		}
	);

	# Provide access to course-specific resources.
	$r->any(
		"$webwork_courses_url/:course/*static" => sub ($c) {
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
			$app->log->info("SOAP endpoints enabled");
			$WeBWorK::SeedCE{soap_authen_key} = $config->{soap_authen_key};

			$r->any('/webwork2_wsdl')->to('SOAP#wsdl');
			$r->post('/webwork2_rpc')->to('SOAP#dispatch');
		} else {
			$app->log->info(qq{Invalid soap_authen_key "$config->{soap_authen_key}". }
					. 'It must consist entirely of digits.  SOAP endpoints NOT enabled.');
		}
	}

	# Send all routes under $webwork_url to the handler.
	# Note that these routes must come last to support the case that $webwork_url is '/'.
	$r->any($webwork_url)->to('Handler#handler');
	$r->any("$webwork_url/*path-info")->to('Handler#handler');

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
