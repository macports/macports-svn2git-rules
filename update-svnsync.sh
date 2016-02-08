#!/bin/bash

set -euo pipefail

svn=https://svn.macports.org/repository/macports
# svnsync doesn't like relative paths
outurl=file://$PWD/repo

svnsync sync --non-interactive --memory-cache-size 512 "$outurl"
