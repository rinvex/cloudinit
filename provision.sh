#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive

# Software Versions
PHP='7.2'
#ENV PHP_VERSION 7.2.9

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
curl --silent --location https://deb.nodesource.com/setup_10.x | sudo -E bash -

# Update Package Lists
apt-get update

# Install Some Basic Packages
apt-get install --no-install-recommends --no-install-suggests -y make curl \
locales build-essential libpcre3-dev python2.7-dev ntp python-pip whois gcc supervisor nginx \
sqlite3 nodejs wkhtmltopdf libmcrypt4 zip unzip git jpegoptim optipng pngquant gifsicle \
php${PHP}-cli php${PHP}-dev php${PHP}-pgsql php${PHP}-sqlite3 php${PHP}-gd php${PHP}-fpm php${PHP}-xml \
php${PHP}-curl php${PHP}-memcached php${PHP}-imap php${PHP}-mysql php${PHP}-mbstring php-pear  \
php${PHP}-zip php${PHP}-bcmath php${PHP}-soap php${PHP}-intl php${PHP}-readline \
php${PHP}-redis mysql-server redis-server unattended-upgrades

pecl channel-update pecl.php.net

# Install svgo npm package
npm install -g svgo

# Install Composer
echo "Install Composer"
curl -sS https://getcomposer.org/installer | HOME="/home/rinvex" php -- --install-dir=/usr/local/bin --filename=composer
chown rinvex:rinvex /home/rinvex/.composer -R
chmod 775 /home/rinvex/.composer
echo "End Install Composer"

# Add Composer Global Bin To Path
printf "\nexport PATH=\"/home/rinvex/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/rinvex/.bashrc

# Install Laravel Envoy & Installer
sudo su rinvex <<'EOF'
/usr/local/bin/composer global require "laravel/envoy=~1.0"
/usr/local/bin/composer global require "laravel/installer=~1.1"
EOF

# Remove default nginx host
rm -rvf /etc/nginx/sites-enabled/default
rm -rvf /etc/nginx/sites-available/default

# Set Some PHP CLI Settings
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/${PHP}/cli/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/${PHP}/cli/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/${PHP}/cli/php.ini
sed -i "s/;date.timezone = .*/date.timezone = UTC/" /etc/php/${PHP}/cli/php.ini

# Set Some PHP-FPM Options
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/${PHP}/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/${PHP}/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/${PHP}/fpm/php.ini
sed -i "s/;date.timezone = .*/date.timezone = UTC/" /etc/php/${PHP}/fpm/php.ini

# Optimize OPcache for production
sed -i "s/;opcache.enable=.*/opcache.enable=1/" /etc/php/${PHP}/fpm/php.ini
sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=512/" /etc/php/${PHP}/fpm/php.ini
sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=30000/" /etc/php/${PHP}/fpm/php.ini
sed -i "s/;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/" /etc/php/${PHP}/fpm/php.ini
sed -i "s/;opcache.save_comments=.*/opcache.save_comments=1/" /etc/php/${PHP}/fpm/php.ini

# Replace default nginx config with optimized one
rm -rvf /etc/nginx/nginx.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/nginx/nginx.conf -O /etc/nginx/nginx.conf

# Download nginx snippets
wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/nginx/snippets/headers.conf -O /etc/nginx/snippets/headers.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/nginx/snippets/expires.conf -O /etc/nginx/snippets/expires.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/nginx/snippets/fastcgi_params.conf -O /etc/nginx/snippets/fastcgi_params.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/nginx/snippets/cross-domain-fonts.conf -O /etc/nginx/snippets/cross-domain-fonts.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/nginx/snippets/protect-system-files.conf -O /etc/nginx/snippets/protect-system-files.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/nginx/snippets/cross-domain-insecure.conf -O /etc/nginx/snippets/cross-domain-insecure.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/nginx/snippets/ssl-stapling.conf -O /etc/nginx/snippets/ssl-stapling.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/nginx/snippets/ssl.conf -O /etc/nginx/snippets/ssl.conf

# Download nginx default sites
wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/nginx/sites-available/no-default.conf -O /etc/nginx/sites-available/no-default.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/sites-available/ssl.no-default.conf -O /etc/nginx/sites-available/ssl.no-default.conf

# Enable default nginx sites
ln -fs "/etc/nginx/sites-available/no-default.conf" "/etc/nginx/sites-enabled/no-default.conf"
ln -fs "/etc/nginx/sites-available/ssl.no-default.conf" "/etc/nginx/sites-enabled/ssl.no-default.conf"

# Set The PHP-FPM User
sed -i "s/user = www-data/user = rinvex/" /etc/php/${PHP}/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = rinvex/" /etc/php/${PHP}/fpm/pool.d/www.conf

sed -i "s/listen\.owner.*/listen.owner = rinvex/" /etc/php/${PHP}/fpm/pool.d/www.conf
sed -i "s/listen\.group.*/listen.group = rinvex/" /etc/php/${PHP}/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/${PHP}/fpm/pool.d/www.conf

# Add User To WWW-Data
usermod -a -G www-data rinvex
id rinvex
groups rinvex

# Generate Strong Diffie-Hellman Group
openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Generate default ssl certificate
gssl $(curl http://169.254.169.254/latest/meta-data/public-ipv4 -s) default

# Add letsencrypt renewal and composer self-update cronjobs
sudo su <<'EOF'
crontab -l | { cat; echo "0 0 * * * \"/.acme.sh\"/acme.sh --cron --home \"/.acme.sh\" > /dev/null"; } | crontab -
crontab -l | { cat; echo "0 0 * * * /usr/local/bin/composer self-update >> /var/log/composer.log 2>&1"; } | crontab -
EOF

# Install letsencrypt client
git clone https://github.com/Neilpang/acme.sh.git /root/acme.sh
cd /root/acme.sh && ./acme.sh --install --accountemail 'aomran@rinvex.com'

# Add acme.sh To Path
printf "\nexport PATH=\"/.acme.sh:\$PATH\"\n" | tee -a /root/.bashrc

# Restart nginx and php${PHP}-fpm services
/etc/init.d/nginx restart
/etc/init.d/php${PHP}-fpm restart

# Clean Up
apt-get -y autoremove
apt-get -y clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
