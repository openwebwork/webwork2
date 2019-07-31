#!/bin/bash
set -eo pipefail

# if command starts with an option, prepend apache2
if [ "${1:0:1}" = '-'  ]; then
    set -- apache2 "$@"
fi



if [ "$1" = 'apache2' ]; then
    # generate conf files if not exist
    for i in site.conf localOverrides.conf; do
        if [ ! -f $APP_ROOT/webwork2/conf/$i ]; then
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
                    -e 's/$server_groupID    = '\''wwdata'\''/$server_groupID    = "root"/' \
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
        chown www-data:root -R $APP_ROOT/courses
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
      mkdir $APP_ROOT/webwork2/htdocs/tmp
      echo "htdocs/tmp directory created"
    fi
    chown www-data:root -R $APP_ROOT/webwork2/htdocs/tmp
      
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
      cd $APP_ROOT/webwork2/bin
      ./OPL-update
    fi

    # generate apache2 reload config if needed
    if [ $DEV -eq 1 ]; then
        echo "PerlModule Apache2::Reload" > /etc/apache2/conf-enabled/apache2-reload.conf
        echo "PerlInitHandler Apache2::Reload" >> /etc/apache2/conf-enabled/apache2-reload.conf
        echo "Running in DEV mode..."
    else
        rm -f /etc/apache2/conf-enabled/apache2-reload.conf
    fi

    # Fix possible permission issues
    echo "Fixing ownership and permissions (just in case it is needed)"
    cd $APP_ROOT/webwork2
    rm -rf htdocs/tmp/*    # pointers which which have no target shut down the rebuild process.
                           # the tmp directory is rebuilt automatically at the cost of some speed.
    chown -R www-data logs tmp DATA htdocs/tmp
    chmod -R u+w logs tmp DATA  ../courses htdocs/tmp
    cd $APP_ROOT
    find courses -type f -exec chown www-data:root {} \;
    find courses -type d -exec chown www-data:root {} \;
    
    # echo "start cpan install XML::Simple"
    # cpan install XML::Simple
    # echo "end fixing ownership and permissions"
    # OLD: chown www-data -R $APP_ROOT/courses
    #    but that sometimes caused errors in Docker on Mac OS X when there was a broken symbolic link somewhere in the directory tree being processed

fi

 exec "$@"
