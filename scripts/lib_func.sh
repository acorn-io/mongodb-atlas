#!/bin/sh

TERMINATION_LOG="/dev/termination-log"
ACORN_OUTPUT="/run/secrets/output"

disk_size_arg() {
  if [ -n "${DISK_SIZE_GB}" ]; then
    echo "diskSizeGB ${DISK_SIZE_GB}"
  fi
}

db_user_update() {
  res=$(atlas dbusers update $@)
  if [ $? -ne 0 ]; then
    echo $res
  fi
}

db_user_create() {
  res=$(atlas dbusers create "$@")
  if [ $? -ne 0 ]; then
    echo $res
  fi
}

db_user_acorn_managed() {
  local generated_db_user=$(sanitize_name "${GENERATED_DB_USER}")
  local generated_root_user=$(sanitize_name "${GENERATED_ROOT_USER}")
  if [ "${1}" = "${generated_db_user}" ] || [ "${1}" = "${generated_root_user}" ]; then
    return 0
  fi
  return 1
}

db_user_exists() {
  atlas dbusers describe $1 2>&1 >/dev/null
  return $?
}

sanitize_name() {
  echo "${1//./-}"
}

check_cluster_exists() {
    local generated_cluster_name=$(sanitize_name "${GENERATED_CLUSTER_NAME}")
    local cluster_name=$(sanitize_name "${1}")
    # Check if the cluster should be managed by Acorn
    atlas cluster describe $cluster_name > /dev/null 2>&1
    if [ $? -ne 0 ] && [ "${cluster_name}" = "${generated_cluster_name}" ]; then
      return 1
    fi

    if [ "${cluster_name}" != "${generated_cluster_name}" ]; then
      return 2
    fi

    # Check if the "acorn_external_id" tag exists and has the correct value
    if atlas cluster describe $cluster_name -o json | jq '.tags | map(select(.key == "acorn_external_id" and .value == env.ACORN_EXTERNAL_ID)) | any'; then
        # "The 'acorn_external_id' tag exists and has the correct value."
        return 0
    else
        # "The 'acorn_external_id' tag does not exist or has an incorrect value."
        return 3
    fi
}

create_cluster() {
    disk_arg=$(disk_size_arg)
    local cluster_name=$(sanitize_name "${CLUSTER_NAME}")
    # Create a cluster in the current project
    echo "-> about to create cluster ${cluster_name} of type ${TIER} in ${PROVIDER} / ${REGION}"
    result=$(atlas cluster create "${cluster_name}" \
            --region "$REGION" --provider "$PROVIDER" \
            --tier "$TIER" --tag acorn_external_id=${ACORN_EXTERNAL_ID} \
            --mdbVersion "$DB_VERSION" --${disk_arg} 2>&1)
  
    # Make sure the cluster was created correctly
    if [ $? -ne 0 ]; then
      echo $result | tee ${TERMINATION_LOG}
      exit 1
    fi
  
    # Wait for Atlas to provide cluster's connection string
    echo "-> waiting for database address"
    while true; do
      DB_ADDRESS=$(atlas cluster describe ${cluster_name} -o json | jq -r .connectionStrings.standardSrv)
      if [ "${DB_ADDRESS}" = "null" ]; then
          sleep 2
          echo "... retrying"
      else
        break
      fi
    done
}

update_cluster() {
    local cluster_name=$(sanitize_name "${CLUSTER_NAME}")
    if atlas cluster get ${cluster_name} -o json 2>&1 | grep ${TIER} > /dev/null ; then
        echo "-> cluster ${cluster_name} already has the correct tier"
    else
        echo "-> updating cluster ${cluster_name} of type ${TIER} in ${PROVIDER} / ${REGION}"
        disk_arg=$(disk_size_arg)
        echo ${disk_arg}
        result=$(atlas cluster upgrade "${cluster_name}" --tier ${TIER} \
                 --tag acorn_external_id=${ACORN_EXTERNAL_ID} \
                 --mdbVersion $DB_VERSION \
                 ${disk_arg} 2>&1)
        if [ $? -ne 0 ]; then
          echo $result | tee /dev/termination_log
          exit 1
        fi
    fi
}

render_service() {
  local cluster_name=$(sanitize_name $1)
  local db_name=${DB_NAME}

  DB_ADDRESS=$(atlas cluster describe ${cluster_name} -o json | jq -r .connectionStrings.standardSrv)
  DB_PROTO=$(echo $DB_ADDRESS | cut -d':' -f1)
  DB_HOST=$(echo $DB_ADDRESS | cut -d'/' -f3)
  echo "DB_ADDRESS: [${DB_ADDRESS}] / DB_PROTO:[${DB_PROTO}] / DB_HOST:[${DB_HOST}]"

  cat > /run/secrets/output<<EOF
services: atlas: {
  address: "${DB_HOST}"
  default: true
  secrets: ["admin", "user"]
  ports: "27017"
  data: {
    proto: "${DB_PROTO}"
    dbName: "${db_name}"
  }
}

secrets: admin: {
  type: "basic"
  data: {
    username: "$(sanitize_name ${DB_ROOT_USER})"
    password: "${DB_ROOT_PASS}"
  }
}

secrets: user: {
  type: "basic"
  data: {
    username: "$(sanitize_name ${DB_USER})"
    password: "${DB_PASS}"
  }
}
EOF
}