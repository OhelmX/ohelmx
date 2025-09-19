#! /bin/bash

set -e
echo '---'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${SCRIPT_DIR}/../../vars.sh

USERNAME=$1
EMAIL=$2
if [ -z "$USERNAME" ] || [ -z "$EMAIL" ]; then
  echo "Usage: $0 <username> <email>"
  exit 1
fi

echo "Creating staff superuser ${USERNAME} with email ${EMAIL}."

echo -n "Enter your password for the new user: "
read -s PASSWORD
echo
echo -n "Enter the password again: "
read -s PASSWORD2
if [ "$PASSWORD" != "$PASSWORD2" ]; then
  echo "Passwords do not match!"
  exit 1
fi

echo "---"
echo "Creating the user, please be patient, this may take a while depending on your servers and connection..."

POD_NAME=$(kubectl get pods -l app.kubernetes.io/component=lms -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it ${POD_NAME} -- env DJANGO_SUPERUSER_PASSWORD=${PASSWORD} ./manage.py lms createsuperuser --username ${USERNAME} --email ${EMAIL} --noinput >/dev/null
kubectl exec -it ${POD_NAME} -- ./manage.py lms manage_user  --superuser --staff ${USERNAME} ${EMAIL} >/dev/null

echo "User ${USERNAME} created successfully."
