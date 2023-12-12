#!/bin/sh
# set -eo pipefail

echo "[delete.sh]"

# Make sure this script only replies to an Acorn deletion event
if [ "${ACORN_EVENT}" != "delete" ]; then
   echo "ACORN_EVENT must be [delete], currently is [${ACORN_EVENT}]"
   exit 0
fi

# Delete the cluster (if created by this service)
if [ "${CREATED_CLUSTER}" != "" ]; then
  echo "deleting cluster ${CREATED_CLUSTER}"
  res=$(atlas cluster delete --force ${CLUSTER_NAME})
  if [ $? -ne 0 ]; then
    echo "error deleting cluster: $res"
  else
    echo "cluster deleted" 
  fi
else
  echo "no cluster created by the service"
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