#!/bin/sh
set -eo pipefail

echo "-> running render.sh with EVENT ${ACORN_EVENT}"

if [ "$ACORN_EVENT" = "delete" ]; then
  # Make sure to delete the cluster only once (in case the job is triggered multiple time)
  (atlas cluster delete --force test || true)
  exit 0
fi

# Create a cluster in the current project
echo "-> about to create a ${TIER} cluster on provider ${PROVIDER} in region ${REGION}"
result=$(atlas cluster create test --region $REGION --provider $PROVIDER --tier $TIER)

# Make sure the cluster was created correctly
if [ $? -ne 0 ]; then
  echo $result
  exit 1
fi

# Wait for Atlas to provide cluster's connection string
while true; do
  DB_ADDRESS=$(atlas cluster describe test -o json | jq -r .connectionStrings.standardSrv)
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

cat > /run/secrets/output<<EOF
services: atlas: {
  address: "${DB_HOST}"
  secrets: ["user"]
  data: {
    proto: "${DB_PROTO}"
    dbName: "${DB_NAME}"
  }
}
secrets: "user": {
  type: "basic"
  data: {
    username: "${DB_USER}"
    password: "${DB_PASS}"
  }
}
EOF