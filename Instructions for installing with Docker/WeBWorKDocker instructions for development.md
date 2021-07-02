

## WeBWorK/Docker instructions for development



* Docker must be installed on your machine

  * https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04
  * docker-compose --ver:   version 1.25.0

* create a directory to work in `webwork-docker`

* `cd webwork-docker`

* obtain the webwork repositories

  * front end (webwork2) `git clone  https://github.com/openwebwork/pg`
  * problem rendering code (pg)`git clone https://github.com/openwebwork/pg`
  * problem library (OPL) `git clone https://github.com/openwebwork/webwork-open-problem-library`

* get the appropriate versions of the code. At the moment (6/16/2021) the default download is the 'master' branch which has version 2.15.  The current version is 2.16 which you will need for installing webwork in docker following these instructions

  * `cd webwork2`

  * `git branch -a` displays all the branches, (-a  includes the remote branches)
  * `git checkout WeBWorK-2.16` (makes a local version of the WeBWorK-2.16 branch -- there are some defaults involved -- the command automatically assumes that you want to copy from origin/WeBWorK-2.16)  (for now pull from mgage/)
  * `git  branch`  check that things worked: you should see * WeBWorK-2.16 (or ww216_patches_quotes)
  * cd ..
  
* webwork-open-problem-library usually only has the master branch so the clone operation has already downloaded the current version

* set configuration in docker documents

  * `cd webwork2`

  * vim docker-compose.yml 

    * in the file webwork2/docker-compose.yml change the line `WEBWORK_ROOT_PASSWORD=passwordRWsetItBeforeFirstStartingTheDBcontainer` replacing `passwordRWset...` with   a reasonable password to be used for `root`  access the mariaDB database. 
    * This password should be set before you do your first build (which is the only time the database is created).  Successive builds use the database that has already been created, unless you explicitly remove that volume

  * vim .env 

    * in the file webwork2/.env change the line `WEBWORK_DB_PASSWORD=passwordRWsetItBeforeFirstStartingTheDBcontainer` replacing `passwordRWset...`with a reasonable password to be used for `webworkWrite` to access the mariaDB database.
    * the other variables can be left with the defaults
        
      
  * sanity checks:

    * git branch  should return WeBWorK-2.16
    * git status should show that the files `webwork2/.env` and `webwork2/docker-compose.yml` have been modified
    * `git diff .env` should show only the new password has been changed
    * `git diff docker-compose.yml` should show that only the new password has been changed.
    * did you change the database passwords for root and for webworkWrite in the files `webwork2/docker-compose.yml` and in `.env`

  * we're ready to build

    * make sure you are in the `webwork2` directory
    * type `docker build --tag webwork-base:forWW216 -f DockerfileStage1 .`
    	* wait -- and watch the messages fly by.
   		* This builds the underlying unix layer of the WeBWorK stack
    *stage2
    	make sure that the line `dockerfile: DockerfileStage2` is uncommented (careful there is also an empty `dockerfile:` line -- ignore it)
    * type `docker-compose build`
    * watch more lines fly by.
    * hopefully this build ends without errors
	* final stage
		* type `docker-compose up`
		* watch more lines fly by
		* a successful build ends with
	    ```
	     --- webwork.maa.org ping statistics ---
	    app_1  | 1 packets transmitted, 1 received, 0% packet loss, time 0ms
	    app_1  | rtt min/avg/max/mdev = 21.580/21.580/21.580/0.000 ms
	    ```
    ------

* or something similar

* do not close the terminal window!

* start your browser to point at `localhost:8080/webwork`

* click on Course Administration

* login with `username admin`  `password admin`

* Congratulations you are now the administrator of your own private WeBWorK site!

* you can turn your site off by pressing ^C in the terminal window or executing `docker-compose down` in another terminal window

* to restart your site type: `docker-compose up -d` the `-d` (for detach) puts the site execution in the background and returns the terminal window to the focus of your keyboard.  It also suppresses all of the reporting lines about the build.  The (re-)build will be much faster since most of the work has been cached. 

* you can turn the site off with `docker-compose down`

* as long as your docker application remains running (and you don't explicitly delete things) the status of your site, including courses created, problems created and assigned, etc., will be preserved from one `docker-compose down` to the next `docker-compose up`. 

* docker-compose build (may not work)

    docker-compose up (more likely to work)
    
    direct your browser to localhost:8080
    
    
    
* successfully tagged webwork: latest

* successfully built  #########

* debugging notes:

    * if admin course is not working you may need to fix it from inside the container using webwork2/bin/addcourse admin

Font Awesome Free 5.15.2 by @fontawesome - https://fontawesome.com
License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License)

added 8 packages from 928 contributors and audited 8 packages in 1.482s

1 package is looking for funding
  run `npm fund` for details

found 0 vulnerabilities



```
Table 'webwork.OPL_local_statistics' doesn't exist at /opt/webwork/webwork2/lib/WeBWorK/Utils/LibraryStats.pm line 71. 
```

Loading failed for the <script> with source “http://localhost:8080/webwork2_files/themes/math4/math4-overrides.js”.

docker volume

docker container

docker images  are all empty

ww-docker-data is empty

docker-compose up  (this time, not docker-compose build   which seems to act funny)

long list of things set up and installed

tmp directory still not correct

docker clean start

	Procedure
	
	Stop the container(s) using the following command:
	
	docker-compose down
	
	Delete all containers using the following command:
	
	docker rm -f $(docker ps -a -q)
	
	Delete all volumes using the following command:
	
	docker volume rm $(docker volume ls -q)
	
	docker image rm $(docker image ls -a -q)
	
	Restart the containers using the following command:
	
	docker-compose up -d

GEThttp://localhost:8080/webwork2_files/themes/math4/math4-coloring.css
[HTTP/1.1 404 Not Found 0ms]
