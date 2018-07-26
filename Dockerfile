FROM ubuntu:16.04

ENV WEBWORK_URL /webwork2
ENV WEBWORK_ROOT_URL http://localhost
ENV WEBWORK_DB_HOST db
ENV WEBWORK_DB_PORT 3306
ENV WEBWORK_DB_NAME webwork
ENV WEBWORK_DB_DSN DBI:mysql:${WEBWORK_DB_NAME}:${WEBWORK_DB_HOST}:${WEBWORK_DB_PORT}
ENV WEBWORK_DB_USER webworkWrite
ENV WEBWORK_DB_PASSWORD passwordRW
ENV WEBWORK_SMTP_SERVER localhost
ENV WEBWORK_SMTP_SENDER webwork@example.com
ENV WEBWORK_TIMEZONE America/New_York
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
# temporary state file location. This might be changed to /run in Wheezy+1
ENV APACHE_PID_FILE /var/run/apache2/apache2.pid
ENV APACHE_RUN_DIR /var/run/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
# Only /var/log/apache2 is handled by /etc/logrotate.d/apache2.
ENV APACHE_LOG_DIR /var/log/apache2
ENV APP_ROOT /opt/webwork
ENV WEBWORK_ROOT $APP_ROOT/webwork2
ENV PG_ROOT $APP_ROOT/pg
ENV DEV 0


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

RUN WEBWORK_VERSION=`cat /tmp/VERSION|sed -n 's/.*\(develop\)'\'';/\1/p' && cat /tmp/VERSION|sed -n 's/.*\([0-9]\.[0-9]*\)'\'';/PG\-\1/p'` \
    && curl -fSL https://github.com/openwebwork/pg/archive/${WEBWORK_VERSION}.tar.gz -o /tmp/${WEBWORK_VERSION}.tar.gz \
    && tar xzf /tmp/${WEBWORK_VERSION}.tar.gz \
    && mv pg-${WEBWORK_VERSION} $APP_ROOT/pg \
    && rm /tmp/${WEBWORK_VERSION}.tar.gz \
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
      PerlPassEnv WEBWORK_URL\n\
      PerlPassEnv WEBWORK_ROOT_URL\n\
      PerlPassEnv WEBWORK_DB_DSN\n\
      PerlPassEnv WEBWORK_DB_USER\n\
      PerlPassEnv WEBWORK_DB_PASSWORD\n\
      PerlPassEnv WEBWORK_SMTP_SERVER\n\
      PerlPassEnv WEBWORK_SMTP_SENDER\n\
      PerlPassEnv WEBWORK_TIMEZONE\n\
      \n<Perl>/' /etc/apache2/conf-enabled/webwork.conf

RUN cd $APP_ROOT/webwork2/ \
    && chown www-data DATA ../courses htdocs/tmp htdocs/applets logs tmp $APP_ROOT/pg/lib/chromatic \
    && chmod -R u+w DATA ../courses htdocs/tmp htdocs/applets logs tmp $APP_ROOT/pg/lib/chromatic

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80

WORKDIR $APP_ROOT

CMD ["apache2", "-DFOREGROUND"]
