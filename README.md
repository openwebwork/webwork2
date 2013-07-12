#WeBWorK Development
This is a rough draft of our developer instructions, so parts of it are likely missing or wrong. Any corrections/additions are welcome

We're trying to folow [git flow](http://nvie.com/posts/a-successful-git-branching-model/) so it would be a good idea for developers to read up on it 
and [install](https://github.com/nvie/gitflow/wiki/Installation) the commandline tools.  
We're working on getting our own, more specific, documentation up about our desired development flow.

Here are the basics to get you set up developing.

First create an account/login to github.  Head to the https://github.com/openwebwork/webwork2 and click **fork**.

Once that's done, clone you're newly forked repo to you're local computer and add openwebwork as an upstream.

```
git add remote upstream git://github.com/openwebwork/webwork2.git
```

I'd also recomend making sure the develop branch is pulled down from openwebwork and ready to push up to you're github repo.

```
git checkout -b develop upstream/develop
git branch --set-upstream develop origin/develop
```

This will let you keep you're version up to date with the official one.

The rest of these instructions will assume you're using the [git flow commandline](https://github.com/nvie/gitflow/wiki/Command-Line-Arguments).. if you're not there are equivilant commands in pure git.

First get you're local repo ready for git flow

```
git flow init
```

Here are the basics for working on a new feature

```
git flow feature start <name>
```

then make you're changes, push everything up to you're github for people to see `git push origin`.

When you're feature is stable (or close) you can issue a pull requst on github from your feature branch to the openwebwork/webwork2 develop branch.
Including a comment stating what the feature is and any more information would be great.
