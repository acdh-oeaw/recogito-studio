FROM  node:alpine

WORKDIR /app

ENV NODE_OPTIONS="--max-old-space-size=8192" \
    NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000 \
    BRANCH=develop

# Copy the post-deployment script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
    
# Update the package list and install the necessary packages
RUN apk update && apk add --no-cache \
    git \
    vim \
    curl \
    iputils

# Clone the Recogito server repository
RUN git clone --depth 1 --branch ${BRANCH} https://github.com/recogito/recogito-server.git

# Remove the default server config and download the custom config
RUN rm -f ./recogito-server/config.json && \
    curl -LJ https://raw.githubusercontent.com/recogito/recogito-studio/${BRANCH}/docker/config/config.json -o ./recogito-server/config.json

WORKDIR /app/recogito-server    

# Build the server
RUN --mount=type=secret,id=secrets_env,dst=/secrets_env \
    --mount=type=cache,target=/tmp/cache \
    if [ -f /secrets_env ]; then . /secrets_env; fi; \
    npm init -y; npm install

WORKDIR /app   
# Clone the Recogito client repository
RUN git clone --depth 1 --branch ${BRANCH} https://github.com/recogito/recogito-client.git

# Remove the default client config and download the custom config
RUN rm -f ./recogito-client/src/config.json && \
    curl -LJ https://raw.githubusercontent.com/recogito/recogito-studio/${BRANCH}/docker/config/config.json -o ./recogito-client/src/config.json && \
    echo "Add custom astro config file" && \
    rm -f ./recogito-client/astro.config.node.mjs

COPY astro.config.node.mjs /app/recogito-client/astro.config.node.mjs 

WORKDIR /app/recogito-client

# Introduce env vars from Github
RUN --mount=type=secret,id=secrets_env,dst=/secrets_env \
    --mount=type=cache,target=/tmp/cache \
    if [ -f /secrets_env ]; then . /secrets_env; fi; \
    npm install @recogito/plugin-ner; npm install @recogito/plugin-tei-inliner; npm install @recogito/plugin-revisions; npm install @recogito/plugin-geotagging; npm install; npm run build-node

WORKDIR /app    
# Expose the necessary port
EXPOSE 3000

# Switch to the non-root user
RUN chown -R 1000:1000 /app
USER node  

# Start the server and client applications
CMD ["sh", "-c", "/app/entrypoint.sh"]
