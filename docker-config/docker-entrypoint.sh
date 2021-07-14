#!/bin/bash
set -eo pipefail

function wait_for_db {
	echo "Waiting for database to become available..."
        while ! timeout 1 bash -c "(cat < /dev/null > /dev/tcp/$WEBWORK_DB_HOST/$WEBWORK_DB_PORT) >/dev/null 2>&1"; do \
		echo "waiting..."
		sleep 0.5; \
	done
}
# if command starts with an option, prepend apache2
if [ "${1:0:1}" = '-'  ]; then
    set -- apache2 "$@"
fi

# Enable SSL when it is requested by the SSL environment variable
if [ $SSL -eq 1 ]; then
  echo "Enabling SSL"
  a2enmod ssl && a2ensite default-ssl
fi

echo "Enabling Apache headers module"
a2enmod headers

# Build more locales
if [ "$ADD_LOCALES" != "0" ]; then
  echo "Rebuilding locales - adding: $ADD_LOCALES"
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
if [ "$ADD_APT_PACKAGES" != "0" ]; then
  apt-get update
  apt-get install -y --no-install-recommends --no-install-suggests $ADD_APT_PACKAGES
fi

# If necessary, clone the OPL in the running container, hopefully in persistent storage
if [ ! -d "$APP_ROOT/libraries/webwork-open-problem-library/OpenProblemLibrary" ]; then
  echo "Cloning the OPL - This takes time - please be patient."
  cd $APP_ROOT/libraries/
  /usr/bin/git clone -v --progress --single-branch --branch master https://github.com/openwebwork/webwork-open-problem-library.git

  # The next line forces the system to run OPL-update or load saved OPL tables below, as we just installed it
  touch "$APP_ROOT/libraries/Restore_or_build_OPL_tables"
fi

if [ "$1" = 'apache2' ]; then
    # generate conf files if not exist
    for i in site.conf localOverrides.conf; do
        if [ ! -f $WEBWORK_ROOT/conf/$i ]; then
            echo "Creating a new $WEBWORK_ROOT/conf/$i"
            cp $WEBWORK_ROOT/conf/$i.dist $WEBWORK_ROOT/conf/$i
            if [ $i == 'site.conf' ]; then
                sed -i -e 's/webwork_url       = '\''\/webwork2'\''/webwork_url       = $ENV{"WEBWORK_URL"}/' \
                    -e 's/server_root_url   = '\'''\''/server_root_url   = $ENV{"WEBWORK_ROOT_URL"}/' \
                    -e 's/^\$database_driver="MariaDB"/$database_driver = $ENV{"WEBWORK_DB_DRIVER"}/' \
                    -e 's/^\$database_host="localhost"/$database_host = $ENV{"WEBWORK_DB_HOST"}/' \
                    -e 's/^\$database_port="3306"/$database_port = $ENV{"WEBWORK_DB_PORT"}/' \
                    -e 's/^\$database_name="webwork"/$database_name = $ENV{"WEBWORK_DB_NAME"}/' \
                    -e 's/^\$database_username ="webworkWrite"/$database_username =$ENV{"WEBWORK_DB_USER"}/' \
                    -e 's/^\$database_password ='\''passwordRW'\''/$database_password =$ENV{"WEBWORK_DB_PASSWORD"}/' \
                    -e 's/mail{smtpServer} = '\'''\''/mail{smtpServer} = $ENV{"WEBWORK_SMTP_SERVER"}/' \
                    -e 's/siteDefaults{timezone} = "America\/New_York"/siteDefaults{timezone} = $ENV{"WEBWORK_TIMEZONE"}/' \
                    -e 's/^# $server_userID     = '\''www-data/$server_userID     = '\''www-data/'  \
                    -e 's/^# $server_groupID    = '\''www-data/$server_groupID    = '\''www-data/' $WEBWORK_ROOT/conf/site.conf
                
                echo "$WEBWORK_ROOT/conf/$i has been modified."
            fi

            if [ $i == 'localOverrides.conf' ]; then
                sed -i -e 's/#$pg{specialPGEnvironmentVars}{Rserve} = {host => "r"};/$pg{specialPGEnvironmentVars}{Rserve} = {host => "r"};/' \
                       -e 's/#$problemLibrary{showLibraryLocalStats} = 0;/$problemLibrary{showLibraryLocalStats} = 0;/' $WEBWORK_ROOT/conf/localOverrides.conf
                echo "$WEBWORK_ROOT/conf/$i has been modified."
            fi
        fi
        
    done
    # create admin course if not existing
    # check first if the admin courses directory exists then check that at 
    # least one of the tables associated with the course (the admin_user table) exists
    
    echo "check admin course and admin tables"
    wait_for_db
    ADMIN_TABLE_EXISTS=`mysql -u $WEBWORK_DB_USER  -p$WEBWORK_DB_PASSWORD -B -N -h db -e "select count(*) from information_schema.tables where table_schema='webwork' and table_name = 'admin_user';"  2>/dev/null`
 
    if [ ! -d "$APP_ROOT/courses/admin" ]; then
        newgrp www-data
        umask 2
        cd $APP_ROOT/courses
        wait_for_db
        $WEBWORK_ROOT/bin/addcourse admin --db-layout=sql_single --users=$WEBWORK_ROOT/courses.dist/adminClasslist.lst --professors=admin
        chown www-data:www-data -R $APP_ROOT/courses
        echo "Admin course is created."
        echo "user: admin password: admin added to course admin and tables upgraded"
    elif [ $ADMIN_TABLE_EXISTS == 0 ]; then
        echo "admin course db tables need updating"
        $WEBWORK_ROOT/bin/upgrade_admin_db.pl
        $WEBWORK_ROOT/bin/wwsh admin $WEBWORK_ROOT/bin/addadmin
        echo "admin course tables created with one user: admin   whose password is admin"
    else 
        echo "using pre-existing admin course and admin tables"
    fi
    
    # use case for the extra check for the admin:
    # In rebuilding a docker box one might clear out the docker containers, 
    # images and volumes including mariaDB, BUT leave the 
    # contents of ww-docker-data directory in place.  It now holds the shell of the courses 
    # including the admin course directory. This means that once you rebuild the box 
    # you can't access the admin course (because the admin_user table is missing) 
    # and you need to run bin/upgrade_admin_db.pl from inside the container. 
    # This check insures that if the admin_user table is missing the whole admin course is rebuilt 
    # even if the admin directory is in place. 

    # modelCourses link if not existing
    if [ ! -d "$APP_ROOT/courses/modelCourse" ]; then
      echo "create modelCourse subdirectory"
      rm -rf $APP_ROOT/courses/modelCourse
      cd $WEBWORK_ROOT/courses.dist
      cp -R modelCourse $APP_ROOT/courses/
    fi
    # create htdocs/tmp directory if not existing
    if [ ! -d "$WEBWORK_ROOT/htdocs/tmp" ]; then
      echo "Creating htdocs/tmp directory"
      mkdir $WEBWORK_ROOT/htdocs/tmp
      chown www-data:www-data -R $WEBWORK_ROOT/htdocs/tmp
      echo "htdocs/tmp directory created"
    fi

    # defaultClasslist.lst and adminClasslist.lst files if not existing
    if [ ! -f "$APP_ROOT/courses/defaultClasslist.lst"  ]; then
      echo "defaultClasslist.lst is being created"
      cd $WEBWORK_ROOT/courses.dist
      cp *.lst $APP_ROOT/courses/
    fi
    if [ ! -f "$APP_ROOT/courses/adminClasslist.lst"  ]; then
      echo "adminClasslist.lst is being created"
      cd $WEBWORK_ROOT/courses.dist
      cp *.lst $APP_ROOT/courses/
    fi
    # run OPL-update if necessary
    if [ ! -f "$WEBWORK_ROOT/htdocs/DATA/tagging-taxonomy.json"  ]; then
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
      touch "$APP_ROOT/libraries/Restore_or_build_OPL_tables"
    fi
    if [ -f "$APP_ROOT/libraries/Restore_or_build_OPL_tables" ]; then
      if [ ! -f "$APP_ROOT/libraries/webwork-open-problem-library/TABLE-DUMP/OPL-tables.sql" ]; then
        # Download a saved version of the OPL sql table data to be loaded and extract
        cd $WEBWORK_ROOT/bin/OPL_releases/
        make extract
        cp -r webwork-open-problem-library $APP_ROOT/libraries/
        # check out commit corresponding to the release
        make latest_release.tag
        OPL_TAG=`cat $WEBWORK_ROOT/bin/OPL_releases/latest_release.tag`
        cd $APP_ROOT/libraries/webwork-open-problem-library/
        git remote rm heiderich || true
        git remote add heiderich https://github.com/heiderich/webwork-open-problem-library.git
        git fetch --tags heiderich
        echo "Checking out tag $OPL_TAG"
        git checkout $OPL_TAG
      fi

      if [ -f "$APP_ROOT/libraries/webwork-open-problem-library/TABLE-DUMP/OPL-tables.sql" ]; then
        echo "Restoring OPL tables from the TABLE-DUMP/OPL-tables.sql file"
        wait_for_db
        $WEBWORK_ROOT/bin/restore-OPL-tables.pl
        $WEBWORK_ROOT/bin/load-OPL-global-statistics.pl
        #$WEBWORK_ROOT/bin/update-OPL-statistics.pl
        if [ -d $APP_ROOT/libraries/webwork-open-problem-library/JSON-SAVED ]; then
          # Restore saved JSON files
          echo "Restoring JSON files from JSON-SAVED directory"
          cp -a $APP_ROOT/libraries/webwork-open-problem-library/JSON-SAVED/*.json $WEBWORK_ROOT/htdocs/DATA/
        else
          echo "No webwork-open-problem-library/JSON-SAVED directory was found."
          echo "You are missing some of the JSON files including tagging-taxonomy.json"
          echo "Some of the library functions will not work properly"
        fi
      else
        echo "About to start OPL-update. This takes a long time - please be patient."
        wait_for_db
        $WEBWORK_ROOT/bin/OPL-update
        # Dump the OPL tables, to allow a quick restore in the future
        $WEBWORK_ROOT/bin/dump-OPL-tables.pl
        # Save a copy of the generated JSON files
        mkdir -p $APP_ROOT/libraries/webwork-open-problem-library/JSON-SAVED
        cp -a $WEBWORK_ROOT/htdocs/DATA/*.json $APP_ROOT/libraries/webwork-open-problem-library/JSON-SAVED
      fi
      rm $APP_ROOT/libraries/Restore_or_build_OPL_tables
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
    cd $WEBWORK_ROOT

    # Minimal chown/chmod code - moves the critical parts which were in
    # blocks below to to here
    # but SKIPS handling htdocs/tmp and ../courses for the chmod line,
    # and SKIPS the deletion of symbolic links.
    # This change significantly speeds up Docker startup time on production
    # servers with many files/courses (on Linux).

    chown -R www-data:www-data logs tmp DATA 
    chmod -R ug+w logs tmp DATA 
    chown  www-data:www-data htdocs/tmp
    chmod ug+w htdocs/tmp
    
    # even if the admin and courses directories already existed their permissions might not have been correct
    # chown www-data:www-data  $APP_ROOT/courses
    chown www-data:www-data  $APP_ROOT/courses/admin/*    

    # Symbolic links which have no target outside the Docker container
    # cause problems duringt the rebuild process on some systems.
    # So we delete them. They will be rebuilt automatically when needed again
    # at the cost of some speed.

    # The following 3 lines (find, chown, chmod) make Docker startup quite slow
    # slow and have been commented out. The critical parts to chown/chmod the
    # directories:   logs/ tmp/ DATA/   were moved above and removed below.
    # Developers who encounter permission issues may want to reenable these lines.

    #find htdocs/tmp -type l -exec rm -f {} \;
    #chown -R www-data:www-data htdocs/tmp
    #chmod -R u+w ../courses htdocs/tmp

    # The chown for files/directories under courses is done using find, as
    # using a simple "chown -R www-data $APP_ROOT/courses" would sometimes
    # cause errors in Docker on Mac OS X when there was a broken symbolic link
    # somewhere in the directory tree being processed.

    # The following 3 lines (cd, find, find) make Docker startup quite slow.
    # Developers who encounter permission issues may want to reenable these lines.

    #cd $APP_ROOT
    #find courses -type f -exec chown www-data:www-data {} \;
    #find courses -type d -exec chown www-data:www-data {} \;

    echo "end fixing ownership and permissions"

    # "touch" and "chown" some file to prevent some warnings
    cd /opt/webwork/webwork2/htdocs/themes/math4
    /usr/bin/touch math4-overrides.css math4-overrides.js math4-coloring.css
    chown www-data:www-data math4-overrides.css math4-overrides.js math4-coloring.css
fi

# The code below allows to use
#    docker container exec -it webwork2_app_1 /usr/sbin/apachectl graceful
# to restart Apache in the container in a "nice" way.

trap "exit 0" SIGWINCH
# code added here
while true
do
    exec "$@" &
    wait $!
done

