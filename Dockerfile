FROM lucj/atlas-cli:v0.2.0
COPY ./scripts/render.sh /acorn/scripts/render.sh
ENTRYPOINT ["/acorn/scripts/render.sh"]