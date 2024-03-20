# ==================================================================
# Phase 1 - Download webwork and pg git repositories.

FROM alpine/git AS base

# Build args specifying the branches for webwork2 and pg used to build the image.
ARG WEBWORK2_GIT_URL
ARG WEBWORK2_BRANCH
ARG PG_GIT_URL
ARG PG_BRANCH

WORKDIR /opt/base

RUN echo Cloning branch $WEBWORK2_BRANCH from $WEBWORK2_GIT_URL \
	&& echo git clone --single-branch --branch ${WEBWORK2_BRANCH} --depth 1 $WEBWORK2_GIT_URL \
	&& git clone --single-branch --branch ${WEBWORK2_BRANCH} --depth 1 $WEBWORK2_GIT_URL \
	&& rm -rf webwork2/.git webwork2/{*ignore,Dockerfile,docker-compose.yml,docker-config}

RUN echo Cloning branch $PG_BRANCH branch from $PG_GIT_URL \
	&& echo git clone --single-branch --branch ${PG_BRANCH} --depth 1 $PG_GIT_URL \
	&& git clone --single-branch --branch ${PG_BRANCH} --depth 1 $PG_GIT_URL \
	&& rm -rf  pg/.git

# Optional - include OPL (also need to uncomment further below when an included OPL is desired):
#RUN git clone --single-branch --branch main --depth 1 https://github.com/openwebwork/webwork-open-problem-library.git \
#  && rm -rf  webwork-open-problem-library/.git

# ==================================================================
# Phase 2 - set ENV variables

# We need to change FROM before setting the ENV variables.

FROM ubuntu:22.04

ENV WEBWORK_URL=/webwork2 \
	WEBWORK_ROOT_URL=http://localhost::8080 \
	WEBWORK_SMTP_SERVER=localhost \
	WEBWORK_SMTP_SENDER=webwork@example.com \
	WEBWORK_TIMEZONE=America/New_York \
	APP_ROOT=/opt/webwork \
	DEBIAN_FRONTEND=noninteractive \
	DEBCONF_NONINTERACTIVE_SEEN=true

ARG ADDITIONAL_BASE_IMAGE_PACKAGES

# Environment variables which depend on a prior environment variable must be set
# in an ENV call after the dependencies were defined.
ENV WEBWORK_ROOT=$APP_ROOT/webwork2 \
	PG_ROOT=$APP_ROOT/pg \
	PATH=$PATH:$APP_ROOT/webwork2/bin

# ==================================================================
# Phase 3 - Install required packages

# Do NOT include "apt-get -y upgrade"
# see: https://docs.docker.com/develop/develop-images/dockerfile_best-practices/

RUN apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
	apt-utils \
	ca-certificates \
	cpanminus \
	culmus \
	curl \
	debconf-utils \
	dvipng \
	dvisvgm \
	fonts-linuxlibertine \
	gcc \
	git \
	imagemagick \
	iputils-ping \
	jq \
	libarchive-extract-perl \
	libarchive-zip-perl \
	libarray-utils-perl \
	libc6-dev \
	libcapture-tiny-perl \
	libclass-tiny-antlers-perl \
	libclass-tiny-perl \
	libcpanel-json-xs-perl \
	libcrypt-jwt-perl \
	libcryptx-perl \
	libdata-dump-perl \
	libdata-structure-util-perl \
	libdatetime-perl \
	libdbd-mysql-perl \
	libdevel-checklib-perl \
	libemail-address-xs-perl \
	libemail-date-format-perl \
	libemail-sender-perl \
	libemail-stuffer-perl \
	libexception-class-perl \
	libextutils-config-perl \
	libextutils-helpers-perl \
	libextutils-installpaths-perl \
	libextutils-xsbuilder-perl \
	libfile-copy-recursive-perl \
	libfile-find-rule-perl-perl \
	libfile-sharedir-install-perl \
	libfuture-asyncawait-perl \
	libgd-barcode-perl \
	libgd-perl \
	libhtml-scrubber-perl \
	libhtml-template-perl \
	libhttp-async-perl \
	libiterator-perl \
	libiterator-util-perl \
	libjson-maybexs-perl \
	libjson-perl \
	libjson-xs-perl \
	liblocale-maketext-lexicon-perl \
	libmail-sender-perl \
	libmail-sender-perl \
	libmariadb-dev \
	libmath-random-secure-perl \
	libmime-base32-perl \
	libmime-tools-perl \
	libminion-backend-sqlite-perl \
	libminion-perl \
	libmodule-build-perl \
	libmodule-pluggable-perl \
	libmojolicious-perl \
	libmojolicious-plugin-renderfile-perl \
	libnet-https-nb-perl \
	libnet-ip-perl \
	libnet-ldap-perl \
	libnet-oauth-perl \
	libossp-uuid-perl \
	libpadwalker-perl \
	libpath-class-perl \
	libpath-tiny-perl \
	libpandoc-wrapper-perl \
	libphp-serialization-perl \
	libpod-wsdl-perl \
	libsoap-lite-perl \
	libsql-abstract-perl \
	libstring-shellquote-perl \
	libsub-uplevel-perl \
	libsvg-perl \
	libtemplate-perl \
	libtest-deep-perl \
	libtest-exception-perl \
	libtest-fatal-perl \
	libtest-mockobject-perl \
	libtest-pod-perl \
	libtest-requires-perl \
	libtest-warn-perl \
	libtest-xml-perl \
	libtext-csv-perl \
	libthrowable-perl \
	libtimedate-perl \
	libuniversal-can-perl \
	libuniversal-isa-perl \
	libuuid-tiny-perl \
	libxml-parser-easytree-perl \
	libxml-parser-perl \
	libxml-semanticdiff-perl \
	libxml-simple-perl \
	libxml-writer-perl \
	libxml-xpath-perl \
	libyaml-libyaml-perl \
	lmodern \
	locales \
	make \
	mariadb-client \
	netpbm \
	patch \
	pdf2svg \
	preview-latex-style \
	ssl-cert \
	sudo \
	texlive \
	texlive-lang-arabic \
	texlive-lang-other \
	texlive-latex-extra \
	texlive-plain-generic \
	texlive-science \
	texlive-xetex \
	tzdata \
	zip $ADDITIONAL_BASE_IMAGE_PACKAGES \
	&& curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
	&& apt-get install -y --no-install-recommends --no-install-suggests nodejs \
	&& apt-get clean \
	&& rm -fr /var/lib/apt/lists/* /tmp/*

# ==================================================================
# Phase 4 - Install additional Perl modules from CPAN that are not packaged for Ubuntu or are outdated in Ubuntu.

RUN cpanm install Statistics::R::IO DBD::MariaDB Mojo::SQLite@3.002 Perl::Tidy@20220613 Archive::Zip::SimpleZip \
	&& rm -fr ./cpanm /root/.cpanm /tmp/*

# ==================================================================
# Phase 5 - Install webwork2 and pg which were downloaded to /opt/base/ in phase 1
# Option: Install the OPL in the image also (about 850 MB)

RUN mkdir -p $APP_ROOT/courses $APP_ROOT/libraries $APP_ROOT/libraries/webwork-open-problem-library $APP_ROOT/webwork2 /www/www/html

COPY --from=base /opt/base/webwork2 $APP_ROOT/webwork2
COPY --from=base /opt/base/pg $APP_ROOT/pg

# Optional - include OPL (also need to uncomment above to clone from GitHub when needed):
#COPY --from=base /opt/base/webwork-open-problem-library $APP_ROOT/libraries/webwork-open-problem-library

# ==================================================================
# Phase 6 - System configuration

# 1. Setup PATH.
# 2. Create the webwork2 PID directory and the /etc/ssl/local directory in case it is needed.
# 3. Perform initial permissions setup for material INSIDE the image.
# 4. Build standard locales.
# 5. Set the default system timezone to be UTC.
# 6. Install third party javascript files.
# 7. Apply patches

# Patch files that are applied below
COPY docker-config/imagemagick-allow-pdf-read.patch /tmp
COPY docker-config/pgfsys-dvisvmg-bbox-fix.patch /tmp

RUN echo "PATH=$PATH:$APP_ROOT/webwork2/bin" >> /root/.bashrc \
	&& mkdir /run/webwork2 /etc/ssl/local \
	&& cd $APP_ROOT/webwork2/ \
		&& chown www-data DATA ../courses logs tmp /etc/ssl/local /run/webwork2 \
		&& chmod -R u+w DATA ../courses logs tmp /run/webwork2 /etc/ssl/local \
	&& echo "en_US ISO-8859-1\nen_US.UTF-8 UTF-8" > /etc/locale.gen \
		&& /usr/sbin/locale-gen \
		&& echo "locales locales/default_environment_locale select en_US.UTF-8\ndebconf debconf/frontend select Noninteractive" > /tmp/preseed.txt \
		&& debconf-set-selections /tmp/preseed.txt \
	&& rm /etc/localtime /etc/timezone && echo "Etc/UTC" > /etc/timezone \
		&& dpkg-reconfigure -f noninteractive tzdata \
	&& cd $WEBWORK_ROOT/htdocs \
		&& npm install \
	&& cd $PG_ROOT/htdocs \
		&& npm install \
	&& patch -p1 -d / < /tmp/imagemagick-allow-pdf-read.patch \
	&& rm /tmp/imagemagick-allow-pdf-read.patch \
	&& patch -p1 -d / < /tmp/pgfsys-dvisvmg-bbox-fix.patch \
	&& rm /tmp/pgfsys-dvisvmg-bbox-fix.patch

# ==================================================================
# Phase 7 - Final setup and prepare docker-entrypoint.sh
# Done near the end, so that an update to docker-entrypoint.sh can be
# done without rebuilding the earlier layers of the Docker image.

EXPOSE 8080
WORKDIR $WEBWORK_ROOT

COPY docker-config/docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

# Add enviroment variables to control some things during container startup
ENV SSL=0 \
	PAPERSIZE=letter \
	SYSTEM_TIMEZONE=UTC \
	ADD_LOCALES=0 \
	ADD_APT_PACKAGES=0

# ================================================

CMD ["sudo", "-E", "-u", "www-data", "hypnotoad", "-f", "bin/webwork2"]
