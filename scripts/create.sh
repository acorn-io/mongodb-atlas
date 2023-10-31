#!/bin/sh
# set -eo pipefail

echo "-> [create.sh]"

# Make sure this script only replies on an Acorn creation event
if [ "${ACORN_EVENT}" != "create" ]; then
   echo "ACORN_EVENT must be [create], currently is [${ACORN_EVENT}]"
   exit 0
fi

# Check if project with that name does not already exit
res=$(atlas project list -o json | jq -r --arg project_name "$PROJECT_NAME" '.results[] | select(.name == $project_name)')
if [ "$res" != "" ]; then
  echo "-> project ${PROJECT_NAME} already exists"
  exit 1
fi 

# Create the project
echo "-> about to create project ${PROJECT_NAME}"
res=$(atlas project create ${PROJECT_NAME} -o json)
if [ $? -ne 0 ]; then
  echo $res
  exit 1
fi
echo "-> project ${PROJECT_NAME} created"

# Get project identifier
projectId=$(echo $res | jq -r '.id')
echo "-> project ${PROJECT_NAME} has id [$projectId]"

# Create a cluster
echo "-> about to create ${TIER} cluster named ${CLUSTER_NAME} in ${PROVIDER} / ${REGION} for project [${PROJECT_NAME}](${projectId})"
res=$(atlas cluster create ${CLUSTER_NAME} --projectId $projectId --region $REGION --provider $PROVIDER --tier $TIER --tag creator=acorn_service --mdbVersion $DB_VERSION)

# Make sure the cluster was created correctly
if [ $? -ne 0 ]; then
  echo $res
  exit 1
fi
echo "-> cluster ${CLUSTER_NAME} created in project [${PROJECT_NAME}](${projectId})"

# Wait for Atlas to provide cluster's connection string
echo "-> waiting for database address"
while true; do
  DB_ADDRESS=$(atlas cluster describe ${CLUSTER_NAME} --projectId $projectId -o json | jq -r .connectionStrings.standardSrv)
  if [ "${DB_ADDRESS}" = "null" ]; then
      sleep 2
      echo "... retrying"
  else
    break
  fi
done

# Allow database network access from current IP
echo "-> allowing connection from current IP address"
res=$(atlas accessList create --projectId $projectId --currentIp)
if [ $? -ne 0 ]; then
  echo $res
fi

# Create db user
echo "-> creating a database user named [${DB_USER}] with Read/Write role on database [${DB_NAME}]"
res=$(atlas dbusers create --projectId $projectId --username ${DB_USER} --password ${DB_PASS} --role readWrite@${DB_NAME})
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
secrets: state: {
  data: {
    project_name: "${PROJECT_NAME}"
    project_id:   "${projectId}"
    cluster_name: "${CLUSTER_NAME}"
  }
}
EOF