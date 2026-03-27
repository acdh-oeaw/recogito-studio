FROM  node:24-slim

WORKDIR /app

# Add env vars
ENV NODE_OPTIONS="--max-old-space-size=8192" \
    NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000 \
    BRANCH=1.9.6

# Copy the post-deployment script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh; \
    chown -R 1000:1000 /app
    
# Update the package list and install the necessary packages

RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    git \
    curl \
    iputils-ping \
    vim \
    && rm -rf /var/lib/apt/lists/*

    
# Switch to the non-root user
USER node

# Clone the Recogito server repository
RUN git clone --depth 1 --branch ${BRANCH} https://github.com/recogito/recogito-server.git

# Remove the default server config and download the custom config
RUN rm -f ./recogito-server/config.json && \
    curl -LJ https://raw.githubusercontent.com/recogito/recogito-studio/${BRANCH}/docker/config/config.json -o ./recogito-server/config.json

WORKDIR /app/recogito-server    

# Build the server
RUN --mount=type=secret,uid=1000,gid=1000,id=secrets_env,dst=/secrets_env \
    --mount=type=cache,target=/tmp/cache \
    if [ -f /secrets_env ]; then . /secrets_env; fi; \
    npm init -y; npm install; \
    npm install supabase

WORKDIR /app   
# Clone the Recogito client repository
RUN git clone --depth 1 --branch ${BRANCH} https://github.com/recogito/recogito-client.git

# Add missing invite template (only exists on main branch, not in 1.9.7)
RUN mkdir -p /app/recogito-client/public/templates && \
    curl -LJ https://raw.githubusercontent.com/recogito/recogito-client/main/public/templates/invite.html \
    -o /app/recogito-client/public/templates/invite.html

# Remove the default client config and download the custom config
RUN rm -f ./recogito-client/src/config.json && \
    curl -LJ https://raw.githubusercontent.com/recogito/recogito-studio/${BRANCH}/docker/config/config.json -o ./recogito-client/src/config.json && \
    echo "Add custom astro config file" && \
    rm -f ./recogito-client/astro.config.node.mjs

COPY astro.config.node.mjs /app/recogito-client/astro.config.node.mjs 

WORKDIR /app/recogito-client

# Introduce env vars from Github
RUN --mount=type=secret,uid=1000,gid=1000,id=secrets_env,dst=/secrets_env \
    --mount=type=cache,target=/tmp/cache \
    if [ -f /secrets_env ]; then . /secrets_env; fi; \
    npm install; \
    npm install @recogito/plugin-ner; npm install @recogito/plugin-tei-inliner; \
    npm install @recogito/plugin-revisions; npm install @recogito/plugin-geotagging; \
    npm run build-node; \
    cd /app/recogito-client/node_modules/@recogito/plugin-ner; \
    npm install trigger.dev@4.4.3; \
    npm install @trigger.dev/sdk@4.4.3; \
    npm install @trigger.dev/build@4.4.3

WORKDIR /app    
# Expose the necessary port
EXPOSE 3000

# Start the server and client applications
CMD ["sh", "-c", "/app/entrypoint.sh"]
