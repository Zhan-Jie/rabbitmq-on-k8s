#!/bin/sh

for i in `ls /scripts/*.sh`; 
do
    if [ "$i" = "$0" ]; then
        continue
    fi
    echo "Execute /scripts/$i"
    sh /scripts/$i
done

echo "logrotate finished."