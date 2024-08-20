# Development identity provider test instance for SAML2 authentication

A development SAML2 identity provider is provided that uses SimpleSAMLphp.
Instructions for utilizing this instance follow.

## Webwork2 Configuration

Copy `/opt/webwork/webwork2/conf/authen_saml2.conf.dist` to
`/opt/webwork/webwork2/conf/authen_saml2.conf`.

The default `conf/authen_saml2.conf.dist` is configured to use the docker
identity provider. So for the docker build, it should work as is.

Without the docker build a few changes are needed.

- Find the `$saml2{idps}{default}` setting and change its value to
  `'http://localhost/simplesaml/module.php/saml/idp/metadata'`.
- Find the `$saml2{sp}{entity_id}` setting and change its value to
  `'http://localhost:3000/webwork2/saml2'`.
- In the `$saml2{sp}{org}` hash change the `url` to `'https://localhost:3000/'`.

The above settings assume you will use `morbo` with the default port.  Change
the port as needed.

## Development IdP test instance with docker

A docker service that implements a SAML2 identity provider is provided in the
`docker-compose.yml.dist` file. To start this identity provider along with the
rest of webwork2, add the `--profile saml2dev` argument to docker compose as in
the following exmaple.

```bash
docker compose --profile saml2dev up
```

Without the profile argument, the identity provider services do not start.

Stop all docker services with

```bash
docker compose --profile saml2dev down
```

## Development IdP test instance without docker

Effective development is not done with docker. So it is usually more useful to
set up an identity provider without docker. The following instructions are for
Ubuntu 24.04, but could be adapted for other operating systems.

A web server and php are needed to serve the SimpleSAMLphp files.  Install these
and other dependencies with:

```bash
sudo apt install \
    apache2 php php-ldap php-zip php-xml php-curl php-sqlite3 php-fpm \
    composer
```

Now download the SimpleSAMLphp source, install php dependencies, install the
SimpleSAMLphp metarefresh module, and set file permissions with

```bash
cd /var/www
sudo mkdir simplesamlphp /var/cache/simplesamlphp
sudo chown $USER:www-data simplesamlphp
sudo chown www-data /var/cache/simplesamlphp
git clone --branch v2.2.1 https://github.com/simplesamlphp/simplesamlphp.git
sudo chown -R $USER:www-data simplesamlphp
sudo chmod -R g+w simplesamlphp
cd simplesamlphp
composer install
composer require simplesamlphp/simplesamlphp-module-metarefresh
```

Next, generate certificates for the SimpleSAMLphp identity provider and make
them owned by the `www-data` user with

```bash
cd /var/www/simplesamlphp/cert
openssl req -newkey rsa:3072 -new -x509 -days 3652 -nodes \
    -out server.crt -keyout server.pem \
    -subj "/C=US/ST=New York/L=Rochester/O=WeBWorK/CN=idp.webwork2"
sudo chown www-data:www-data server.crt server.pem
```

Next, copy the `idp` configuration files from `docker-config`.

```bash
cp /opt/webwork/webwork2/docker-config/idp/config/* /var/www/simplesamlphp/config/
cp /opt/webwork/webwork2/docker-config/idp/metadata/* /var/www/simplesamlphp/metadata/
```

The configuration files are setup to work with the docker build. So there are
some changes that are needed.

Edit the file `/var/www/simplesamlphp/config/config.php` and change
`baseurlpath` to `simplesaml/`.

Edit the file `/var/www/simplesamlphp/metadata/saml20-idp-hosted.php` and change
the line that reads
`$metadata['http://localhost:8180/simplesaml'] = [`
to
`$metadata['http://localhost/simplesaml'] = [`.

Enable the apache2 idp configuration with

```bash
sudo cp /opt/webwork/webwork2/docker-config/idp/idp.apache2.conf /etc/apache2/conf-available
sudo a2enconf idp.apache2 php8.3-fpm
```

Edit the file `/etc/apache2/conf-available/idp.apache2.conf` and add the line
`SetEnv SP_METADATA_URL http://localhost:3000/webwork2/saml2/metadata` to the
beginning of the file. This again assumes you will use `morbo` with the default
port, so change the port if necessary.

Restart (or start) apache2 with `sudo systemctl restart apache2`.

The SimpleSAMLphp identity provider needs to fetch webwork2's service provider
metadata.  For this execute

```bash
curl -f http://localhost/simplesaml/module.php/cron/run/metarefresh/webwork2
```

That is done automatically with the docker build.  The command usually only
needs to be done once, but may need to be run again if settings are changed.

## Identity provider administration

The identity provider has an admin interface. You can login to the docker
instance with the password 'admin' at
`http://localhost:8180/simplesaml/module.php/admin/federation`
or without docker at
`http://localhost/simplesaml/module.php/admin/federation`.

The admin interface lets you check if the identity provider has properly
registered the webwork2 service provider under the 'Federation' tab, it should
be listed under the "Trusted entities" section.

You can also test login with the user accounts listed below in the "Test" tab
under the "example-userpass" authentication source.

## Single sign-on users

The following single sign-on accounts are preconfigured:

- Username: student01, Password: student01
- Username: instructor01, Password: instructor01
- Username: staff01, Password: staff01

You can add more accounts to the `docker-config/idp/config/authsources.php` file
in the `example-userpass` section. If using docker the identity provider, the
image will need to be rebuilt for the changes to take effect.

## Troubleshooting

### "Error retrieving metadata"

This error message indicates that the Saml2 authentication module wasn't able to
fetch the metadata from the identity provider metadata URL. Make sure the
identity provider is accessible to webwork2.

### User not found in course

The user was verified by the identity provider but did not have a corresponding
user account in the Webwork course. The Webwork user account needs to be created
separately as the Saml2 autentication module does not do user provisioning.

### The WeBWorK service provider does not appear in the service provider Federation tab

This can occur when using the docker identity provider service because Webwork's
first startup can be slow enough that the IdP wasn't able to successfully fetch
metadata from the webwork2 metadata URL. Restarting everything should fix this.
