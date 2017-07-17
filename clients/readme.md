# README

* The client directory contains software which shows how WeBWorK  PG questions can be accessed from outside the WeBWorK2 framework via a webserver. 

* For immediate testing copy `TestWW.html.dist` to `TestWW.html` and `Second_semester_calculus_topics.html.dist` to `Second_semester_calculus_topics.html`.  Open these files in an internet connected browser to see PG questions displayed in an ordinary webpage.
* These files illustrate the technology that is used to embed WeBWorK questions into the textbooks using [Mathbook\_XML](https://mathbook.pugetsound.edu/) (now PreTeXt).
* An earlier version of this technology embedding WeBWorK problems into HTML pages is described in this [blog post](http://michaelgage.blogspot.com/2015/06/whether-writing-full-text-book-or-just.html)
* To view this technology in action  from the command line one can use this command.
 
```
cd /opt/webwork/webwork2/clients
sendXMLRPC.pl -b t/input.pg
```
* `sendXMLRPC.pl` accepts a number of options that determine the information returned including HTML or PDF presentation, correct answers, and so forth.

* Many editors can be set up to send the text being edited through a command line program for display.  The file `sendxmlrpc_bbedit.pl` is an example of a connecting script that works with the Mac's BBedit.

-------------------------

* Here is more documentation on sendXMLRPC.pl

NAME
    webwork2/clients/sendXMLRPC.pl

DESCRIPTION
    
This script will take a list of files or directories and send it to a
WeBWorK daemon webservice to have it rendered. For directories each .pg file under that directory is rendered.

The results can be displayed in a browser (use -b or -B switches), on the command line (Use -h or -H switches) or summary information about
whether the problem was correctly rendered can be sent to a log file
(use -c or C switches).

The capital letter switches, -B, -H, and -C render the question twice. The first rendering returns an answer hash which contains the correct answers. The question is then resubmitted to the renderer with the correct answers filled in and displayed.

IMPORTANT: Remember to configure the local output file and display
    command near the top of this script. !!!!!!!!

IMPORTANT: Create a valid credentials file.

SYNOPSIS
*            `sendXMLRPC -vcCbB input.pg`

DETAILS

credentials file
  
* These locations are searched, in order,  for the credentials file.
        `("$ENV{HOME}/.ww_credentials", "$ENV{HOME}/ww_session_credentials", 'ww_credentials', 'ww_credentials.dist');`

        Place a credential file containing the following information at one of the locations above 
        or create a file with this information and specify it with the --credentials option.
    
            %credentials = (
                            userID                 => "my login name for the webwork course",
                            course_password        => "my password ",
                            courseID               => "the name of the webwork course",
                  XML_URL                  => my_site_edu/webwork2
                  XML_PASSWORD          => "site password" # preliminary access to site (often 123456789)
                  $FORM_ACTION_URL      =  'https://my_site_edu/webwork2/html2xml'; #action url for form
            );

* Options
* 
``` 
    -a
                Displays the answer hashes returned
                by the question on the command line.

    -A
                Same as -a but renders the question
                with the correct answers submitted.

    -b
                Display the rendered question in a
                browser (specified by the 
                DISPLAY_HTML_COMMAND variable).

    -B
                Same as -b but renders the question 
                with the correct answers submitted.

    -h
                Prints to STDOUT the entire object 
                returned by the webwork_client xmlrpc request.
                This includes the answer information displayed
                by -a and -A and much more.

    -H
                Same as -h but renders the question with
                the correct answers submitted

    -c
                "check" -- Record success or failure of 
                rendering the question to a log file.

    -C
                Same as -c but the question is rendered
                with the correct answers submitted. 
                This succeeds only if the correct answers,
                as determined from the answer hash, all succeed.

    f=s
                Specify the format used by the browser in
                displaying the question. 
                Choices for s are
                 	standard
                 	sticky
                 	debug 
                 	simple

    -v
                Verbose output. Used mostly for debugging. 
                In particular it displays explicitly the 
                correct answers which are (will be)  
                submitted to the question.

    -e
				Open the source file in an editor. 
```
The single letter options can be "bundled" e.g.  -vcCbB

```
    --tex    
				Process question in TeX mode and output to the command line
            
    --list   pg_list
				Read and process a list of .pg files contained in
				the file `pg_list`.  `pg_list` consists of a 
				sequence of lines each of which contains the full
				path to a pg file that should be processed. 
				(For example this might be the output from an
				earlier run of sendXMLRPC using the -c flag. )

    --pg
             Triggers the printing of the all of the variables
             available to the PG question. The table appears
             within the question content. Use in conjunction
             with -b or -B.

    --anshash
             Prints the answer hash for each answer in the
             PG_debug output which appears below the question
             content. Use in conjunction with -b or -B. 
             This is similar to -a or -A but the output
             appears in the browser and not on the command line.

    --ansgrp
             Prints the PGanswergroup for each answer evaluator.
             The information appears in the PG_debug output
             which follows the question content.  Use in 
             conjunction with -b or -B.
             This contains more information than printing
             the answer hash. (perhaps too much).

    --credentials=s
             Specifies a file s where the  credential
             information can be found.

	--help
		       Prints help information. 
	   
	--log 
		       Sets path to log file
```

