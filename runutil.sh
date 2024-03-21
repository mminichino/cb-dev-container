#!/bin/bash
#
PRINT_USAGE="Usage: $0 <options>
             --run   Run container
             --show  Show container
             --shell Get shell in running container
             --log   Show container log
             --tail  Tail container log
             --local Use local container image
             --stop  Stop container
             --start Start container
             --rm    Remove container
             --rmi   Remove container image
             --yes   Assume yes to questions
             --prune Prune unused docker image data"
YES=0
RUN_ARGS=""
container=cbdev
image=mminichino/${container}
container_tag="4.0.2"

function print_usage {
if [ -n "$PRINT_USAGE" ]; then
   echo "$PRINT_USAGE"
fi
}

function err_exit {
   if [ -n "$1" ]; then
      echo "[!] Error: $1"
   else
      print_usage
   fi
   exit 1
}

docker ps >/dev/null 2>&1
if [ $? -ne 0 ]; then
   echo "Can not run docker."
   exit 1
fi

while true; do
  case "$1" in
    --run )
            shift
            echo "Starting container ${container} from image ${image}"
            [ -n "$(docker ps -q -a -f name=${container})" ] && docker rm ${container}
            docker run -d --name ${container} \
                                -p 8091:8091 \
                                -p 18091:18091 \
                                -p 8092:8092 \
                                -p 18092:18092 \
                                -p 8093:8093 \
                                -p 18093:18093 \
                                -p 8094:8094 \
                                -p 18094:18094 \
                                -p 8095:8095 \
                                -p 18095:18095 \
                                -p 8096:8096 \
                                -p 18096:18096 \
                                -p 8097:8097 \
                                -p 18097:18097 \
                                -p 11207:11207 \
                                -p 11210:11210 \
                                -p 9102:9102 \
                                -p 4984:4984 \
                                -p 4985:4985 \
                                -p 8080:8080 \
                                -p 8081:8081 \
                                ${image}:${container_tag}
            exit
            ;;
    --show )
            shift
            docker ps -a --filter name=${container}
            exit
            ;;
    --shell )
            shift
            docker exec -it ${container} /bin/bash
            exit
            ;;
    --log )
            shift
            docker logs -n 200 ${container}
            exit
            ;;
    --tail )
            shift
            docker logs -f ${container}
            exit
            ;;
    --local )
            shift
            image=${container}
            ;;
    --ssl  )
            shift
            RUN_ARGS="${RUN_ARGS} -s"
            ;;
    --stop )
            shift
            if [ "$YES" -eq 0 ]; then
              echo -n "Container will stop. Continue? [y/n]: "
              read ANSWER
              [ "$ANSWER" = "n" -o "$ANSWER" = "N" ] && exit
            fi
            docker stop ${container}
            exit
            ;;
    --start )
            shift
            docker start ${container}
            exit
            ;;
    --rm )
            shift
            if [ "$YES" -eq 0 ]; then
              echo -n "WARNING: removing the container can not be undone. Continue? [y/n]: "
              read ANSWER
              [ "$ANSWER" = "n" -o "$ANSWER" = "N" ] && exit
            fi
            for container_id in $(docker ps -q -a -f name=${container}); do
              docker stop ${container_id}
              docker rm ${container_id}
            done
            exit
            ;;
    --rmi )
            shift
            if [ "$YES" -eq 0 ]; then
              echo -n "Remove container images? [y/n]: "
              read ANSWER
              [ "$ANSWER" = "n" -o "$ANSWER" = "N" ] && exit
            fi
            for image in $(docker images ${image} | tail -n +2 | awk '{print $3}'); do docker rmi $image ; done
            exit
            ;;
    --yes )
            shift
            YES=1
            ;;
    --prune )
            shift
            docker image prune -f
            docker builder prune -a -f
            exit
            ;;
    * )
            print_usage
            exit 1
            ;;
  esac
done
