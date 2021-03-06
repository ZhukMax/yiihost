#!/bin/bash

# Keys for script
while [ 1 ] ; do 
   if [ "$1" = "--blank" ] ; then 
      PROJECT="b" 
   elif [ "$1" = "-b" ] ; then 
      PROJECT="b"
   elif [ "$1" = "--new" ] ; then 
      PROJECT="n" 
   elif [ "$1" = "-n" ] ; then 
      PROJECT="n"
   elif [ "$1" = "--exists" ] ; then 
      PROJECT="x" 
   elif [ "$1" = "-x" ] ; then 
      PROJECT="x"
   elif [ -z "$1" ] ; then 
      break
   else 
      echo "Error: unknown key" 1>&2 
      exit 1 
   fi 
   shift 
done

echo "Enter username for site:"
read USERNAME

echo "Enter domain"
read DOMAIN

if [ -z "$PROJECT" ] ; then
	read -n 1 -p "blank ([b]), new (n) or exists (x) project? " PROJECT
fi

if [ $PROJECT == n ] || [$PROJECT == new]
then
	cd /var/www
	composer global require "fxp/composer-asset-plugin:^1.2.0"
	composer create-project --prefer-dist yiisoft/yii2-app-basic $USERNAME
	chmod -R 777 /var/www/$USERNAME/runtime/
	chmod -R 777 /var/www/$USERNAME/web/assets/
elif [ $PROJECT == x ] || [$PROJECT == exists]
then
	cd /var/www/
	echo "Enter url to your git-repository:"
	read REPO
	git clone $REPO
	cd ~
elif [ $PROJECT == b ] || [$PROJECT == blank]
then
	cd /var/www
	mkdir /var/www/$USERNAME
fi

mkdir /var/www/$USERNAME/tmp
mkdir /var/www/$USERNAME/logs
chmod -R 755 /var/www/$USERNAME/
chown www-data:www-data /var/www/$USERNAME

echo "Creating vhost file"
echo "
server {
    charset utf-8;
    client_max_body_size 128M;

    listen 80;

    server_name $DOMAIN www.$DOMAIN;
    root        /var/www/$USERNAME/web;
    index       index.php;

    access_log  /var/www/$USERNAME/logs/access.log;
    error_log   /var/www/$USERNAME/logs/error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar)\$ {
        try_files \$uri =404;
    }
    error_page 404 /404.html;

    location ~ \.php\$ {
        include fastcgi.conf;
        fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
    }

    location ~ /\.(ht|svn|git) {
        deny all;
    }
}
" > /etc/nginx/sites-available/$USERNAME.conf
ln -s /etc/nginx/sites-available/$USERNAME.conf /etc/nginx/sites-enabled/$USERNAME.conf

service nginx restart
service php7.0-fpm restart

echo "MySQL[1] or PostgreSQL[2]"
echo "(default 1):"
read DBVERS

echo "Enter DataBase root password:"
read -s ROOTPASS

echo "Enter password for new DB:"
read -s SQLPASS

echo "Creating database"

Q1="CREATE DATABASE IF NOT EXISTS $USERNAME DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;;"
Q2="GRANT ALTER,DELETE,DROP,CREATE,INDEX,INSERT,SELECT,UPDATE,CREATE TEMPORARY TABLES,LOCK TABLES ON $USERNAME.* TO '$USERNAME'@'localhost' IDENTIFIED BY '$SQLPASS';"
Q3="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}"

if [[ $DBVERS = 2 ]]
then
	psql -username=root --password=$ROOTPASS -e "$SQL"
else
	mysql -uroot --password=$ROOTPASS -e "$SQL"
fi
