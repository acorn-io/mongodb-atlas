#!/bin/sh
# set -eo pipefail

echo "-> [delete.sh][${ACORN_EVENT}]"

# Make sure correct event is sent to the deletion job
if [ "$ACORN_EVENT" = "delete" ]; then
  # Make sure the cluster exists
  atlas cluster get ${CLUSTER_NAME} 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "cluster ${CLUSTER_NAME} does not exist"
    exit 0
  fi

  # Delete the cluster
  atlas cluster delete --force ${CLUSTER_NAME}

  # Delete user
  atlas dbusers delete --force ${DB_USER}

fi