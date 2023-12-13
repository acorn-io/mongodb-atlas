#!/bin/sh
# set -eo pipefail

#set -x

echo "[delete.sh]"

. $(dirname $0)/lib_func.sh

# Make sure this script only replies to an Acorn deletion event
if [ "${ACORN_EVENT}" != "delete" ]; then
   echo "ACORN_EVENT must be [delete], currently is [${ACORN_EVENT}]"
   exit 0
fi

SKIPPED="false"
sanitized_generated_cluster_name=$(sanitize_name "${GENERATED_CLUSTER_NAME}")
sanitized_generated_root_user=$(sanitize_name "${GENERATED_ROOT_USER}")
sanitized_generated_db_user=$(sanitize_name "${GENERATED_DB_USER}")

# Delete the cluster (if created by this service)
cluster_exists_response=$(check_cluster_exists "${sanitized_generated_cluster_name}")
if [ $? -eq 0 ]; then
  echo "deleting cluster ${sanitized_generated_cluster_name}"
  res=$(atlas cluster delete --force ${sanitized_generated_cluster_name})
  if [ $? -ne 0 ]; then
    echo "error deleting cluster: $res"
  else
    echo "cluster deleted" 
  fi
else
  echo "This was an existing cluster created outside of Acorn service... skipping delete in Atlas."
  SKIPPED="true"
fi

# Delete root user if created by this service
if db_user_exists "${sanitized_generated_root_user}"; then
  echo "deleting db root user ${sanitized_generated_root_user}"
  res=$(atlas dbusers delete --force ${sanitized_generated_root_user})
  if [ $? -ne 0 ]; then
    echo "error deleting dbuser: $res"
  else
    echo "db root user deleted"
  fi
else
  echo "root user was created outside of Acorn service... skipping delete in Atlas."
  SKIPPED="true"
fi 

# Delete user if created by this service
if db_user_acorn_managed "${sanitized_generated_db_user}"; then
  echo "deleting db user ${sanitized_generated_db_user}"
  res=$(atlas dbusers delete --force ${sanitized_generated_db_user})
  if [ $? -ne 0 ]; then
    echo "error deleting dbuser: $res"
  else
    echo "db user deleted"
  fi
else
  echo "user was created outside of Acorn service... skipping delete in Atlas."
  SKIPPED="true"
fi 

if [ "${SKIPPED}" == "true" ]; then
  echo "Existing resources were not deleted by Acorn, you must go to Atlas console to delete those."
fi