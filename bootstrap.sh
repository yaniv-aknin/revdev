#!/usr/bin/env bash

set -ex

# NOTE: in the holy name of simplicity and laziness I don't bother handling $PROJECT_ROOT which needs quoting;
#       if you try using this script with a $PROJECT_ROOT that has a space in it or so, you're a friggin' moron

if [ ! -e /etc/lsb-release ] || ! egrep 'Ubuntu' /etc/lsb-release > /dev/null; then
    echo "this script expects Ubuntu" # but if you know what you're doing, you can just do as the script does
                                      # on your system
                                      # and if you use Debian, then I'm sorry, were I a better man I'd test and
                                      # allow running on it, too
    exit 1
fi

if [ -z $PROJECT_ROOT ]; then
    PROJECT_ROOT="/opt/revdev"
fi

if [ ! -d $PROJECT_ROOT ] || ! grep d3333ce73f05 $PROJECT_ROOT/bootstrap.sh > /dev/null; then
    echo "you should have cloned this repo at $PROJECT_ROOT"
    exit 1
fi

if [ "$(id -u)" != "0" ]; then
    echo "this script expects to run as root"
    exit 1
fi

if dpkg-query -W -f '${Provides}\n' | grep httpd > /dev/null; then
    if [ -n "$IDEMPOTENT" ]; then
        echo "removing your existing nginx"
        apt-get --assume-yes purge nginx-full
        apt-get --assume-yes autoremove
    else
        echo "it appears you already have a webserver on this system; cowardly aborting"
        exit 1
    fi
fi

if [ -n "$1" ]; then
    REVDEV_KEY_PASSWORD="$1"
fi

patch_config_file() {
    grep "$1" "$2" > /dev/null || echo "$1" >> "$2"
}

# setup the revdev user
cd $PROJECT_ROOT
mkdir -p home/.ssh
[ ! -f home/.ssh/id_rsa ] && ssh-keygen -f home/.ssh/id_rsa -N '' -q
if [ -n "$IDEMPOTENT" ] && id revdev 2> /dev/null; then
    userdel revdev
fi
useradd revdev -d $PROJECT_ROOT/home/ -M -s /bin/sh -r
echo -n "permitopen=\"127.0.0.1:1\",command=\"exec /usr/bin/python -u $PROJECT_ROOT/bin/manager\" " > home/.ssh/authorized_keys
cat home/.ssh/id_rsa.pub >> home/.ssh/authorized_keys
chown -R revdev:revdev home/.ssh
cp home/.ssh/id_rsa www/key
chmod 644 www/key
cat > /etc/sudoers.d/revdev << EOF
Cmnd_Alias     NETSTAT = /bin/netstat -tnlp
Cmnd_Alias     RELOAD_NGINX = /etc/init.d/nginx reload
revdev  ALL=NOPASSWD: NETSTAT, RELOAD_NGINX
EOF
chmod 440 /etc/sudoers.d/revdev

# install/configure nginx
apt-get install --assume-yes nginx-full
mkdir -p nginx/conf.d
chown revdev:revdev nginx/conf.d
mkdir -p nginx/log
chown www-data nginx/log
patch_config_file "DAEMON_OPTS=\"-c $PROJECT_ROOT/nginx/nginx.conf\"" /etc/default/nginx
SERVER_BODY=$(cat << EOF
        root $PROJECT_ROOT/www/;
        index   index.html  index.php;
        access_log /var/log/nginx/access.log;
        server_name  revdev;
        location /key {
            auth_basic revdev;
            auth_basic_user_file $PROJECT_ROOT/nginx/htpasswd;
        }
EOF
)
if [ -d ssl ]; then
    OPTIONAL_SSL_INCLUDE="include $PROJECT_ROOT/ssl/nginx.conf;"
    cat > ssl/nginx.conf << EOF
    ssl_certificate      $PROJECT_ROOT/ssl/certificate.crt;
    ssl_certificate_key  $PROJECT_ROOT/ssl/key.key;

    server {
        listen       443 ssl;
        ssl on;
        $SERVER_BODY
    }
EOF
fi
cat > nginx/nginx.conf << EOF
error_log /var/log/nginx/error.log;
user www-data;
worker_processes 4;
pid /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;

    server {
        listen       8000 default_server;
        listen       80;
        $SERVER_BODY
    }

    $OPTIONAL_SSL_INCLUDE
    include $PROJECT_ROOT/nginx/conf.d/*;
}

EOF
echo ${REVDEV_KEY_USERNAME:-revdev}:$(openssl passwd -crypt ${REVDEV_KEY_PASSWORD:-secret}) > nginx/htpasswd
/etc/init.d/nginx start

# configure sshd for great justice
patch_config_file "UseDNS no" /etc/ssh/sshd_config
patch_config_file "ClientAliveInterval 3" /etc/ssh/sshd_config
service ssh reload

set +ex
cat << EOF




REVDEV INSTALLED SUCCESSFULLY (at least, I think).

Assuming you'd like this revdev server to be called revdev.mydomain.com, that its IP is 1.2.3.4 and that you'd like your development machine to be accessible at mylaptop.revdev.mydomain.com, you will need to do the following:

1. Make sure these DNS records are in place:
    revdev    IN  A      1.2.3.4
    *.revdev  IN  CNAME  revdev.mydomain.com.

2. Run the following commands on your laptop:
    wget http://revdev:secret@revdev.mydomin.com/key -O ~/.ssh/revdev_rsa
    chmod 600 ~/.ssh/revdev_rsa
    ssh -i ~/.ssh/revdev_rsa -R localhost:0:localhost:8000 revdev@revdev.mydomain.com mylaptop

3. Open a browser and direct it to http://mylaptop.revdev.mydomain.com. You're done!

Comments? Questions? Head over to https://github.com/yaniv-aknin/revdev and be social :)

EOF
