#!/bin/bash

set +x
IMAGE_NAME=e2guardian
OS_RELEASE=${OS_RELEASE:-$(grep VERSION_ID /etc/os-release | cut -d '=' -f 2)}
OS_IMAGE=${OS_IMAGE:-"registry.fedoraproject.org/fedora:${OS_RELEASE}"}
BUILD_ID=${BUILD_ID:-`date +%s`}
BUILD_ARCH=${BUILD_ARCH:-`uname -m`}
PUSHREG=${PUSHREG:-""}

echo podman build --build-arg OS_RELEASE=${OS_RELEASE} --build-arg OS_IMAGE=${OS_IMAGE} --build-arg DEVBUILD=${DEVBUILD} -t ${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID} -f Containerfile
podman build --build-arg OS_RELEASE=${OS_RELEASE} --build-arg OS_IMAGE=${OS_IMAGE} --build-arg DEVBUILD=${DEVBUILD} -t ${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID} -f Containerfile


if [ $? -eq 0 ]; then
  echo  podman tag ${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID} ${BUILD_ARCH}/${IMAGE_NAME}:latest
  podman tag ${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID} ${BUILD_ARCH}/${IMAGE_NAME}:latest

  if [ ! -z "${PUSHREG}" ]; then
    echo podman tag ${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID} ${PUSHREG}/${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID}
    podman tag ${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID} ${PUSHREG}/${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID}
    echo podman push ${PUSHREG}/${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID}
    podman push ${PUSHREG}/${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID}
    echo podman tag ${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID} ${PUSHREG}/${BUILD_ARCH}/${IMAGE_NAME}:latest
    podman tag ${BUILD_ARCH}/${IMAGE_NAME}:${BUILD_ID} ${PUSHREG}/${BUILD_ARCH}/${IMAGE_NAME}:latest
    echo podman push ${PUSHREG}/${BUILD_ARCH}/${IMAGE_NAME}:latest
    podman push ${PUSHREG}/${BUILD_ARCH}/${IMAGE_NAME}:latest
  fi
fi

