#!/bin/bash

set -euo pipefail

url=https://svn.macports.org/repository/macports
incremental=
chunksize=1000
limit=141514
end=$(( limit / chunksize ))
start=0

echo "Dumping $url from 0 to $(( end * chunksize )) in chunks of $chunksize"

for (( i=0; i < $end; i++ )); do
	outfile=$(printf "macports.%03d.svn.gz" "$i")
	rangestart=$(( i * chunksize ))
	rangeend=$(( (i + 1) * chunksize - 1 ))
	if [ -f "$outfile" ]; then
		printf "Skipping range %03d to %03d (already dumped)\n" "$rangestart" "$rangeend" 
		incremental=--incremental
		continue
	fi

	printf "Dumping range %03d to %03d...\n" "$rangestart" "$rangeend"
	time svnrdump dump -q $incremental \
		--revision "$(( i * chunksize )):$(( (i + 1) * chunksize - 1 ))" \
		"$url" | gzip -9 > ".tmp.${outfile}"
	mv ".tmp.${outfile}" "${outfile}"

	incremental=--incremental
done
