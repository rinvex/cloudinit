#!/usr/bin/env bash

set -e

# Write serve script (add virtual host)
# Usage: serve domain.ext /home/user/path email@domain.ext
cat > /usr/local/bin/serve << EOF
#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [[ \$# -eq 0 ]] || [[ -z "\$1" ]] || [[ -z "\$2" ]]; then
    echo "Invalid arguments provided! Usage: serve domain.ext /path/to/root/public/directory email@domain.ext"
    exit 1
fi

echo "Creating nginx configuration files..."

mkdir /etc/nginx/snippets/\$1/before -p 2>/dev/null
mkdir /etc/nginx/snippets/\$1/server -p 2>/dev/null
mkdir /etc/nginx/snippets/\$1/after -p 2>/dev/null

block="# NGINX SNIPPETS (DOT NOT REMOVE!)
include snippets/global/before/*;
include snippets/\$1/before/*;

server {
    listen \${5:-443} ssl http2;
    server_name \$1;
    root \"\$2\";

    # certs sent to the client in SERVER HELLO are concatenated in ssl_certificate
    ssl_certificate /etc/letsencrypt/live/\$1/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/\$1/privkey.pem;

    # NGINX SNIPPETS (DOT NOT REMOVE!)
    include snippets/global/general/ssl.conf;
    include snippets/global/general/headers.conf;

    ## verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/letsencrypt/live/\$1/fullchain.pem;

    # Use Google DNS servers for upstream dns resolving
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    index index.html index.htm index.php;

    charset utf-8;

    # NGINX SNIPPETS (DOT NOT REMOVE!)
    include snippets/global/server/*;
    include snippets/\$1/server/*;

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

# NGINX SNIPPETS (DOT NOT REMOVE!)
include snippets/global/after/*;
include snippets/\$1/after/*;
"

echo "\$block" > "/etc/nginx/sites-available/\$1"
ln -fs "/etc/nginx/sites-available/\$1" "/etc/nginx/sites-enabled/\$1"

# Stop nginx service
/etc/init.d/nginx stop

# Generate a new letsencrypt certificate
echo "Generating letsencrypt certificate..."
certbot-auto certonly --standalone --webroot-path \$2 --domain \$1 --domain www.\$1 --email \$3 --agree-tos

# Write SSL redirection config
ssl_redirect="# Redirect every request to HTTPS...
server {
    listen \${4:-80};
    listen [::]:\${4:-80};

    server_name .\$1;
    return 301 https://\\\$host\\\$request_uri;
}

# Redirect SSL to primary domain SSL...
server {
    listen \${5:-443} ssl http2;
    listen [::]:\${5:-443} ssl http2;

    # certs sent to the client in SERVER HELLO are concatenated in ssl_certificate
    ssl_certificate /etc/letsencrypt/live/\$1/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/\$1/privkey.pem;

    # NGINX SNIPPETS (DOT NOT REMOVE!)
    include snippets/global/general/ssl.conf;
    include snippets/global/general/headers.conf;

    ## verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/letsencrypt/live/\$1/fullchain.pem;

    # Use Google DNS servers for upstream dns resolving
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    server_name www.\$1;
    return 301 https://\$1\\\$request_uri;
}
"

echo "\$ssl_redirect" > "/etc/nginx/snippets/\$1/before/ssl_redirect.conf"

# Start nginx service
/etc/init.d/nginx start

echo "Done!"
EOF

chmod +x /usr/local/bin/serve


# Write unserve script (remove virtual host)
# Usage: unserve domain.ext
cat > /usr/local/bin/unserve << EOF
#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [[ \$# -eq 0 ]] || [[ -z "\$1" ]]; then
    echo "Invalid arguments provided! Usage: serve domain.ext"
    exit 1
fi

echo "Removing letsencrypt..."
rm -rvf /etc/letsencrypt/live/\$1
rm -rvf /etc/letsencrypt/archive/\$1
rm -rvf /etc/letsencrypt/renewal/\$1.conf

echo "Removing virtual host..."
rm -rvf /etc/nginx/snippets/\$1
rm -rvf /etc/nginx/sites-enabled/\$1
rm -rvf /etc/nginx/sites-available/\$1

# Restart nginx service
/etc/init.d/nginx restart

echo "Done!"
EOF

chmod +x /usr/local/bin/unserve


# Write deploy script
# Usage: deploy domain.ext branch
cat > /usr/local/bin/deploy << EOF
#!/usr/bin/env bash

set -e

if [[ \$# -eq 0 ]] || [[ -z "\$1" ]] || [[ -z "\$2" ]]; then
    echo "Invalid arguments provided! Usage: deploy domain.ext branch"
    exit 1
fi

cd /home/rinvex/\$1
git pull origin \$2
composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

[[ \$2 = 'master' ]] && environment='production' || environment='dev'

npm install
npm run \$environment

if [ -f artisan ]
then
    php artisan optimize
    php artisan route:cache
    php artisan config:cache
    php artisan migrate --force
    php artisan cache:clear
    php artisan view:clear
fi

echo "Done!"
EOF

chmod +x /usr/local/bin/deploy


# Write secure script
# Usage: secure user password
cat > /usr/local/bin/secure << EOF
#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [[ \$# -eq 0 ]] || [[ -z "\$1" ]] || [[ -z "\$2" ]]; then
    echo "Invalid arguments provided! Usage: secure user password"
    exit 1
fi

echo -n "\$1:" >> /etc/nginx/.htpasswd
openssl passwd -apr1 "\$2" >> /etc/nginx/.htpasswd

echo -n 'Copy the following two auth lines into your '
echo 'desired nginx location block to be secured:'
echo '-------------------------'
echo 'auth_basic "Restricted Content";'
echo 'auth_basic_user_file /etc/nginx/.htpasswd;'
echo '-------------------------'

EOF

chmod +x /usr/local/bin/secure
