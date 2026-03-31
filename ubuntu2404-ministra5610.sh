#!/bin/bash

set -e

echo "[+] Updating system"
apt update && apt upgrade -y
apt install -y net-tools software-properties-common curl unzip git

VERSION="5.6.10"
TIME_ZONE="Europe/Amsterdam"
MYSQL_ROOT_PASSWORD="t538y7gbGYAGA1-hfa_)654!aae"
REPOSITORY="https://portal.novyte.nl/"

# Locale
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# System tweaks
cat <<EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
fs.file-max = 327680
EOF
sysctl -p

# PHP 8.3 (default in 24.04)
add-apt-repository ppa:ondrej/php -y
apt update

# Web stack
apt install -y nginx apache2
systemctl stop nginx apache2

# PHP 8.3 + modules (updated equivalents)
apt install -y php8.3 php8.3-cli php8.3-fpm php8.3-mysql php8.3-curl php8.3-xml php8.3-mbstring php8.3-zip php8.3-intl php8.3-soap php8.3-gd php8.3-sqlite3 php8.3-bcmath php8.3-imagick php8.3-redis php-pear memcached php8.3-memcached

update-alternatives --set php /usr/bin/php8.3

# Phing (modern install via composer instead of pear)
apt install -y composer
composer global require phing/phing
ln -s ~/.config/composer/vendor/bin/phing /usr/local/bin/phing || true

# Node.js (modern LTS instead of ancient npm 2.x)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Timezone
timedatectl set-timezone $TIME_ZONE

# MySQL (now MariaDB in Ubuntu 24.04)
apt install -y mariadb-server
systemctl enable mariadb
systemctl start mariadb

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"

mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE stalker_db;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE USER 'stalker'@'%' IDENTIFIED BY 'ChangeMe123';"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'stalker'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"

# Allow remote connections
sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mariadb

# Install Ministra
cd /var/www/html
wget $REPOSITORY/ministra-$VERSION.zip
unzip ministra-$VERSION.zip
rm ministra-$VERSION.zip

# Apache config
a2enmod rewrite
systemctl restart apache2

# Permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# NPM fix
mkdir -p /var/www/.npm
chmod 777 /var/www/.npm

# Basic config fetch
cd /var/www/html/stalker_portal/server || true
wget -O custom.ini $REPOSITORY/custom.ini || true

# Build (if needed)
cd /var/www/html/stalker_portal/deploy || true
phing || true

IP=$(hostname -I | awk '{print $1}')

echo "-------------------------------------------"
echo "Install complete"
echo "Portal: http://$IP/stalker_portal"
echo "MySQL root password: $MYSQL_ROOT_PASSWORD"
echo "-------------------------------------------"
