#!/bin/bash
# Сборка образа

# Сам собираемый образ нам не нужен, только результат сборки из него
docker build  \
  --progress=plain \
  --target res-img \
  --output type=local,dest=./result \
  --build-arg PB_ARGS="-code 0.0.1a" \
  -f Dockerfile  .
