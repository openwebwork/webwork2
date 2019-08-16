#!/bin/bash
set -eo pipefail

# if command starts with an option, prepend apache2
if [ "${1:0:1}" = '-'  ]; then
    set -- apache2 "$@"
fi

# Enable SSL when it is requested by the SSL environment variable
if [ $SSL -eq 1 ]; then
  echo "Enabling SSL"
  a2enmod ssl && a2ensite default-ssl
fi

# Build more locales
if [ "$ADD_LOCALES" != "0" ]; then
  echo "Rebulding locales - adding: $ADD_LOCALES"
  cp -a /etc/locale.gen /etc/locale.gen.orig
  /bin/echo -e "en_US ISO-8859-1\nen_US.UTF-8 UTF-8\n$ADD_LOCALES" > /etc/locale.gen.tmp
  /usr/bin/tr "," "\n" < /etc/locale.gen.tmp > /etc/locale.gen
  rm /etc/locale.gen.orig
  /usr/sbin/locale-gen
fi

# Set system timezone if not the default UTC
if [ "$SYSTEM_TIMEZONE" != "UTC" ]; then
  echo "Setting system timezone to $SYSTEM_TIMEZONE"
  rm /etc/localtime
  rm /etc/timezone
  echo "$SYSTEM_TIMEZONE" > /etc/timezone
  dpkg-reconfigure -f noninteractive tzdata
fi

# Modify default papersize based on environment variable PAPERSIZE
echo "Setting libpaper1 papersize to $PAPERSIZE"
echo "libpaper1 libpaper/defaultpaper select $PAPERSIZE\nlibpaper1:amd64 libpaper/defaultpaper select $PAPERSIZE\ndebconf debconf/frontend select Noninteractive" > /tmp/preseed.txt
debconf-set-selections /tmp/preseed.txt
dpkg-reconfigure -f noninteractive libpaper1

# Install some extra packages
if [ "$ADD_PACKAGES" != "0" ]; then
  apt-get update
  apt-get install -y --no-install-recommends --no-install-suggests $ADD_PACKAGES
fi

# If necessary, install the OPL in the running container, hopefully in persistent storage
if [ ! -d "$APP_ROOT/libraries/webwork-open-problem-library/OpenProblemLibrary" ]; then
  echo "Installing the OPL - This takes time - please be patient."
  cd $APP_ROOT/libraries/
  /usr/bin/git clone -v --progress --single-branch --branch master --depth 1 https://github.com/openwebwork/webwork-open-problem-library.git
  # The next line forces the system to run OPL-update or load saved OPL tables below, as we just installed it
  touch "$APP_ROOT/libraries/RunOPLupdate"
fi

if [ "$1" = 'apache2' ]; then
    # generate conf files if not exist
    for i in site.conf localOverrides.conf; do
        if [ ! -f $APP_ROOT/webwork2/conf/$i ]; then
            echo "Creating a new $APP_ROOT/webwork2/conf/$i"
            cp $APP_ROOT/webwork2/conf/$i.dist $APP_ROOT/webwork2/conf/$i
            if [ $i == 'site.conf' ]; then
                sed -i -e 's/webwork_url       = '\''\/webwork2'\''/webwork_url       = $ENV{"WEBWORK_URL"}/' \
                    -e 's/server_root_url   = '\'''\''/server_root_url   = $ENV{"WEBWORK_ROOT_URL"}/' \
                    -e 's/database_dsn ="dbi:mysql:webwork"/database_dsn =$ENV{"WEBWORK_DB_DSN"}/' \
                    -e 's/database_username ="webworkWrite"/database_username =$ENV{"WEBWORK_DB_USER"}/' \
                    -e 's/database_password ="passwordRW"/database_password =$ENV{"WEBWORK_DB_PASSWORD"}/' \
                    -e 's/mail{smtpServer} = '\'''\''/mail{smtpServer} = $ENV{"WEBWORK_SMTP_SERVER"}/' \
                    -e 's/mail{smtpSender} = '\'''\''/mail{smtpSender} = $ENV{"WEBWORK_SMTP_SENDER"}/' \
                    -e 's/siteDefaults{timezone} = "America\/New_York"/siteDefaults{timezone} = $ENV{"WEBWORK_TIMEZONE"}/' \
                    -e 's/$server_groupID    = '\''wwdata'\''/$server_groupID    = "www-data"/' \
                    $APP_ROOT/webwork2/conf/site.conf
            fi
        fi
    done
    # create admin course if not existing
    if [ ! -d "$APP_ROOT/courses/admin"  ]; then
        # wait for db to start up
        echo "Waiting for database to start..."
        while ! timeout 1 bash -c "(cat < /dev/null > /dev/tcp/$WEBWORK_DB_HOST/$WEBWORK_DB_PORT) >/dev/null 2>&1"; do sleep 0.5; done
        newgrp www-data
        umask 2
        cd $APP_ROOT/courses
        WEBWORK_ROOT=$APP_ROOT/webwork2 $APP_ROOT/webwork2/bin/addcourse admin --db-layout=sql_single --users=$APP_ROOT/webwork2/courses.dist/adminClasslist.lst --professors=admin
        chown www-data:www-data -R $APP_ROOT/courses
        echo "Admin course is created."
    fi
    # modelCourses link if not existing
    if [ ! -d "$APP_ROOT/courses/modelCourse" ]; then
      echo "create modelCourse subdirectory"
      rm -rf $APP_ROOT/courses/modelCourse
      cd $APP_ROOT/webwork2/courses.dist
      cp -R modelCourse $APP_ROOT/courses/
    fi
    # create htdocs/tmp directory if not existing
    if [ ! -d "$APP_ROOT/webwork2/htdocs/tmp" ]; then
      echo "Creating htdocs/tmp directory"
      mkdir $APP_ROOT/webwork2/htdocs/tmp
      chown www-data:www-data -R $APP_ROOT/webwork2/htdocs/tmp
      echo "htdocs/tmp directory created"
    fi

    # defaultClasslist.lst and adminClasslist.lst files if not existing
    if [ ! -f "$APP_ROOT/courses/defaultClasslist.lst"  ]; then
      echo "defaultClasslist.lst is being created"
      cd $APP_ROOT/webwork2/courses.dist
      cp *.lst $APP_ROOT/courses/
    fi
    if [ ! -f "$APP_ROOT/courses/adminClasslist.lst"  ]; then
      echo "adminClasslist.lst is being created"
      cd $APP_ROOT/webwork2/courses.dist
      cp *.lst $APP_ROOT/courses/
    fi
    # run OPL-update if necessary
    if [ ! -f "$APP_ROOT/webwork2/htdocs/DATA/tagging-taxonomy.json"  ]; then
      # The next line forces the system to run OPL-update below, as the
      # tagging-taxonomy.json file was found to be missing.
      if [ -f "$APP_ROOT/libraries/webwork-open-problem-library/TABLE-DUMP/OPL-tables.sql" ]; then
        echo "The tagging-taxonomy.json file is missing in webwork2/htdocs/DATA/."
        echo "But the libraries/webwork-open-problem-library/TABLE-DUMP/OPL-tables.sql files was seen"
        echo "so the OPL tables and the JSON files will (hopefully) be restored from save versions"
      else
        echo "We will run OPL-update as the tagging-taxonomy.json file is missing in webwork2/htdocs/DATA/."
        echo "Check if you should be mounting webwork2/htdocs/DATA/ from outside the Docker image!"
      fi
      touch "$APP_ROOT/libraries/RunOPLupdate"
    fi
    if [ -f "$APP_ROOT/libraries/RunOPLupdate" ]; then
      cd $APP_ROOT/webwork2/bin
      if [ -f "$APP_ROOT/libraries/webwork-open-problem-library/TABLE-DUMP/OPL-tables.sql" ]; then
        echo "Restoring OPL tables from the TABLE-DUMP/OPL-tables.sql file"
        ./restore-OPL-tables
	./update-OPL-statistics
        if [ -d $APP_ROOT/libraries/webwork-open-problem-library/JSON-SAVED ]; then
          # Restore saved JSON files
          echo "Restoring JSON files from JSON-SAVED directory"
          cp -a $APP_ROOT/libraries/webwork-open-problem-library/JSON-SAVED/*.json $APP_ROOT/webwork2/htdocs/DATA/
        else
          echo "No webwork-open-problem-library/JSON-SAVED directory was found."
          echo "You are missing some of the JSON files including tagging-taxonomy.json"
          echo "Some of the library functions will not work properly"
        fi
      else
        echo "About to start OPL-update. This takes a long time - please be patient."
        ./OPL-update
	# Dump the OPL tables, to allow a quick restore in the future
        ./dump-OPL-tables
        # Save a copy of the generated JSON files
        mkdir -p $APP_ROOT/libraries/webwork-open-problem-library/JSON-SAVED
        cp -a $APP_ROOT/webwork2/htdocs/DATA/*.json $APP_ROOT/libraries/webwork-open-problem-library/JSON-SAVED
      fi
      rm $APP_ROOT/libraries/RunOPLupdate
    fi
    # Compile chromatic/color.c if necessary - may be needed for PG directory mounted from outside image
    if [ ! -f "$APP_ROOT/pg/lib/chromatic/color"  ]; then
      cd $APP_ROOT/pg/lib/chromatic
      gcc color.c -o color
    fi
    # generate apache2 reload config if needed
    if [ $DEV -eq 1 ]; then
        echo "PerlModule Apache2::Reload" >> /etc/apache2/conf-enabled/apache2-reload.conf
        echo "PerlInitHandler Apache2::Reload" >> /etc/apache2/conf-enabled/apache2-reload.conf
        echo "Running in DEV mode..."
    else
      if [ $SSL -eq 0 ]; then
        rm -f /etc/apache2/conf-enabled/apache2-reload.conf
      fi
    fi

    # Fix possible permission issues
    echo "Fixing ownership and permissions (just in case it is needed)"
    cd $APP_ROOT/webwork2
    # Symbolic links which have no target outside the Docker container
    # cause problems duringt the rebuild process on some systems.
    # So we delete them. They will be rebuilt automatically when needed again
    # at the cost of some speed.
    find htdocs/tmp -type l -exec rm -f {} \;
    chown -R www-data:www-data logs tmp DATA htdocs/tmp
    chmod -R u+w logs tmp DATA  ../courses htdocs/tmp
    cd $APP_ROOT
    # The chown for files/directories under courses is done using find, as
    # using a simple "chown -R www-data $APP_ROOT/courses" would sometimes
    # cause errors in Docker on Mac OS X when there was a broken symbolic link
    # somewhere in the directory tree being processed.
    find courses -type f -exec chown www-data:www-data {} \;
    find courses -type d -exec chown www-data:www-data {} \;
    echo "end fixing ownership and permissions"

fi

exec "$@"
