#!/bin/sh
alias kubectl=/opt/kubectl

server_option=--server="${K8S_HOST}:${K8S_PORT}"
pods=$(kubectl $server_option get pod --no-headers -l app=rabbitmq 2> /dev/null | awk '{print $1}')

echo '========== LOG CLEANUP starts... ========='
for pod in $pods 
do
    echo "========== clean logs on $pod... =========="
    kubectl $server_option exec $pod sh /etc/rabbitmq/logrotate.sh
done
echo '========== LOG CLEANUP finished~ ========='