#WeBWorK Development

The following are directions for new users to set up a machine for WeBWorK development, as well as our procedures for submitting and merging pull requests.  

## First Time Setup

If you are interested in writing code for WeBWorK you need to first get WeBWorK installation running, either on your own server or on a virtual machine.  This can either be done using the automated installation script at https://github.com/aubreyja/ww_install by running the commands:
```
wget --no-check-certificate https://raw.github.com/aubreyja/ww_install/master/install_webwork.sh
bash install_webwork.sh
```
Report any issues you have to aubreyja's github repository.  Alternatively you can manually install WeBWorK using the (largely outdated) instructions at http://webwork.maa.org/wiki/Get_WeBWorK. 

Next you will need to set up your own repository and add it as a remote to your WeBWorK installation.  
1.  Start by clicking the fork button on the upper right hand side of this page.  
2.  Your WeBWorK installation currently has the openwebwork github repository set up as a remote named origin.  Add your remote by using the command
```
cd /opt/webwork/webwork2
git remote add personal https://github.com/<github username here>/webwork2.git
cd /opt/webwork/pg
git remote add personal https://github.com/<github username here>/pg.git
```
Note:  If you installed WeBWorK manually using clone from your personal repository, then your personal repository will be named origin.  You would then add the openwebwork repository using a similar command as above.  You can then rename your branches using `git branch -m <old branch name> <new branch name>`.  
3.  Recommended:  This step is optional but recommended.  As described in the next section, all new code for WeBWorK should be written on feature branches.  We don't recommend keeping local copies of the develop and master branches around since you shouldn't be making commits to those.  If you want to work with a fresh copy of develop you should either make a feature branch or checkout a "headless"  version of develop to play around on.  The following commands will checkout a "headless" develop and delete the local master branch.
```
git checkout origin/develop
git branch -D master
```

## Coding and Workflow

Now you are ready to start making changes to WeBWorK.  The first thing you have to decide before you write your first line of code is where do you want your code to end up.  There are (usually) three possibilities:
*  master:  Only small important changes (i.e. hotfixes) should be submitted to master.  These are fixes to major bugs. 
*  release/x.y:  This branch is the beta of the upcoming release.  Submissions to this branch should either be bugfixing or minor improvements with little risk. 
*  develop:  This is the man development branch.  Most submissions should go here.  

After you have decided where you want your changes to end up you should create a feature branch as follows:
``` 
git checkout -b <my-feature-branch> origin/develop
```
This feature branch is set up to track, and eventually be merged into upstream/develop.  (Of course change develop to whichever branch you are targeting.)  

Note: If you just want to check out a version of develop to test something use `git checkout origin/develop`.  This creates a "headless" branch of develop for testing purposes.  If you decide you want to keep those changes you can use `git checkout -b <my-feature-branch>` and it will save your changes to a new feature branch. 

Now you are ready to code.  The recommended workflow looks something like 

1.  `git checkout -b <my-feature-branch> origin/develop`
2.  *code*
3.  `git commit -a`
4.  `git pull origin/develop`
5.  *fix merge conflicts, if any, and commit changes*
6.  `git push personal <my-feature-branch>`
7.  *repeat*

In particular you should be wary about pulling anything other your tracking branch (e.g. origin/develop) into your feature branch.  Ideally after your code is pulled into openwebwork its network graph should either be a "loop" or a "ladder".  
```
origin/develop ----------------------------o
                           \              /
                            \            /
personal/my-feature-branch   o-----o----o
```
```
origin/develop ---------------o--o---------o-o-------------o
                           \          \         \         /
                            \          \         \       /
personal/my-feature-branch   o-----o----o--o------o--o--o
```
Here the last diagonal line represents the final merge of the feature branch into the target branch. 

The most strict version of this policy is that your feature branch is only allowed to pull its tracking branch.  It should not have any other branches merged into it and it should not be merged into other branches.  This is more restrictive than is absolutely necessary, but it is very safe.  If you do decide to merge your branch into something else, or merge something else into it, keep the following in mind: 
*  If you merge a branch from origin other than your tracking branch into your feature branch, then your feature branch will not be able to be merged into openwebwork anymore. I.E. If you based your feature branch off origin/develop then you cannot pull origin/master or origin/release/x.y into your feature branch. 
*  If you merge a different feature branch which is tracking a branch different than your current feature branch, then your feature branch will not be able to be integrated into openwebwork anymore.  I.E.  If you have feature-a which is tracking origin/develop then you cannot pull feature-b into feature-a if feature-b is tracking origin/master. 
*  You can merge two feature branches which are both tracking the same branch in origin, but it makes life more difficult for the person evaluating the pull request, so have a good reason for doing so.  

Writing all of your changes into feature branches helps keep different features and different changes separate.  You can work on your experimental new student view in one branch, bugfix a previous contribution in another branch, and apply a quick hotfix to master in a third.  This does mean your local machine fills up with feature branches.  You can delete branches that have already been merged with `git branch -d <my-feature-branch>`.

## Creating Pull Requests

If you have been following the advice of the previous section then creating the pull request should be relatively simple.  
1.  Make sure your feature branch can be merged cleanly.  In other words, pull it's tracking branch (`git pull`), fix any conflicts, commit the results, and push to your git repository. 

2.  Go to the webwork2 repository page in your personal account, select your feature branch from the branch dropdown and click the green button. 

3.  Click "Edit" on the pull request bar and change the base of the openwebwork/webwork2 fork to the tracking branch of your feature.  I.E.  If your feature was created using `git checkout -b my-feature-branch origin/develop` then make sure you select "develop" as the base for openwebwork.  

4.  Review your pull request.  In particular take a close look at the file changes. 

    -  Are all of the changes relevant to your feature?  Did anything unexpected sneak in? 

    -  Do you have any "configuration" changes or changes with hard-coded path?  Any site specific code?  

    -  Are there a reasonable number of changes?  Will it be easy for a reviewer to look over your submission?  

    Note: If your are adding js libraries to WeBWorK and they are making your pull request hard to read, one solution is to create a new feature branch, just add the js libraries, and submit that pull first.  It should be accepted and merged relatively quickly.  Afterwards your feature branch will have a much smaller set of changes. 

5.  Pick a title for your pull request and write a description.  Your description should describe the major changes included in the pull request as well as fairly detailed instructions on how to test to see if the changes are working.  The better your description is and the clearer your instructions are the more likely someone will be able to test and merge your pull request in a timely manner.  

6.  Double check that the pull request is for the correct branch and submit.  Now scroll down to the bottom of the pull request page and check that it can be merged.  (The merge button should be green, not grey.)  If it can't be merged, pull the target branch into the feature branch, fix any conflicts, and push the changes to your personal git repository.  
Note:  It is likely you will need/want to change your pull request after it has been submitted.  If you push new commits to your personal git repository they will automatically be integrated into your pull request.  

After your pull request has been merged you can delete your feature branch.  Your changes are part of openwebwork now.  All that's left is to sit back and wait for someone to break something.  You can sign up for an account with the WeBWorK bug tracking service at http://bugs.webwork.maa.org.  Once you have an account you can set up you can get bug reports emailed to you by visiting preferences, going to the email preferences tab and clicking "Enable All Mail".  

## Merging Pull Requests

The other side of the coin is reviewing and testing submitted pull request so they can be merged.  This is usually done by by a maintainer of the openwebwork repository, but it doesn't have to be.  Anyone can review a pull request.  Something to keep in mind is that anything pulled into master is immediately distributed and has to be rock solid.  Anything pulled into a release/x.y branch will be merged into master in about six months and needs to be very stable.  Things merged into develop will make it into master in about a year or so, passing through a release branch on the way.  In particular something pulled into develop will eventually end up in master, and should be at least in its "beta" stage.  Experimental or preliminary code should be kept on individual contributers personal github repos and distributed from there.  

The standard procedure follows:
1.  Open the pull request and check to see that the file changes look sane and that the feature is being pulled into the correct branch.

Note:  First time submitters don't always use feature branches.  Often they are submitting their personal versions of develop.  As long as the file changes look fine its reasonable to think of "develop" as a badly named feature branch.  However you should point them to this documentation for future contributions. 

2.  Open the "Network" page for openwebwork and find the line corresponding to the feature branch on the Network page.  (You may need to click "refresh".)  Ideally the line will either be a "loop" or a "ladder" minus the final pull.  (See the above diagram).  
*  The branch must track (i.e. be split from) the same branch it is being pulled into.  E.G. If it splits off master it cannot be pulled into develop. 
Note: This is a common issue with first time submitters.  Point them to these instructions.  They can salvage their work by creating a proper feature branch and then either rebasing or using cherry-pick to move their commits to the feature branch.  
*  If a branch which is targeted for, say, develop, has had master or release/x.y merged into it, then it cannot be merged.  The developer will need to make a new feature branch tracking the appropriate branch and then use rebase or cherry-pick to move their code over. 
*  Beware of spaghetti pull requests.  Its fine if two feature branches which both track the same branch in origin are merged together, but it creates confusion.  In particular, if a feature branch tracking master has been pulled into a feature branch tracking develop then the feature branch tracking develop cannot be merged into openwebwork.  

3.  Get a local copy of the proposed changes.  The easiest way to do this is to go to the bottom of the "Conversation" tab on the pull request page, click the "command line" link, and run the commands under "Step 1".  You may need to add "origin/" in front of the target branch.  The result will look something like 
```
git checkout -b <git-username>-feature/<feature-branch-name> origin/<target-branch>
git pull https://github.com/<git-username>/webwork2.git <feature-branch-name>
```
Restart the webserver, and update config files or upgrade databases as necessary.  

4.  Test the code using the testing instructions provided in the pull request.  If they didn't provide instructions, figure out your own way to test the changes.  If/When something breaks, report it as a comment.  The submitter can fix the bugs and the pull request will update automatically.  

5.  Do a more thorough overview of the file changes.  Check to see that the changes look reasonable and that nothing seems unusual, out of place, or wrong.  
6.  Continue to try and break the pull request.  When the code is ready to be merged, write a short comment explaining what you have tested and merge the commit.  You should merge the pull request using the web interface, not via the command line.  

Note:  If you do not have merge privileges for openwebwork you can still review pull requests.  Just follow steps 1 through 6 and when you are done write a comment explaining what you have tested and what the results were.  A maintainer can then merge the request later. 

For cleanup feel free to delete the branch that you created to test the pull request `git branch -D <git-username>-feature/<feature-branch-name>`

## Frequently Asked Questions

*  I don't want to develop, I just want to use webwork.

Take a look at the install instructions near the top of the page.  A reasonable first step is to try the ww_install script.  
```
wget --no-check-certificate https://raw.github.com/aubreyja/ww_install/master/install_webwork.sh
bash install_webwork.sh
```

* I have a bug and I would like to report it. 

You can submit bugs using the github "issues" feature.  However, our standard bug tracker is at http://bugs.webwork.maa.org/.  In particular the best way to report bugs in problems is to use the "report bugs in this problem" button in the problem editor.  

*  I don't remember what my remotes are called and which is which?  

You can use `git remote -v` to list your current remotes and which repositories they are connected to.  

*  I can't keep all of these feature branches straight.  Help! 

Feature branches can be deleted after they are merged, which should keep the number down.  You can also use `git branch -vv` to list all of the branches on your machine, including what they are tracking.  

*  I just want to test out a few changes, why can't I have a local copy of develop?  

You can use a local copy of develop.  If you do `git checkout origin/develop` it will create a temporary "headless" version of develop which you can use to experiment.  This headless version can be turned into a proper feature branch later if you decide your changes are worth saving. 

*  I can't see my feature branch/merge/whatever on the network graph? 

You may need to click the refresh link. 

*  My question/problem isn't on this list.  

You can poke around in the official WeBWorK wiki at http://webwork.maa.org/wiki/Main_Page, visit the forums at http://webwork.maa.org/moodle/mod/forum/index.php, or try the IRC chatroom #webwork on freenode.  Be patient.  WeBWorK developers all have day jobs and other pressing concerns.  
