FROM lucj/atlas-cli:1.12.2
ARG action=create
COPY ./scripts/${action}.sh /acorn/scripts/render.sh
ENTRYPOINT ["/acorn/scripts/render.sh"]