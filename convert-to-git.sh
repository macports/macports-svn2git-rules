#!/bin/bash

set -euo pipefail

current_dir=$(cd "$(dirname "$0")" && pwd)

##
# Build svn2git if necessary.
svn2git_repo=$current_dir/svn2git
svn2git=$svn2git_repo/build/svn-all-fast-export
if [ ! -f "$svn2git" ]; then
	# We need qmake, MacPorts has a weird path by default
	qmake=$(which qmake || true)
	if [ -z "$qmake" ] && [ -f "/opt/local/libexec/qt4/bin/qmake" ]; then
		qmake="/opt/local/libexec/qt4/bin/qmake"
	fi
	if [ -z "$qmake" ]; then
		echo "qmake not found, cannot continue" >&2
		exit 1
	fi

	# Build svn2git
	pushd "$svn2git_repo/" >/dev/null
	mkdir -p "build"
	cd "build"
	cat > ../src/local-config.pri <<-EOF
		SVN_INCLUDE = /opt/local/include/subversion-1
		SVN_LIBDIR = /opt/local/lib
		APR_INCLUDE = /opt/local/include/apr-1
	EOF
	"$qmake" CONFIG-=app_bundle QMAKE_LFLAGS+="-L/opt/local/lib -stdlib=libc++" QMAKE_CXXFLAGS+="-stdlib=libc++" ..
	make
	popd >/dev/null
fi
if [ ! -f "$svn2git" ]; then
	echo "No path to svn2git set and the build doesn't seem to have produced it, cannot continue" >&2
	exit 2
fi

# Configure variables; it seems the input directory must be relative, or
# svn2git will crash at the end.
indir=../repo
outdir=$PWD/git
identity_map=$current_dir/gitconversion.authors
rules=$current_dir/gitconversion.rules

rm -rf "$outdir"
mkdir -p "$outdir"
cd "$outdir"
"$svn2git" \
	--identity-map="$identity_map" \
	--rules="$rules" \
	--stats \
	"$indir"

# Compress output repositories
for repo in "$outdir/macports/"*; do
	printf "Compressing repository in %s\n" "$repo"
	du -sh "$repo"
	git -C "$repo" gc --aggressive --prune=all
	git -C "$repo" repack -a -d -f --window=250 --depth=250
	du -sh "$repo"
done
