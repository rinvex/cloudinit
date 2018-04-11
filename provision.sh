#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive

# Update Package List
apt-get update

# Update System Packages
apt-get -y dist-upgrade

# Force Locale
echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8
export LANG=en_US.UTF-8

# Set My Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Setup some SSH Options
sed -i "s/PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config

# Restart ssh service
/etc/init.d/ssh restart

# Install Some PPAs
apt-add-repository ppa:ondrej/php -y
apt-add-repository ppa:nginx/stable -y
curl --silent --location https://deb.nodesource.com/setup_9.x | sudo -E bash -

# Update Package Lists
apt-get update

# Install Some Basic Packages
apt-get install -y build-essential libpcre3-dev python2.7-dev ntp python-pip whois gcc supervisor \
nginx sqlite3 nodejs wkhtmltopdf libmcrypt4 unzip make jpegoptim optipng pngquant gifsicle \
php7.2-cli php7.2-dev php7.2-pgsql php7.2-sqlite3 php7.2-gd php7.2-fpm php7.2-xml \
php7.2-curl php7.2-memcached php7.2-imap php7.2-mysql php7.2-mbstring \
php7.2-zip php7.2-bcmath php7.2-soap php7.2-intl php7.2-readline \
php7.2-redis mysql-server redis-server unattended-upgrades \
mosquitto mosquitto-clients libmosquitto-dev

# Install PHP-Mosquitto
pecl install Mosquitto-alpha

cat > /etc/php/7.2/mods-available/mosquitto.ini << EOF
; configuration for php common module
; priority=10
extension=mosquitto.so
EOF

ln -s /etc/php/7.2/mods-available/mosquitto.ini /etc/php/7.2/cli/conf.d/20-mosquitto.ini
ln -s /etc/php/7.2/mods-available/mosquitto.ini /etc/php/7.2/fpm/conf.d/20-mosquitto.ini

# Install svgo npm package
npm install -g svgo

# Install Composer
curl -sS https://getcomposer.org/installer | HOME="/home/rinvex" php -- --install-dir=/usr/local/bin --filename=composer
chown rinvex:rinvex /home/rinvex/.composer -R
chmod 775 /home/rinvex/.composer

# Add Composer Global Bin To Path
printf "\nPATH=\"/home/rinvex/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/rinvex/.profile

# Install Laravel Envoy & Installer
sudo su rinvex <<'EOF'
/usr/local/bin/composer global require "laravel/envoy=~1.0"
/usr/local/bin/composer global require "laravel/installer=~1.1"
EOF

# Install PHPMyAdmin
git clone --depth=1 --branch=STABLE https://github.com/phpmyadmin/phpmyadmin.git
cd phpmyadmin && composer install

# Remove default nginx host
rm -rvf /etc/nginx/sites-enabled/default
rm -rvf /etc/nginx/sites-available/default

# Set Some PHP CLI Settings
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.2/cli/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.2/cli/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.2/cli/php.ini
sed -i "s/;date.timezone = .*/date.timezone = UTC/" /etc/php/7.2/cli/php.ini

# Set Some PHP-FPM Options
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.2/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.2/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.2/fpm/php.ini
sed -i "s/;date.timezone = .*/date.timezone = UTC/" /etc/php/7.2/fpm/php.ini

# Optimize OPcache for production
sed -i "s/;opcache.enable=.*/opcache.enable=1/" /etc/php/7.2/fpm/php.ini
sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=512/" /etc/php/7.2/fpm/php.ini
sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=30000/" /etc/php/7.2/fpm/php.ini
sed -i "s/;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/" /etc/php/7.2/fpm/php.ini
sed -i "s/;opcache.save_comments=.*/opcache.save_comments=1/" /etc/php/7.2/fpm/php.ini

# Replace default nginx config with optimized one
rm -rvf /etc/nginx/nginx.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/rinvex/nginx/nginx.conf -O /etc/nginx/nginx.conf

# Download nginx snippets
wget https://raw.githubusercontent.com/rinvex/cloudinit/rinvex/nginx/snippets/headers.conf -O /etc/nginx/snippets/headers.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/rinvex/nginx/snippets/expires.conf -O /etc/nginx/snippets/expires.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/rinvex/nginx/snippets/fastcgi_params.conf -O /etc/nginx/snippets/fastcgi_params.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/rinvex/nginx/snippets/cross-domain-fonts.conf -O /etc/nginx/snippets/cross-domain-fonts.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/rinvex/nginx/snippets/protect-system-files.conf -O /etc/nginx/snippets/protect-system-files.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/rinvex/nginx/snippets/cross-domain-insecure.conf -O /etc/nginx/snippets/cross-domain-insecure.conf

# Download nginx default sites
wget https://raw.githubusercontent.com/rinvex/cloudinit/rinvex/nginx/sites-available/no-default.conf -O /etc/nginx/sites-available/no-default.conf

# Enable default nginx sites
ln -fs "/etc/nginx/sites-available/no-default.conf" "/etc/nginx/sites-enabled/no-default.conf"

# Set The PHP-FPM User
sed -i "s/user = www-data/user = rinvex/" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = rinvex/" /etc/php/7.2/fpm/pool.d/www.conf

sed -i "s/listen\.owner.*/listen.owner = rinvex/" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/listen\.group.*/listen.group = rinvex/" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.2/fpm/pool.d/www.conf

# Add User To WWW-Data
usermod -a -G www-data rinvex
id rinvex
groups rinvex

# Restart nginx and php7.2-fpm services
/etc/init.d/nginx restart
/etc/init.d/php7.2-fpm restart

# Clean Up
apt-get -y autoremove
apt-get -y clean
