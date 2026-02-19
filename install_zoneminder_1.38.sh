#!/bin/bash
echo "This script installs LAMP + ZoneMinder 1.38.x on Debian 13 , Ubuntu 24.04 ( and probably newer versions but not tested ) and Linux Mint "

if ((UID)); then
  echo "This script must be run as root! Use « sudo ./$0 » or « sudo bash $0 »."
  exit 0
fi

apt update || exit 0 # quit if update isn't working

# detect installed OS
test -f /etc/issue.net && os=$(cut -d " " -f1  /etc/issue.net) || exit 1
test -f /usr/lib/os-release && . /usr/lib/os-release || exit 1 # $ID , $NAME , $VERSION_CODENAME"

# veryfi and install if necessary , packages listed below :
packages2install=("software-properties-common" "apache2" "mariadb-server" "php" "libapache2-mod-php" "php-mysql" "lsb-release" "gnupg2")
for p in "${packages2install[@]}"; do
	if ! dpkg-query -l "$p" | grep -q "^[hi]i"; then
		if test "$p" = "mariadb-server" &&  dpkg-query -l "mysql-server" | grep -q "^[hi]i"; then
    	echo "mysql-server is already installed , mariadb-server will not be installed !"
    	continue
    else
    	apt-get install -qq "$p"
    fi
  fi
done

# it is better to not modify the php.ini file ( modification will be erased when php will be upgrade )
# but if we create a new file in directory /etc/php/*/apache2/conf.d/zoneminder.custom.ini for each version of apache , no problem , so :
for d in /etc/php/*; do
	echo "[Date]" | tee "$d"/apache2/conf.d/zoneminder.custom.ini
	echo "date.timezone = $(</etc/timezone)" | tee -a "$d"/apache2/conf.d/zoneminder.custom.ini
done

# delete all sources referencing zoneminder :
rm /etc/apt/sources.list.d/*zoneminder*
apt clean && apt update && apt full-upgrade -y && apt autopurge -y

# do  what you need in your OS :
case "$os" in

	Debian|LMDE)
		if test -f /etc/apt/trusted.gpg.d/zmrepo.gpg; then
			rm /etc/apt/trusted.gpg.d/zmrepo.gpg
		fi
		if ! wget -O- https://zmrepo.zoneminder.com/debian/archive-keyring.gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/zmrepo.gpg; then
			echo "error to retrieve key!"
			exit 2
		fi
		# echo "deb https://zmrepo.zoneminder.com/debian/release-1.38 $VERSION_CODENAME/" | sudo tee /etc/apt/sources.list.d/zoneminder.list
		echo "deb https://zmrepo.zoneminder.com/debian/master $VERSION_CODENAME/" | sudo tee /etc/apt/sources.list.d/zoneminder.list
		apt update
	;;

	Ubuntu|Linux)
		add-apt-repository -y ppa:iconnor/zoneminder-1.38
	;;

	*)
	;;
esac

apt-get install -qq zoneminder

# configuring apache2 on start :
systemctl enable apache2
systemctl start apache2
a2enmod cgi rewrite headers expires
systemctl restart apache2

# configuring zoneminder
chmod 640 /etc/zm/zm.conf
chown root:www-data /etc/zm/zm.conf
adduser www-data video
a2enconf zoneminder

systemctl restart apache2

# configuring mariadb / mysql server DB :
mysql --defaults-file=/etc/mysql/debian.cnf -p < /usr/share/zoneminder/db/zm_create.sql
mysql --defaults-file=/etc/mysql/debian.cnf -p -e "grant lock tables,alter,drop,select,insert,update,delete,create,index,alter routine,create routine, trigger,execute,references on zm.* to 'zmuser'@localhost identified by 'zmpass';"

systemctl enable zoneminder
systemctl start zoneminder
systemctl daemon-reload # necessary when upgrading

echo
echo "Install complete. Please follow instructions in starter guide : https://zoneminder.readthedocs.io/en/latest/userguide/gettingstarted.html"
