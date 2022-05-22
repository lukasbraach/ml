#!/bin/bash

# basic settings
WORK_DIR=$(pwd)
PREFIX=ml
GROUP=aiteam

#
# you probably don't need to modify anything below this line.
#

USR_ID=$(id -u)
GRP_ID=$(getent group $GROUP | cut -d: -f 3)

IMAGE="$USER/$PREFIX"
CONTAINER_NAME=$(echo "${PREFIX}_${USER}${WORK_DIR}" | tr \/ _)
AMOUNT_IMAGES=$(docker images "$IMAGE" | wc -l)
SCRIPTPATH="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1
  pwd -P
)"

if [ "$AMOUNT_IMAGES" -le 1 ]; then
  #
  # only build the image if it's not already existing.
  #

  echo "Image $IMAGE not found on local docker daemon. Now building..."
  docker build -t "$IMAGE" \
    --build-arg USER="$USER" \
    --build-arg USER_ID="$USR_ID" \
    --build-arg GROUP_ID="$GRP_ID" \
    "$SCRIPTPATH"
else
  echo "Image $IMAGE found on local docker daemon."
fi

AMOUNT_CONTAINERS=$(docker ps -a --quiet --filter="name=^/$CONTAINER_NAME$" | wc -l)

if [ "$AMOUNT_CONTAINERS" -eq 0 ]; then
  #
  # only create container if not already existing for path.
  #

  echo "Creating a new ML container for user $USER and work path $WORK_DIR"

  docker create -it --name "$CONTAINER_NAME" --runtime=nvidia \
    -u "$USR_ID:$GRP_ID" \
    --workdir="/home/$USER" \
    --volume="/etc/group:/etc/group:ro" \
    --volume="/etc/passwd:/etc/passwd:ro" \
    --volume="/etc/shadow:/etc/shadow:ro" \
    --mount type=bind,source="$WORK_DIR",target=/opt/work \
    --mount type=bind,source="/srv/datasets",target=/opt/data \
    --network host \
    --shm-size=172gb \
    "$IMAGE" &>/dev/null
fi

CONTAINER_ID=$(docker ps --quiet --filter="name=^/$CONTAINER_NAME$")

if [ -z "$CONTAINER_ID" ]; then
  #
  # start created container
  #
  echo "Starting the container..."

  docker start "$CONTAINER_NAME" &>/dev/null
  CONTAINER_ID=$(docker ps --quiet --filter="name=^/$CONTAINER_NAME$")
fi

if [ -n "$NVIDIA_VISIBLE_DEVICES" ]; then
  USE_GPUS="$NVIDIA_VISIBLE_DEVICES"
fi

echo "Connecting to the running container..."
echo ""
docker exec -e NVIDIA_VISIBLE_DEVICES="$USE_GPUS" -it "$CONTAINER_NAME" /bin/bash
echo ""

AMOUNT_PS_LINES=$(docker top "$CONTAINER_NAME" -e | wc -l)

if [ "$AMOUNT_PS_LINES" -le 2 ]; then
  #
  # stopping the container if no user processes are running anymore.
  #

  docker kill "$CONTAINER_NAME" &>/dev/null
  echo "Stopped the container."
  echo "Your container has been persisted to the docker daemon."
  echo ""
  echo "If you don't need the container anymore, please delete it"
  echo "by running: docker rm $CONTAINER_ID"
  echo ""
fi
