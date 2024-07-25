#!/bin/bash

if [ "$SUDO_USER" ]; then
    username=$SUDO_USER
else
    username=$USER
fi

docker stop apache-container 
docker rm apache-container 
cd /Users/$username/peviitor/search-engine
docker build -t fe:latest .
docker run --name deploy_fe --network mynetwork --ip 172.18.0.13 --rm \
    -v /Users/$username/peviitor/build:/app/build fe:latest npm run build:local
rm -f /Users/$username/peviitor/build/.htaccess
cp -r /Users/$username/peviitor/api /Users/$username/peviitor/build
docker run --name apache-container --network mynetwork --ip 172.18.0.11 -d -p 8080:80 \
    -v /Users/$username/peviitor/build:/var/www/html sebiboga/php-apache:latest