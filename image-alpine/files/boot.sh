#!/bin/bash

set -e

debug_msg() {
    if [ "$BOOT_DEBUG" = "true" ];
    then
        echo "[DEBUG] boot.sh: $1"
    fi
}

gen_cookie(){
    cookie='123456789ABCDEFGHIJKLMN'
    if [ $RABBITMQ_ERLANG_COOKIE ]; then
        cookie=$RABBITMQ_ERLANG_COOKIE
    fi

    echo $cookie > /var/lib/rabbitmq/.erlang.cookie
}

echo '[1] test kube-dns ...'
curl -k -s --head -m 5 https://kubernetes

echo '[2] generate erlang cookie'
gen_cookie 

echo '[3] test connecting to k8s apiserver'
curl -s -m 5 http://${K8S_HOST}:${K8S_PORT}/api

echo '[4] copy configuration files to /etc/rabbitmq/'
cp -f /tmp/rabbitmq_config/* /etc/rabbitmq/

echo '[5] change directory owner'
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /var/log/rabbitmq

echo '[6] rabbitmq starts'
rabbitmq-server -detached

echo '[7] show running logs...'
tail -F /var/log/rabbitmq/${RABBITMQ_NODENAME}.log
