#! /bin/bash

# Requirements:
# mkcert
# helm
# k3d
# kubectl
# git

set -e
echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh
echo "Creating k3d cluster for ${CLUSTERNAME}"

mkdir -p ${SCRIPT_DIR}/volumes

if [ -n "$(git status --porcelain)" ]; then
  echo "Please ensure there are no changes or untracked files before installing"
  exit 1
fi

# create the docker network if not present
# This is required to reduce the MTU in cases where using a VPN (namely wireguard)
EXISTING_NETWORK=$(docker network ls | grep " ${NETWORK} " || [[ $? == 1 ]])
if [ -z "${EXISTING_NETWORK}" ]; then
  echo "Network ${NETWORK} not found, creating"
  # docker network create --opt com.docker.network.driver.mtu=1400 ${NETWORK}
  docker network create --opt com.docker.network.driver.mtu=1400 --driver bridge --subnet 172.18.0.0/24 --gateway 172.18.0.1 ${NETWORK}
fi

REGISTRY_CONFIG_FILE=${SCRIPT_DIR}/registries.yaml
if [ -f ${REGISTRY_CONFIG_FILE} ]; then
  echo "Using registry config file ${REGISTRY_CONFIG_FILE}"
  REGISTRY_CONFIG="--registry-config ${REGISTRY_CONFIG_FILE}"
else
  REGISTRY_CONFIG=""
fi

if [ -z "${K3S_IMAGE_NAME}" ]; then
  K3S_IMAGE="--image docker.io/rancher/k3s:v1.34.2-k3s1"
else
  K3S_IMAGE="--image ${K3S_IMAGE_NAME}"
fi

echo "Creating cluster with image: ${K3S_IMAGE}"

mkdir -p ~/.kube

k3d cluster create ${CLUSTERNAME} --config ${SCRIPT_DIR}/k3d-ok3dx-config.yml \
  ${K3S_IMAGE} ${REGISTRY_CONFIG} \
  --network ${NETWORK} \
  --k3s-arg "--kube-controller-manager-arg=node-cidr-mask-size-ipv4=21@server:*" \
  --volume ${SCRIPT_DIR}/volumes:/opt/${APPNAME}/volumes@all \
  --volume ${SCRIPT_DIR}/../../workspaces:/workspaces@all \
  --volume ${SCRIPT_DIR}/../../workspaces/apps/edx-platform:/openedx/edx-platform@all \
  --volume ${SCRIPT_DIR}/../../workspaces/mnt:/mnt@all

# TODO: put this back when we have a better solution for local volumes
# declare -a DIRECTORIES=(${APPNAME}-db ${APPNAME}-documentdb ${APPNAME}-minio ${APPNAME}-backups ${APPNAME}-meilisearch)
# declare -a DIRECTORIES=(${APPNAME}-db ${APPNAME}-documentdb ${APPNAME}-minio ${APPNAME}-backups ${APPNAME}-meilisearch)
# mkdir -p "${SCRIPT_DIR}/volumes/${DIRECTORIES[@]}"
# sudo chmod 777 "${SCRIPT_DIR}/volumes/${DIRECTORIES[@]}"

k3d kubeconfig merge ${CLUSTERNAME} --output ${KUBECONFIG}
kubectl --kubeconfig ${KUBECONFIG} config set-context ${MAIN_CONTEXT} --namespace=${NAMESPACE}
kubectl config use-context ${MAIN_CONTEXT}

# dockerhub and some other sites can be extremely slow over ipv6 in certain situations
docker exec -i ${MAIN_CONTEXT}-server-0 sysctl -w net.ipv6.conf.all.disable_ipv6=1

echo '--- Creating namespaces'
echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: ${NAMESPACE}" | kubectl --context ${MAIN_CONTEXT} apply -f -
echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: ${INGRESS_NAMESPACE}" | kubectl --context ${MAIN_CONTEXT} apply -f -
echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: cert-manager" | kubectl apply --context ${MAIN_CONTEXT} -f -

echo '--- Applying secrets'
kubectl --context ${MAIN_CONTEXT} -n ${NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx/
kubectl --context ${MAIN_CONTEXT} -n ${NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-infra/
kubectl --context ${MAIN_CONTEXT} -n ${NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-shared/

mkcert -install
export CAROOT=$(mkcert -CAROOT)
echo '--- Setting up mkcert for automatic TLS generation (for development ONLY)'
kubectl --context ${MAIN_CONTEXT} -n cert-manager create secret tls mkcert-ca-key-pair \
  --key "${CAROOT}/rootCA-key.pem" \
  --cert "${CAROOT}/rootCA.pem"

echo '--- Automatic secrets generation finished (for development ONLY)'

export LB_IP=$(docker network inspect ${NETWORK} | jq -r ".[].Containers[] | select(.Name == \"k3d-${CLUSTERNAME}-serverlb\") | .IPv4Address | split(\"/\")[0]")
export GATEWAY_IP=$(docker network inspect ${NETWORK} | jq -r ".[].IPAM.Config[0].Gateway")
export BACKUPS_LB_IP=$(docker network inspect ${NETWORK} | jq -r ".[].Containers[] | select(.Name == \"k3d-${BACKUPS_CLUSTERNAME}-serverlb\") | .IPv4Address | split(\"/\")[0]")
export MINIO_HOST=files.${LOCALHOST_NAME}
export BACKUPS_HOST=backups.${LOCALHOST_NAME}

echo "Load balancer IP address detected: ${LB_IP}, backups LB IP: ${BACKUPS_LB_IP}"

helmfile --kubeconfig ${KUBECONFIG} --kube-context ${MAIN_CONTEXT} --environment dev \
  -f ${SCRIPT_DIR}/../helmfile/helmfile-cluster-infra.yaml.gotmpl sync --include-transitive-needs

# helmfile --kubeconfig ${KUBECONFIG} --kube-context ${MAIN_CONTEXT} --environment dev \
#   -f ${SCRIPT_DIR}/../helmfile/helmfile.yaml.gotmpl sync --include-transitive-needs

echo "Cluster ${CLUSTERNAME} created successfully"
