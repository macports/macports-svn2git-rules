#!/bin/bash

set -euo pipefail

svn=https://svn.macports.org/repository/macports
# svnsync doesn't like relative paths
outdir=$PWD/repo
outurl=file://$outdir

printf "#!/bin/sh\nexit 0\n" > "$outdir/hooks/pre-revprop-change"
chmod +x "$outdir/hooks/pre-revprop-change"

svnsync init --allow-non-empty --non-interactive --memory-cache-size 512 "$outurl" "$svn"
