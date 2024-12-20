#!/bin/bash
# Сборка образа

source docker.env

#docker build --progress=plain \
 docker build  \
  -t ${IMAGE_NAME}:${IMAGE_TAG} \
  -t ${IMAGE_NAME} \
  -f Dockerfile  .
