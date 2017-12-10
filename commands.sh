#!/usr/bin/env bash

set -e

# Write serve script (add virtual host)
# Usage: serve domain.ext /home/user/path
cat > /usr/local/bin/serve << EOF
#!/usr/bin/env bash

set -e

if [[ \$EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [[ \$# -eq 0 ]] || [[ -z "\$1" ]] || [[ -z "\$2" ]]; then
    echo "Invalid arguments provided! Usage: serve domain.ext /path/to/root/public/directory"
    exit 1
fi

echo "Creating nginx configuration files..."

# Create nginx site log directory
mkdir /var/log/nginx/\$1 -p 2>/dev/null

server="# Redirect all www. client requests non-www.
server {
    listen 80;
    listen [::]:80;
    server_name www.\$1;
    return 301 https://\\\$host\\\$request_uri;
}

server {
    listen 80;
    listen [::]:80;

    server_name \$1;
    root "\$2";

    # Redirect HTTP client requests to HTTPS
    if (\\\$http_x_forwarded_proto != "https") {
        return 301 https://\\\$host\\\$request_uri;
    }

    # Custom 404 page
    error_page 404 /index.php;

    # Include basic nginx server config
    include /etc/nginx/snippets/headers.conf;
    include /etc/nginx/snippets/expires.conf;
    include /etc/nginx/snippets/cross-domain-fonts.conf;
    include /etc/nginx/snippets/protect-system-files.conf;

    index index.html index.htm index.php;

    charset utf-8;

    location / {
        try_files \\\$uri \\\$uri/ /index.php?\\\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log  /var/log/nginx/\$1/access.log;
    error_log  /var/log/nginx/\$1/error.log error;

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/var/run/php/php7.1-fpm.sock;
        fastcgi_index index.php;
        include /etc/nginx/snippets/fastcgi_params.conf;
    }

    location ~ /\.ht {
        deny all;
    }
}
"

echo "\$server" > "/etc/nginx/sites-available/\$1"
ln -fs "/etc/nginx/sites-available/\$1" "/etc/nginx/sites-enabled/\$1"

# Start nginx service
/etc/init.d/nginx restart

echo "Done!"
EOF

chmod +x /usr/local/bin/serve


# Write unserve script (remove virtual host)
# Usage: unserve domain.ext
cat > /usr/local/bin/unserve << EOF
#!/usr/bin/env bash

set -e

if [[ \$EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [[ \$# -eq 0 ]] || [[ -z "\$1" ]]; then
    echo "Invalid arguments provided! Usage: serve domain.ext"
    exit 1
fi

echo "Removing virtual host..."
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

if [[ \$2 -eq 'master' ]]; then
   composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader
   npm install
   npm run production
else
   composer install --no-interaction --prefer-dist --optimize-autoloader
   npm install
   npm run dev
fi


if [[ -f artisan ]]; then
    php artisan optimize
    php artisan view:clear
    php artisan cache:clear
    php artisan route:clear
    php artisan config:clear
    php artisan migrate --force

    if [[ \$2 -eq 'master' ]]; then
        php artisan route:cache
        php artisan config:cache
    fi
fi

# Restart php service to flush OPCache
/etc/init.d/php7.1-fpm restart

echo "Done!"
EOF

chmod +x /usr/local/bin/deploy


# Write secure script
# Usage: secure user password
cat > /usr/local/bin/secure << EOF
#!/usr/bin/env bash

set -e

if [[ \$EUID -ne 0 ]]; then
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
