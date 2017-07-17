* Use the `site.conf` and `localOverrides.conf` files to customize
the behavior of the site.  

* `site.conf` contains global variables which are required for basic configuration.
`defaults.config` contains initial settings for many customizable options in WeBWorK.  
Do not edit `defaults.config`!  It will be overridden next time you upgrade.

* The `localOverrides.conf` file is read after the `defaults.config` file is processed 
and will overwrite configurations in `defaults.config`.  Use this file 
to make changes to the settings in `defaults.config`, as it will be left alone when you upgrade.

* The files `course.conf` and `simple.conf` in the course directories is read last and can override
previous configuration settings.


* This configuration system  simplifies the process of updating webwork2 since it is less likely that one will need to modify the config files when upgrading.  
* Default configurations or permissions for 
new features are defined in `defaults.config` and allow automatic upgrades.  You can override these 
at any point from `localOverrides.conf`.

FIRST TIME RECONFIGURATION

* COPY `site.conf.dist` to `site.conf`.
* COPY `localOverrides.conf.dist` to `localOverrides.conf`.

in order to get started. 




