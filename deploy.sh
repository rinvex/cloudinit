#!/usr/bin/env bash

if [[ $# -eq 0 ]] || [[ -z "$1" ]] || [[ -z "$2" ]]; then
    echo "Invalid arguments provided! Usage: deploy domain.ext production
    exit 1
fi

cd /home/rinvex/$1
git pull origin master
composer install --no-interaction --prefer-dist --optimize-autoloader

npm install
npm run $2

if [ -f artisan ]
then
    php artisan migrate --force
fi
