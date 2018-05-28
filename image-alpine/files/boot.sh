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

	tail -F $log_name
}

gen_cookie(){
    cookie='123456789ABCDEFGHIJKLMN'
    if [ $RABBITMQ_ERLANG_COOKIE ]; then
        cookie=$RABBITMQ_ERLANG_COOKIE
    fi

    echo $cookie > /var/lib/rabbitmq/.erlang.cookie
    chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
    chmod 400 /var/lib/rabbitmq/.erlang.cookie
}

start_time=`date +%s`

elapsed(){
    cur_time=`date +%s` || true
    period=`expr $cur_time - $start_time` || true
    echo "elapsed $period seconds."
}

echo '[1] test kube-dns ...'
curl -k -s --head -m 5 https://kubernetes
elapsed

echo '[2] generate erlang cookie'
gen_cookie 

echo '[3] test connecting to k8s apiserver'
curl -s -m 5 http://${K8S_HOST}:${K8S_PORT}/api
elapsed

echo '[4] copy configuration files to /etc/rabbitmq/'
cp -f /tmp/rabbitmq_config/* /etc/rabbitmq/
elapsed

echo '[5] change directory owner'
chown rabbitmq:rabbitmq /var/log/rabbitmq /var/lib/rabbitmq/mnesia
elapsed

echo '[6] rabbitmq starts'
rabbitmq-server -detached
elapsed

echo '[7] show running logs...'
wait_for_log /var/log/rabbitmq/${RABBITMQ_NODENAME}.log
