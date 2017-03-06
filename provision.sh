#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

# Update Package List

apt-get update

# Update System Packages
apt-get -y upgrade

# Force Locale

echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8

# Setup some SSH Options

sed -i "s/PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config

# Restart ssh service
/etc/init.d/ssh restart

# Install Some PPAs

apt-get install -y software-properties-common curl

apt-add-repository ppa:nginx/stable -y
apt-add-repository ppa:ondrej/php -y

curl --silent --location https://deb.nodesource.com/setup_7.x | bash -

# Update Package Lists

apt-get update

# Install Some Basic Packages

apt-get install -y build-essential gcc git libmcrypt4 libpcre3-dev ntp unzip \
make python2.7-dev python-pip unattended-upgrades whois vim letsencrypt

# Set My Timezone

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Install PHP Stuffs

apt-get install -y --force-yes php7.1-cli php7.1-dev \
php7.1-pgsql php7.1-sqlite3 php7.1-gd \
php7.1-curl php7.1-memcached \
php7.1-imap php7.1-mysql php7.1-mbstring \
php7.1-xml php7.1-zip php7.1-bcmath php7.1-soap \
php7.1-intl php7.1-readline

# Install Composer

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Add Composer Global Bin To Path

printf "\nPATH=\"$(sudo su - rinvex -c 'composer config -g home 2>/dev/null')/vendor/bin:\$PATH\"\n" | tee -a /home/rinvex/.profile

# Install Laravel Envoy & Installer

sudo su rinvex <<'EOF'
/usr/local/bin/composer global require "laravel/envoy=~1.0"
/usr/local/bin/composer global require "laravel/installer=~1.1"
EOF

# Set Some PHP CLI Settings

sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.1/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.1/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.1/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.1/cli/php.ini

# Install Nginx & PHP-FPM

apt-get install -y --force-yes nginx php7.1-fpm

rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default

# Restart nginx service
/etc/init.d/nginx restart

# Setup Some PHP-FPM Options

sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.1/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.1/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.1/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.1/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.1/fpm/php.ini

# Copy fastcgi_params to Nginx because they broke it on the PPA

cat > /etc/nginx/fastcgi_params << EOF
fastcgi_param    QUERY_STRING        \$query_string;
fastcgi_param    REQUEST_METHOD        \$request_method;
fastcgi_param    CONTENT_TYPE        \$content_type;
fastcgi_param    CONTENT_LENGTH        \$content_length;
fastcgi_param    SCRIPT_FILENAME        \$request_filename;
fastcgi_param    SCRIPT_NAME        \$fastcgi_script_name;
fastcgi_param    REQUEST_URI        \$request_uri;
fastcgi_param    DOCUMENT_URI        \$document_uri;
fastcgi_param    DOCUMENT_ROOT        \$document_root;
fastcgi_param    SERVER_PROTOCOL        \$server_protocol;
fastcgi_param    GATEWAY_INTERFACE    CGI/1.1;
fastcgi_param    SERVER_SOFTWARE        nginx/\$nginx_version;
fastcgi_param    REMOTE_ADDR        \$remote_addr;
fastcgi_param    REMOTE_PORT        \$remote_port;
fastcgi_param    SERVER_ADDR        \$server_addr;
fastcgi_param    SERVER_PORT        \$server_port;
fastcgi_param    SERVER_NAME        \$server_name;
fastcgi_param    HTTPS            \$https if_not_empty;
fastcgi_param    REDIRECT_STATUS        200;
EOF

# Set The Nginx & PHP-FPM User

sed -i "s/user www-data;/user rinvex;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf

sed -i "s/user = www-data/user = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf

sed -i "s/listen\.owner.*/listen.owner = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf
sed -i "s/listen\.group.*/listen.group = rinvex/" /etc/php/7.1/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.1/fpm/pool.d/www.conf

# Generate Strong Diffie-Hellman Group
openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Create global nginx hooks folders
mkdir /etc/nginx/rinvex-conf/global/before -p 2>/dev/null
mkdir /etc/nginx/rinvex-conf/global/server -p 2>/dev/null
mkdir /etc/nginx/rinvex-conf/global/after -p 2>/dev/null

# Prepare letsencrypt stuff
mkdir /home/rinvex/.letsencrypt && chmod 755 /home/rinvex/.letsencrypt
echo "RINVEX TEST FILE" > /home/rinvex/.letsencrypt/test && chmod 644 /home/rinvex/.letsencrypt/test

# Write letsencrypt acme challenge test file
letsencrypt_challenge="location /.well-known/acme-challenge {
    alias /home/rinvex/.letsencrypt;
}
"
echo "\$letsencrypt_challenge" > "/etc/nginx/rinvex-conf/global/server/letsencrypt_challenge.conf"

# Restart nginx and php7.1-fpm services
/etc/init.d/nginx restart
/etc/init.d/php7.1-fpm restart

# Add User To WWW-Data

usermod -a -G www-data rinvex
id rinvex
groups rinvex

# Install Node

apt-get install -y nodejs

# Install SQLite

apt-get install -y sqlite3

# Clean Up

apt-get -y autoremove
apt-get -y clean

# Write serve script
cat > /usr/local/bin/serve << EOF
#!/usr/bin/env bash

echo "Creating nginx configuration files..."

mkdir /etc/nginx/rinvex-conf/\$1/before -p 2>/dev/null
mkdir /etc/nginx/rinvex-conf/\$1/server -p 2>/dev/null
mkdir /etc/nginx/rinvex-conf/\$1/after -p 2>/dev/null

block="# RINVEX HOOKS (DOT NOT REMOVE!)
include rinvex-conf/global/before/*;
include rinvex-conf/\$1/before/*;

server {
    listen \${3:-80};
    listen \${4:-443} ssl http2;
    server_name \$1;
    root \"\$2\";

    index index.html index.htm index.php;

    charset utf-8;

    # RINVEX HOOKS (DOT NOT REMOVE!)
    include rinvex-conf/global/server/*;
    include rinvex-conf/\$1/server/*;

    location / {
        try_files \\\$uri \\\$uri/ /index.php?\\\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/\$1-error.log error;

    error_page 404 /index.php;

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/var/run/php/php7.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}

# RINVEX HOOKS (DOT NOT REMOVE!)
include rinvex-conf/global/after/*;
include rinvex-conf/\$1/after/*;
"

echo "\$block" > "/etc/nginx/sites-available/\$1"
ln -fs "/etc/nginx/sites-available/\$1" "/etc/nginx/sites-enabled/\$1"

# Restart nginx service
/etc/init.d/nginx restart

# Generate a new letsencrypt certificate
echo "Generating letsencrypt certificate..."
letsencrypt certonly --webroot -w \$2 -d \$1 -d www.\$1 --agree-tos -m support@\$1

# Write SSL redirection config
ssl_redirect="# Redirect every request to HTTPS...
server {
    listen \${3:-80};
    listen [::]:\${3:-80};

    server_name .\$1;
    return 301 https://\\\$host\\\$request_uri;
}

# Redirect SSL to primary domain SSL...
server {
    # Based on Mozilla SSL Configuration Generator
    # https://mozilla.github.io/server-side-tls/ssl-config-generator/
    listen \${4:-443} ssl http2;
    listen [::]:\${4:-443} ssl http2;

    # certs sent to the client in SERVER HELLO are concatenated in ssl_certificate
    ssl_certificate /etc/letsencrypt/live/\$1/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/\$1/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Diffie-Hellman parameter for DHE ciphersuites, recommended 2048 bits
    ssl_dhparam /etc/nginx/dhparam.pem;

    # intermediate configuration. tweak to your needs.
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS';
    ssl_prefer_server_ciphers on;

    # HSTS and other security headers (ngx_http_headers_module is required) (15768000 seconds = 6 months)
    add_header Strict-Transport-Security max-age=15768000;
    add_header X-Frame-Options \"SAMEORIGIN\";
    add_header X-XSS-Protection \"1; mode=block\";
    add_header X-Content-Type-Options \"nosniff\";

    # OCSP Stapling ---
    # fetch OCSP records from URL in ssl_certificate and cache them
    ssl_stapling on;
    ssl_stapling_verify on;

    ## verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/letsencrypt/live/\$1/fullchain.pem;

    # Use Google DNS servers for upstream dns resolving
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    server_name www.\$1;
    return 301 https://\$1\\\$request_uri;
}
"

echo "\$ssl_redirect" > "/etc/nginx/rinvex-conf/\$1/before/ssl_redirect.conf"

# Restart nginx service
/etc/init.d/nginx restart

echo "Done!"
EOF

chmod +x /usr/local/bin/serve
