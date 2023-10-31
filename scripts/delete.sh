#!/bin/sh
# set -eo pipefail

echo "-> [delete.sh]"

# Make sure this script only repply on an Acorn deletion event
if [ "${ACORN_EVENT}" != "delete" ]; then
   echo "ACORN_EVENT must be [delete], currently is [${ACORN_EVENT}]"
   exit 0
fi

# Make sure the project with that ID exists
echo "-> checking if project [${PROJECT_NAME}](${PROJECT_ID}) exists"
res=$(atlas project list -o json | jq -r --arg project_id "$PROJECT_ID" --arg project_name "$PROJECT_NAME" '.results[] | select(.id == $project_id and .name == $project_name)')
if [ "$res" = "" ]; then
  echo "-> project [${PROJECT_NAME}](${PROJECT_ID}) does not exist"
  exit 1
fi

# Delete cluster first (project cannot be deleted if a cluster is running)
echo "-> deleting cluster ${CLUSTER_NAME} in project [${PROJECT_NAME}](${PROJECT_ID})"

# Make sure cluster exists first
res=$(atlas cluster get --projectId $PROJECT_ID ${CLUSTER_NAME} 2>/dev/null)
if [ "$res" = "" ]; then
  echo "-> cluster ${CLUSTER_NAME} does not exist"
else
  echo "-> cluster ${CLUSTER_NAME} does exist"
  # Delete cluster
  res=$(atlas cluster delete --force --projectId $PROJECT_ID ${CLUSTER_NAME})
  if [ $? -ne 0 ]; then
    echo $res
    exit 1
  fi

  # Wait for deletion process to be terminated
  echo "-> waiting for deletion process to terminate"
  while true; do
    res=$(atlas cluster get ${CLUSTER_NAME} --projectId ${PROJECT_ID} 2>/dev/null)
    if [ "$res" != "" ]; then
        sleep 2
        echo "... still waiting"
    else
      break
    fi
  done
  echo "-> cluster ${CLUSTER_NAME} deleted from project [${PROJECT_NAME}](${PROJECT_ID})"
fi

# Delete the project
echo "-> deleting project [${PROJECT_NAME}](${PROJECT_ID})"
res=$(atlas project delete --force ${PROJECT_ID})
if [ $? -ne 0 ]; then
  echo $res
  exit 1
fi
echo "-> project [${PROJECT_NAME}](${PROJECT_ID}) deleted"