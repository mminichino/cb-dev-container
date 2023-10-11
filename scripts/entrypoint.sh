#!/bin/bash
USE_SSL=0
PRINT_USAGE="Usage: $0 [ -s ]
             -s Use SSL for Sync Gateway"
set -e

function print_usage {
if [ -n "$PRINT_USAGE" ]; then
   echo "$PRINT_USAGE"
fi
}

while getopts "s" opt
do
  case $opt in
    s)
      USE_SSL=1
      ;;
    \?)
      print_usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

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

if [ -e /etc/service/git-daemon ]; then
  rm /etc/service/git-daemon
fi

# Start Couchbase Server
echo "Starting Couchbase Server -- Web UI available at http://<ip>:$restPortValue"
echo "and logs available in /opt/couchbase/var/lib/couchbase/logs"
runsvdir -P /etc/service 'log: ...........................................................................................................................................................................................................................................................................................................................................................................................................' &

echo "Configuring Couchbase Server"
swmgr cluster create -n testdb
echo "Starting Sync Gateway"
swmgr gateway configure
bundlemgr -b StartSGW

swmgr cluster wait -n testdb
swmgr gateway wait

cd /demo/couchbase

# Configuration complete

touch /demo/couchbase/.ready

echo "The following output is now a tail of sg_info.log:"
tail -f /home/sync_gateway/logs/sg_info.log &
childPID=$!
wait $childPID
