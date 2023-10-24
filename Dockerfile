FROM alpine:3.18
ARG ATLAS_CLI_VERSION="1.12.2"
ARG action=create
RUN apk add -u jq
RUN OS="$(uname | tr '[:upper:]' '[:lower:]')" \
    ARCH="$(uname -m | sed -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    wget https://fastdl.mongodb.org/mongocli/mongodb-atlas-cli_${ATLAS_CLI_VERSION}_${OS}_${ARCH}.tar.gz && \
    tar -xf mongodb-atlas-cli_${ATLAS_CLI_VERSION}_${OS}_${ARCH}.tar.gz && \
    mv mongodb-atlas-cli_${ATLAS_CLI_VERSION}_${OS}_${ARCH}/bin/atlas /usr/local/bin && \
    rm -r mongodb-atlas-cli_${ATLAS_CLI_VERSION}_${OS}_${ARCH}.tar.gz mongodb-atlas-cli_${ATLAS_CLI_VERSION}_${OS}_${ARCH}
COPY ./scripts/${action}.sh /acorn/scripts/render.sh
ENTRYPOINT ["/acorn/scripts/render.sh"]