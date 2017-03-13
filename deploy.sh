#!/usr/bin/env bash

cd /home/rinvex/{{DOMAIN}}
git pull origin master
composer install --no-interaction --prefer-dist --optimize-autoloader

npm install
npm run {{ENVIRONMENT}}

if [ -f artisan ]
then
    php artisan migrate --force
fi
