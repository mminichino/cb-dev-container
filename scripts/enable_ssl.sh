#!/bin/bash

RUN_PID=$(cat /etc/sync_gateway/run.pid)

kill -TERM "$RUN_PID"

/opt/couchbase-sync-gateway/bin/sync_gateway --defaultLogFilePath=/demo/couchbase/logs /etc/sync_gateway/config_ssl.json &
echo $! > /etc/sync_gateway/run.pid
