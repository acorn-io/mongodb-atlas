## Purpose

This folder defines an Acorn service which allows to create a Mongo Atlas cluster on the fly. 

In this very early version each cluster created by the service has the following characteristics, they are currently hardcoded but will soon become service's arguments:

- cloud provider: AWS 
- region: EU_WEST_1
- tier: M0

Notes:
- only one M0 cluster can be created in each Atlas project
- for cluster other than M0 tier billing information needs to be provided in Atlas

## Prerequisites

To use this service you need to have an Atlas Mongo account, to create an organization and a project within this one.

Note: this example uses an organization named *Techwhale* containing the project *webhooks*

Next create a public / private api key pair at the organization level

![Organization api keys](./images/organization-api-keys.png)

Next get the project ID

![Getting project ID](./images/project-id.png)

For this demo I set those 3 values in the following environment variables:

- MONGODB_ATLAS_PUBLIC_API_KEY
- MONGODB_ATLAS_PRIVATE_API_KEY
- MONGODB_ATLAS_PROJECT_ID

## Running the service

First we need to create the secret *atlas-creds* providing the public and private keys as well as the Atlas project ID we want the MongoDB cluster to be created in.

Note: the following example uses environment variables already defined in the current shell 

```
acorn secrets create \
  --type opaque \
  --data public_key=$MONGODB_ATLAS_PUBLIC_API_KEY \
  --data private_key=$MONGODB_ATLAS_PRIVATE_API_KEY \
  --data project_id=$MONGODB_ATLAS_PROJECT_ID \
  atlas-creds
```

Next we run the Acorn:

```
acorn run -n atlas .
```

In a few tens of seconds a new Atlas cluster will be up and running.

![Cluster created](./images/cluster-created.png)

Running the service directly was just a test to ensure a cluster is actually created from this service.

Then we can delete the application, this will also delete the associated Atlas cluster:

```
acorn rm atlas --all --force
```

Note: Also, from the Atlas dashboard, we make sure to delete the cluster as we will create a new one in a next section.

Please check in the examples fodler how to use this service.

## Status

This service is currently a WIP, feel free to give it a try. Feedback are welcome.