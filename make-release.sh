#!/bin/sh
# Builds Parable.app and zips it for a GitHub release.
set -eu
cd "$(dirname "$0")"
./make-app.sh release
rm -f Parable.zip
# ditto keeps the code signature and extended attributes intact.
ditto -c -k --keepParent Parable.app Parable.zip
echo "wrote $PWD/Parable.zip"
shasum -a 256 Parable.zip
