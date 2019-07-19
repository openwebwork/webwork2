FROM ubuntu:18.04

ENV PG_BRANCH=develop \
    WEBWORK_URL=/webwork2 \
    WEBWORK_ROOT_URL=http://localhost \
    WEBWORK_DB_HOST=db \
    WEBWORK_DB_PORT=3306 \
    WEBWORK_DB_NAME=webwork \
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
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    DEV=0

ENV WEBWORK_DB_DSN=DBI:mysql:${WEBWORK_DB_NAME}:${WEBWORK_DB_HOST}:${WEBWORK_DB_PORT} \
    WEBWORK_ROOT=$APP_ROOT/webwork2 \
    PG_ROOT=$APP_ROOT/pg \
    PATH=$PATH:$APP_ROOT/webwork2/bin

# For ubuntu 18.04 add libemail-address-xs-perl
# For ubuntu 18.04 replace texlive-generic-recommended with texlive-plain-generic
#    texlive-generic-recommended # For ubuntu 16.04 - contains path.sty
#    texlive-plain-generic       # For ubuntu 18.04 - contains path.sty



RUN apt-get update \
    && apt-get -y upgrade \
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
	libemail-address-xs-perl \
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
	libxml-simple-perl \
	libsoap-lite-perl \
	libsql-abstract-perl \
	libstring-shellquote-perl \
	libtemplate-perl \
	libtext-csv-perl \
	libtimedate-perl \
	libuuid-tiny-perl \
	libxml-parser-perl \
	libxml-writer-perl \
	libxmlrpc-lite-perl \
	libapache2-reload-perl \
	cpanminus \
	libxml-parser-easytree-perl \
	libiterator-perl \
	libiterator-util-perl \
	libpod-wsdl-perl \
	libtest-xml-perl \
	libmodule-build-perl \
	libxml-semanticdiff-perl \
	libxml-xpath-perl \
	libpath-tiny-perl \
	libarray-utils-perl \
	libhtml-template-perl \
	libtest-pod-perl \
	libemail-sender-perl \
	libmail-sender-perl \
	libmodule-pluggable-perl \
	libemail-date-format-perl \
	libcapture-tiny-perl \
	libthrowable-perl \
	libdata-dump-perl \
	libfile-sharedir-install-perl \
	libclass-tiny-perl \
	libtest-requires-perl \
	libtest-mockobject-perl \
	libtest-warn-perl \
	libsub-uplevel-perl \
	libtest-exception-perl \
	libuniversal-can-perl \
	libuniversal-isa-perl \
	libtest-fatal-perl \
	libjson-xs-perl \
	make \
	netpbm \
	preview-latex-style \
	texlive \
	texlive-latex-extra \
	texlive-plain-generic \
	texlive-xetex \
	texlive-latex-recommended \
	texlive-lang-other \
	texlive-lang-arabic \
	libc6-dev \
	git \
	mysql-client \
	tzdata \
	apt-utils \
	locales \
	debconf-utils \
	vim \
	telnet \
	mc \
	file \
	ssl-cert \
	ca-certificates \
	culmus \
	fonts-linuxlibertine \
	lmodern \
    && apt-get clean \
    && rm -fr /var/lib/apt/lists/* /tmp/*

# texlive-generic-recommended # For ubuntu 16.04 - contains path.sty
# texlive-plain-generic       # For ubuntu 18.04 - contains path.sty

RUN echo 'America/New_York' > /etc/timezone \
    && echo "tzdata tzdata/Areas select America\ntzdata tzdata/Zones/America select New_York\nlocales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8\nlocales locales/default_environment_locale select en_US.UTF-8\ndebconf debconf/frontend select Noninteractive\nca-certificates ca-certificates/trust_new_crts select yes" > /tmp/preseed.txt \
    && cp -a /etc/locale.gen /etc/locale.gen.orig \
    && echo "en_US ISO-8859-1\nen_US.UTF-8 UTF-8" > /etc/locale.gen \
    && rm -f /etc/localtime /etc/timezone \
    && debconf-set-selections /tmp/preseed.txt \
    && dpkg-reconfigure -f noninteractive tzdata \
    && /usr/sbin/locale-gen

# Perl module installs - those not packaged for Ubuntu

RUN cpanm install Statistics::R::IO \
    && rm -fr ./cpanm /root/.cpanm /tmp/*

# XML::Parser::EasyTree Iterator Iterator::Util Pod::WSDL Array::Utils HTML::Template Mail::Sender Email::Sender::Simple Data::Dump

RUN mkdir -p $APP_ROOT/courses $APP_ROOT/libraries $APP_ROOT/webwork2

# Block to include webwork2 in the container, when needed, instead of  getting it from a bind mount.
#    Uncomment when needed, and set the correct branch name on the following line.
#ENV WEBWORK_BRANCH=develop   # need a valid branch name from https://github.com/openwebwork/webwork2
#RUN curl -fSL https://github.com/openwebwork/webwork2/archive/${WEBWORK_BRANCH}.tar.gz -o /tmp/${WEBWORK_BRANCH}.tar.gz \
#    && cd /tmp \
#    && tar xzf /tmp/${WEBWORK_BRANCH}.tar.gz \
#    && mv webwork2-${WEBWORK_BRANCH} $APP_ROOT/webwork2 \
#    && rm -rf /tmp/${WEBWORK_BRANCH}.tar.gz /tmp/webwork2-${WEBWORK_BRANCH}

# The next block installs PG from Git, using the branch set above as PG_BRANCH.
# and compiles color.c in the copy INSIDE the image.

RUN curl -fSL https://github.com/openwebwork/pg/archive/${PG_BRANCH}.tar.gz -o /tmp/${PG_BRANCH}.tar.gz \
    && tar xzf /tmp/${PG_BRANCH}.tar.gz \
    && mv pg-${PG_BRANCH} $APP_ROOT/pg \
    && rm /tmp/${PG_BRANCH}.tar.gz \
    && cd $APP_ROOT/pg/lib/chromatic \
    && gcc color.c -o color

# The next block would install the OPL from Git. Disabled for developers who
# use an external OPL tree.

#RUN curl -fSL https://github.com/openwebwork/webwork-open-problem-library/archive/master.tar.gz -o /tmp/opl.tar.gz \
#    && tar xzf /tmp/opl.tar.gz \
#    && mv webwork-open-problem-library-master $APP_ROOT/libraries/webwork-open-problem-library \
#    && rm /tmp/opl.tar.gz

# MathJax

RUN curl -fSL https://github.com/mathjax/MathJax/archive/master.tar.gz -o /tmp/mathjax.tar.gz \
    && tar xzf /tmp/mathjax.tar.gz \
    && mv MathJax-master $APP_ROOT/MathJax \
    && rm /tmp/mathjax.tar.gz


RUN echo "PATH=$PATH:$APP_ROOT/webwork2/bin" >> /root/.bashrc

COPY . $APP_ROOT/webwork2

# Move these lines into docker-entrypoint.sh so the bind mount of courses
# will be available
#RUN cd $APP_ROOT/webwork2/courses.dist \
#    && cp *.lst $APP_ROOT/courses/ \
#    && cp -R modelCourse $APP_ROOT/courses/

COPY docker-config/ssl/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf

# setup apache
# if no SSL needed - comment out the line && a2enmod ssl && a2ensite default-ssl \
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
    && mkdir -p $APACHE_RUN_DIR $APACHE_LOCK_DIR $APACHE_LOG_DIR \
    && mkdir /etc/ssl/local  \
    && a2enmod rewrite \
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
#\
#    && a2enmod ssl && a2ensite default-ssl
# The LAST line, and the "\" on the line above should be commented out if SSL is not needed

RUN mkdir $APP_ROOT/libraries/webwork-open-problem-library \
    && cd $APP_ROOT/webwork2/ \
    && chown www-data DATA ../courses  htdocs/applets logs tmp $APP_ROOT/pg/lib/chromatic \
    && chmod -R u+w DATA ../courses  htdocs/applets logs tmp $APP_ROOT/pg/lib/chromatic

COPY docker-config/docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80

# Comment out the next line if SSL is not needed
#EXPOSE 443

WORKDIR $APP_ROOT




CMD ["apache2", "-DFOREGROUND"]
