# Configuration of webwork2

Do not directly modify any of the files in the initial git clone of webwork2. If a filename contains `.dist` then the
file is intended to be copied to a file by the same name without `.dist` and the copy modified as needed. Specific
instructions are given below. If a filename **does** contain `.dist` then it should **not** be modified. If changes
are made to `.dist` files, then the modifications will be lost or cause conflict when webwork2 is upgraded.

## Configuration files for webwork2

Basic webwork2 configuration files.

- `site.conf.dist` should be copied to `site.conf`, and contains global variables required for basic server
  configuration. This file is read first in the initialization sequence.
- `defaults.config` contains initial settings for many customizable options in WeBWorK. This file is read second in the
  initialization sequence. **This file should not be changed**
- `localOverrides.conf.dist` should be copied to `localOverrides.conf`. `localOverrides.conf` will be read after the
  `defaults.config` file is processed and will overwrite configurations in `defaults.config`. Use this file to make
  changes to the settings in `defaults.config`.

Configuration extension files.

- `authen_LTI.conf.dist` should be copied to `authen_LTI.conf` if you want to allow LTI authentication into webwork2
  from an LMS.
- `LTIConfigVariables.config` includes some additional variables used by `authen_LTI.conf` and is included by that file.
- `authen_CAS.conf.dist` should be copied to `authen_CAS.conf` to configure CAS authentication.
- `authen_ldap.conf.dist` should be copied to `authen_ldap.conf` to configure LDAP authentication.

Server configuration files.

- `webwork2.mojolicious.dist.yml` contains the webwork2 Mojolicious app configuration settings. Copy this file to
  `webwork2.mojolicious.yml` if you need to change those settings. You usually will need to do this.
- `webwork2.dist.service` is a systemd configuration file for linux systems that serves the webwork2 app via the
  Mojolicious hypnotoad server. If you need to change it, then copy it to `webwork2.service`.
- `webwork2-job-queue.dist.service` is a systemd configuration file for linux systems that runs the webwork2 job queue
  via Minion. If you need to change it, then copy it to `webwork2-job-queue.service`.
- `webwork2.apache2.4.dist.conf` is only used if you proxy hypnotoad via apache2. Copy this to `webwork2.apache2.4.conf`
  if any changes need to be made.
- `webwork2.nginx.dist.conf` is only used if you proxy hypnotoad via nginx. Copy this to `webwork2.nginx.conf` if any
  changes need to be made.

## Initial configururation of webwork2

- Copy `site.conf.dist` to `site.conf` and `localOverrides.conf.dist` to `localOverrides.conf`, and adjust the variables
  in `site.conf` as needed. In particular you will need to set `$server_root_url` to the server name, and set
  `$database_password` to the password for the database.
- Adjust the variables in `localOverrides.conf` to customize your server for your needs.
- Copy any of the other `.dist` files and adjust the variables in them as needed. Note that those files will need to be
  included by the `localOverrides.conf` file.

## Configuration of webwork2 when upgrading

Examine the differences between your copies of the `.dist` files and the corresponding `.dist` files, and adjust your
copies as needed for changes to the variables that have been made. It is helpful to view a side-by-side `diff` of your
copy to the corresponding `.dist` file for this.

## Running webwork2 for development

There are two important settings that you may need to change in `site.conf`

- make sure that `$server_root_url` is set to `http://localhost:3000`.
- make sure that `$pg_dir` is set to the top of your pg directory.

After any other changes in the initial configuration of webwork2 you are ready to run webwork2 for development.
To do so from the webwork2 directory execute the following

```bash
./bin/dev_scripts/webwork2-morbo
```

Note that if you have permissions set for standard production use, then you may need to run this script as the server
user. You can do this on Ubuntu/Debian systems or MacOS with

```bash
sudo -u www-data ./bin/dev_scripts/webwork2-morbo
```

Use the server user on your system instead of "www-data" if it is different.

You can now open your browser to `http://localhost:3000/webwork2`.

For development and testing of the webwork2 job queue additionally execute the following.

```bash
./bin/webwork2 minion worker
```

Note that this needs to be run by the same user as the webwork2 app. Both need to have read and write access to the
SQLite database file that is used for the job queue.

Additionally note that the Minion worker does not hot reload. You must manually restart the worker to reload with
changes to the task modules.

## Direct deployment of webwork2 for production via hypnotoad

This is the simplest way to deploy webwork2 for production. Note that you should only use this if your server is
dedicated to only serving webwork2. In addition this may not work in some other cases. For instance, it may not work
with Shibboleth authentication.

First set up the webwork2 Mojolicious app:

- Copy `webwork2.mojolicious.dist.yml` to `webwork2.mojolicious.yml`.
- Change `server_user` and `server_group` to the appropriate values for your system.  On Ubuntu appropriate values are
  `www-data` for both.
- To run the server without SSL certificates change `listen` in the `hypnotoad` section at the end of the file to
  `- http://*:80`. This is not recommended for production use.
- To use SSL certificates change `listen` in the `hypnotoad` section to
  `- https://*:443?cert=/path/to/fullchain.pem&key=/path/to/privkey.pem`.
- Change `proxy: 1` to `proxy: 0` or comment out that line.
- You may also want to adjust the other settings in the file. The `server_root_url_redirect` setting may be useful.
- Instead of using that setting, you can also copy `htdocs/index.dist.html` to `htdocs/index.html` and that will be the
  server front page.
- Install the Perl module `Mojolicious::Plugin::SetUserGroup`.

The Mojolicious hypnotoad server will be started by the root user and the user and group will be switched to what is set
for `server_user` and `server_group` after the app starts.  It is not advisable to run the Mojolicious hypnotoad server
as a user that can directly login to the server.  On Ubuntu systems you can use the `www-data` user that is already
available. If a user is needed you can create the user `webwork`, for example, with `sudo useradd -M webwork`.  Make
sure that the user has read access to the SSL certificates given in the configuration above if using certificates.
Usually the user and group will be the same.

Then set up the systemd service:

- Copy `webwork2.dist.service` to `webwork2.service`.
- Comment out the `User`, `Group`, and `Environment` settings in the copy.
- To enable and start the service, execute

```bash
sudo systemctl enable /opt/webwork/webwork2/conf/webwork2.service
sudo systemctl start webwork2
```

You should now be able to open your browser to `http://yoursite.edu/webwork2` or `https://yoursite.edu/webwork2`.

## Deployment of webwork2 via hypnotoad proxied by apache2

This is a more versatile deployment approach. It allows you to use urls not consumed by webwork2 for other purposes.

First install and configure apache2. This is not covered in this document.

Then set up the webwork2 Mojolicious app:

- Copy `webwork2.mojolicious.dist.yml` to `webwork2.mojolicious.yml` if you want to modify settings in that file.
- Copy `webwork2.apache2.4.dist.conf` to `webwork2.apache2.4.conf`.
- Change the `X-Forwarded-Proto` to `http` if you do not have SSL certificates.
- Execute the following from the `/opt/webwork/webwork` directory to enable the webwork2 apache configuration:

```bash
sudo ln -s $PWD/conf/webwork2.apache2.4.conf /etc/conf-enabled/webwork2.conf
sudo a2enmod proxy proxy_http
sudo systemctl restart apache2
```

Now set up the systemd service:

- Copy `webwork2.dist.service` to `webwork2.service`.
- Execute the following to enable and start the service:

```bash
sudo systemctl enable /opt/webwork/webwork2/conf/webwork2.service
sudo systemctl start webwork2
```

## Deployment of webwork2 via hypnotoad proxied by nginx

This is a more versatile deployment approach. It allows you to use urls not consumed by webwork2 for other purposes.

First install and configure nginx. This is not covered in this document.

Then set up the webwork2 Mojolicious app:

- Copy `webwork2.mojolicious.dist.yml` to `webwork2.mojolicious.yml` if you want to modify settings in that file.
- Copy `webwork2.nginx.dist.conf` to `webwork2.nginx.conf` if you want to modify any settings. This will setup
  a reverse proxy for all webwork2 paths to proxy to the hypnotoad server. Usually this file will not need to be
  modified. You could even use the `.dist` file directly in most cases.
- Edit your nginx server configuration file (this may be in `/etc/nginx/conf.d` or `/etc/nginx/sites-available`) and add
  the line `include /opt/webwork/webwork2/conf/webwork2.nginx.conf;` to the end of the `server` section in that file.
- Execute the following from the `/opt/webwork/webwork2` directory to enable the webwork2 nginx configuration:

```bash
sudo systemctl restart nginx
```

Now set up the systemd service:

- Copy `webwork2.dist.service` to `webwork2.service`.
- Execute the following to enable and start the service:

```bash
sudo systemctl enable /opt/webwork/webwork2/conf/webwork2.service
sudo systemctl start webwork2
```

### Deployment of the webwork2 job queue for all server arrangments

Some long running processes are not directly run by the webwork2 Mojolicious app. Particularly mass grade updates via
LTI and sending of instructor emails. Instead these tasks are executed via the webwork2 Minion job queue.

Set up the job queue:

- Copy `webwork2-job-queue.dist.service` to `webwork2-job-queue.service`.

Then execute the following to start the job queue:

```bash
sudo systemctl enable /opt/webwork/webwork2/conf/webwork2-job-queue.service
sudo systemctl start webwork2-job-queue

```
