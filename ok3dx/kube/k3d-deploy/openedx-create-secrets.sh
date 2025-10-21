#! /bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh

kubectl config use-context k3d-${CLUSTERNAME}

echo '--- Creating namespaces'
echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: ${NAMESPACE}" | kubectl apply -f -
echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: ${INGRESS_NAMESPACE}" | kubectl apply -f -

echo '--- Applying secrets'
kubectl -n ${NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx/
kubectl -n ${NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-infra/
kubectl -n ${NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-shared/

kubectl config use-context k3d-${BACKUPS_CLUSTERNAME}
echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: ${BACKUPS_NAMESPACE}" | kubectl apply -f -
kubectl -n ${BACKUPS_NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-backups/
kubectl -n ${BACKUPS_NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-shared/


echo '--- Automatic secrets generation finished (for development ONLY)'
