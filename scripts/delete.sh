#!/bin/sh
# set -eo pipefail

echo "[delete.sh]"

# Make sure this script only replies to an Acorn deletion event
if [ "${ACORN_EVENT}" != "delete" ]; then
   echo "ACORN_EVENT must be [delete], currently is [${ACORN_EVENT}]"
   exit 0
fi

# Make sure a cluster with the name provided exists
cluster=$(atlas cluster list -o json | jq -r --arg cluster_name "$CLUSTER_NAME" '
  if .results then
    .results[] | select(.name == $cluster_name)
  else
    empty
  end
')
if [ "$cluster" = "" ]; then
  echo "cluster ${CLUSTER_NAME} does not exists" | tee /dev/termination-log
  exit 1
fi 
echo "cluster ${CLUSTER_NAME} found"

# Make sure the cluster retrieved has the correct acornid tag
cluster_acorn_id=$(echo $cluster | jq -r '.tags[] | select(.key == "acornid") | .value')
if [ "$cluster_acorn_id" != "$ACORN_EXTERNAL_ID" ]; then
  echo "cluster ${CLUSTER_NAME} does not have the correct Acorn ID ($ACORN_EXTERNAL_ID) => atlas cluster will not be deleted"
  exit 0
fi
echo "cluster ${CLUSTER_NAME} has the correct Acorn ID ($ACORN_EXTERNAL_ID)"

# Delete the cluster
echo "deleting cluster ${CLUSTER_NAME}"
res=$(atlas cluster delete --force ${CLUSTER_NAME})
if [ $? -ne 0 ]; then
  echo "error deleting cluster: $res"
else
  echo "cluster deleted" 
fi

# Delete root user if created by this service
if [ "${CREATED_DB_ROOT_USER}" != "" ]; then
  echo "deleting db root user ${CREATED_DB_ROOT_USER}"
  res=$(atlas dbusers delete --force ${CREATED_DB_ROOT_USER})
  if [ $? -ne 0 ]; then
    echo "error deleting dbuser: $res"
  else
    echo "db root user deleted"
  fi
else
  echo "no root user to delete as none was created by this service"
fi 

# Delete user if created by this service
if [ "${CREATED_DB_USER}" != "" ]; then
  echo "deleting db user ${CREATED_DB_USER}"
  res=$(atlas dbusers delete --force ${CREATED_DB_USER})
  if [ $? -ne 0 ]; then
    echo "error deleting dbuser: $res"
  else
    echo "db user deleted"
  fi
else
  echo "no user to delete as none was created by this service"
fi 