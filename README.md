# Couchbase Dev Container 4.0.0

Container to run Sync Gateway and Couchbase Server for development purposes

Download the helper script:

````
curl -L -O https://github.com/mminichino/cb-dev-container/releases/download/1.0.0/runutil.sh
````

Run the container:

````
./runutil.sh --run
````

Watch the container console output:

````
./runutil.sh --tail
````

Stop the container:
````
./runutil.sh --stop
````

Docker command to run the container:
````
docker run -d --name empdemo \
                -p 8091:8091 \
                -p 8092:8092 \
                -p 8093:8093 \
                -p 8094:8094 \
                -p 8095:8095 \
                -p 8096:8096 \
                -p 8097:8097 \
                -p 11210:11210 \
                -p 9102:9102 \
                -p 4984:4984 \
                -p 4985:4985 \
                mminichino/empdemo
````
