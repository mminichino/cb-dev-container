FROM ubuntu:focal as base

# Install required OS packages
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -q -y runit numactl tzdata lsof lshw bzip2 jq git vim netcat sysstat apt-utils ca-certificates gnupg lsb-release net-tools python3.9 python3.9-dev python3-pip python3-setuptools cmake build-essential curl sudo

# Get Couchbase release package and Sync Gateway package
RUN curl -s -o /var/tmp/couchbase-release-1.0-amd64.deb https://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-amd64.deb
RUN curl -s -o /var/tmp/couchbase-sync-gateway-enterprise_3.0.3_x86_64.deb http://packages.couchbase.com/releases/couchbase-sync-gateway/3.0.3/couchbase-sync-gateway-enterprise_3.0.3_x86_64.deb
RUN dpkg -i /var/tmp/couchbase-release-1.0-amd64.deb

# Prepare Python environment
RUN pip3 install --upgrade pip setuptools wheel

# Create Couchbase user
RUN groupadd -g 1000 couchbase
RUN useradd couchbase -u 1000 -g couchbase -M

# Install Couchbase Server
RUN apt-get update
RUN export INSTALL_DONT_START_SERVER=1 \
    && apt-get install -q -y couchbase-server

# Indicate that Couchbase is running in a container
RUN sed -i -e '1 s/$/\/docker/' /opt/couchbase/VARIANT.txt

# Setup Couchbase Server run environment
COPY scripts/run /etc/service/couchbase-server/run
RUN mkdir -p /etc/runit/runsvdir/default/couchbase-server/supervise \
    && chown -R couchbase:couchbase \
                /etc/service \
                /etc/runit/runsvdir/default/couchbase-server/supervise

# Enable cbcollect_info to run in the container
COPY scripts/dummy.sh /usr/local/bin/
RUN ln -s dummy.sh /usr/local/bin/iptables-save \
    && ln -s dummy.sh /usr/local/bin/lvdisplay \
    && ln -s dummy.sh /usr/local/bin/vgdisplay \
    && ln -s dummy.sh /usr/local/bin/pvdisplay

# Create directories
RUN mkdir -p /opt/couchbase-sync-gateway/data
RUN mkdir -p /demo/couchbase
RUN mkdir /demo/couchbase/logs
RUN mkdir /demo/couchbase/bin

# Install Sync Gatwway
# The package includes a post install action that will not work in a container
# so we remove it before we install the package
WORKDIR /var/tmp
RUN dpkg-deb -R couchbase-sync-gateway-enterprise_3.0.3_x86_64.deb tmp
RUN rm tmp/DEBIAN/postinst
RUN dpkg-deb -b tmp couchbase-sync-gateway.deb
WORKDIR /
RUN dpkg -i /var/tmp/couchbase-sync-gateway.deb
RUN chown -R couchbase:couchbase /opt/couchbase-sync-gateway
RUN chmod 755 /opt/couchbase-sync-gateway/service/sync_gateway_service_install.sh
RUN chmod 755 /opt/couchbase-sync-gateway/examples
RUN useradd sync_gateway -u 1002 -g couchbase
COPY config/sync_gateway.json /etc/sync_gateway/config.json

# Entry point script to configure the environment on container start
COPY scripts/entrypoint.sh /demo/couchbase/bin

# Add CBPerf utility that will be used to install the demo schema
RUN git clone -b Version_2.0 https://github.com/mminichino/cbperf /demo/couchbase/cbperf
WORKDIR /demo/couchbase/cbperf
RUN ./setup.sh -y

# Cleanup
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /demo/couchbase
EXPOSE 4984 4985 4986 8091 8092 8093 8094 8095 8096 11207 11210 11211 18091 18092 18093 18094 18095 18096
VOLUME /opt/couchbase/var

# Start the container
CMD ["/demo/couchbase/bin/entrypoint.sh"]
