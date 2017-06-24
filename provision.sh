#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive

# Update Package List
apt-get update

# Update System Packages
apt-get -y upgrade

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
curl --silent --location https://deb.nodesource.com/setup_7.x | bash -

# Update Package Lists
apt-get update

# Install Some Basic Packages
apt-get install -y build-essential libpcre3-dev python2.7-dev ntp \
python-pip whois nginx sqlite3 nodejs wkhtmltopdf gcc libmcrypt4 unzip make \
php7.1-cli php7.1-dev php7.1-pgsql php7.1-sqlite3 php7.1-gd php7.1-fpm php7.1-xml \
php7.1-curl php7.1-memcached php7.1-imap php7.1-mysql php7.1-mbstring \
php7.1-zip php7.1-bcmath php7.1-soap php7.1-intl php7.1-readline \

# Install certbot
echo "Installing Certbot..."
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/certbot-auto -O /usr/local/bin/certbot-auto
chmod a+x /usr/local/bin/certbot-auto
certbot-auto --os-packages-only --quiet

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
 
# Remove default nginx host
rm -rvf /etc/nginx/sites-enabled/default
rm -rvf /etc/nginx/sites-available/default

# Set Some PHP CLI Settings
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.1/cli/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.1/cli/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.1/cli/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.1/cli/php.ini

# Set Some PHP-FPM Options
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.1/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.1/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.1/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.1/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.1/fpm/php.ini

# Copy fastcgi_params to Nginx because they broke it on the PPA
cat > /etc/nginx/fastcgi_params << EOF
fastcgi_param    QUERY_STRING        \$query_string;
fastcgi_param    REQUEST_METHOD      \$request_method;
fastcgi_param    CONTENT_TYPE        \$content_type;
fastcgi_param    CONTENT_LENGTH      \$content_length;
fastcgi_param    SCRIPT_FILENAME     \$request_filename;
fastcgi_param    SCRIPT_NAME         \$fastcgi_script_name;
fastcgi_param    REQUEST_URI         \$request_uri;
fastcgi_param    DOCUMENT_URI        \$document_uri;
fastcgi_param    DOCUMENT_ROOT       \$document_root;
fastcgi_param    SERVER_PROTOCOL     \$server_protocol;
fastcgi_param    GATEWAY_INTERFACE   CGI/1.1;
fastcgi_param    SERVER_SOFTWARE     nginx/\$nginx_version;
fastcgi_param    REMOTE_ADDR         \$remote_addr;
fastcgi_param    REMOTE_PORT         \$remote_port;
fastcgi_param    SERVER_ADDR         \$server_addr;
fastcgi_param    SERVER_PORT         \$server_port;
fastcgi_param    SERVER_NAME         \$server_name;
fastcgi_param    HTTPS               \$https if_not_empty;
fastcgi_param    REDIRECT_STATUS     200;
EOF

# Replace default nginx config with optimized one
rm -rvf /etc/nginx/nginx.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/nginx.conf -O /etc/nginx/nginx.conf

# Download nginx snippets
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/snippets/ssl.conf -O /etc/nginx/snippets/ssl.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/snippets/headers.conf -O /etc/nginx/snippets/headers.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/snippets/expires.conf -O /etc/nginx/snippets/expires.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/snippets/ssl-stapling.conf -O /etc/nginx/snippets/ssl-stapling.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/snippets/cross-domain-fonts.conf -O /etc/nginx/snippets/cross-domain-fonts.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/snippets/protect-system-files.conf -O /etc/nginx/snippets/protect-system-files.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/snippets/cross-domain-insecure.conf -O /etc/nginx/snippets/cross-domain-insecure.conf

# Download nginx default sites
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/sites-available/no-default.conf -O /etc/nginx/sites-available/no-default.conf
wget https://raw.githubusercontent.com/rinvex/cloudinit/master/nginx/sites-available/ssl.no-default.conf -O /etc/nginx/sites-available/ssl.no-default.conf

# Enable default nginx sites
ln -fs "/etc/nginx/sites-available/no-default.conf" "/etc/nginx/sites-enabled/no-default.conf"
ln -fs "/etc/nginx/sites-available/ssl.no-default.conf" "/etc/nginx/sites-enabled/ssl.no-default.conf"

# Set The PHP-FPM User
sed -i "s/user = www-data/user = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf

sed -i "s/listen\.owner.*/listen.owner = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf
sed -i "s/listen\.group.*/listen.group = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.1/fpm/pool.d/www.conf

# Generate Strong Diffie-Hellman Group
openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Generate default ssl certificate
gssl $(curl http://169.254.169.254/latest/meta-data/public-ipv4 -s) default

# Restart nginx service
/etc/init.d/nginx restart

# Add letsencrypt renewal and composer self-update cronjobs
sudo su <<'EOF'
crontab -l | { cat; echo "0 */12 * * * certbot-auto renew --pre-hook \"sudo /etc/init.d/nginx stop\" --post-hook \"sudo /etc/init.d/nginx start\" --agree-tos --quiet"; } | crontab -
crontab -l | { cat; echo "0 0 * * * /usr/local/bin/composer self-update >> /var/log/composer.log 2>&1"; } | crontab -
EOF

# Add toran proxy cronjob as rinvex user
# sudo su rinvex <<'EOF'
# crontab -l | { cat; echo "0 * * * * cd /home/rinvex/toran.domain.com && php bin/cron >> bin/cron.log"; } | crontab -
# EOF

# Restart nginx and php7.1-fpm services
/etc/init.d/nginx restart
/etc/init.d/php7.1-fpm restart

# Add User To WWW-Data
usermod -a -G www-data rinvex
id rinvex
groups rinvex

# Clean Up
apt-get -y autoremove
apt-get -y clean
