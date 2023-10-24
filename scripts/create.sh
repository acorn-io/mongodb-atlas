#!/bin/sh
# set -eo pipefail

echo "-> [create.sh]"

# Make sure this script only repply on an Acorn creation event
if [ "${ACORN_EVENT}" != "create" ]; then
   echo "ACORN_EVENT must be [create], currently is [${ACORN_EVENT}]"
   exit 0
fi

# Check if cluster with that name already exit
atlas cluster get ${CLUSTER_NAME} 2>/dev/null
if [ $? -eq 0 ]; then
  echo "-> cluster ${CLUSTER_NAME} already exists"

  DB_ADDRESS=$(atlas cluster describe ${CLUSTER_NAME} -o json | jq -r .connectionStrings.standardSrv)
  DB_PROTO=$(echo $DB_ADDRESS | cut -d':' -f1)
  DB_HOST=$(echo $DB_ADDRESS | cut -d'/' -f3)
  echo "DB_ADDRESS: [${DB_ADDRESS}] / DB_PROTO:[${DB_PROTO}] / DB_HOST:[${DB_HOST}]"

  cat > /run/secrets/output<<EOF
  services: atlas: {
    address: "${DB_HOST}"
    secrets: ["user"]
    ports: "27017"
    data: {
      proto: "${DB_PROTO}"
      dbName: "${DB_NAME}"
    }
  }
EOF
  exit 0
else
  echo "-> cluster ${CLUSTER_NAME} does not exist"
fi

# Create a cluster in the current project
echo "-> about to create cluster ${CLUSTER_NAME} of type ${TIER} in ${PROVIDER} / ${REGION}"
result=$(atlas cluster create ${CLUSTER_NAME} --region $REGION --provider $PROVIDER --tier $TIER --tag creator=acorn_service --mdbVersion $DB_VERSION)

# Make sure the cluster was created correctly
if [ $? -ne 0 ]; then
  echo $result
  exit 1
fi

# Wait for Atlas to provide cluster's connection string
echo "-> waiting for database address"
while true; do
  DB_ADDRESS=$(atlas cluster describe ${CLUSTER_NAME} -o json | jq -r .connectionStrings.standardSrv)
  if [ "${DB_ADDRESS}" = "null" ]; then
      sleep 2
      echo "... retrying"
  else
    break
  fi
done

# Allow database network access from current IP
echo "-> allowing connection from current IP address"
res=$(atlas accessList create --currentIp)
if [ $? -ne 0 ]; then
  echo $res
fi

# Create db user
echo "-> creating a database user"
res=$(atlas dbusers create --username ${DB_USER} --password ${DB_PASS} --role readWrite@${DB_NAME})
if [ $? -ne 0 ]; then
  echo $res
fi

# Extract proto and host from address returned
DB_PROTO=$(echo $DB_ADDRESS | cut -d':' -f1)
DB_HOST=$(echo $DB_ADDRESS | cut -d'/' -f3)
echo "-> connection string: [${DB_PROTO}://${DB_USER}:${DB_PASS}@${DB_HOST}]"

cat > /run/secrets/output<<EOF
services: atlas: {
  address: "${DB_HOST}"
  secrets: ["user"]
  ports: "27017"
  data: {
    proto: "${DB_PROTO}"
    dbName: "${DB_NAME}"
  }
}
EOF