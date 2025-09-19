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

helm upgrade --install ${APPNAME}-infra --namespace ${NAMESPACE} --create-namespace ${CHART_REPO}-infra \
  --values ${SCRIPT_DIR}/infra.yaml ${EXTRA_VALUES}

echo '---'
echo "Helm charts installed for ${APPNAME}-infra in namespace ${NAMESPACE}"
