#!/usr/bin/env bash

set -e

BASEURL=https://github.com/macports/macports-base.git
BASEDIR=github/macports-base.git

### main

if [ ! -d "$BASEDIR" ]; then
    mkdir -p $BASEDIR
    git clone --mirror $BASEURL $BASEDIR
else
    git -C $BASEDIR fetch -t
fi

cd $BASEDIR

git for-each-ref --shell --sort='refname' \
    --format="ref=%(refname) branch=%(refname:strip=2)" 'refs/heads/release_*' | \
while read entry; do
    eval $entry
    newbranch=$(sed -E 's/release_([0-9_]+)/release-\1/' <<< "$branch" | tr _ .)

    echo "$newbranch <- $branch"
    git branch -f $newbranch $ref
done
