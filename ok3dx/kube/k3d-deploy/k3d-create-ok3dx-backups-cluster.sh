#! /bin/bash

# Requirements:
# mkcert
# helm
# k3d
# kubectl
# git

# set -e
echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh
echo "Creating k3d cluster for ${BACKUPS_CLUSTERNAME}"

mkdir -p ${SCRIPT_DIR}/volumes

if [ -n "$(git status --porcelain)" ]; then
  echo "Please ensure there are no changes or untracked files before installing"
  exit 1
fi

# create the docker network if not present
# This is required to reduce the MTU in cases where using a VPN (namely wireguard)
EXISTING_NETWORK=$(docker network ls | grep " ${NETWORK} ")
if [ -z "${EXISTING_NETWORK}" ]; then
  echo "Network ${NETWORK} not found, creating"
  # docker network create --opt com.docker.network.driver.mtu=1400 ${NETWORK}
  docker network create --opt com.docker.network.driver.mtu=1400 --driver bridge --subnet 172.18.0.0/24 --gateway 172.18.0.1 ${NETWORK}
fi

if [ -z "${K3S_IMAGE_NAME}" ]; then
  K3S_IMAGE="--image docker.io/rancher/k3s:v1.34.2-k3s1"
else
  K3S_IMAGE="--image ${K3S_IMAGE_NAME}"
fi

echo "Creating cluster with image: ${K3S_IMAGE}"

mkdir -p ~/.kube

k3d cluster create ${BACKUPS_CLUSTERNAME} --config ${SCRIPT_DIR}/k3d-backups-config.yml \
  --k3s-arg "--kube-controller-manager-arg=node-cidr-mask-size-ipv4=21@server:*" \
  ${K3S_IMAGE} --network ${NETWORK}
k3d kubeconfig merge ${BACKUPS_CLUSTERNAME} --output ${KUBECONFIG}
kubectl --kubeconfig ${KUBECONFIG} config set-context ${BACKUPS_CONTEXT} --namespace=${BACKUPS_NAMESPACE}

# dockerhub and some other sites can be extremely slow over ipv6 in certain situations
docker exec -i ${BACKUPS_CONTEXT}-server-0 sysctl -w net.ipv6.conf.all.disable_ipv6=1

echo -e "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: ${BACKUPS_NAMESPACE}" | kubectl \
  --context ${BACKUPS_CONTEXT} apply -f -
kubectl --context ${BACKUPS_CONTEXT} -n ${BACKUPS_NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-backups/
kubectl --context ${BACKUPS_CONTEXT} -n ${BACKUPS_NAMESPACE} apply -f ${SCRIPT_DIR}/secrets/openedx-shared/

helmfile --kube-context ${BACKUPS_CONTEXT} -f ${SCRIPT_DIR}/../helmfile/helmfile-backups.yaml.gotmpl --environment dev \
  sync --include-transitive-needs

echo "Cluster ${BACKUPS_CLUSTERNAME} created successfully"
