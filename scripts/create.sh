#!/bin/sh
# set -eox pipefail

echo "[create.sh]"

. $(dirname $0)/lib_func.sh

# Couple of variables to make local testing simpler
TERMINATION_LOG="/dev/termination-log"
ACORN_OUTPUT="/run/secrets/output"

# Make sure this script is only triggered on Acorn creation and update events
echo "event: ${ACORN_EVENT}"
if [ "${ACORN_EVENT}" = "delete" ]; then
   echo "ACORN_EVENT must be [create/update], currently is [${ACORN_EVENT}]"
   exit 0
fi

# Use uppercase values for TIER / PROVIDER / REGION in case user specified lowercase ones
TIER=$(echo $TIER | tr a-z A-Z)
PROVIDER=$(echo $PROVIDER | tr a-z A-Z)
REGION=$(echo $REGION | tr a-z A-Z)

check_cluster_exists "${CLUSTER_NAME}"
cluster_exists_response=$?

case ${cluster_exists_response} in
  0)
    echo "cluster ${CLUSTER_NAME} exists and belongs to this external id"
    update_cluster
    ;;
  1)
    echo "cluster ${CLUSTER_NAME} needs to be created"
    create_cluster
    ;;
  2)
    echo "Cluster ${CLUSTER_NAME} exists, will use it"
    ;;
  3)
    echo "cluster ${CLUSTER_NAME} exists, but provisioned by another Acorn"| tee ${TERMINATION_LOG}
    exit 1
    ;;
  4)
    echo "cluster ${CLUSTER_NAME} doesn't exist in atlas, need to create cluster in Atlas first" | tee ${TERMINATION_LOG}
    exit 1
    ;;
  *)
    echo "unknown response from check_cluster_exists: ${cluster_exists_response}" | tee ${TERMINATION_LOG}
    exit 1
    ;;
esac

# Allow database network access from current IP
echo "allowing connection from current IP address"
res=$(atlas accessList create --currentIp)
if [ $? -ne 0 ]; then
  echo $res
fi

# Handle admin db user
# check in atlas if the user exists
sanitized_db_root_user=$(sanitize_name "${DB_ROOT_USER}")
if db_user_exists "${sanitized_db_root_user}" && db_user_acorn_managed "${sanitized_db_root_user}"; then
  echo "-> user ${sanitized_db_root_user} already exist... updating"
  db_user_update "${sanitized_db_root_user}" --password "${DB_ROOT_PASS}" --role "dbAdmin@${DB_NAME},readWrite@${DB_NAME}"
fi
  
if ! db_user_exists "${sanitized_db_root_user}" && db_user_acorn_managed "${sanitized_db_root_user}"; then
  echo "-> creating user ${sanitized_db_root_user}"
  db_user_create --username "${sanitized_db_root_user}" --password "${DB_ROOT_PASS}" --role "dbAdmin@${DB_NAME},readWrite@${DB_NAME}"
fi

# handle db user
sanitized_db_user=$(sanitize_name "${DB_USER}")
if db_user_exists "${sanitized_db_user}" && db_user_acorn_managed "${sanitized_db_user}"; then
  echo "-> user ${sanitized_db_user} already exist... updating"
  db_user_update "${sanitized_db_user}" --password "${DB_PASS}" --role "readWrite@${DB_NAME}"
fi

if ! db_user_exists "${sanitized_db_user}" && db_user_acorn_managed "${sanitized_db_user}"; then
  echo "-> creating user ${sanitized_db_user}"
  db_user_create --username "${sanitized_db_user}" --password "${DB_PASS}" --role "readWrite@${DB_NAME}"
fi

render_service ${CLUSTER_NAME}