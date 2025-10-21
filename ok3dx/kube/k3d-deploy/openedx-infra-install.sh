#!/bin/bash

set -e

echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh
echo "Installing helm charts for ${APPNAME}-infra in namespace ${NAMESPACE}"

# Check for additional values file
EXTRA_VALUES=""
if [ -f "${SCRIPT_DIR}/overrides-infra-local.yaml" ]; then
  EXTRA_VALUES="--values ${SCRIPT_DIR}/overrides-infra-local.yaml"
fi

LB_IP=$(docker network inspect k3d-${CLUSTERNAME} | jq -r ".[].Containers[] | select(.Name == \"k3d-${CLUSTERNAME}-serverlb\") | .IPv4Address | split(\"/\")[0]")
BACKUPS_LB_IP=$(docker network inspect k3d-${CLUSTERNAME} | jq -r ".[].Containers[] | select(.Name == \"k3d-${BACKUPS_CLUSTERNAME}-serverlb\") | .IPv4Address | split(\"/\")[0]")

helm upgrade --install ${APPNAME}-infra --namespace ${NAMESPACE} --create-namespace ${CHART_REPO}-infra \
  --values ${SCRIPT_DIR}/overrides-infra.yaml --values ${SCRIPT_DIR}/overrides-infra-dev.yaml ${EXTRA_VALUES} \
  --set openedx.dev.files.lbIP=${LB_IP} \
  --set openedx.dev.backups.lbIP=${BACKUPS_LB_IP} \

# Restart coredns to pick up any changes to the configmap
kubectl -n kube-system rollout restart deployment coredns

echo '---'
echo "Helm charts installed for ${APPNAME}-infra in namespace ${NAMESPACE}"
