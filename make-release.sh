#!/bin/sh
# Builds Parable.app and zips it for a GitHub release.
set -eu
cd "$(dirname "$0")"
./make-app.sh release
rm -f Parable.zip
# Leave out extended attributes: they get stored as ._ files, which command-line
# unzip drops inside the app, breaking its code signature.
ditto -c -k --norsrc --noextattr --keepParent Parable.app Parable.zip
echo "wrote $PWD/Parable.zip"
shasum -a 256 Parable.zip
