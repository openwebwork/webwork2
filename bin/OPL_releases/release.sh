#!/bin/bash
#
# Shell script to make releases of webwork problem libraries, heavily inspired
# by https://github.com/gap-system/ReleaseTools/blob/master/release

set -e

######################################################################
#
# Usage information
#
help() {
cat <<EOF
Usage: $0 [OPTIONS]

A tool for making releases of webwork problem libraries on GitHub.

Run this from within a git clone of your webwork problem library repository, checked out
at the revision you want to release.

Actions
  -h,  --help                      display this help text and exit
  -f, --force                      if a release with the same name already exists: overwrite it

Paths
  --librarydir <path>              directory containing the library [Default: current directory]
  --tmpdir <path>                  to a temporary directory [Default: tmp subdirectory of current directory]
  --libraryname <name>             library name

Custom settings
  -t,  --tag <tag>                 git tag for the release
  -r,  --repository <repository>   set GitHub repository (as USERNAME/REPONAME)
  --token <oauth>                  GitHub access token

Notes:
* To learn how to create a GitHub access token, please consult
  https://help.github.com/articles/creating-an-access-token-for-command-line-use/
EOF
    exit 0
}

######################################################################
#
# Various little helper functions


# print notices in green
notice() {
    printf '\033[32m%s\033[0m\n' "$*"
}

# print warnings in yellow
warning() {
    printf '\033[33mWARNING: %s\033[0m\n' "$*"
}

# print error in red and exit
error() {
    printf '\033[31mERROR: %s\033[0m\n' "$*"
    exit 1
}

# check for uncommitted changes
verify_git_clean() {
    git update-index --refresh
    git diff-index --quiet HEAD -- ||
        error "uncommitted changes detected"
}

# helper function for parsing GitHub's JSON output. Right now,
# we only extra the value of a single key at a time. This means
# we may end up parsing the same JSON data two times, but that
# doesn't really matter as it is tiny.
json_get_key() {
    echo "$response" | python -c 'import json,sys;obj=json.load(sys.stdin);print(obj.get("'"$1"'",""))'
}

# On Mac OS X, tar stores extended attributes in ._FOO files inside archives.
# Setting COPYFILE_DISABLE prevents that. See <http://superuser.com/a/260264>
export COPYFILE_DISABLE=1


######################################################################
#
# Command line processing
#
CONTENT="METADATA"
LIBRARY_DIR="$PWD"
TMP_DIR="$PWD/tmp"

FORCE=no
while [ x"$1" != x ]; do
  option="$1" ; shift
  case "$option" in
    -h | --help ) help ;;

    --librarydir ) LIBRARY_DIR="$1"; shift ;;
    --libraryname ) LIBRARY_NAME="$1"; shift ;;
    --tmpdir ) TMP_DIR="$1"; shift ;;

    -t | --tag ) TAG="$1"; shift ;;
    -r | --repository ) REPO="$1"; shift ;;
    --token ) TOKEN="$1"; shift ;;

    -f | --force ) FORCE=yes ;;
    --no-force ) FORCE=no ;;

    -- ) break ;;
    * ) error "unknown option '$option'" ;;
  esac
done


######################################################################
#
# Some initial sanity checks
#

command -v curl >/dev/null 2>&1 ||
    error "the 'curl' command was not found, please install it"

command -v git >/dev/null 2>&1 ||
    error "the 'git' command was not found, please install it"

command -v python >/dev/null 2>&1 ||
    error "the 'python' command was not found, please install it"

cd $LIBRARY_DIR
#verify_git_clean


######################################################################
#
# Determine the basename for the package archives
#
#

notice "Library path: " $LIBRARY_DIR

notice "Updating OPL tables"
OPL-update

notice "Dumping OPL tables"
dump-OPL-tables.pl

######################################################################
#
# Fetch GitHub oauth token, used to authenticate the following commands.
# See https://help.github.com/articles/git-automation-with-oauth-tokens/
#
if [ "x$TOKEN" = x ] ; then
    TOKEN=$(git config --get github.token || echo)
fi
if [ "x$TOKEN" = x ] && [ -r ~/.github_shell_token ] ; then
    TOKEN=$(cat ~/.github_shell_token)
fi
if [ "x$TOKEN" = x ] ; then
    error "could not determine GitHub access token"
fi


######################################################################
#
# Determine GitHub repository and username, and the current branch
#
if [ x"$REPO" = "x" ] ; then
    error "could not guess GitHub repository"
fi
notice "Using GitHub repository $REPO"

GITHUB_USER=$(dirname "$REPO")
notice "Using GitHub username $GITHUB_USER"


######################################################################
#
# Derive API urls
#
API_URL=https://api.github.com/repos/$REPO/releases
UPLOAD_URL=https://uploads.github.com/repos/$REPO/releases


######################################################################
#
# Determine the tag, and validate it
#
#verify_git_clean

cd $LIBRARY_DIR

if git show-ref -q "$TAG" ; then
    notice "Using git tag $TAG"
else
    notice "Creating git tag $TAG"
    git tag "$TAG"
fi;

HEAD_REF=$(git rev-parse --verify HEAD)
TAG_REF=$(git rev-parse --verify "$TAG^{}")

if [ "x$TAG_REF" != "x$HEAD_REF" ] ; then
    error "tag $TAG is not the HEAD commit -- did you tag the right commit?"
fi


echo ""


######################################################################
#
# Get fresh (unmodified) copies of the files, and generate some stuff
#

# Clean any remains of previous export attempts
mkdir -p "$TMP_DIR"
rm -rf "${TMP_DIR:?}/$LIBRARY_NAME"*

# Set umask to ensure the file permissions in the release
# archives are sane.
umask 0022

notice "Preparing content"
mkdir "$TMP_DIR/$LIBRARY_NAME"
cp -r $LIBRARY_DIR/TABLE-DUMP "$TMP_DIR/$LIBRARY_NAME/TABLE-DUMP"
cp -r $LIBRARY_DIR/JSON-SAVED "$TMP_DIR/$LIBRARY_NAME/JSON-SAVED"

#notice "Removing unnecessary files"
#rm -f .git* .hg* .cvs*
#rm -f .appveyor.yml .codecov.yml .travis.yml


######################################################################
#
# Push commits to GitHub
#

cd "$LIBRARY_DIR"

# construct GitHub URL for pusing
REMOTE="https://$GITHUB_USER:$TOKEN@github.com/$REPO"

# Make sure the branch is on the server
notice "Pushing your branch to GitHub"
notice "Remote: $REMOTE"

# Make sure the tag is on the server
notice "Pushing your tag to GitHub"
if [ "x$FORCE" = xyes ] ; then
    git push --force "$REMOTE" "$TAG"
else
    git push "$REMOTE" "$TAG"
fi

######################################################################
#
# Create the GitHub release
#

# check if release already exists
response=$(curl -s -S -X GET "$API_URL/tags/$TAG?access_token=$TOKEN")
MESSAGE=$(json_get_key message)
RELEASE_ID=$(json_get_key id)

if [ "$MESSAGE" = "Not Found" ] ; then
    MESSAGE=  # release does not yet exist -> that's how we like it
elif [ x"$RELEASE_ID" != x ] ; then
    # release already exists -> error out or delete it
    if [ "x$FORCE" = xyes ] ; then
        notice "Deleting existing release $TAG from GitHub"
        response=$(curl --fail -s -S -X DELETE "$API_URL/$RELEASE_ID?access_token=$TOKEN")
        MESSAGE=
    else
        error "release $TAG already exists on GitHub, aborting (use --force to override this)"
    fi
fi

if [ x"$MESSAGE" != x ] ; then
    error "accessing GitHub failed: $MESSAGE"
fi

# Create the release by sending suitable JSON
DATA=$(cat <<EOF
{
  "tag_name": "$TAG",
  "name": "$TAG",
  "body": "Release for $LIBRARY_NAME",
  "draft": false,
  "prerelease": false
}
EOF
)

notice "Creating new release $TAG on GitHub"
response=$(curl -s -S -H "Content-Type: application/json" \
 -X POST --data "$DATA" "$API_URL?access_token=$TOKEN")

MESSAGE=$(json_get_key message)
if [ x"$MESSAGE" != x ] ; then
    error "creating release on GitHub failed: $MESSAGE"
fi
RELEASE_ID=$(json_get_key id)
if [ x"$RELEASE_ID" = x ] ; then
    error "creating release on GitHub failed: no release id"
fi


######################################################################
#
# Test whether ARCHIVE_FORMATS contains at least one valid format
#

FOUND_VALID_FORMAT=0
VALID_ARCHIVE_FORMATS='.tar.gz .tar.bz2 .zip'
for VALID_FORMAT in $VALID_ARCHIVE_FORMATS
do
	if [[ $ARCHIVE_FORMATS =~ $VALID_FORMAT ]]
	then
		FOUND_VALID_FORMAT=1;
	fi;
done;
if [[ $FOUND_VALID_FORMAT == "0" ]]
then
	warning "No valid archive format specified." ;
	exit 1;
fi;

######################################################################
#
# Create and upload all requested archive files (as per ARCHIVE_FORMATS)
#
cd "$TMP_DIR"
echo ""
for EXT in $ARCHIVE_FORMATS ; do
    ARCHIVENAME=$LIBRARY_NAME-$CONTENT$EXT
    FULLNAME="$TMP_DIR/$ARCHIVENAME"
    notice "Creating $ARCHIVENAME ..."
    case $EXT in
    .tar.gz)
        tar cf - "$LIBRARY_NAME" | gzip -9c > "$ARCHIVENAME"
        MIMETYPE="application/x-gzip"
        ;;
    .tar.bz2)
        tar cf - "$LIBRARY_NAME" | bzip2 -9c > "$ARCHIVENAME"
        MIMETYPE="application/x-bzip2"
        ;;
    .zip)
        zip -r9 --quiet "$ARCHIVENAME" "$LIBRARY_NAME"
        MIMETYPE="application/zip"
        ;;
    *)
        warning "unsupported archive format $EXT"
        continue
        ;;
    esac
    if [ ! -f "$FULLNAME" ] ; then
        error "failed creating $FULLNAME"
    fi
    notice "Uploading $ARCHIVENAME with mime type $MIMETYPE"
    response=$(curl --fail --progress-bar -o "$TMP_DIR/upload.log" \
        -X POST "$UPLOAD_URL/$RELEASE_ID/assets?name=$ARCHIVENAME" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token $TOKEN" \
        -H "Content-Type: $MIMETYPE" \
        --data-binary @"$FULLNAME")
done



exit 0
