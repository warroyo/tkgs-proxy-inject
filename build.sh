#!/bin/bash

docker build -t proxy-inject:1.3.0 .
# docker save proxy-inject:1.3.0 | gzip > proxy-inject.tar.gz