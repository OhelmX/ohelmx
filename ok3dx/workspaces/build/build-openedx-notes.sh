#!/bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh

# Parse command line arguments
TAG=""
NOTES_REPOSITORY=""
NOTES_REPOSITORY_VERSION=""
for arg in "$@"; do
  case $arg in
    --tag=*)
      TAG="${arg#*=}"
      ;;
    --notes-repository=*)
      NOTES_REPOSITORY="${arg#*=}"
      ;;
    --notes-repository-version=*)
      NOTES_REPOSITORY_VERSION="${arg#*=}"
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
CONTAINER_REF=${CONTAINER_REGISTRY}/openedx-notes:${TAG}
GITHUB_REPO=edx-notes-api

echo "Building and pushing images for ${APPNAME} to ${CONTAINER_REF}"

BUILD_EXTRA_ARGS=""
if [ -n "$NOTES_REPOSITORY" ]; then
  BUILD_EXTRA_ARGS+=" --build-arg NOTES_REPOSITORY=${NOTES_REPOSITORY}"
fi
if [ -n "$NOTES_REPOSITORY_VERSION" ]; then
  BUILD_EXTRA_ARGS+=" --build-arg NOTES_REPOSITORY_VERSION=${NOTES_REPOSITORY_VERSION}"
fi
docker build ${BUILD_EXTRA_ARGS} -t ${CONTAINER_REF} ${SCRIPT_DIR}/${GITHUB_REPO}

docker push ${CONTAINER_REF}
