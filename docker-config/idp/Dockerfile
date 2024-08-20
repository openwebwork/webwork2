FROM php:8.3-apache
WORKDIR /var/www

# Install composer and the php extension installer.
COPY --from=composer/composer:2-bin /composer /usr/bin/composer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN apt-get update && \
	apt-get -y install git curl vim && \
	install-php-extensions ldap zip

# Directories used by simplesamlphp.  These need to be accessible by the apache2 user.
RUN mkdir simplesamlphp/ /var/cache/simplesamlphp
RUN chown www-data simplesamlphp/ /var/cache/simplesamlphp

COPY ./idp.apache2.conf /etc/apache2/conf-available
RUN a2enconf idp.apache2

# Composer doesn't like to be root, so run the rest as the apache user.
USER www-data

# Install simplesamlphp
RUN git clone --branch v2.2.1 https://github.com/simplesamlphp/simplesamlphp.git
WORKDIR /var/www/simplesamlphp

# Generate the server certificates.
RUN cd cert/ && \
	openssl req -newkey rsa:3072 -new -x509 -days 3652 -nodes -out server.crt -keyout server.pem \
		-subj "/C=US/S=New York/L=Rochester/O=WeBWorK/CN=idp.webwork2"

# Use composer to install dependencies.
RUN composer install && \
	composer require simplesamlphp/simplesamlphp-module-metarefresh

# Copy configuration files.
COPY ./config/ config/
COPY ./metadata/ metadata/

