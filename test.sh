cat > /usr/bin/svrjs-updater << 'EOF'
#!/bin/bash

##Print splash
echo '********************************'
echo '**SVR.JS updater for GNU/Linux**'
echo '********************************'
echo

##Check if user is root
if [ "$(id -u)" != "0" ]; then
  echo 'You need to have root privileges to update SVR.JS'
  exit 1
fi

##Check if SVR.JS is installed
if ! [ -d /usr/lib/svrjs ]; then
  echo 'SVR.JS isn'"'"'t installed (or it'"'"'s installed without using SVR.JS installer)!'
  exit 1
fi

##Create .installer.prop file, if it doesn't exist
if ! [ -f /usr/lib/svrjs/.installer.prop ]; then
  echo manual > /usr/lib/svrjs/.installer.prop;
fi

##Check the SVR.JS installation type
INSTALLTYPE="$(cat /usr/lib/svrjs/.installer.prop)"
if [ "$INSTALLTYPE" == "manual" ]; then
  echo -n 'Path to SVR.JS zip archive: '
  read SVRJSZIPARCHIVE
elif [ "$INSTALLTYPE" == "stable" ]; then
  SVRJSOLDVERSION=""
  SVRJSVERSION="$(curl -fsL https://downloads.svrjs.org/latest.svrjs)"
  if [ "$SVRJSVERSION" == "" ]; then
    echo 'There was a problem while determining latest SVR.JS version!'
    exit 1
  fi
  if [ -f /usr/lib/svrjs/.installer.version ]; then
    SVRJSOLDVERSION="$(cat /usr/lib/svrjs/.installer.version)"
  fi
  if [ "$SVRJSOLDVERSION" == "$SVRJSVERSION" ]; then
    echo 'Your SVR.JS version is up to date!'
    exit 0
  fi
  SVRJSZIPARCHIVE="$(mktemp /tmp/svrjs.XXXXX.zip)"
  if ! curl -fsSL "https://downloads.svrjs.org/svr.js.$SVRJSVERSION.zip" > $SVRJSZIPARCHIVE; then
    echo 'There was a problem while downloading latest SVR.JS version!'
    exit 1
  fi
  echo "$SVRJSVERSION" > /usr/lib/svrjs/.installer.version
elif [ "$INSTALLTYPE" == "lts" ]; then
  SVRJSOLDVERSION=""
  SVRJSVERSION="$(curl -fsL https://downloads.svrjs.org/latest-lts.svrjs)"
  if [ "$SVRJSVERSION" == "" ]; then
    echo 'There was a problem while determining latest LTS SVR.JS version!'
    exit 1
  fi
  if [ -f /usr/lib/svrjs/.installer.version ]; then
    SVRJSOLDVERSION="$(cat /usr/lib/svrjs/.installer.version)"
  fi
  if [ "$SVRJSOLDVERSION" == "$SVRJSVERSION" ]; then
    echo 'Your SVR.JS version is up to date!'
    exit 0
  fi
  SVRJSZIPARCHIVE="$(mktemp -d /tmp/svrjs.XXXXX.zip)"
  if ! curl -fsSL "https://downloads.svrjs.org/svr.js.$SVRJSVERSION.zip" > $SVRJSZIPARCHIVE; then
    echo 'There was a problem while downloading latest LTS SVR.JS version!'
    exit 1
  fi
  echo "$SVRJSVERSION" > /usr/lib/svrjs/.installer.version
else
  echo 'There was a problem determining SVR.JS installation type!'
  exit 1
fi

##Check if SVR.JS zip archive exists
if ! [ -f $SVRJSZIPARCHIVE ]; then
  echo 'Can'"'"'t find SVR.JS archive! Make sure to download SVR.JS archive file from https://svrjs.org and rename it to "svrjs.zip".'
  exit 1
fi

##Copy SVR.JS files
echo "Copying SVR.JS files..."
unzip -o $SVRJSZIPARCHIVE -d /usr/lib/svrjs svr.compressed modules.compressed svr.js > /dev/null
chown svrjs:svrjs /usr/lib/svrjs/svr.compressed /usr/lib/svrjs/modules.compressed /usr/lib/svrjs/svr.js
chmod 775 /usr/lib/svrjs/svr.compressed /usr/lib/svrjs/modules.compressed /usr/lib/svrjs/svr.js
unzip -o $SVRJSZIPARCHIVE -d /usr/lib/svrjs logviewer.js loghighlight.js > /dev/null
chown svrjs:svrjs /usr/lib/svrjs/logviewer.js /usr/lib/svrjs/loghighlight.js
chmod 775 /usr/lib/svrjs/logviewer.js /usr/lib/svrjs/loghighlight.js
unzip -o $SVRJSZIPARCHIVE -d /usr/lib/svrjs svrpasswd.js > /dev/null
chown svrjs:svrjs /usr/lib/svrjs/svrpasswd.js
chmod 775 /usr/lib/svrjs/svrpasswd.js
pushd .
cd /usr/lib/svrjs
node svr.js > /dev/null
popd

echo "Done! SVR.JS is updated successfully! You can now restart SVR.JS using \"/etc/init.d/svrjs restart\" or \"systemctl restart svrjs\"."
EOF
