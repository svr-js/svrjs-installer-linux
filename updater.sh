#!/bin/bash

##Print splash
echo '****************************'
echo '**SVR.JS updater for Linux**'
echo '****************************'
echo

##Check if user is root
if [ "$(id -u)" != "0" ]; then
  echo 'You need to have root privileges to update SVR.JS'
  exit 1
fi

##Check if svrjs.zip exists
if ! [ -f svrjs.zip ]; then
  echo 'Can'"'"'t find SVR.JS archive in "svrjs.zip"! Make sure to download SVR.JS archive file from https://svrjs.org and rename it to "svrjs.zip".'
  exit 1
fi

##Check if SVR.JS is installed
if ! [ -d /usr/lib/svrjs ]; then
  echo 'SVR.JS isn'"'"'t installed (or it'"'"'s installed without using SVR.JS installer)!'
  exit 1
fi

##Copy SVR.JS files
echo "Copying SVR.JS files..."
unzip -o svrjs.zip -d /usr/lib/svrjs svr.compressed modules.compressed svr.js > /dev/null
chown svrjs:svrjs /usr/lib/svrjs/svr.compressed /usr/lib/svrjs/modules.compressed /usr/lib/svrjs/svr.js
chmod 775 /usr/lib/svrjs/svr.compressed /usr/lib/svrjs/modules.compressed /usr/lib/svrjs/svr.js
unzip -o svrjs.zip -d /usr/lib/svrjs logviewer.js loghighlight.js > /dev/null
chown svrjs:svrjs /usr/lib/svrjs/logviewer.js /usr/lib/svrjs/loghighlight.js
chmod 775 /usr/lib/svrjs/logviewer.js /usr/lib/svrjs/loghighlight.js
unzip -o svrjs.zip -d /usr/lib/svrjs svrpasswd.js > /dev/null
chown svrjs:svrjs /usr/lib/svrjs/svrpasswd.js
chmod 775 /usr/lib/svrjs/svrpasswd.js
pushd .
cd /usr/lib/svrjs
node svr.js > /dev/null
popd

echo "Done! SVR.JS is updated successfully!"
