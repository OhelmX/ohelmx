#!/bin/bash

# Pre-install steps before executing openedx-install.sh

set -e

echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh
echo "Pre-install steps for ${APPNAME} in namespace ${NAMESPACE}"

helmfile -f ${SCRIPT_DIR}/helmfile.yaml.gotmpl sync
