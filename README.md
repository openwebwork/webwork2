                                       WeBWorK                                    
                         Online Homework Delivery System                        
                                   Version 2.*
                        Branch:  github.com/openwebwork 

             https://webwork.maa.org/wiki/Release_notes_for_WeBWorK_2.16
                    Copyright 2000-2021, The WeBWorK Project
                             https://openwebwork.org/
                             http://webwork.maa.org
                              All rights reserved.  
                                                          
# Welcome to WeBWorK

WeBWorK is an open-source online homework system for math and sciences courses. WeBWorK is supported by the MAA and the NSF and comes with an Open Problem Library (OPL) of over 30,000 homework problems. Problems in the OPL target most lower division undergraduate math courses and some advanced courses. Supported courses include college algebra, discrete mathematics, probability and statistics, single and multivariable calculus, differential equations, linear algebra and complex analysis.  Find out more at the main WeBWorK [webpage](http://webwork.maa.org).

## Information for Users

New users interested in getting started with their own WeBWorK server, or instructors looking to learn more about how to use WeBWorK in their classes, should take a look at one of the following resources: 
*  The [WeBWorK project home page](https://openwebwork.org/) - General information and resources including announcements of events and important project news
*  [WeBWorK wiki](http://webwork.maa.org/wiki/Main_Page) - The main WeBWorK wiki
*  [Instructors](http://webwork.maa.org/wiki/Instructors) - Information for Instructors
*  [Problem Authors](http://webwork.maa.org/wiki/Authors) - Information for Problem Authors
*  [WW_Install](http://github.com/aubreyja/ww_install) - Information for using the WW_install script
*  [Forum](http://webwork.maa.org/moodle/mod/forum/index.php?id=3) - The WeBWorK Forum
*  [Frequently Asked Questions](https://github.com/openwebwork/webwork2/wiki/Frequently-Asked-Questions) - A list of frequently asked questions.  

## Information for downloading

* The current version is WeBWorK-2.16 and its companion PG-2.16

* Installation manuals can be found at https://webwork.maa.org/wiki/Category:Installation_Manuals

* If you would prefer to download a previous release, say WeBWorK 2.14, then run the following commands:

```
cd /opt/webwork/webwork2
git checkout -b WeBWorK2.14+ WeBWorK2.14+
```
* If you want to pull the PG-2.14 branch of pg then run:

```
cd /opt/webwork/pg
git checkout -b PG-2.14+ PG-2.14+
```
* If you also need an earlier branch of MathJax then run:

```
cd /opt/webwork/MathJax
git checkout legacy-v2
```

* A tab to the upper right lists the releases that are available.

## Information For Developers

People interested in developing new features for WeBWorK should take a look at the following resources.  People interested in developing new problems for WeBWorK should visit [Problem Authors](http://webwork.maa.org/wiki/Authors).
*  [First Time Setup](https://github.com/openwebwork/webwork2/wiki/First-Time-Setup) - Setting up your clone of this github repo for the first time.  
*  [Coding and Workflow](https://github.com/openwebwork/webwork2/wiki/Coding-and-Workflow) -  Our suggested workflow processes.  Following this will make it much easier to get code accepted into the repo. 
*  [Creating Pull Requests](https://github.com/openwebwork/webwork2/wiki/Creating-Pull-Requests) - Instructions on how to submit a pull request. 
*  [More Information](https://github.com/openwebwork/webwork2/wiki/) - Our Github wiki has additional information for developers, including information about WeBWorK3. 
