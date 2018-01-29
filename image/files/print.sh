#!/bin/bash
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
