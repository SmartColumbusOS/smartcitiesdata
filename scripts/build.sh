#!/usr/bin/env bash

set -e

app="${1}"
version="${2}"

docker rmi -f smartcolumbusos:build
docker build -t smartcolumbusos:build .
docker build -t smartcolumbusos/$app:$version apps/$app
