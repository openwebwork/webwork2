FROM ubuntu:16.04

ENV WEBWORK_URL=/webwork2 \
  WEBWORK_ROOT_URL=http://localhost \
  WEBWORK_DB_HOST=db \
  WEBWORK_DB_PORT=3306 \
  WEBWORK_DB_NAME=webwork \
  WEBWORK_DB_DSN=DBI:mysql:${WEBWORK_DB_NAME}:${WEBWORK_DB_HOST}:${WEBWORK_DB_PORT} \
  WEBWORK_DB_USER=webworkWrite \
  WEBWORK_DB_PASSWORD=passwordRW \
  WEBWORK_SMTP_SERVER=localhost \
  WEBWORK_SMTP_SENDER=webwork@example.com \
  WEBWORK_TIMEZONE=America/New_York \
  APACHE_RUN_USER=www-data \
  APACHE_RUN_GROUP=www-data \
  # temporary state file location. This might be changed to /run in Wheezy+1 \
  APACHE_PID_FILE=/var/run/apache2/apache2.pid \
  APACHE_RUN_DIR=/var/run/apache2 \
  APACHE_LOCK_DIR=/var/lock/apache2 \
  # Only /var/log/apache2 is handled by /etc/logrotate.d/apache2.
  APACHE_LOG_DIR=/var/log/apache2 \
  APP_ROOT=/opt/webwork \
  WEBWORK_ROOT=$APP_ROOT/webwork2 \
  PG_ROOT=$APP_ROOT/pg \
  DEV=0 \
  PG_VERSION=rel-PG-2.14


RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests \
       apache2 \
       curl \
       dvipng \
       gcc \
       libapache2-request-perl \
       libcrypt-ssleay-perl \
       libdatetime-perl \
       libdancer-perl \
       libdancer-plugin-database-perl \
       libdbd-mysql-perl \
       libemail-address-perl \
       libexception-class-perl \
       libextutils-xsbuilder-perl \
       libfile-find-rule-perl-perl \
       libgd-perl \
       libhtml-scrubber-perl \
       libjson-perl \
       liblocale-maketext-lexicon-perl \
       libmail-sender-perl \
       libmime-tools-perl \
       libnet-ip-perl \
       libnet-ldap-perl \
       libnet-oauth-perl \
       libossp-uuid-perl \
       libpadwalker-perl \
       libpath-class-perl \
       libphp-serialization-perl \
       libsoap-lite-perl \
       libsql-abstract-perl \
       libstring-shellquote-perl \
       libtemplate-perl \
       libtext-csv-perl \
       libtimedate-perl \
       libuuid-tiny-perl \
       libxml-parser-perl \
       libxml-writer-perl \
       libapache2-reload-perl \
       make \
       netpbm \
       preview-latex-style \
       texlive \
       texlive-latex-extra \
       libc6-dev \
       git \
       mysql-client \
    && curl -Lk https://cpanmin.us | perl - App::cpanminus \
    && cpanm install XML::Parser::EasyTree Iterator Iterator::Util Pod::WSDL Array::Utils HTML::Template XMLRPC::Lite Mail::Sender Email::Sender::Simple Data::Dump Statistics::R::IO \
    && rm -fr /var/lib/apt/lists/* ./cpanm /root/.cpanm /tmp/*

RUN mkdir -p $APP_ROOT/courses $APP_ROOT/libraries $APP_ROOT/webwork2

COPY VERSION /tmp

RUN curl -fSL https://github.com/openwebwork/pg/archive/${PG_VERSION}.tar.gz -o /tmp/${PG_VERSION}.tar.gz \
    && tar xzf /tmp/${PG_VERSION}.tar.gz \
    && mv pg-${PG_VERSION} $APP_ROOT/pg \
    && curl -fSL https://github.com/openwebwork/webwork-open-problem-library/archive/master.tar.gz -o /tmp/opl.tar.gz \
    && tar xzf /tmp/opl.tar.gz \
    && mv webwork-open-problem-library-master $APP_ROOT/libraries/webwork-open-problem-library \
    && rm /tmp/opl.tar.gz \
    && curl -fSL https://github.com/mathjax/MathJax/archive/master.tar.gz -o /tmp/mathjax.tar.gz \
    && tar xzf /tmp/mathjax.tar.gz \
    && mv MathJax-master $APP_ROOT/MathJax \
    && rm /tmp/mathjax.tar.gz \
    && rm /tmp/VERSION
    #curl -fSL https://github.com/openwebwork/webwork2/archive/WeBWorK-${WEBWORK_VERSION}.tar.gz -o /tmp/WeBWorK-${WEBWORK_VERSION}.tar.gz \
    #&& tar xzf /tmp/WeBWorK-${WEBWORK_VERSION}.tar.gz \
    #&& mv webwork2-WeBWorK-${WEBWORK_VERSION} $APP_ROOT/webwork2 \
    #&& rm /tmp/WeBWorK-${WEBWORK_VERSION}.tar.gz \

RUN echo "PATH=$PATH:$APP_ROOT/webwork2/bin" >> /root/.bashrc

COPY . $APP_ROOT/webwork2

RUN cd $APP_ROOT/webwork2/courses.dist \
    && cp *.lst $APP_ROOT/courses/ \
    && cp -R modelCourse $APP_ROOT/courses/ \
    && cd $APP_ROOT/pg/lib/chromatic \
    && gcc color.c -o color

# setup apache
RUN cd $APP_ROOT/webwork2/conf \
    && cp webwork.apache2.4-config.dist webwork.apache2.4-config \
    && cp $APP_ROOT/webwork2/conf/webwork.apache2.4-config /etc/apache2/conf-enabled/webwork.conf \
    && a2dismod mpm_event \
    && a2enmod mpm_prefork \
    && sed -i -e 's/Timeout 300/Timeout 1200/' /etc/apache2/apache2.conf \
    && sed -i -e 's/MaxRequestWorkers     150/MaxRequestWorkers     20/' \
        -e 's/MaxConnectionsPerChild   0/MaxConnectionsPerChild   100/' \
        /etc/apache2/mods-available/mpm_prefork.conf \
    && cp $APP_ROOT/webwork2/htdocs/favicon.ico /var/www/html \
    && sed -i -e 's/^<Perl>$/\
      PerlPassWEBWORK_URL\n\
      PerlPassWEBWORK_ROOT_URL\n\
      PerlPassWEBWORK_DB_DSN\n\
      PerlPassWEBWORK_DB_USER\n\
      PerlPassWEBWORK_DB_PASSWORD\n\
      PerlPassWEBWORK_SMTP_SERVER\n\
      PerlPassWEBWORK_SMTP_SENDER\n\
      PerlPassWEBWORK_TIMEZONE\n\
      \n<Perl>/' /etc/apache2/conf-enabled/webwork.conf

RUN cd $APP_ROOT/webwork2/ \
    && chown www-data DATA ../courses htdocs/tmp htdocs/applets logs tmp $APP_ROOT/pg/lib/chromatic \
    && chmod -R u+w DATA ../courses htdocs/tmp htdocs/applets logs tmp $APP_ROOT/pg/lib/chromatic

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80

WORKDIR $APP_ROOT

CMD ["apache2", "-DFOREGROUND"]
