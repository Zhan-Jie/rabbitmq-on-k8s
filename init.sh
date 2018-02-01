#!/bin/bash
openssl rand -hex 16 > erlang.cookie
kubectl create secret generic erlang.cookie --from-file=erlang.cookie

kubectl create -f yaml/headless-svc.yaml
kubectl create -f yaml/svc.yaml
kubectl create -f yaml/stateful.yaml
