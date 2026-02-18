#!/bin/bash
clear
echo "This script installs LAMP + ZoneMinder 1.38.x on Debian 13 , Ubuntu 24.04 ( and probably newer versions but not tested ) and Linux Mint "

if ((UID)); then
  echo "This script must be run as root! Use « sudo ./$0 » or « sudo bash $0 »."
  exit 0
fi

# detect installed OS
os="$(grep -E ^ID= /usr/lib/os-release | cut -d '=' -f2)"

apt update || exit 0 # quit if update isn't working
apt autopurge -y

# veryfi and install if necessary , packages listed below :
packages2install=("software-properties-common" "apache2" "mariadb-server" "php" "libapache2-mod-php" "php-mysql" "lsb-release" "gnupg2")
for p in "${packages2install[@]}"; do
	if ! dpkg-query -f '${binary:Package}\n' -W "$p" &>/dev/null; then
    apt-get install -qq "$p"
  fi
done

#sed -Ei 's@[;](date\.timezone =).*@\1 '"$(<\/etc\/timezone)"'@' /etc/php/*/apache2/php.ini
# it is better to not modify the php.ini file ( modification will be erased when php will be upgrade )
# but if we create a new file in directory /etc/php/*/apache2/conf.d/zoneminder.custom.ini for each version of apache , no problem , so :
for d in /etc/php/*; do
	echo "[Date]" | tee "$d"/apache2/conf.d/zoneminder.custom.ini
	echo "date.timezone = $(</etc/timezone)" | tee -a "$d"/apache2/conf.d/zoneminder.custom.ini
done

#Activating apache2 on start :
mkdir /var/log/apache2
systemctl enable apache2
systemctl start apache2

# configuring mariadb / mysql server DB :
sudo mysql --defaults-file=/etc/mysql/debian.cnf -p < /usr/share/zoneminder/db/zm_create.sql
sudo mysql --defaults-file=/etc/mysql/debian.cnf -p -e "grant lock tables,alter,drop,select,insert,update,delete,create,index,alter routine,create routine, trigger,execute,references on zm.* to 'zmuser'@localhost identified by 'zmpass';"

# delete all sources referencing zoneminder :
rm /etc/apt/sources.list.d/*zoneminder*
apt clean
# upgrade packages :
apt update
apt full-upgrade -y

# do  what you need in your OS :
case "$os" in

	debian)
		if test -f /etc/apt/trusted.gpg.d/zmrepo.gpg; then
			rm /etc/apt/trusted.gpg.d/zmrepo.gpg
		fi
		if ! wget -O- https://zmrepo.zoneminder.com/debian/archive-keyring.gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/zmrepo.gpg; then
			echo "error to retrieve key!"
			exit 0
		fi
		echo "deb https://zmrepo.zoneminder.com/debian/master $(lsb_release  -c -s)/" | sudo tee /etc/apt/sources.list.d/zoneminder.list
		apt update		
		apt install -y zoneminder
	;;

	ubuntu|linuxmint)
		add-apt-repository -y ppa:iconnor/zoneminder-1.38
		apt install -y zoneminder
	;;

	*)
	;;
esac

# configuration APACHE / PHP / zoneminder
chmod 640 /etc/zm/zm.conf
chown root:www-data /etc/zm/zm.conf
systemctl enable zoneminder
service zoneminder start
adduser www-data video
a2enconf zoneminder
a2enmod rewrite headers expires
service apache2 reload
#systemctl reload apache2

echo
echo "Install complete. follow instructions in starter guide : https://zoneminder.readthedocs.io/en/latest/userguide/gettingstarted.html"

Sleep 10
xdg-open http://localhost/zm
