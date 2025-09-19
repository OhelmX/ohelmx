#!/bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh

# Parse command line arguments
TAG=""
EDX_PLATFORM_DIRECTORY=""
for arg in "$@"; do
  case $arg in
    --tag=*)
      TAG="${arg#*=}"
      ;;
    --edx-platform-directory=*)
      EDX_PLATFORM_DIRECTORY="${arg#*=}"
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

if [ -z "$TAG" ]; then
  echo "Error: --tag parameter is required"
  exit 1
fi
if [ -z "$EDX_PLATFORM_DIRECTORY" ]; then
  echo "Error: --edx-platform-directory parameter is required"
  exit 1
fi
if [ ! -d "$EDX_PLATFORM_DIRECTORY" ]; then
  echo "Error: Directory $EDX_PLATFORM_DIRECTORY does not exist"
  exit 1
fi
CONTAINER_REF=${CONTAINER_REGISTRY}/openedx:${TAG}
GITHUB_REPO=edx-platform

echo "Building and pushing images for ${APPNAME} to ${CONTAINER_REF}"

docker build --tag=${CONTAINER_REF}:${TAG} --output=type=docker \
  --build-context=edx-platform=${$EDX_PLATFORM_DIRECTORY} ${SCRIPT_DIR}/${GITHUB_REPO}

docker push ${CONTAINER_REF}
