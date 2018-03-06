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

check_apiserver(){
ck=1
retry=0
apiserver="http://${K8S_HOST}:${K8S_PORT}/api/v1"
while [ $ck -ne 0 -a $retry -lt 10 ]
do
	curl $apiserver
	ck=$?
        let retry=retry+1
	sleep 2
done
if [ $retry -lt 10 ] ; then
	return 0
else
	echo "unable to connect kubernetes apiserver:$apiserver. Refuse to start rabbitmq server."
	return 1	
fi
}

gen_cookie(){
cookie='123456789ABCDEFGHIJKLMN'
if [ $RABBITMQ_ERLANG_COOKIE ]; then
	cookie=$RABBITMQ_ERLANG_COOKIE
fi

echo $cookie > /var/lib/rabbitmq/.erlang.cookie
}

ping -c 5 ${MY_POD_NAME}${K8S_HOSTNAME_SUFFIX}
gen_cookie 

check_apiserver && \
rabbitmq-server -detached && \
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /var/log/rabbitmq && \
wait_for_log /var/log/rabbitmq/${RABBITMQ_NODENAME}.log
