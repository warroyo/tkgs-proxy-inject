#!/bin/bash

docker load -i proxy-inject.tar.gz
docker tag proxy-inject docker-registry.kube-system.svc:5000/proxy/proxy-inject:latest
docker push docker-registry.kube-system.svc:5000/proxy/proxy-inject:latest