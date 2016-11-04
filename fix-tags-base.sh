#!/usr/bin/env bash

if [ ${BASH_VERSINFO[0]} -lt 4 ]; then
    echo "This script needs bash 4.x" >&2
    exit 1
fi

set -e

BASEURL=https://github.com/macports/macports-base.git
BASEDIR=github/macports-base.git
SVNREPO=file://$PWD/repo
AUTHORMAP=$PWD/gitconversion.authors

### helper functions

declare -A authors
authors_read=0
read-author-map() {
    while read entry; do
        if [[ $entry =~ ^# ]]; then
            continue
        elif [[ $entry =~ ^(.*)\ =\ (.*)$ ]]; then
            local svnauthor=${BASH_REMATCH[1]}
            local gitauthor=${BASH_REMATCH[2]}
            authors[$svnauthor]="$gitauthor"
        fi
    done < $AUTHORMAP 
}

map-author() {
    if [ $authors_read -eq 0 ]; then
        read-author-map
        authors_read=1
    fi

    local svnauthor="$1"
    local gitauthor=""
    if [ -z "$svnauthor" ]; then
        gitauthor="nobody <nobody@localhost>"
    else
        gitauthor=${authors[$svnauthor]}
    fi
    if [ -z "$gitauthor" ]; then
        echo "Error: unable to map $svnauthor!" >&2
        exit 1
    fi
    echo "$gitauthor"
}

### main

if [ ! -d "$BASEDIR" ]; then
    mkdir -p $BASEDIR
    git clone --mirror $BASEURL $BASEDIR
else
    git -C $BASEDIR fetch -t
fi

cd $BASEDIR

git for-each-ref --shell --sort='refname' \
    --format="tag=%(refname:strip=2) gitauthorname=%(authorname) gitauthoremail=%(authoremail) gitdate=%(authordate) gitrev=%(objectname)" 'refs/tags/release_*' | \
while read entry; do
    eval $entry
    newtag=$(sed -E 's/release_([0-9_]+)/v\1/' <<< "$tag" | tr _ .)

    # Skip -archive tags
    # These are supposed to point at the same object as the non-archive tag and
    # generally do, except for those converted from CVS.
    if [[ $newtag == *-archive ]]; then
        continue
    fi

    svntagurl="$SVNREPO/tags/$tag"
    svnurl="$svntagurl"
    svnrev=$(svn info --show-item last-changed-revision $svntagurl)

    # Fix old CVS tags, they have a dummy commit by nobody on top
    if [ "$gitauthoremail" = "<nobody@localhost>" ]; then
        gitrev="$(git rev-parse $(git rev-parse refs/tags/$tag)^)"
        svnrev="$(git log -1 $gitrev |grep "git-svn-id: " |sed -E 's/^.*@([0-9]*).*$/\1/')"
        svnurl="$SVNREPO"
    fi

    # Fix release_1_6_0 that was updated and reverted
    # https://trac.macports.org/changeset/39535
    # https://trac.macports.org/changeset/39572
    if [ "$tag" == "release_1_6_0" ]; then
        gitrev="1e1f0faa0a35f8dc992174edad3a077cd2481938"
        svnrev="32094"
        svnurl="$SVNREPO"
    fi

    svndate="$(svn info --show-item last-changed-date $svnurl -r$svnrev)"
    svnauthor="$(svn info --show-item last-changed-author $svnurl -r$svnrev)"
    svnmappedauthor="$(map-author $svnauthor)"
    svnmappedauthorname="$(sed -E 's/^(.*) <(.*)>$/\1/' <<< "$svnmappedauthor")"
    svnmappedauthoremail="$(sed -E 's/^(.*) <(.*)>$/\2/' <<< "$svnmappedauthor")"

    version=${newtag#v}
    message=<<-EOF
	Release $version

        $SVNREPO/tags/$tag
	EOF

    echo "$newtag -> $gitrev:"

    env GIT_COMMITTER_NAME="$svnmappedauthorname" \
        GIT_COMMITTER_EMAIL="$svnmappedauthoremail" \
        GIT_COMMITTER_DATE="$svndate" \
        GIT_AUTHOR_NAME="$svnmappedauthorname" \
        GIT_AUTHOR_EMAIL="$svnmappedauthoremail" \
        GIT_AUTHOR_DATE="$svndate" \
        git tag -f -a -m "$message" "$newtag" "$gitrev"
done
