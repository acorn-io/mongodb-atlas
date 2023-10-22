#!/bin/sh
# set -eo pipefail

echo "-> [create.sh][${ACORN_EVENT}]"

# Check if cluster with that name already exit
atlas cluster get ${CLUSTER_NAME} 2>/dev/null
if [ $? -eq 0 ]; then
  echo "-> cluster ${CLUSTER_NAME} already exists"

  DB_ADDRESS=$(atlas cluster describe ${CLUSTER_NAME} -o json | jq -r .connectionStrings.standardSrv)
  DB_PROTO=$(echo $DB_ADDRESS | cut -d':' -f1)
  DB_HOST=$(echo $DB_ADDRESS | cut -d'/' -f3)
  echo "DB_ADDRESS: [${DB_ADDRESS}] / DB_PROTO:[${DB_PROTO}] / DB_HOST:[${DB_HOST}]"

  cat > /tmp/run/secrets/output<<EOF
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
echo "-> about to create a ${TIER} cluster on provider ${PROVIDER} in region ${REGION}"
result=$(atlas cluster create ${CLUSTER_NAME} --region $REGION --provider $PROVIDER --tier $TIER --tag creator=acorn_service --mdbVersion $DB_VERSION)

# Make sure the cluster was created correctly
if [ $? -ne 0 ]; then
  echo $result
  exit 1
fi

# Wait for Atlas to provide cluster's connection string
while true; do
  DB_ADDRESS=$(atlas cluster describe ${CLUSTER_NAME} -o json | jq -r .connectionStrings.standardSrv)
  echo ${DB_ADDRESS}
  if [ "${DB_ADDRESS}" = "null" ]; then
      sleep 2
  else
    break
  fi
done

# Allow database network access from current IP
atlas accessList create --currentIp

# Create db user
atlas dbusers create --username ${DB_USER} --password ${DB_PASS} --role readWrite@${DB_NAME}

# Extract proto and host from address returned
DB_PROTO=$(echo $DB_ADDRESS | cut -d':' -f1)
DB_HOST=$(echo $DB_ADDRESS | cut -d'/' -f3)
echo "DB_ADDRESS: [${DB_ADDRESS}] / DB_PROTO:[${DB_PROTO}] / DB_HOST:[${DB_HOST}]"

cat > /tmp/run/secrets/output<<EOF
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