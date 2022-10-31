#!/bin/bash
set -e

staticConfigFile=/opt/couchbase/etc/couchbase/static_config
restPortValue=8091

# see https://developer.couchbase.com/documentation/server/current/install/install-ports.html
function overridePort() {
    portName=$1
    portNameUpper=$(echo $portName | awk '{print toupper($0)}')
    portValue=${!portNameUpper}

    # only override port if value available AND not already contained in static_config
    if [ "$portValue" != "" ]; then
        if grep -Fq "{${portName}," ${staticConfigFile}
        then
            echo "Don't override port ${portName} because already available in $staticConfigFile"
        else
            echo "Override port '$portName' with value '$portValue'"
            echo "{$portName, $portValue}." >> ${staticConfigFile}

            if [ ${portName} == "rest_port" ]; then
                restPortValue=${portValue}
            fi
        fi
    fi
}

overridePort "rest_port"
overridePort "mccouch_port"
overridePort "memcached_port"
overridePort "query_port"
overridePort "ssl_query_port"
overridePort "fts_http_port"
overridePort "moxi_port"
overridePort "ssl_rest_port"
overridePort "ssl_capi_port"
overridePort "ssl_proxy_downstream_port"
overridePort "ssl_proxy_upstream_port"

if [ "$(whoami)" = "couchbase" ]; then
    # Ensure that /opt/couchbase/var is owned by user 'couchbase' and
    # is writable
    if [ ! -w /opt/couchbase/var -o \
        $(find /opt/couchbase/var -maxdepth 0 -printf '%u') != "couchbase" ]; then
        echo "/opt/couchbase/var is not owned and writable by UID 1000"
        echo "Aborting as Couchbase Server will likely not run"
        exit 1
    fi
fi

# Start Couchbase Server
echo "Starting Couchbase Server -- Web UI available at http://<ip>:$restPortValue"
echo "and logs available in /opt/couchbase/var/lib/couchbase/logs"
runsvdir -P /etc/service 'log: ...........................................................................................................................................................................................................................................................................................................................................................................................................' &

# Start Sync Gateway
echo "Starting Sync Gateway"
/opt/couchbase-sync-gateway/bin/sync_gateway --defaultLogFilePath=/demo/couchbase/logs /etc/sync_gateway/config.json &

# Wait for CBS to start
echo -n "Waiting for Couchbase Server to start ... "
while true; do
  if /opt/couchbase/bin/couchbase-cli host-list \
  --cluster 127.0.0.1 \
  --username Administrator \
  --password "password" | \
  grep -q "Unable to connect"; then
    sleep 1
  else
    break
  fi
done
echo "done."

# Configuration section
echo "Configuring Couchbase Cluster"

# Initialize the node
if /opt/couchbase/bin/couchbase-cli host-list \
  --cluster 127.0.0.1 \
  --username Administrator \
  --password "password" | \
  grep -q "127.0.0.1"; then
    echo "This node already exists in the cluster"
else
/opt/couchbase/bin/couchbase-cli node-init \
  --cluster 127.0.0.1 \
  --username Administrator \
  --password "password" \
  --node-init-hostname 127.0.0.1 \
  --node-init-data-path /opt/couchbase/var/lib/couchbase/data \
  --node-init-index-path /opt/couchbase/var/lib/couchbase/data \
  --node-init-analytics-path /opt/couchbase/var/lib/couchbase/data \
  --node-init-eventing-path /opt/couchbase/var/lib/couchbase/data
fi

# Initialize the single node cluster
if /opt/couchbase/bin/couchbase-cli setting-cluster \
  --cluster 127.0.0.1 \
  --username Administrator \
  --password "password" | \
  grep -q 'ERROR: Cluster is not initialized'; then
/opt/couchbase/bin/couchbase-cli cluster-init \
  --cluster 127.0.0.1 \
  --cluster-username Administrator \
  --cluster-password "password" \
  --cluster-port 8091 \
  --cluster-ramsize 256 \
  --cluster-fts-ramsize 512 \
  --cluster-index-ramsize 256 \
  --cluster-eventing-ramsize 256 \
  --cluster-analytics-ramsize 1024 \
  --cluster-name empdemo \
  --index-storage-setting default \
  --services "data,index,query"
else
  echo "This node is already initialized"
fi

cd /demo/couchbase/cbperf

# Wait for the cluster to initialize and for all services to start
set +e
while true; do
  sleep 1
  ./cb_perf list --host 127.0.0.1 --ping --test 2>&1
  [ $? -ne 0 ] && continue
  break
done

cd /demo/couchbase

# Configuration complete

while true; do
  if [ -f /demo/couchbase/logs/sg_info.log ]; then
    break
  fi
  sleep 1
done

touch /demo/couchbase/.ready

echo "The following output is now a tail of sg_info.log:"
tail -f /demo/couchbase/logs/sg_info.log &
childPID=$!
wait $childPID
