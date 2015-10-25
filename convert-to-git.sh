#!/bin/bash

set -euo pipefail

indir=repo
outdir=git
identity_map=gitconversion.authors
rules=gitconversion.rules
svn2git=/Users/clemens/Development/Svn2Git/build/svn-all-fast-export

rm -rf "$outdir"
mkdir "$outdir" || true
cd "$outdir"
"$svn2git" \
	--identity-map="../$identity_map" \
	--rules="../$rules" \
	--stats \
	"../$indir"
