#!/bin/sh


/docker-entrypoint.d/20-envsubst-on-templates.sh
nginx -g "daemon off;" &
while :; do 
    sleep 6h & 
    wait ${!}
    nginx -s reload
done
