

## WeBWorK/Docker startup instructions



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

* *The following commands are used only when you are building a docker container with code that you can edit.*

  * *now repeat the commands used to obtain webwork2 with pg*
    * *`cd pg`*
    * *`git branch -a`; `git checkout PG-2.16`; `git branch`*

* webwork-open-problem-library usually only has the master branch so the clone operation has already downloaded the current version

* set configuration in docker documents

  * `cd webwork2`

  * vim docker-compose.yml 

    * in the file webwork2/docker-compose.yml change the line `WEBWORK_ROOT_PASSWORD=passwordRWsetItBeforeFirstStartingTheDBcontainer` to  a reasonable password to be used for `root`  access the mariaDB database. 

  * vim .env 

    * in the file webwork2/.env change the line `WEBWORK_DB_PASSWORD=passwordRWsetItBeforeFirstStartingTheDBcontainer` to  a reasonable password to be used for `webworkWrite` to access the mariaDB database.
    * the other variables can be left with the defaults

  * *The following commands are used only when you are building a docker container with 'webwork2' and 'pg' code that you can edit*

    * *since we will be using local copies of webwork2 and pg uncomment the lines:*

          - "../pg:/opt/webwork/pg"

    * *you also need to install npm outside the docker container since the docker build machinery is unable to do this*

    * *for unix*

      	apt-get install npm
      	npm install

    * *we're using non-standard repos so in docker-compose.yml set*

      *`WEBWORK2_GIT_url=https:///github.com/mgage/webwork2.git`*

      *`WEBWORK2_BRANCH=ww216_patch_quotes`*

    * *set `hostname meg.org`  or what ever you use, if anything*

  * sanity checks:

    * git branch  should return WeBWorK-2.16
    * git status should show that the files `webwork2/.env` and `webwork2/docker-compose.yml` have been modified
    * `git diff .env` should show only the new password has been changed
    * `git diff docker-compose.yml` should show that only the new password has been changed.

  * we're ready to build

    * make sure you are in the `webwork2` directory
    * type `docker-compose up`
    * wait -- and watch the messages fly by.

* build

* the build ends with   

  ```
   --- webwork.maa.org ping statistics ---
  app_1  | 1 packets transmitted, 1 received, 0% packet loss, time 0ms
  app_1  | rtt min/avg/max/mdev = 21.580/21.580/21.580/0.000 ms
  ```

  ------

* or something similar

* do not close the terminal window!

* start your browser and point at `localhost:8080/webwork`

* click on Course Administration

* login with `username admin`  `password admin`

* Congratulations you are now the administrator of your own private WeBWorK site!

* -----

* you can turn your site off by pressing ^C in the terminal window or executing `docker-compose down` in another terminal window

* to restart your site type: `docker-compose up -d` the `-d` (for detach) puts the site execution in the background and returns the terminal window to the focus of your keyboard.  It also suppresses all of the reporting lines about the build.  The (re-)build will be much faster since most of the work has been cached. 

* you can turn the site off with `docker-compose down`

* as long as your docker application remains running (and you don't explicitly delete things) the status of your site, including courses created, problems created and assigned, etc., will be preserved from one `docker-compose down` to the next `docker-compose up`. 

* What next:
  * These instructions are designed to get a WeBWorKs site up and running quickly.
  * There are (or will be) additional instructions for setting up docker so that you can modify pg code (e.g. macros) and even webwork2 code, test the changes and upload the modifications as pull requests to the maintainers of WeBWorK at https://github.com/openwebwork. 
  * There will also be additional instructions for setting up docker so that it can serve as a secure and efficient production WeBWorK server for your classes.