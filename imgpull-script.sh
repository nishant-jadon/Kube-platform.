#!/bin/bash
# Download required images & pust to Private Registry.

# Define Private Registry server name 

regsrv=
docid=
docpass=

# Declare images in an array 

imgname=( "quay.io/coreos/kube-state-metrics:v1.3.0" "k8s.gcr.io/addon-resizer:1.8.3" "prom/node-exporter:v0.16.0" "prom/prometheus:v2.4.3" "prom/alertmanager:v0.15.3" "grafana/loki:v0.3.0" "grafana/fluent-bit-plugin-loki:0.1" "grafana/grafana:latest" )

# Docker Private Registry login

docker login --username=$docid --password=$docpass $regsrv
           
# Pushing image to private registry

for i in "${imgname[@]}"
do
	echo Image name: $i
	docker pull $i
  sleep 3
	imgid=`docker images $i | awk '{print $3}' | grep -v IMAGE`´
	docker tag $imgid $regsrv/$i
	docker push $regsrv/$i
done
