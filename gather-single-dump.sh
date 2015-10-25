#!/bin/bash

set -euo pipefail

outdir=repo

mkdir "$outdir" || true
#mount -t tmpfs none "$outdir"
svnadmin create "$outdir"
for file in macports.*.svn.gz; do
	printf "Importing %s...\n" "$file"
	gzip -cd < "$file" | time svnadmin load --quiet --force-uuid "$outdir"
done

printf "Dumping gathered repository..."
time svnadmin dump --quiet "$outdir" | gzip -9 > ".tmp.macports.svn.gz"
mv ".tmp.macports.svn.gz" "macports.svn.gz"

#umount "$outdir"
