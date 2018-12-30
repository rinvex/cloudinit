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

if [[ \$# -eq 0 ]] || [[ -z "\$1" ]] || [[ -z "\$2" ]] || [[ -z "\$3" ]]; then
    echo "Invalid arguments provided! Usage: serve [domain] [path] [cert-dns-plugin]"
    echo "serve domain.ext /path/to/root/public/directory dns_aws"
    exit 1
fi

echo "Creating nginx configuration files..."

# Create nginx site log directory
mkdir /var/log/nginx/\$1 -p 2>/dev/null
mkdir /etc/nginx/ssl/\$1 -p 2>/dev/null

server="# Redirect all www. client requests to non-www.
# Always redirect to HTTPS regardless of the $scheme
server {
    server_name www.\$1;
    return 301 https://\$1\\\$request_uri;
}

# Catch HTTP requests without www. and redirect to HTTPS
server {
    listen 80;
    listen [::]:80;

    server_name \$1;

    # Redirect to HTTPS if not behind secured load balancer
    if (\\\$http_x_forwarded_proto != "https") {
        return 301 https://\$1\\\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name \$1;
    root "\$2";
    charset utf-8;

    # Include nginx ssl config
    include /etc/nginx/snippets/ssl.conf;
    include /etc/nginx/snippets/ssl-stapling.conf;

    # certs sent to the client in SERVER HELLO are concatenated in ssl_certificate
    ssl_certificate /etc/nginx/ssl/\$1/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/\$1/privkey.pem;

    ## verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/nginx/ssl/\$1/fullchain.pem;

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
    error_log /var/log/nginx/\$1/error.log error;

    location ~ \.php\$ {
        fastcgi_index index.php;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
        include /etc/nginx/snippets/fastcgi_params.conf;
    }

    location ~ /\.ht {
        deny all;
    }
}
"

echo "\$server" > "/etc/nginx/sites-available/\$1"
ln -fs "/etc/nginx/sites-available/\$1" "/etc/nginx/sites-enabled/\$1"

# Set letsencrypt environment variables
if [ \$3 = "dns_aws" ]; then
    if [ -z "$AWS_ACCESS_KEY_ID" ]
    then
        echo "AWS_ACCESS_KEY_ID was not set, please enter the path: "
        read aws_access_key_id_var
        export AWS_ACCESS_KEY_ID=\$aws_access_key_id_var
    fi

    if [ -z "$AWS_SECRET_ACCESS_KEY" ]
    then
        echo "AWS_SECRET_ACCESS_KEY was not set, please enter the path: "
        read aws_secret_access_key_var
        export AWS_SECRET_ACCESS_KEY=\$aws_secret_access_key_var
    fi
fi

if [ \$3 = "dns_cf" ]; then
    if [ -z "$CF_Key" ]
    then
        echo "CF_Key was not set, please enter the path: "
        read cf_key_var
        export CF_Key=\$cf_key_var
    fi

    if [ -z "$CF_Email" ]
    then
        echo "CF_Email was not set, please enter the path: "
        read cf_email_var
        export CF_Email=\$cf_email_var
    fi
fi

if [ \$3 = "dns_dgon" ]; then
    if [ -z "$DO_API_KEY" ]
    then
        echo "DO_API_KEY was not set, please enter the path: "
        read do_api_key_var
        export DO_API_KEY=\$do_api_key_var
    fi
fi

# Generate letsencrypt certificates
acme.sh --issue --dns \$3 -d \$1 -d *.\$1

acme.sh --install-cert -d \$1 \
--cert-file /etc/nginx/ssl/\$1/cert.pem \
--key-file /etc/nginx/ssl/\$1/privkey.pem \
--ca-file /etc/nginx/ssl/\$1/request.csr \
--fullchain-file /etc/nginx/ssl/\$1/fullchain.pem \
--reloadcmd "/etc/init.d/nginx restart"

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

echo "Removing letsencrypt..."
rm -rvf /etc/nginx/ssl/\$1

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

# Generate javascript routes
php artisan laroute:generate

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
/etc/init.d/php7.2-fpm restart

# Restart all queue workers
php artisan queue:restart

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


# Write queue script
# Usage: queue worker-name domain.ext [options]
cat > /usr/local/bin/queue << EOF
#!/usr/bin/env bash

set -e
if [[ \$EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# set an initial values
QUIET=''
SLEEP=10
QUEUE=''
NUMPROCS=3
WUSER=\$USER
TIMEOUT=60
TRIES=3
ENV=''
USAGE="Usage: \$(basename "\$0") [options]

OPTIONS:
    -h | --help                     Display this help message
    -w | --worker <name>            Queue worker name to be used
    -d | --domain <domain>          Domain name on the filesystem
    -c | --connection <name>        The name of the queue connection to work
    -t | --timeout <seconds>        The number of seconds a child process can run
    -e | --env <environment>        The environment the command should run under
    -p | --numprocs <number>        The number worker instances to be launched
    -s | --sleep <seconds>          Number of seconds to sleep when no job is available
    -x | --tries <number>           Number of times to attempt a job before logging it failed
    -l | --queue <name>             The names of the queues to work
    -u | --user <user>              System user to be used by queue worker
    -q | --quiet                    Do not output any message"

# Read the options
PARSED_OPTIONS='getopt -n "\$0" -o hqw:d:c:t:e:p:s:x:l:u: --l help,quiet,worker:,domain:,connection:,timeout:,env:,numprocs:,sleep:,tries:,queue:,user: -- "\$@"'

# A little magic, necessary when using getopt
eval set -- "\$PARSED_OPTIONS"

# extract options and their arguments into variables.
# Now goes through all the options with a case and using shift to analyse 1 argument at a time.
# \$1 identifies the first argument, and when we use shift we discard the first argument, so \$2 becomes \$1 and goes again through the case.
while true ; do
    case "\$1" in
        -h|--help) echo "\$USAGE" >&2 ; exit 1 ; shift ;;
        -q|--quiet) QUIET="--quiet" ; shift ;;
        -w|--worker)
            case "\$2" in
                "") shift 2 ;;
                *) WORKER='\$2' ; shift 2 ;;
            esac ;;
        -c|--connection)
            case "\$2" in
                "") shift 2 ;;
                *) CONNECTION='\$2' ; shift 2 ;;
            esac ;;
        -d|--domain)
            case "\$2" in
                "") shift 2 ;;
                *) DOMAIN='\$2' ; shift 2 ;;
            esac ;;
        -s|--sleep)
            case "\$2" in
                "") shift 2 ;;
                *) SLEEP='--sleep=\$2' ; shift 2 ;;
            esac ;;
        -l|--queue)
            case "\$2" in
                "") shift 2 ;;
                *) QUEUE='--queue="\$2"' ; shift 2 ;;
            esac ;;
        -p|--numprocs)
            case "\$2" in
                "") shift 2 ;;
                *) NUMPROCS=\$2 ; shift 2 ;;
            esac ;;
        -u|--user)
            case "\$2" in
                "") shift 2 ;;
                *) WUSER=\$2 ; shift 2 ;;
            esac ;;
        -t|--timeout)
            case "\$2" in
                "") shift 2 ;;
                *) TIMEOUT='--timeout=\$2' ; shift 2 ;;
            esac ;;
        -x|--tries)
            case "\$2" in
                "") shift 2 ;;
                *) TRIES='--tries=\$2' ; shift 2 ;;
            esac ;;
        -e|--env)
            case "\$2" in
                "") shift 2 ;;
                *) ENV='--env="\$2"' ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error! Run '\$(basename "\$0") -h' for help." ; exit 1 ;;
    esac
done

if [[ -z "\$WORKER" ]] || [[ -z "\$DOMAIN" ]]; then
    echo "You must supply at least: worker, and domain names! Run '\$(basename "\$0") -h' for help."
    exit 1
fi

config="[program:\$WORKER]
command=php /home/\$WUSER/\$DOMAIN/artisan queue:work \$CONNECTION \$SLEEP \$QUEUE \$TIMEOUT \$TRIES \$ENV \$QUIET

process_name=%(program_name)s_%(process_num)02d
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=\$WUSER
numprocs=\$NUMPROCS
stdout_logfile=/var/log/supervisor/\$WORKER.log"

echo "\$config" > "/etc/supervisor/conf.d/\$WORKER.conf"

echo "Added queue worker '\$WORKER' successfully!"

# Update Supervisor
supervisorctl reread
supervisorctl update
supervisorctl start \$WORKER:*

echo "Updated supervisor successfully!"
EOF

chmod +x /usr/local/bin/queue
