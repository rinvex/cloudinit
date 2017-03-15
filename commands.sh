#!/usr/bin/env bash

set -e

# Write serve script (add virtual host)
# Usage: serve domain.ext /home/user/path
cat > /usr/local/bin/serve << EOF
#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [[ \$# -eq 0 ]] || [[ -z "\$1" ]] || [[ -z "\$2" ]]; then
    echo "Invalid arguments provided! Usage: serve domain.ext /path/to/root/public/directory"
    exit 1
fi

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

# Stop nginx service
/etc/init.d/nginx stop

# Generate a new letsencrypt certificate
echo "Generating letsencrypt certificate..."
certbot-auto certonly --standalone --webroot-path \$2 --domain \$1 --domain www.\$1 --email support@\$1 --agree-tos --quiet

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

# Write server headers
server_headers="# HSTS and other security headers (ngx_http_headers_module is required) (15768000 seconds = 6 months)
add_header Strict-Transport-Security max-age=15768000;
add_header X-Frame-Options \"SAMEORIGIN\";
add_header X-XSS-Protection \"1; mode=block\";
add_header X-Content-Type-Options \"nosniff\";
"

echo "\$server_headers" > "/etc/nginx/rinvex-conf/\$1/server/server_headers.conf"

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
rm -rvf /etc/nginx/rinvex-conf/\$1
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
# Usage: secure directory user password
cat > /usr/local/bin/secure << EOF
#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [[ \$# -eq 0 ]] || [[ -z "\$1" ]] || [[ -z "\$2" ]] || [[ -z "\$3" ]]; then
    echo "Invalid arguments provided! Usage: secure directory user password"
    exit 1
fi

touch .htpasswd
echo -n '\$1:' >> /etc/nginx/.htpasswd
openssl passwd -apr1 '\$2' >> /etc/nginx/.htpasswd
echo >> /etc/nginx/.htpasswd

echo -n 'Copy the following two auth lines into your '
echo 'desired nginx location block to be secured:'
echo '-------------------------'
echo 'auth_basic "Restricted Content";'
echo 'auth_basic_user_file /etc/nginx/.htpasswd;'
echo '-------------------------'

EOF

chmod +x /usr/local/bin/secure
