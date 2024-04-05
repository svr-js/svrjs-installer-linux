#!/bin/bash

##Print splash
echo '**********************************'
echo '**SVR.JS installer for GNU/Linux**'
echo '**********************************'
echo

##Check if user is root
if [ "$(id -u)" != "0" ]; then
  echo 'You need to have root privileges to install SVR.JS'
  exit 1
fi

##Determine the OS
OS="$(uname -s)"
if [ "$OS" == "Linux" ]; then
  if [ -f /etc/redhat-release ] ; then
    DISTRO=rhel
  elif [ -f /etc/SuSE-release ] ; then
    DISTRO=suse
  elif [ -f /etc/debian_version ] ; then
    DISTRO=debian
  elif [ -f /etc/arch-release ] ; then
    DISTRO=arch
  else
    DISTRO=other
  fi
elif [ "$OS" == "FreeBSD" ]; then
  DISTRO=freebsd
else
  DISTRO=other
fi

##Define depedency installation functions
install_nodejs() {
  case "$DISTRO" in
    "debian") apt install nodejs;;
    "rhel") yum install nodejs;;
    "suse") zypper install nodejs;;
    "arch") pacman -S nodejs;;
    "freebsd") pkg install node;;
    *) echo "You need to install Node.JS manually"
  esac
}

install_unzip() {
  case "$DISTRO" in
    "debian") apt install unzip;;
    "rhel") yum install unzip;;
    "suse") zypper install unzip;;
    "arch") pacman -S unzip;;
    "freebsd") pkg install unzip;;
    *) echo "You need to install unzip manually"
  esac
}

install_setcap() {
  case "$DISTRO" in
    "debian") apt install libcap2-bin;;
    "rhel") yum install libcap;;
    "suse") zypper install libcap-progs;;
    "arch") pacman -S libcap;;
    "freebsd") echo "Your OS doesn't support setcap";;
    *) echo "You need to install setcap manually"
  esac
}

##Select SVR.JS installation type
echo 'Select your SVR.JS installation type. Valid SVR.JS installation types:'
echo '0 - Latest stable version'
echo '1 - Latest LTS version'
echo '2 - Install and update manually'
echo -n 'Your SVR.JS installation type: '
read ITP
case $ITP in
  0) INSTALLTYPE=stable;;
  1) INSTALLTYPE=lts;;
  2) INSTALLTYPE=manual;;
  *) echo 'Invalid SVR.JS installation type!'; exit 1;;
esac

if [ "$INSTALLTYPE" == "manual" ]; then
  echo -n 'Path to SVR.JS zip archive: '
  read SVRJSZIPARCHIVE
elif [ "$INSTALLTYPE" == "stable" ]; then
  SVRJSVERSION="$(curl -fsL https://downloads.svrjs.org/latest.svrjs)"
  if [ "$SVRJSVERSION" == "" ]; then
    echo 'There was a problem while determining latest SVR.JS version!'
    exit 1
  fi
  SVRJSZIPARCHIVE="$(mktemp /tmp/svrjs.XXXXX.zip)"
  if ! curl -fsSL "https://downloads.svrjs.org/svr.js.$SVRJSVERSION.zip" > $SVRJSZIPARCHIVE; then
    echo 'There was a problem while downloading latest SVR.JS version!'
    exit 1
  fi
elif [ "$INSTALLTYPE" == "lts" ]; then
  SVRJSVERSION="$(curl -fsL https://downloads.svrjs.org/latest-lts.svrjs)"
  if [ "$SVRJSVERSION" == "" ]; then
    echo 'There was a problem while determining latest LTS SVR.JS version!'
    exit 1
  fi
  SVRJSZIPARCHIVE="$(mktemp -d /tmp/svrjs.XXXXX.zip)"
  if ! curl -fsSL "https://downloads.svrjs.org/svr.js.$SVRJSVERSION.zip" > $SVRJSZIPARCHIVE; then
    echo 'There was a problem while downloading latest LTS SVR.JS version!'
    exit 1
  fi
else
  echo 'There was a problem determining SVR.JS installation type!'
  exit 1
fi

##Check if SVR.JS zip archive exists
if ! [ -f $SVRJSZIPARCHIVE ]; then
  echo 'Can'"'"'t find SVR.JS archive! Make sure to download SVR.JS archive file from https://svrjs.org and rename it to "svrjs.zip".'
  exit 1
fi

##Check if unzip is installed
echo "Checking for unzip..."
unziputil=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f unzip | awk '{ print $2}' | xargs)
if [ "$unziputil" == "" ]; then
  install_unzip #Install unzip
fi
unziputil=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f unzip | awk '{ print $2}' | xargs)
if [ "$unziputil" == "" ]; then
  echo 'Can'"'"'t locate unzip!'
  exit 1
fi

##Check if Node.JS is installed
echo "Checking for Node.JS..."
nodejs=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f node | awk '{ print $2}' | xargs)
if [ "$nodejs" == "" ]; then
  install_nodejs #Install Node.JS
fi
nodejs=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f node | awk '{ print $2}' | xargs)
if [ "$nodejs" == "" ]; then
  echo 'Can'"'"'t locate Node.JS!'
  exit 1
fi

##Check if setcap is installed
echo "Checking for setcap..."
setcapis=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f setcap | awk '{ print $2}' | xargs)
if [ "$setcapis" == "" ]; then
  install_setcap #Install Node.JS
fi
setcapis=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f setcap | awk '{ print $2}' | xargs)
if [ "$setcapis" == "" ]; then
  echo 'Can'"'"'t locate setcap, you need to grant networking permissions manually'
else
  ##Grant networking permissions to Node.JS
  echo "Granting networking permissions..."
  sudo setcap cap_net_bind_service=+ep $nodejs
fi

##Copy SVR.JS files
echo "Copying SVR.JS files..."
mkdir /usr/lib/svrjs
echo $INSTALLTYPE > /usr/lib/svrjs/.installer.prop;
if [ "$SVRJSVERSION" != "" ]; then
  echo "$SVRJSVERSION" > /usr/lib/svrjs/.installer.version
fi
unzip $SVRJSZIPARCHIVE -d /usr/lib/svrjs > /dev/null
pushd .
cd /usr/lib/svrjs
node svr.js > /dev/null
popd
ln -s /usr/lib/svrjs/log /var/log/svrjs
ln -s /usr/lib/svrjs/config.json /etc/svrjs-config.json
node -e 'var fs=require("fs"),config=JSON.parse(fs.readFileSync("/usr/lib/svrjs/config.json").toString());config.wwwroot="/var/www/svrjs",fs.writeFileSync("/usr/lib/svrjs/config.json",JSON.stringify(config));' > /dev/null
mkdir -p /var/www/svrjs
mv /usr/lib/svrjs/index.html /var/www/svrjs
mv /usr/lib/svrjs/tests.html /var/www/svrjs
mv /usr/lib/svrjs/licenses /var/www/svrjs
mv /usr/lib/svrjs/testdir /var/www/svrjs
mv /usr/lib/svrjs/serverSideScript.js /var/www/svrjs
mv /usr/lib/svrjs/logo.png /var/www/svrjs
mv /usr/lib/svrjs/powered.png /var/www/svrjs
mv /usr/lib/svrjs/favicon.ico /var/www/svrjs 2>/dev/null
mv /usr/lib/svrjs/views.txt /var/www/svrjs 2>/dev/null
mv /usr/lib/svrjs/hviews.txt /var/www/svrjs 2>/dev/null
cp -R /usr/lib/svrjs/.dirimages /var/www/svrjs

##Install SVR.JS utilities
echo "Installing SVR.JS utilities..."
echo '#!/bin/bash' > /tmp/svrjs-utiltemplate
echo 'PARAMETERS=$(printf "%q " "$@")' >> /tmp/svrjs-utiltemplate
echo >> /tmp/svrjs-utiltemplate
echo 'if [ "$PARAMETERS" == "'"'""'"' " ]; then' >> /tmp/svrjs-utiltemplate
echo '  PARAMETERS=""' >> /tmp/svrjs-utiltemplate
echo 'fi' >> /tmp/svrjs-utiltemplate
echo >> /tmp/svrjs-utiltemplate
echo 'cd /usr/lib/svrjs' >> /tmp/svrjs-utiltemplate
cp /tmp/svrjs-utiltemplate /usr/bin/svrjs-loghighlight
echo 'node loghighlight.js $PARAMETERS' >> /usr/bin/svrjs-loghighlight
chmod a+x /usr/bin/svrjs-loghighlight
cp /tmp/svrjs-utiltemplate /usr/bin/svrjs-logviewer
echo 'node logviewer.js $PARAMETERS' >> /usr/bin/svrjs-logviewer
chmod a+x /usr/bin/svrjs-logviewer
cp /tmp/svrjs-utiltemplate /usr/bin/svrpasswd
echo 'node svrpasswd.js $PARAMETERS' >> /usr/bin/svrpasswd
chmod a+x /usr/bin/svrpasswd
cp /tmp/svrjs-utiltemplate /usr/bin/svrjs
echo 'node svr.js $PARAMETERS' >> /usr/bin/svrjs
chmod a+x /usr/bin/svrjs
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
chmod a+x /usr/bin/svrjs-updater

##Create user for running SVR.JS and assign permissions of files
echo "Creating user for running SVR.JS..."
useradd -r -d /usr/lib/svrjs svrjs
echo "Assigning SVR.JS permissions..."
chown -hR svrjs:svrjs /usr/lib/svrjs
chown -hR svrjs:svrjs /var/log/svrjs
chown -hR svrjs:svrjs /var/www/svrjs
find /usr/lib/svrjs -type d -exec chmod 755 {} \;
find /usr/lib/svrjs -type f -exec chmod 644 {} \;
find /var/log/svrjs -type d -exec chmod 755 {} \;
find /var/log/svrjs -type f -exec chmod 644 {} \;
find /var/www/svrjs -type d -exec chmod 755 {} \;
find /var/www/svrjs -type f -exec chmod 644 {} \;

##Install SVR.JS service
echo "Installing SVR.JS service..."
systemddetect=$(whereis -b -B $(echo $PATH | sed 's|:| |g') -f systemctl | awk '{ print $2}' | xargs)
if [ "$systemddetect" == "" ]; then
  echo '#!/bin/bash' > /etc/init.d/svrjs
  echo '### BEGIN INIT INFO' >> /etc/init.d/svrjs
  echo '# Provides:          svrjs' >> /etc/init.d/svrjs
  echo '# Required-Start:    $local_fs $remote_fs $network $syslog $named' >> /etc/init.d/svrjs
  echo '# Required-Stop:     $local_fs $remote_fs $network $syslog $named' >> /etc/init.d/svrjs
  echo '# Default-Start:     2 3 4 5' >> /etc/init.d/svrjs
  echo '# Default-Stop:      0 1 6' >> /etc/init.d/svrjs
  echo '# X-Interactive:     true' >> /etc/init.d/svrjs
  echo '# Short-Description: SVR.JS web server' >> /etc/init.d/svrjs
  echo '# Description:       Start the web server' >> /etc/init.d/svrjs
  echo '#  This script will start the SVR.JS web server.' >> /etc/init.d/svrjs
  echo '### END INIT INFO' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'server="/usr/lib/svrjs/svr.js"' >> /etc/init.d/svrjs
  echo 'servicename="SVR.JS web server"' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'user="svrjs"' >> /etc/init.d/svrjs
  echo 'nodejs=$(whereis -b -B $(echo $PATH | sed '"'"'s|:| |g'"'"') -f node | awk '"'"'{ print $2}'"'"' | xargs)' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'script="$(basename $0)"' >> /etc/init.d/svrjs
  echo 'lockfile="/var/lock/$script"' >> /etc/init.d/svrjs
  echo ' ' >> /etc/init.d/svrjs
  echo '. /etc/rc.d/init.d/functions 2>/dev/null || . /etc/rc.status 2>/dev/null || . /lib/lsb/init-functions 2>/dev/null' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'ulimit -n 12000 2>/dev/null' >> /etc/init.d/svrjs
  echo 'RETVAL=0' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'privilege_check()' >> /etc/init.d/svrjs
  echo '{' >> /etc/init.d/svrjs
  echo '  if [ "$(id -u)" != "0" ]; then' >> /etc/init.d/svrjs
  echo '    echo '"'"'You need to have root privileges to manage SVR.JS service'"'" >> /etc/init.d/svrjs
  echo '    exit 1' >> /etc/init.d/svrjs
  echo '  fi' >> /etc/init.d/svrjs
  echo '}' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'do_start()' >> /etc/init.d/svrjs
  echo '{' >> /etc/init.d/svrjs
  echo '    if [ ! -f "$lockfile" ] ; then' >> /etc/init.d/svrjs
  echo '        echo -n $"Starting $servicename: "' >> /etc/init.d/svrjs
  echo '        runuser -l "$user" -c "$nodejs $server > /dev/null &" && echo_success || echo_failure' >> /etc/init.d/svrjs
  echo '        RETVAL=$?' >> /etc/init.d/svrjs
  echo '        echo' >> /etc/init.d/svrjs
  echo '        [ $RETVAL -eq 0 ] && touch "$lockfile"' >> /etc/init.d/svrjs
  echo '    else' >> /etc/init.d/svrjs
  echo '        echo "$servicename is locked."' >> /etc/init.d/svrjs
  echo '        RETVAL=1' >> /etc/init.d/svrjs
  echo '    fi' >> /etc/init.d/svrjs
  echo '}' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'echo_failure() {' >> /etc/init.d/svrjs
  echo '    echo -n "fail"' >> /etc/init.d/svrjs
  echo '}' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'echo_success() {' >> /etc/init.d/svrjs
  echo '    echo -n "success"' >> /etc/init.d/svrjs
  echo '}' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'echo_warning() {' >> /etc/init.d/svrjs
  echo '    echo -n "warning"' >> /etc/init.d/svrjs
  echo '}' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'do_stop()' >> /etc/init.d/svrjs
  echo '{' >> /etc/init.d/svrjs
  echo '    echo -n $"Stopping $servicename: "' >> /etc/init.d/svrjs
  echo '    pid=`ps -aefw | grep "$nodejs $server" | grep -v " grep " | awk '"'"'{print $2}'"'"'`' >> /etc/init.d/svrjs
  echo '    kill -9 $pid > /dev/null 2>&1 && echo_success || echo_failure' >> /etc/init.d/svrjs
  echo '    RETVAL=$?' >> /etc/init.d/svrjs
  echo '    echo' >> /etc/init.d/svrjs
  echo '    [ $RETVAL -eq 0 ] && rm -f "$lockfile"' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo '    if [ "$pid" = "" -a -f "$lockfile" ]; then' >> /etc/init.d/svrjs
  echo '        rm -f "$lockfile"' >> /etc/init.d/svrjs
  echo '        echo "Removed lockfile ( $lockfile )"' >> /etc/init.d/svrjs
  echo '    fi' >> /etc/init.d/svrjs
  echo '}' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'do_status()' >> /etc/init.d/svrjs
  echo '{' >> /etc/init.d/svrjs
  echo '   pid=`ps -aefw | grep "$nodejs $server" | grep -v " grep " | awk '"'"'{print $2}'"'"' | head -n 1`' >> /etc/init.d/svrjs
  echo '   if [ "$pid" != "" ]; then' >> /etc/init.d/svrjs
  echo '     echo "$servicename (pid $pid) is running..."' >> /etc/init.d/svrjs
  echo '   else' >> /etc/init.d/svrjs
  echo '     echo "$servicename is stopped"' >> /etc/init.d/svrjs
  echo '   fi' >> /etc/init.d/svrjs
  echo '}' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'case "$1" in' >> /etc/init.d/svrjs
  echo '    start)' >> /etc/init.d/svrjs
  echo '        privilege_check' >> /etc/init.d/svrjs
  echo '        do_start' >> /etc/init.d/svrjs
  echo '        ;;' >> /etc/init.d/svrjs
  echo '    stop)' >> /etc/init.d/svrjs
  echo '        privilege_check' >> /etc/init.d/svrjs
  echo '        do_stop' >> /etc/init.d/svrjs
  echo '        ;;' >> /etc/init.d/svrjs
  echo '    status)' >> /etc/init.d/svrjs
  echo '        do_status' >> /etc/init.d/svrjs
  echo '        ;;' >> /etc/init.d/svrjs
  echo '    restart)' >> /etc/init.d/svrjs
  echo '        privilege_check' >> /etc/init.d/svrjs
  echo '        do_stop' >> /etc/init.d/svrjs
  echo '        do_start' >> /etc/init.d/svrjs
  echo '        RETVAL=$?' >> /etc/init.d/svrjs
  echo '        ;;' >> /etc/init.d/svrjs
  echo '    *)' >> /etc/init.d/svrjs
  echo '        echo "Usage: $0 {start|stop|status|restart}"' >> /etc/init.d/svrjs
  echo '        RETVAL=1' >> /etc/init.d/svrjs
  echo 'esac' >> /etc/init.d/svrjs
  echo >> /etc/init.d/svrjs
  echo 'exit $RETVAL' >> /etc/init.d/svrjs
  chmod a+x /etc/init.d/svrjs
  update-rc.d svrjs defaults
  /etc/init.d/svrjs start
else
  echo '[Unit]' > /etc/systemd/system/svrjs.service
  echo 'Description=SVR.JS web server' >> /etc/systemd/system/svrjs.service
  echo 'After=network.target' >> /etc/systemd/system/svrjs.service
  echo >> /etc/systemd/system/svrjs.service
  echo '[Service]' >> /etc/systemd/system/svrjs.service
  echo 'Type=simple' >> /etc/systemd/system/svrjs.service
  echo 'User=svrjs' >> /etc/systemd/system/svrjs.service
  echo 'ExecStart=/usr/bin/env node /usr/lib/svrjs/svr.js' >> /etc/systemd/system/svrjs.service
  echo 'Restart=on-failure' >> /etc/systemd/system/svrjs.service
  echo >> /etc/systemd/system/svrjs.service
  echo '[Install]' >> /etc/systemd/system/svrjs.service
  echo 'WantedBy=multi-user.target' >> /etc/systemd/system/svrjs.service
  systemctl enable svrjs
  systemctl start svrjs
fi

echo "Done! SVR.JS is installed successfully!"
