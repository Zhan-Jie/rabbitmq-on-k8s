#!/bin/bash

set -e

wait_for_log(){
	log_name=$1

	echo 'check log file '$log_name'...'
	while true
	do
		if [ ! -f $log_name ]; then
			sleep 5
		else
			break
		fi
	done

	tail -f $log_name
}

echo '[0] unalias cp'
unalias -a cp

gen_cookie(){
    cookie='123456789ABCDEFGHIJKLMN'
    if [ $RABBITMQ_ERLANG_COOKIE ]; then
        cookie=$RABBITMQ_ERLANG_COOKIE
    fi

    echo $cookie > /var/lib/rabbitmq/.erlang.cookie
    chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
    chmod 400 /var/lib/rabbitmq/.erlang.cookie
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
echo "/var/lib/rabbitmq/mnesia"
ls -la /var/lib/rabbitmq/mnesia
echo "/var/log/rabbitmq"
ls -la /var/log/rabbitmq
chown rabbitmq:rabbitmq /var/log/rabbitmq /var/lib/rabbitmq/mnesia

echo '[6] rabbitmq starts'
rabbitmq-server -detached

echo '[7] print logs'
wait_for_log /var/log/rabbitmq/${RABBITMQ_NODENAME}.log
