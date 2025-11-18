#!/bin/bash

set -e

echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh
echo "Installing helm charts for ${APPNAME} in namespace ${NAMESPACE}"

export LB_IP=$(docker network inspect ${NETWORK} | jq -r ".[].Containers[] | select(.Name == \"k3d-${CLUSTERNAME}-serverlb\") | .IPv4Address | split(\"/\")[0]")
export GATEWAY_IP=$(docker network inspect ${NETWORK} | jq -r ".[].IPAM.Config[0].Gateway")
export BACKUPS_LB_IP=$(docker network inspect ${NETWORK} | jq -r ".[].Containers[] | select(.Name == \"k3d-${BACKUPS_CLUSTERNAME}-serverlb\") | .IPv4Address | split(\"/\")[0]")
export MINIO_HOST=files.${LOCALHOST_NAME}
export BACKUPS_HOST=backups.${LOCALHOST_NAME}

echo "Using LB_IP=${LB_IP}, GATEWAY_IP=${GATEWAY_IP}, BACKUPS_LB_IP=${BACKUPS_LB_IP}, MINIO_HOST=${MINIO_HOST}, BACKUPS_HOST=${BACKUPS_HOST}"

helmfile --kubeconfig ${KUBECONFIG} --kube-context ${MAIN_CONTEXT} --environment dev \
  -f ${SCRIPT_DIR}/../helmfile/helmfile.yaml.gotmpl apply --skip-deps

echo '---'
echo "Helm charts installed for ${APPNAME} in namespace ${NAMESPACE}"
