# SAML2 Authentication Plugin

This Mojolicious plugin implements SAML2 authentication for Webwork. SAML2
functionality is provided by the
[Net::SAML2](https://metacpan.org/dist/Net-SAML2) library. Net::SAML2 claims to
be compatible with a wide array of SAML2 based Single Sign On systems such as
Shibboleth. This plugin is intended to replace the previous Shibboleth
authentication module that depended on Apache mod_shib.

There are two components to SAML2 support, the Mojolicious plugin here and a a
regular Webwork Authen module at `lib/WeBWorK/Authen/Saml2.pm`.

## Configuration

To enable the Saml2 plugin, copy `conf/authen_saml2.dist.yml` to
`conf/authen_saml2.yml`.

Important settings:

- *idp.metadata_url* - must be set to the IdP's metadata endpoint
- *sp.entity_id* - the ID for the Webwork SP, this is usually the application
  root URL plus the base path to the SP
- *sp.attributes* - list of attribute OIDs that the SP will look at and try to
  match to a Webwork username
- *sp.cert*, *sp.signing_key* - a unique key and cert pair must be generated
  for your own prod deployments. The example key and cert is only meant for dev
  use as described below in [Docker Compose](#docker-compose-dev).

The Saml2 plugin will generate its own xml metadata that can be used by the IdP
for configuration. This is available at the `/saml2/metadata` URL with the
default config. Endpoint locations, such as metadata, can be configured under
`sp.route`.

### Generate key and cert

OpenSSL can be used to generate the key and cert, like the following command:

```bash
openssl req -newkey rsa:4096 -new -x509 -days 3652 -nodes -out saml.crt -keyout saml.pem
```

The cert is placed in `saml.crt`. The key is in `saml.pem`.

### localOverrides.conf

Webwork's authentication system will need to be configured to use the Saml2
module in `conf/localOverrides.conf`. The example below allows bypassing the
Saml2 module to use the internal username/password login as a fallback:

```perl
$authen{user_module} = [
 'WeBWorK::Authen::Saml2',
    'WeBWorK::Authen::Basic_TheLastOption'
];
```

If you add the bypass query to a course url, the Saml2 module will be skipped
and the next one in the list used, e.g.:
`http://localhost:8080/webwork2/TEST100?bypassSaml2=1`

Admin login also needs its own config, the example below assumes the bypass
option is disabled:

```perl
$authen{admin_module} = [
 'WeBWorK::Authen::Saml2'
];
```

To disable the bypass, `conf/authen_saml2.yml` must also be edited, commenting
out the `bypass_query` line.

## Docker Compose Dev

A dev use SAML2 IdP was added to docker-compose.yml.dist, to start this IdP
along with the rest of the Webwork, add the '--profile saml2dev' arg to docker
compose:

```bash
docker compose --profile saml2dev up
```

Without the profile arg, the IdP services do not start. The dev IdP is a
SimpleSAMLphp instance.

### Setup

The default `conf/authen_saml2.dist.yml` is configured to use this dev IdP.
Just copy it to `conf/authen_saml2.yml` and it should work.

### Admin

The dev IdP has an admin interface, you can login with the password 'admin' at:

```text
http://localhost:8180/simplesaml/module.php/admin/federation
```

The admin interface lets you check if the IdP has properly registered the
Webwork SP under the 'Federation' tab, it should be listed under the "Trusted
entities" section.

You can also test login with the user accounts listed below in the "Test" tab
under the "example-userpass" authentication source.

### Users

There are some single sign-on accounts preconfigured:

- Username: student01
  - Password: student01
- Username: instructor01
  - Password: instructor01
- Username: staff01
  - Password: staff01

You can add more accounts at `docker-config/idp/config/authsources.php` in the
`example-userpass` section. The IdP image will need to be rebuilt for the
change to take effect.

## Troubleshooting

### Webwork doesn't start, "Error retrieving metadata"

This error message indicates that the Saml2 plugin wasn't able to grab metadata
from the IdP metadata url. Make sure the IdP is accessible by the container.
Example error message:

```text
app-1  | Can't load application from file "/opt/webwork/webwork2/bin/webwork2":
Error retrieving metadata: Can't connect to idp.docker:8180 (Connection
refused) (500)
```

### User not found in course

The user was verified by the IdP but did not have a corresponding user account
in the Webwork course. The Webwork user account needs to be created separately
as the Saml2 plugin does not do user provisioning.

### Logout shows uninitialized value warnings

The message on the page reads "The course TEST100 uses an external
authentication system ()."

The external auth message takes values from LTI config. If you're not using
LTI, you can define the missing values separately in `localOverrides.conf`:

```perl
$LTIVersion = 'v1p3';
$LTI{v1p3}{LMS_name} = 'Webwork';
$LTI{v1p3}{LMS_url} = 'http://localhost:8080/';
```

It's not an ideal solution but the Saml2 plugin needs to declare itself as an
external auth system in order to avoid the internal 2FA. And the external auth
message assumes LTI is on.

### Dev IdP does not show the Webwork SP in Federation tab

Webwork's first startup might be slow enough that the IdP wasn't able to
successfully grab metadata from the Webwork Saml2 plugin. Restarting everything
should fix this.
