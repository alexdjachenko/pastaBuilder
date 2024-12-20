#!/bin/bash
# Отправка образа в реестр

source docker.env

docker push $IMAGE_NAME:$IMAGE_TAG

