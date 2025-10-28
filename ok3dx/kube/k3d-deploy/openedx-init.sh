#!/bin/bash

set -e

echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh
echo "Initing openedx for ${APPNAME} in namespace ${NAMESPACE}"

# argo submit --from workflowtemplate/openedx-init-workflow-template -n ${NAMESPACE} && argo logs -f @latest

kubectl config use-context k3d-${CLUSTERNAME}

echo -e "apiVersion: argoproj.io/v1alpha1\nkind: Workflow\nmetadata:\n  name: openedx-init-$(date +"%Y%m%d%H%M%S")\nspec:\n  workflowTemplateRef:\n    name: openedx-init-workflow-template" | kubectl apply -f -

echo '---'
echo "Inited openedx for ${APPNAME} in namespace ${NAMESPACE}"
