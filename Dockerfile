FROM node:24-slim

WORKDIR /app

# Environment variables
ENV NODE_OPTIONS="--max-old-space-size=8192" \
    NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000 \
    BRANCH=1.11.0

# Copy the startup script
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh && \
    chown -R 1000:1000 /app

# Install required system packages
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    git \
    curl \
    iputils-ping \
    vim \
    && rm -rf /var/lib/apt/lists/*

USER node

# Clone the Recogito server
RUN git clone --depth 1 --branch "${BRANCH}" \
    https://github.com/recogito/recogito-server.git

# Replace the server configuration
RUN curl -fL \
    "https://raw.githubusercontent.com/recogito/recogito-studio/${BRANCH}/docker/config/config.json" \
    -o /app/recogito-server/config.json

WORKDIR /app/recogito-server

# Install server dependencies
RUN --mount=type=secret,uid=1000,gid=1000,id=secrets_env,dst=/secrets_env \
    --mount=type=cache,target=/tmp/cache \
    set -e; \
    if [ -f /secrets_env ]; then . /secrets_env; fi; \
    npm init -y; \
    npm install; \
    npm install supabase

WORKDIR /app

# Clone the Recogito client
RUN git clone --depth 1 --branch "${BRANCH}" \
    https://github.com/recogito/recogito-client.git

# Download the invite template
RUN mkdir -p /app/recogito-client/public/templates && \
    curl -fL \
    https://raw.githubusercontent.com/recogito/recogito-client/main/public/templates/invite.html \
    -o /app/recogito-client/public/templates/invite.html

# Replace the client configuration
RUN curl -fL \
    "https://raw.githubusercontent.com/recogito/recogito-studio/${BRANCH}/docker/config/config.json" \
    -o /app/recogito-client/src/config.json

# Copy the custom Astro configuration
COPY --chown=node:node astro.config.node.mjs \
    /app/recogito-client/astro.config.node.mjs

WORKDIR /app/recogito-client

# Fix German timeago locale import used by notifications
RUN sed -i \
    's|timeago.js/lib/lang/de|timeago.js/esm/lang/de|' \
    src/components/TimeAgo/TimeAgo.tsx

# Install dependencies, align Trigger.dev versions, then build
RUN --mount=type=secret,uid=1000,gid=1000,id=secrets_env,dst=/secrets_env \
    --mount=type=cache,target=/tmp/cache \
    set -e; \
    if [ -f /secrets_env ]; then . /secrets_env; fi; \
    npm install --include=dev; \
    npm install @recogito/plugin-ner; \
    npm install @recogito/plugin-tei-inliner; \
    npm install @recogito/plugin-revisions; \
    npm install @recogito/plugin-geotagging; \
    npm install --include=dev --save-exact \
        trigger.dev@4.7.4 \
        @trigger.dev/sdk@4.7.4 \
        @trigger.dev/build@4.7.4; \
    cd /app/recogito-client/node_modules/@recogito/plugin-ner; \
    npm install --include=dev --save-exact \
        trigger.dev@4.7.4 \
        @trigger.dev/sdk@4.7.4 \
        @trigger.dev/build@4.7.4; \
    cd /app/recogito-client; \
    npm run build-node

WORKDIR /app

EXPOSE 3000

CMD ["sh", "-c", "/app/entrypoint.sh"]
