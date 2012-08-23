
##How to use this dev repo:
Click fork webwork2-dev, all your future dev work will be done from your fork.

If you're using the commandline for git on your computer run these commands:

If you don't have a local repo yet:
```
git clone git@github.com:<your user name>/webwork2-dev.git
```

If you already have a repo:
__warning these commands will just merge it with you're currently checkedout branch!__

```
git remote add webwork2-dev git@github.com:<your user name>/webwork2-dev.git
git fetch webwork2-dev
git merge webwork2-dev/master

```

fix whatever problems are present

make some changes

commit

`git push webwork2-dev master`

go to your github webwork2-dev fork and click pull request.  Create a new pull request to openwebwork/webwork2-dev.