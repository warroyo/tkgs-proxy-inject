#!/bin/bash

docker build -t proxy-inject:1.0.1 .
docker save proxy-inject:1.0.1 | gzip > proxy-inject.tar.gz