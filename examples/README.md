## Using the service

We need to create a secret containing the atlas api keys (this secret will allow the job to connect to the Atlas account).

Notes:
- the following example uses environment variables already defined in the current shell (see main [../README.md](../README.md))
- if you have already created the secret in the previous step there is no need to run the command once again

```
acorn secrets create \
  --type opaque \
  --data public_key=$MONGODB_ATLAS_PUBLIC_API_KEY \
  --data private_key=$MONGODB_ATLAS_PRIVATE_API_KEY \
  --data project_id=$MONGODB_ATLAS_PROJECT_ID \
  atlas-creds
```

### Using the Atlas service with a simple container

The following Acornfile defines 2 items:
- a reference to the *atlas* service
- a container named *app* using this service

The container only tries to connect to the database using the MONGODB_URL provided in the env variable, this one is created from the service's properties: 

```
services: db: {
  image: "ghcr.io/lucj/acorn-mongo-atlas:v#.#.#"
  serviceArgs: {
    dbName: "mydb"
  }
}

containers: app: {
  image: "mongo:6.0.5"
  entrypoint: ["/bin/sh", "-c", "/check-db.sh"]
  env: {
    DB_HOST: "@{service.db.address}"
    DB_NAME: "@{service.db.data.dbName}"
    DB_PROTO: "@{service.db.data.proto}"
    DB_USER: "@{service.db.secrets.user.username}"
    DB_PASS: "@{service.db.secrets.user.password}"
  }
  files: "/check-db.sh": """
    echo "Will try to connect to cluster"
    while true; do
      echo "=> testing DB connection..."
      mongosh ${DB_PROTO}://${DB_HOST} -u ${DB_USER} -p ${DB_PASS} --eval "db.adminCommand('ping')" 
      if [ $? -eq 0 ]; then
        break
      else
        sleep 5
      fi
    done
    echo "connected to the DB"
    sleep 3600
  """
}
```

This simple application can be run with the following command:

```
acorn run -n app
```

From Atlas dashboard we could see a MongoDB cluster was automatically created.

Also, from the *app* container logs we can see the connection was successfull after the second attempt:

```
# acorn logs app
app-9b6876cbb-49x88: Will try to connect to [mongodb+srv://l4rcsrbw:wk9d5cgfkxf7hk8d@test.9flmpis.mongodb.net]
app-9b6876cbb-49x88: => testing DB connection...
app-9b6876cbb-49x88: Current Mongosh Log ID:    646a6d1bfaedda3a9caa08a1
app-9b6876cbb-49x88: Connecting to:             mongodb+srv://<credentials>@test.9flmpis.mongodb.net/?appName=mongosh+1.8.2
app-9b6876cbb-49x88: MongoServerError: bad auth : Authentication failed.
app-9b6876cbb-49x88: => testing DB connection...
app-9b6876cbb-49x88: Current Mongosh Log ID:    646a6d21847e03e28677ceab
app-9b6876cbb-49x88: Connecting to:             mongodb+srv://<credentials>@test.9flmpis.mongodb.net/?appName=mongosh+1.8.2
app-9b6876cbb-49x88: Using MongoDB:             6.0.6
app-9b6876cbb-49x88: Using Mongosh:             1.8.2
app-9b6876cbb-49x88: 
app-9b6876cbb-49x88: For mongosh info see: https://docs.mongodb.com/mongodb-shell/
app-9b6876cbb-49x88: 
app-9b6876cbb-49x88: 
app-9b6876cbb-49x88: To help improve our products, anonymous usage data is collected and sent to MongoDB periodically (https://www.mongodb.com/legal/privacy-policy).
app-9b6876cbb-49x88: You can opt-out by running the disableTelemetry() command.
app-9b6876cbb-49x88: 
app-9b6876cbb-49x88: { ok: 1 }
```

We've seen all to use a service right from a (simple) application container. In the next part we will use in a more interesting application. Before going to the next part, we delete the Acorn app and remove the Atlas cluster from the dashboard (as we've done previously).

### Using the atlas service with a microservice application

[https://webhooks.app/](https://webhooks.app/) is a microservice application which purpose is to provide a webhook (HTTP POST endpoint) on the fly, it is mainly dedicated to tests and demos. The source code is available in GitLab [https://gitlab.com/web-hook](https://gitlab.com/web-hook), each time a change is done in one of the microservices the application is build and pushed to the Docker Hub as an Acorn image in [https://hub.docker.com/r/lucj/webhooksapp/tags](https://hub.docker.com/r/lucj/webhooksapp/tags).

The Acornfile used to build the Acorn image of the Webhooks application ([https://gitlab.com/web-hook/config/-/blob/main/apps/acorn/Acornfile](https://gitlab.com/web-hook/config/-/blob/main/apps/acorn/Acornfile)) now makes reference to the Atlas service. 

In order to run the app and ensure it uses a MongoDB Atlas cluster created on the fly, we just need to use the *--atlas* flag as follows:

```
$ acorn run -n webhook lucj/webhooksapp --atlas
...

┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
| STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[5] UPTODATE[5] OK |
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

The Atlas cluster is correctly created (this can be verified from the Atlas dashboard) and a HTTP endpoint is returned after a few tens of seconds. Using this endpoint we can access the application and verify it's working fine sending a dummy payload.

![Webhooks app](../images/webhooks-1.png)

![Webhooks app](../images/webhooks-2.png)