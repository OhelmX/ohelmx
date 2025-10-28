#!/bin/bash

set -e

echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh
echo "Installing helm charts for ${APPNAME} in namespace ${NAMESPACE}"

# Check for additional values file
EXTRA_VALUES=""
if [ -f "${SCRIPT_DIR}/overrides-local.yaml" ]; then
  EXTRA_VALUES="--values ${SCRIPT_DIR}/overrides-local.yaml"
fi

kubectl config use-context k3d-${CLUSTERNAME}

helm upgrade --install ${APPNAME} --namespace ${NAMESPACE} --create-namespace ${CHART_REPO} \
  --values ${SCRIPT_DIR}/overrides-dev.yaml ${EXTRA_VALUES}

echo '---'
echo "Helm charts installed for ${APPNAME} in namespace ${NAMESPACE}"
