#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

# Update Package List
apt-get update

# Update System Packages
apt-get -y upgrade

# Force Locale
echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8

# Set My Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Setup some SSH Options
sed -i "s/PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config

# Restart ssh service
/etc/init.d/ssh restart

# Install Some PPAs
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C
apt-add-repository ppa:nginx/stable -y
apt-add-repository ppa:ondrej/php -y
curl --silent --location https://deb.nodesource.com/setup_7.x | bash -

# Update Package Lists
apt-get update

# Install Some Basic Packages
apt-get install -y build-essential gcc libmcrypt4 \
libpcre3-dev ntp unzip make python2.7-dev python-pip whois \
php7.1-cli php7.1-dev php7.1-pgsql php7.1-sqlite3 php7.1-gd \
php7.1-curl php7.1-memcached php7.1-imap php7.1-mysql php7.1-mbstring \
php7.1-xml php7.1-zip php7.1-bcmath php7.1-soap php7.1-intl php7.1-readline \
php7.1-fpm nginx sqlite3 nodejs wkhtmltopdf

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

# Hide nginx server version
 sed -i "s/# server_tokens off;/server_tokens off;/" /etc/nginx/nginx.conf
 
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

# Set The Nginx & PHP-FPM User
sed -i "s/user www-data;/user rinvex;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf

sed -i "s/user = www-data/user = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf

sed -i "s/listen\.owner.*/listen.owner = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf
sed -i "s/listen\.group.*/listen.group = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.1/fpm/pool.d/www.conf

# Restart nginx service
/etc/init.d/nginx restart

# Generate Strong Diffie-Hellman Group
openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Create global nginx hooks folders
mkdir /etc/nginx/rinvex-conf/global/before -p 2>/dev/null
mkdir /etc/nginx/rinvex-conf/global/server -p 2>/dev/null
mkdir /etc/nginx/rinvex-conf/global/after -p 2>/dev/null

# Add letsencrypt cronjob
sudo su rinvex <<'EOF'
crontab -l | { cat; echo "0 */12 * * * certbot-auto renew --agree-tos --quiet"; } | crontab -
EOF

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
