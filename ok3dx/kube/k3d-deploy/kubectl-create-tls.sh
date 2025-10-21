#! /bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh

# doesn't seem to do any harm to just run this again, even though it "fails" if already installed
mkcert -install

kubectl --kubeconfig ${KUBECONFIG} config use-context k3d-${CLUSTERNAME}

kubectl create secret tls mkcert-ca-key-pair \
  --key "$(mkcert -CAROOT)"/rootCA-key.pem \
  --cert "$(mkcert -CAROOT)"/rootCA.pem -n cert-manager

kubectl -n cert-manager apply -f ${SCRIPT_DIR}/manifests/mkcert-issuer.yaml

echo '--- Automatic tls generation finished (for development ONLY)'
