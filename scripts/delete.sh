#!/bin/sh
# set -eo pipefail

echo "-> [delete.sh]"

# Make sure this script only repply on an Acorn deletion event
if [ "${ACORN_EVENT}" != "delete" ]; then
   echo "ACORN_EVENT must be [delete], currently is [${ACORN_EVENT}]"
   exit 0
fi

# Make sure the cluster exists
atlas cluster get ${CLUSTER_NAME} 2>/dev/null
if [ $? -ne 0 ]; then
  echo "cluster ${CLUSTER_NAME} does not exist"
  exit 0
fi

# Delete the cluster
echo "-> deleting cluster ${CLUSTER_NAME}"
res=$(atlas cluster delete --force ${CLUSTER_NAME})
if [ $? -ne 0 ]; then
  echo $res
fi

# Delete user
echo "-> deleting associated user ${DB_USER}"
res=$(atlas dbusers delete --force ${DB_USER})
if [ $? -ne 0 ]; then
  echo $res
fi