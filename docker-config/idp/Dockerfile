# actual image we'll run in the end
FROM php:8.3-apache
WORKDIR /var/www

# Install composer & php extension installer
COPY --from=composer/composer:2-bin /composer /usr/bin/composer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN apt-get update && \
    apt-get -y install git curl vim && \
    install-php-extensions ldap zip

# dirs used by simplesamlphp needs to be accessible by apache user
RUN mkdir simplesamlphp/ /var/cache/simplesamlphp
RUN chown www-data. simplesamlphp/ /var/cache/simplesamlphp
# Composer doesn't like to be root, so we'll run the rest as the apache user
USER www-data

# Install simplesamlphp
ARG SIMPLESAMLPHP_TAG=v2.2.1
RUN git clone --branch $SIMPLESAMLPHP_TAG https://github.com/simplesamlphp/simplesamlphp.git
WORKDIR /var/www/simplesamlphp

# Generate certs
RUN cd cert/ && \
    openssl req -newkey rsa:3072 -new -x509 -days 3652 -nodes -out server.crt -keyout server.pem -subj "/C=CA/SP=BC/L=Vancouver/O=UBC/CN=idp.docker"

# Use composer to install dependencies
RUN composer install && \
    composer require simplesamlphp/simplesamlphp-module-metarefresh

# Copy config files
COPY ./config/ config/
COPY ./metadata/ metadata/

COPY ./apache.conf /etc/apache2/sites-available/000-default.conf
