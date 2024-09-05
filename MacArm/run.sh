#!/bin/bash

if ! command -v git &> /dev/null
then
    echo "Git is not installed. Please install Git and re-run the script."
    exit 1
fi

if ! command -v docker &> /dev/null
then
    echo "Docker is not installed. Please install Docker and re-run the script."
    exit 1
fi

if [ "$SUDO_USER" ]; then
    username=$SUDO_USER
else
    username=$USER
fi

sudo rm -rf /private/var/peviitor

echo "Remove existing containers if they exist"
for container in apache-container solr-container data-migration deploy-fe
do
  if [ "$(docker ps -aq -f name=$container)" ]; then
    docker stop $container
    docker rm $container
  fi
done

# Check if "mynetwork" network exists, create if it doesn't
network='mynetwork'
if [ -z "$(docker network ls | grep $network)" ]; then
  docker network create --subnet=172.18.0.0/16 $network
fi

docker pull node:alpine
git clone https://github.com/peviitor-ro/search-engine.git /private/var/peviitor/search-engine
sudo chmod -R 777 /private/var/peviitor
cd /private/var/peviitor/search-engine
pwd
ls
docker build -t fe:latest .
docker run --name deploy_fe --network mynetwork --ip 172.18.0.13 --rm \
    -v /private/var/peviitor/build:/app/build fe:latest npm run build:local
rm -f /private/var/peviitor/build/.htaccess

git clone https://github.com/peviitor-ro/api.git /private/var/peviitor/api
sudo chmod -R 777 /private/var/peviitor
cp -r /private/var/peviitor/api /private/var/peviitor/build
docker run --name apache-container --network mynetwork --ip 172.18.0.11 -d -p 8080:80 \
    -v /private/var/peviitor/build:/var/www/html sebiboga/php-apache:latest
ls
git clone https://github.com/peviitor-ro/solr.git /private/var/peviitor/solr
sudo chmod -R 777 /private/var/peviitor
docker run --name solr-container --network mynetwork --ip 172.18.0.10 -d -p 8983:8983 \
    -v /private/var/peviitor/solr/core/data:/var/solr/data solr:latest
ls
# Wait for Solr container to be ready
until [ "$(docker inspect -f {{.State.Running}} solr-container)" == "true" ]; do
    sleep 0.1;
done;

docker run --name solr-curl-container --network mynetwork --ip 172.18.0.14 --rm alexstefan1702/solr-curl-update

echo "Script execution completed."