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

server="# Redirect every HTTP request to non-www HTTPS...
# Choose between www and non-www, listen on the *wrong* one and redirect to
# the right one -- http://wiki.nginx.org/Pitfalls#Server_Name
server {
  listen [::]:80;
  listen 80;

  # listen on both hosts
  server_name \$1 www.\$1;

  # Include nginx security headers
  include /etc/nginx/snippets/headers.conf;

  # and redirect to the https host (declared below)
  # avoiding http://www -> https://www -> https:// chain.
  return 301 https://\$1\\\$request_uri;
}

server {
  listen [::]:443 ssl http2;
  listen 443 ssl http2;

  # listen on the wrong host
  server_name www.\$1;

  # Include nginx ssl config
  include /etc/nginx/snippets/ssl.conf;
  include /etc/nginx/snippets/headers.conf;
  include /etc/nginx/snippets/ssl-stapling.conf;

  # certs sent to the client in SERVER HELLO are concatenated in ssl_certificate
  ssl_certificate /etc/letsencrypt/live/\$1/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/\$1/privkey.pem;

  ## verify chain of trust of OCSP response using Root CA and Intermediate certs
  ssl_trusted_certificate /etc/letsencrypt/live/\$1/fullchain.pem;

  # and redirect to the non-www host (declared below)
  return 301 https://\$1\\\$request_uri;
}

server {
  listen [::]:443 ssl http2;
  listen 443 ssl http2;

  # The host name to respond to
  server_name \$1;

  # Include nginx ssl config
  include /etc/nginx/snippets/ssl.conf;
  include /etc/nginx/snippets/ssl-stapling.conf;

  # certs sent to the client in SERVER HELLO are concatenated in ssl_certificate
  ssl_certificate /etc/letsencrypt/live/\$1/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/\$1/privkey.pem;

  ## verify chain of trust of OCSP response using Root CA and Intermediate certs
  ssl_trusted_certificate /etc/letsencrypt/live/\$1/fullchain.pem;

  # Path for static files
  root \$2;

  # Specify a charset
  charset utf-8;

  # Custom 404 page
  error_page 404 /index.php;

  # Include basic nginx server config
  include /etc/nginx/snippets/headers.conf;
  include /etc/nginx/snippets/expires.conf;
  include /etc/nginx/snippets/cross-domain-fonts.conf;
  include /etc/nginx/snippets/protect-system-files.conf;

  index index.html index.htm index.php;

  location / {
      try_files \\\$uri \\\$uri/ /index.php?\\\$query_string;
  }

  location = /favicon.ico { access_log off; log_not_found off; }
  location = /robots.txt  { access_log off; log_not_found off; }

  access_log /var/log/nginx/\$1/access.log main;
  error_log /var/log/nginx/\$1/error.log warn;

  location ~ \.php\$ {
      fastcgi_split_path_info ^(.+\.php)(/.+)\$;
      fastcgi_pass unix:/var/run/php/php7.1-fpm.sock;
      fastcgi_index index.php;
      include fastcgi_params;
  }
}
"

echo "\$server" > "/etc/nginx/sites-available/\$1"
ln -fs "/etc/nginx/sites-available/\$1" "/etc/nginx/sites-enabled/\$1"

# Stop nginx service
/etc/init.d/nginx stop

# Generate a new letsencrypt certificate
echo "Generating letsencrypt certificate..."
certbot-auto certonly --standalone --webroot-path \$2 --domain \$1 --domain www.\$1 --email \${3:-help@rinvex.com} --agree-tos

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

if [[ \$EUID -ne 0 ]]; then
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

[[ \$2 = 'master' ]] && environment='production' || environment='dev'
[[ \$2 = 'master' ]] && flags='--no-dev' || flags=''

cd /home/rinvex/\$1
git pull origin \$2
composer install \$flags --no-interaction --prefer-dist --optimize-autoloader

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


# Write gssl script
# Usage: gssl domain.ext frinedlyName
cat > /usr/local/bin/gssl << EOF
#!/usr/bin/env bash

set -e

if [[ \$EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [[ \$# -eq 0 ]] || [[ -z "\$1" ]] || [[ -z "\$2" ]]; then
    echo "Invalid arguments provided! Usage: gssl domain.ext frinedlyName"
    exit 1
fi

# Set our CSR variables
SUBJ="
C=US
ST=California
O=
localityName=San Francisco
commonName=\$1
organizationalUnitName=
emailAddress=
"

# Create our SSL directory
# in case it doesn't exist
sudo mkdir -p "/etc/ssl/\$2"

# Generate our Private Key, CSR and Certificate
sudo openssl genrsa -out "/etc/ssl/\$2/\$2.key" 2048
sudo openssl req -new -subj "\$(echo -n "\$SUBJ" | tr "\n" "/")" -key "/etc/ssl/\$2/\$2.key" -out "/etc/ssl/\$2/\$2.csr" -passin pass:""
sudo openssl x509 -req -days 365 -in "/etc/ssl/\$2/\$2.csr" -signkey "/etc/ssl/\$2/\$2.key" -out "/etc/ssl/\$2/\$2.crt"

EOF

chmod +x /usr/local/bin/gssl
