#!/bin/bash
openssl rand -hex 16 > erlang.cookie
kubectl create secret generic erlang.cookie --from-file=erlang.cookie

kubectl label node 172.20.0.34 mq-node=yes
kubectl label node 172.20.0.35 mq-node=yes
kubectl label node 172.20.0.36 mq-node=yes

kubectl create configmap rabbitmq-configmap --from-file=./rabbitmq_config/

kubectl create -f yaml/headless-svc.yaml
kubectl create -f yaml/svc.yaml
kubectl create -f yaml/stateful.yaml
