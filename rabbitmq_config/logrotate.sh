#!/bin/bash

my_ip=$(hostname -i)
cur_time=$(date +%Y%m%d_%H.%M)
log_suffix="${cur_time}.$RANDOM"
log_base='/var/log/rabbitmq'

log="$log_base/${RABBITMQ_NODENAME}.log"
sasl_log="$log_base/${RABBITMQ_NODENAME}-sasl.log"

if [ ! -f $log ]; then
    echo "[ERROR] log file $log is not found."
    exit 1
fi
if [ ! -f $sasl_log ]; then
    echo "[ERROR] log file $sasl_log is not found."
    exit 1
fi

# 10KB
log_size=`stat -c "%s" $log`
sasl_log_size=`stat -c "%s" $sasl_log`
if [ $log_size -lt 10240 -a $sasl_log_size -lt 10240 ]; then
    echo 'log files are less than 10KB. log rotation is canceled.'
    exit 0
fi

rabbitmqctl rotate_logs $log_suffix

log_bak="$log$log_suffix"
sasl_log_bak="$sasl_log$log_suffix"

zip "$log_base/${my_ip}_${MY_POD_NAME}_${cur_time}.zip" $log_bak && rm -vf $log_bak
zip "$log_base/${my_ip}_${MY_POD_NAME}_${cur_time}-sasl.zip" $sasl_log_bak && rm -vf $sasl_log_bak

# delete files that are last modified 7 days ago
find $log_base -mtime +7 -type f -name "*.zip" | xargs rm -vf