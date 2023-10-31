## Purpose

This folder defines an Acorn service which allows to create a Mongo Atlas cluster on the fly. 

In the current version:
- the service creates a new project
- a cluster with the following characteristics is created in that one: 
  - cloud provider: AWS 
  - region: US_EAST_1
  - tier: M0

Notes: for a cluster other than M0 tier billing information needs to be provided in Atlas

## Prerequisites

To use this service you need to have an Atlas Mongo account and to create an organization/

Note: this example uses an organization named *Techwhale* containing the project *webhooks*

Next create a public / private api key pair at the organization level

![Organization api keys](./images/organization-api-keys.png)

For this demo I set those 3 values in the following environment variables:

- MONGODB_ATLAS_PUBLIC_API_KEY
- MONGODB_ATLAS_PRIVATE_API_KEY
- MONGODB_ATLAS_ORG_ID

Next we need to create the secret *atlas-creds* providing the public / private keys created above as well as the organization id:

Note: the following example uses environment variables already defined in the current shell 

```
acorn secrets create \
  --type opaque \
  --data public_key=$MONGODB_ATLAS_PUBLIC_API_KEY \
  --data private_key=$MONGODB_ATLAS_PRIVATE_API_KEY \
  --data org_id=$MONGODB_ATLAS_ORG_ID \
  atlas-creds
```

## Usage

The [examples folder](https://github.com/acorn-io/mongodb-atlas/tree/main/examples) contains a sample application using this Service. This app consists in a Python backend based on the FastAPI library, it displays a web page indicating the number of times the application was called, a counter is saved in the underlying MongoDB database and incremented with each request. The screenshot below shows the UI of the example application. 

![UI](./examples/images/ui.png)

To use the Mongo Service, we first define a *service* property in the Acornfile of the application:

```
services: db: {
  image: "ghcr.io/acorn-io/mongodb-atlas:v#.#-#"
}
```

Next we define the application container. This one can connect to the MongoDB service via environment variables which values are set based on the service's properties.

```
containers: {
  app: {
    build: {
			context: "."
			target:  "dev"
		}
    consumes: ["db"]
    ports: publish: "8000/http"
    env: {
      DB_HOST:  "@{service.db.address}"
      DB_NAME:  "@{service.db.data.dbName}"
      DB_PROTO: "@{service.db.data.proto}"
      DB_USER:  "@{service.db.secrets.user.username}"
      DB_PASS:  "@{service.db.secrets.user.password}"
    }
  }
}
```

This container is built using the Dockerfile in the examples folder. Once built, the container consumes the MongoDB Atlas service using the address and credentials provided through via the dedicated variables.

This example can be run with the following command (to be run from the *examples* folder)

```
acorn run -n app
```

After a few tens of seconds an http endpoint will be returned. Using this endpoint we can access the application and see the counter incremented on each reload of the page.

## Running the app in Acorn Sandbox

Instead of managing your own Acorn installation, you can deploy this application in the Acorn Sandbox, the free SaaS offering provided by Acorn. Access to the sandbox requires only a GitHub account, which is used for authentication.

[![Run in Acorn](https://acorn.io/v1-ui/run/badge?image=ghcr.io+acorn-io+mongodb-atlas+examples:v%23.%23-%23)](https://acorn.io/run/ghcr.io/acorn-io/mongodb-atlas/examples:v%23.%23-%23)

An application running in the Sandbox will automatically shut down after 2 hours, but you can use the Acorn Pro plan to remove the time limit and gain additional functionalities.

## Status

This service is still a work in progress. Feedback are welcome.