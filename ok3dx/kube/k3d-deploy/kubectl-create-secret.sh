#! /bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh

domain_tls () {
  DOMAIN=$1
  CERT_NAME=$2
  CERT=${APPNAME}-${CERT_NAME}-cert
  echo "--- trying to (re)create secret for ${DOMAIN}"
  kubectl -n ${INGRESS_NAMESPACE} delete secret ${CERT} --ignore-not-found
  echo '---'
  mkcert -cert-file ${SCRIPT_DIR}/local-secrets/${DOMAIN}.pem -key-file ${SCRIPT_DIR}/local-secrets/${DOMAIN}-key.pem ${DOMAIN}
  kubectl -n ${INGRESS_NAMESPACE} create secret tls ${CERT} --key ${SCRIPT_DIR}/local-secrets/${DOMAIN}-key.pem --cert ${SCRIPT_DIR}/local-secrets/${DOMAIN}.pem
  echo "--- Hopefully (re)created ${DOMAIN}"
}

echo '--- Creating namespaces'
echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: ${NAMESPACE}" | kubectl apply -f -
echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: ${INGRESS_NAMESPACE}" | kubectl apply -f -
echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: ${BACKUPS_NAMESPACE}" | kubectl apply -f -

for i in $TLS_DOMAINS; do
  domain_tls ${i} "${i//./-}"
done

echo '--- Applying secrets'
kubectl -n ${NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx/
kubectl -n ${NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-infra/
kubectl -n ${NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-shared/
kubectl -n ${BACKUPS_NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-backups/
kubectl -n ${BACKUPS_NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-shared/

echo '--- Automatic secrets generation finished (for development ONLY)'
