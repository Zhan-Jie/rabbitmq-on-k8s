#!/bin/bash

cur_time=$(date +%Y%m%d_%H.%M)
log_suffix="${cur_time}.$RANDOM"

rabbitmqctl rotate_logs $log_suffix

log_bak="/var/log/rabbitmq/${RABBITMQ_NODENAME}.log$log_suffix"

my_ip=$(hostname -i)
mv $log_bak "/var/log/rabbitmq/${my_ip}_${MY_POD_NAME}_${cur_time}.log"
rm -vf "/var/log/rabbitmq/${RABBITMQ_NODENAME}-sasl.log$log_suffix"

# delete files that are last modified 7 days ago
find /var/log/rabbitmq/ -mtime +7 -type f | xargs rm -vf