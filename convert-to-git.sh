#!/bin/bash

set -euo pipefail

##
# Handle option parsing. This accepts a single flag -f, denoting whether the
# incremental import should be continued, or the output directory should be
# deleted, starting from scratch.
force=0
if [ $# -gt 0 ] && [ "$1" == "-f" ]; then
	force=1
	echo "Force option set, removing existing work directory." >&2
fi

current_dir=$(cd "$(dirname "$0")" && pwd)

##
# Build svn2git if necessary.
svn2git=$(command -v svn-all-fast-export 2>&1)
if [ ! -f "$svn2git" ]; then
	svn2git_repo=$current_dir/svn2git
	svn2git=$svn2git_repo/build/svn-all-fast-export
fi
if [ ! -f "$svn2git" ]; then
	# We need qmake, MacPorts has a weird path by default
	qmake=$(command -v qmake 2>&1)
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

if [ "$force" = 1 ] || [ ! -f "$outdir/lastrev" ]; then
	rm -rf "$outdir"
fi
mkdir -p "$outdir"
cd "$outdir"

# Find resume version, if available
resume_from=$(cat lastrev || echo 0)
resume_from=$(( resume_from + 1 ))
max_rev=$(svnlook youngest "$indir")

# Do the export
"$svn2git" \
	--identity-map="$identity_map" \
	--rules="$rules" \
	--add-metadata \
	--resume-from "$resume_from" \
	--max-rev "$max_rev" \
	--stats \
	"$indir" || (rm -f "lastrev"; exit 1)
# ... but make sure to delete the lastrev file if something failed, because
# that means we need to start over

# Store the last imported revision, if successful
echo "$max_rev" > "lastrev"

# Compress output repositories
if [ $resume_from -eq 1 ]; then
	for repo in "$outdir/macports/"*; do
		printf "Compressing repository in %s\n" "$repo"
		du -sh "$repo"
		git -C "$repo" gc --aggressive --prune=all
		git -C "$repo" repack -a -d -f --window=250 --depth=250
		du -sh "$repo"
	done
fi
